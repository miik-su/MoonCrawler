///|
pub struct Engine {
  config : @core.Config
  frontier : @frontier.Frontier
  priv scheduler : @scheduler.Scheduler
  priv robots : @robots.Cache
  priv robots_locks : Map[String, OriginFlight]
  priv admitted : Map[String, Int32]
  priv mut stop_requested : async () -> Bool
  priv checkpoint_mutex : @async.Mutex
  priv fetcher : &@fetcher.UnsafeFetcher
  priv parser : &@parser.Parser
  priv store : &@storage.Storage
  priv processors : Array[&@pipeline.Processor]
  priv pages : Map[String, @core.Page]
  priv changed_pages : Map[String, @core.Page]
  priv mut checkpoint_count : Int32
  priv mut initialized : Bool
  priv mut stopped : Bool
}

///|
pub fn Engine::new(
  config : @core.Config,
  fetcher : &@fetcher.UnsafeFetcher,
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
      @frontier.restore(config, s.tasks, @clock.epoch_ms())
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
    robots: @robots.Cache::new(capacity=config.robots_cache_capacity),
    robots_locks: {},
    admitted: {},
    stop_requested: () => false,
    checkpoint_mutex: @async.Mutex(),
    fetcher,
    parser,
    store,
    processors,
    pages,
    changed_pages: {},
    checkpoint_count: 0,
    initialized: snapshot is Some(_),
    stopped: false,
  }
}

///|
pub fn Engine::seed(self : Engine, url : String) -> Bool raise {
  let parsed = @url.parse(url)
  @security.check_url(parsed, self.config)
  self.frontier.enqueue(
    { url: parsed, depth: 0, priority: 0, source: "", },
    @clock.epoch_ms(),
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
    saved_at: @clock.epoch_ms(),
  }
}

///|
async fn Engine::checkpoint(self : Engine) -> Unit {
  self.checkpoint_mutex.acquire()
  defer self.checkpoint_mutex.release()
  let tasks = self.frontier.drain_changes()
  let pages = self.changed_pages.values().to_array()
  self.changed_pages.clear()
  if tasks.is_empty() && pages.is_empty() {
    return
  }
  self.store.commit_batch(self.config, tasks, pages, @clock.epoch_ms())
  self.checkpoint_count += 1
  if self.checkpoint_count % 100 == 0 {
    self.store.save(self.snapshot())
  }
}

///|
async fn Engine::send(
  self : Engine,
  url : @url.Url,
  robots_request~ : Bool = false,
) -> @core.Response {
  @security.check_url(url, self.config)
  if (self.stop_requested)() {
    raise @core.Paused
  }
  while !self.scheduler.acquire(url.host, @async.now()) {
    if (self.stop_requested)() {
      raise @core.Paused
    }
    @async.sleep(25)
  }
  defer self.scheduler.release(url.host)
  // Even custom transports must satisfy the complete-hop timeout contract.
  @async.with_timeout(self.config.timeout_ms, () => {
    let config = if robots_request {
      { ..self.config, max_body_bytes: self.config.max_robots_bytes, }
    } else {
      self.config
    }
    self.fetcher.fetch(url, config)
  })
}

///|
async fn Engine::allowed_by_robots(self : Engine, url : @url.Url) -> Bool {
  if !self.config.robots {
    return true
  }
  let flight = self.robots_locks.get_or_init(url.origin(), () => OriginFlight::{
    lock: @async.Mutex(),
    waiters: 0,
  })
  flight.waiters += 1
  defer {
    flight.waiters -= 1
    if flight.waiters == 0 {
      self.robots_locks.remove(url.origin()) |> ignore
    }
  }
  flight.lock.acquire()
  defer flight.lock.release()
  let rules = match self.robots.get(url.origin(), @async.now()) {
    Some(rules) => rules
    None => {
      let mut target = @url.parse(url.origin() + "/robots.txt")
      let response : @core.Response? = try {
        for hops = 0; ; hops = hops + 1 {
          let response = self.send(target, robots_request=true)
          if [301, 302, 303, 307, 308].contains(response.status) &&
            hops < self.config.max_robots_redirects {
            guard response.headers.get("location") is Some(location) else {
              raise @core.Protocol("robots redirect lacks Location")
            }
            let next = @url.resolve(target, location)
            if target.scheme == "https" && next.scheme != "https" {
              raise @core.Security("TLS downgrade")
            }
            target = next
            self.defer_response(response, target.host)
          } else {
            break Some(response)
          }
        }
      } catch {
        @core.Paused => raise @core.Paused
        _ => None
      }
      match response {
        Some(r) => {
          if r.status == 429 || r.status == 503 {
            self.defer_response(r, target.host)
          }
          self.robots.update(url.origin(), r.status, r.body, @async.now())
        }
        None => self.robots.update(url.origin(), 503, "", @async.now())
      }
    }
  }
  rules.allows(self.config.user_agent, url.path + url.query)
}

