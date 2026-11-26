///|
fn Engine::sitemap_allowed(
  self : Engine,
  url : @url.Url,
  origin : String,
) -> Bool {
  url.origin() == origin &&
  self.config.accepts({ url, depth: 0, priority: 0, source: "", })
}

///|
async fn Engine::get_sitemap(
  self : Engine,
  initial : @url.Url,
  origin : String,
) -> (@url.Url, @sitemap.Document) {
  let mut target = initial
  let visited : Map[String, Bool] = Map([])
  for hop in 0..<=self.config.max_redirects {
    if !self.sitemap_allowed(target, origin) || visited.contains(target.key()) {
      raise @core.Policy("Sitemap redirect outside scope or loop")
    }
    @security.check_url(target, self.config)
    visited[target.key()] = true
    if !self.allowed_by_robots(target) {
      raise @core.RobotsDenied
    }
    let response = self.send(
      target,
      body_limit=self.config.max_body_bytes.min(1048576),
    )
    if [301, 302, 303, 307, 308].contains(response.status) {
      guard response.headers.get("location") is Some(value) else {
        raise @core.Protocol("Sitemap redirect missing Location")
      }
      if hop == self.config.max_redirects {
        raise @core.Protocol("Sitemap redirect limit")
      }
      target = @url.resolve(target, value)
      self.defer_response(response, target.host)
    } else {
      if response.status != 200 {
        raise @core.Protocol("Sitemap HTTP \{response.status}")
      }
      return (target, @sitemap.parse(response.body))
    }
  }
  raise @core.Protocol("Sitemap redirect limit")
}

///|
async fn Engine::discover(
  self : Engine,
  roots : Array[String],
  origin : String,
) -> Int32 {
  let maps : Array[(@url.Url, Int32)] = []
  let seen : Map[String, Bool] = Map([])
  let pages : Map[String, @core.Request] = Map([])
  let fetched : Map[String, Bool] = Map([])
  let mut total = 0
  for item in roots {
    let url = @url.parse(item) catch { _ => continue }
    if self.sitemap_allowed(url, origin) && !seen.contains(url.key()) {
      if maps.length() >= 16 {
        raise @core.Capacity("Sitemap document limit")
      }
      seen[url.key()] = true
      maps.push((url, 0))
    }
  }
  let mut i = 0
  while i < maps.length() {
    let (map_url, depth) = maps[i]
    i += 1
    if fetched.contains(map_url.key()) {
      continue
    }
    let (url, document) = self.get_sitemap(map_url, origin)
    seen[url.key()] = true
    fetched[url.key()] = true
    let path = url.path.split("/").to_array()
    let directory = path[:path.length() - 1]
      .to_owned()
      .map(p => p.to_owned())
      .join("/") +
      "/"
    for value in document.locations {
      total += 1
      if total > 10000 {
        raise @core.Capacity("aggregate Sitemap location limit")
      }
      let candidate = @url.parse(value) catch { _ => continue }
      if !self.sitemap_allowed(candidate, origin) {
        continue
      }
      match document.kind {
        @sitemap.Index =>
          if !seen.contains(candidate.key()) {
            if depth >= 2 || maps.length() >= 16 {
              raise @core.Capacity("Sitemap index traversal limit")
            }
            seen[candidate.key()] = true
            maps.push((candidate, depth + 1))
          }
        @sitemap.UrlSet => {
          if !candidate.path.has_prefix(directory) {
            continue
          }
          @security.check_url(candidate, self.config) catch {
            _ => continue
          }
          let key = candidate.key(include_query=self.config.include_query)
          if !pages.contains(key) {
            pages[key] = {
              url: candidate,
              depth: 0,
              priority: 0,
              source: url.key(),
            }
          }
        }
      }
    }
  }
  let mut added = 0
  for _, request in pages {
    if self.frontier.enqueue(request, @clock.epoch_ms()) {
      added += 1
    }
  }
  added
}

///|
/// Before the first run, discover authorized pages from an explicit Sitemap.
/// The invocation is bounded and validates all fetched documents before enqueue.
pub async fn Engine::discover_sitemap(self : Engine, value : String) -> Int32 {
  if self.initialized {
    raise @core.Invalid("Sitemap discovery requires a new job")
  }
  let url = @url.parse(value)
  @security.check_url(url, self.config)
  if !self.sitemap_allowed(url, url.origin()) {
    raise @core.Policy("Sitemap outside crawl scope")
  }
  @async.with_timeout(60000, () => self.discover([url.key()], url.origin()))
}

///|
/// Fetch the site's Robots rules and discover its declared same-origin Sitemaps.
pub async fn Engine::discover_robots_sitemaps(
  self : Engine,
  value : String,
) -> Int32 {
  if self.initialized || !self.config.robots {
    raise @core.Invalid(
      "Robots Sitemap discovery requires a new job with Robots enabled",
    )
  }
  let seed = @url.parse(value)
  @security.check_url(seed, self.config)
  @async.with_timeout(60000, () => {
    self.allowed_by_robots(seed) |> ignore
    let roots = match self.robots.get(seed.origin(), @clock.tick_ms()) {
      Some(rules) => rules.sitemaps()
      None => []
    }
    self.discover(roots, seed.origin())
  })
}
