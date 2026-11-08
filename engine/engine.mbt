///|
pub struct Engine {
  config : @core.Config
  frontier : @frontier.Frontier
  priv scheduler : @scheduler.Scheduler
  priv robots : @robots.Cache
  priv robots_mutex : @async.Mutex
  priv checkpoint_mutex : @async.Mutex
  priv fetcher : &@fetcher.Fetcher
  priv parser : &@parser.Parser
  priv store : &@storage.Storage
  priv processors : Array[&@pipeline.Processor]
  priv pages : Map[String, @core.Page]
  priv mut stopped : Bool
}

///|
pub fn Engine::new(
  config : @core.Config,
  fetcher : &@fetcher.Fetcher,
  store : &@storage.Storage,
  parser~ : &@parser.Parser = @parser.HtmlParser::{ },
  processors~ : Array[&@pipeline.Processor] = [@pipeline.CleanText::{ }],
  snapshot? : @storage.Snapshot,
) -> Engine raise @core.CrawlError {
  config.validate()
  let frontier = match snapshot {
    None => @frontier.Frontier::new(config)
    Some(s) => {
      @storage.validate(s)
      if s.config != config {
        raise @core.Invalid("resume must use the saved configuration")
      }
      @frontier.restore(config, s.tasks, @async.now())
    }
  }
  let pages : Map[String, @core.Page] = Map([])
  if snapshot is Some(s) {
    for page in s.pages {
      pages[page.url] = page
    }
  }
  {
    config,
    frontier,
    scheduler: @scheduler.Scheduler::new(config),
    robots: @robots.Cache::new(),
    robots_mutex: @async.Mutex(),
    checkpoint_mutex: @async.Mutex(),
    fetcher,
    parser,
    store,
    processors,
    pages,
    stopped: false,
  }
}

///|
pub fn Engine::seed(self : Engine, url : String) -> Bool raise {
  let parsed = @url.parse(url)
  @security.check_url(parsed, self.config)
  self.frontier.enqueue(
    { url: parsed, depth: 0, priority: 0, source: "", },
    @async.now(),
  )
}

///|
pub fn Engine::pages(self : Engine) -> Array[@core.Page] {
  self.pages.values().to_array()
}

///|
pub fn Engine::snapshot(self : Engine) -> @storage.Snapshot {
  {
    version: 1,
    config: self.config,
    tasks: self.frontier.snapshot(),
    pages: self.pages(),
    saved_at: @async.now(),
  }
}

///|
async fn Engine::checkpoint(self : Engine) -> Unit {
  self.checkpoint_mutex.acquire()
  defer self.checkpoint_mutex.release()
  self.store.save(self.snapshot())
}

///|
async fn Engine::send(self : Engine, url : @url.Url) -> @core.Response {
  @security.check_url(url, self.config)
  while !self.scheduler.acquire(url.host, @async.now()) {
    @async.sleep(10)
  }
  defer self.scheduler.release(url.host)
  // Even custom transports must satisfy the complete-hop timeout contract.
  @async.with_timeout(self.config.timeout_ms, () => {
    self.fetcher.fetch(url, self.config)
  })
}

///|
async fn Engine::allowed_by_robots(self : Engine, url : @url.Url) -> Bool {
  if !self.config.robots {
    return true
  }
  self.robots_mutex.acquire()
  defer self.robots_mutex.release()
  let rules = match self.robots.get(url.origin(), @async.now()) {
    Some(rules) => rules
    None => {
      let mut target = @url.parse(url.origin() + "/robots.txt")
      let response : @core.Response? = try {
        for hops = 0; ; hops = hops + 1 {
          let response = self.send(target)
          if [301, 302, 303, 307, 308].contains(response.status) &&
            hops < self.config.max_redirects {
            guard response.headers.get("location") is Some(location) else {
              raise @core.Protocol("robots redirect lacks Location")
            }
            let next = @url.resolve(target, location)
            if target.scheme == "https" && next.scheme != "https" {
              raise @core.Security("TLS downgrade")
            }
            target = next
          } else {
            break Some(response)
          }
        }
      } catch {
        _ => None
      }
      match response {
        Some(r) =>
          self.robots.update(url.origin(), r.status, r.body, @async.now())
        None => self.robots.update(url.origin(), 503, "", @async.now())
      }
    }
  }
  rules.allows(self.config.user_agent, url.path + url.query)
}