///|
async fn Engine::execute(self : Engine, lease : @core.Task) -> Unit {
  let mut target = if lease.redirect_url.is_empty() {
    lease.request.url
  } else {
    @url.parse(lease.redirect_url)
  }
  let visited : Map[String, Bool] = Map([])
  let response = for hops = lease.redirect_hops; ; hops = hops + 1 {
    if !self.config.accepts({ ..lease.request, url: target, }) {
      raise @core.Policy("redirect target rejected by crawl policy")
    }
    @security.check_url(target, self.config)
    if visited.contains(target.key()) {
      raise @core.Protocol("redirect loop")
    }
    visited[target.key()] = true
    if !self.allowed_by_robots(target) {
      raise @core.RobotsDenied
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
      if !self.config.accepts({ ..lease.request, url: target, }) {
        raise @core.Policy("redirect target rejected by crawl policy")
      }
      @security.check_url(target, self.config)
      let delay = match response.headers.get("retry-after") {
        Some(v) => @retry.retry_after(v, now_ms=@clock.epoch_ms()).unwrap_or(0)
        None => 0
      }
      self.frontier.follow(
        lease,
        target,
        hops + 1,
        @clock.epoch_ms() + delay.to_int64(),
      )
      return
    } else {
      break response
    }
  }
  if @retry.retryable(response.status) {
    let floor = match response.headers.get("retry-after") {
      Some(v) => @retry.retry_after(v, now_ms=@clock.epoch_ms())
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
      @clock.epoch_ms(),
      "HTTP \{response.status}",
      retry_delay=delay,
    )
    return
  }
  if response.status == 304 && !self.pages.contains(target.key()) {
    raise @core.Protocol("304 without cached representation")
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
    self.changed_pages[page.url] = page
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
        ignore(self.frontier.enqueue(request, @clock.epoch_ms()))
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
      self.frontier.claim(@clock.epoch_ms(), eligible=r => {
        self.admitted.get(r.url.host).unwrap_or(0) < self.config.per_host &&
        self.scheduler.eligible(r.url.host, @async.now())
      }) {
      None => @async.sleep(20)
      Some(lease) => {
        let host = lease.request.url.host
        self.admitted[host] = self.admitted.get(host).unwrap_or(0) + 1
        defer {
          self.admitted[host] = self.admitted[host] - 1
        }
        self.checkpoint()
        self.execute(lease) catch {
          @core.Paused => {
            self.frontier.requeue(lease, @clock.epoch_ms())
            self.stopped = true
          }
          @core.RobotsDenied =>
            self.frontier.skip(lease, BlockedByRobots, "robots denied")
          @core.Policy(message) =>
            self.frontier.skip(lease, SkippedByPolicy, message)
          @core.Network(_) | @async.TimeoutError =>
            self.frontier.fail(
              lease,
              @clock.epoch_ms(),
              "transient network failure",
              retry_delay=@retry.delay(
                lease.attempts,
                @async.now().to_int().reinterpret_as_uint(),
              ),
            )
          e => self.frontier.fail(lease, @clock.epoch_ms(), e.to_string())
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
  self.stop_requested = should_stop
  if !self.initialized {
    if self.store.load() is Some(_) {
      raise @core.Storage("existing job requires an explicitly loaded snapshot")
    }
    self.store.save(self.snapshot())
    self.frontier.drain_changes() |> ignore
    self.initialized = true
  }
  self.checkpoint()
  @async.with_task_group(group => {
    for _ in 0..<self.config.concurrency {
      group.spawn_bg(() => self.worker(should_stop))
    }
  })
  self.checkpoint()
}