///|
async fn Engine::execute(self : Engine, lease : @core.Task) -> Unit {
  let mut target = lease.request.url
  let visited : Map[String, Bool] = Map([])
  let response = for hops = 0; ; hops = hops + 1 {
    @security.check_url(target, self.config)
    if visited.contains(target.key()) {
      raise @core.Protocol("redirect loop")
    }
    visited[target.key()] = true
    if !self.allowed_by_robots(target) {
      raise @core.Protocol("robots denied")
    }
    let response = self.send(target)
    if [301, 302, 303, 307, 308].contains(response.status) {
      if hops >= self.config.max_redirects {
        raise @core.Protocol("redirect limit exceeded")
      }
      guard response.headers.get("location") is Some(location) else {
        raise @core.Protocol("redirect lacks Location")
      }
      let next = @url.resolve(target, location)
      if target.scheme == "https" && next.scheme != "https" {
        raise @core.Security("TLS downgrade")
      }
      target = next
    } else {
      break response
    }
  }
  if @retry.retryable(response.status) {
    let floor = match response.headers.get("retry-after") {
      Some(v) => @retry.retry_after(v, now_ms=@async.now())
      None => None
    }
    let delay = @retry.delay(
      lease.attempts,
      @async.now().to_int().reinterpret_as_uint(),
      retry_after_ms?=floor,
    )
    self.scheduler.defer_host(target.host, @async.now() + delay.to_int64())
    self.frontier.fail(
      lease,
      @async.now(),
      "HTTP \{response.status}",
      retry_delay=delay,
    )
    return
  }
  if response.status == 304 || response.status == 204 {
    self.frontier.complete(lease)
    return
  }
  if response.status < 200 || response.status >= 300 {
    raise @core.Protocol("HTTP \{response.status}")
  }
  let page = self.parser.parse(response)
  let processed = @pipeline.run(page, self.processors)
  // Link discovery and page insertion occur before completing the task and snapshotting.
  // Filtered pages also suppress discovery, making pipeline rejection predictable.
  if processed is Some(page) {
    self.pages[page.url] = page
    let nofollow = page.metadata.get("robots").unwrap_or("").to_lower()
    if !nofollow.contains("nofollow") && !nofollow.contains("none") {
      for link in page.links {
        let url = @url.parse(link) catch { _ => continue }
        let request : @core.Request = {
          url,
          depth: lease.request.depth + 1,
          priority: lease.request.priority,
          source: page.url,
        }
        ignore(self.frontier.enqueue(request, @async.now()))
      }
    }
  }
  self.frontier.complete(lease)
}

///|
async fn Engine::worker(self : Engine, should_stop : async () -> Bool) -> Unit {
  while !self.stopped && self.frontier.has_work() {
    if should_stop() {
      self.stopped = true
      break
    }
    match
      self.frontier.claim(@async.now(), eligible=r => {
        self.scheduler.eligible(r.url.host, @async.now())
      }) {
      None => @async.sleep(20)
      Some(lease) => {
        self.checkpoint()
        self.execute(lease) catch {
          @core.Network(_) | @async.TimeoutError =>
            self.frontier.fail(
              lease,
              @async.now(),
              "transient network failure",
              retry_delay=@retry.delay(
                lease.attempts,
                @async.now().to_int().reinterpret_as_uint(),
              ),
            )
          e => self.frontier.fail(lease, @async.now(), e.to_string())
        }
        self.checkpoint()
      }
    }
  }
}

///|
/// Cooperative pause stops new claims, drains in-flight tasks and persists a final checkpoint.
pub async fn Engine::run(
  self : Engine,
  should_stop~ : async () -> Bool = () => false,
) -> Unit {
  self.stopped = false
  self.checkpoint()
  @async.with_task_group(group => {
    for _ in 0..<self.config.concurrency {
      group.spawn_bg(() => self.worker(should_stop))
    }
  })
  self.checkpoint()
}
