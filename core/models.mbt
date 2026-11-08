///|
pub(all) suberror CrawlError {
  Invalid(String)
  Security(String)
  Capacity(String)
  Protocol(String)
  Network(String)
  Storage(String)
  StaleLease
  Policy(String)
  RobotsDenied
  Paused
} derive(Debug)

///|
pub(all) struct Request {
  url : @url.Url
  depth : Int32
  priority : Int32
  source : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) enum State {
  Pending
  Running
  Succeeded
  RetryPending
  PermanentlyFailed
  Cancelled
  SkippedByPolicy
  BlockedByRobots
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Task {
  request : Request
  state : State
  attempts : Int32
  generation : Int32
  ready_at : Int64
  lease_until : Int64
  error : String
  redirect_url : String
  redirect_hops : Int32
  continuation : Bool
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct Response {
  url : @url.Url
  status : Int32
  headers : Map[String, String]
  body : String
} derive(Debug)

///|
pub(all) struct Page {
  url : String
  title : String
  description : String
  text : String
  links : Array[String]
  images : Array[String]
  canonical : String
  metadata : Map[String, String]
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct Config {
  schema_version : Int32
  max_depth : Int32
  max_pages : Int32
  concurrency : Int32
  per_host : Int32
  delay_ms : Int32
  timeout_ms : Int32
  max_body_bytes : Int32
  max_header_bytes : Int32
  max_redirects : Int32
  max_attempts : Int32
  lease_ms : Int32
  user_agent : String
  allowed_hosts : Array[String]
  denied_paths : Array[String]
  denied_extensions : Array[String]
  include_query : Bool
  robots : Bool
  allow_loopback : Bool
  allow_any_public_host : Bool
  max_robots_redirects : Int32
  max_robots_bytes : Int32
  robots_cache_capacity : Int32
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Config::default() -> Config {
  {
    schema_version: 2,
    max_depth: 3,
    max_pages: 1000,
    concurrency: 4,
    per_host: 1,
    delay_ms: 1000,
    timeout_ms: 15000,
    max_body_bytes: 2097152,
    max_header_bytes: 65536,
    max_redirects: 5,
    max_attempts: 3,
    lease_ms: 120000,
    user_agent: "MoonCrawler/0.1",
    allowed_hosts: [],
    denied_paths: [],
    denied_extensions: [".pdf", ".zip", ".png", ".jpg", ".js", ".css"],
    include_query: true,
    robots: true,
    allow_loopback: false,
    allow_any_public_host: false,
    max_robots_redirects: 5,
    max_robots_bytes: 1048576,
    robots_cache_capacity: 256,
  }
}

///|
pub fn Config::validate(self : Config) -> Unit raise CrawlError {
  if self.schema_version != 2 {
    raise Invalid("unsupported config version")
  }
  if self.allowed_hosts.is_empty() && !self.allow_any_public_host {
    raise Invalid(
      "set allowed_hosts or explicitly enable allow_any_public_host",
    )
  }
  if self.delay_ms > 60000 ||
    self.max_robots_redirects < 5 ||
    self.max_robots_redirects > 20 ||
    self.max_robots_bytes < 512000 ||
    self.max_robots_bytes > 16777216 ||
    self.robots_cache_capacity < 1 ||
    self.robots_cache_capacity > 10000 {
    raise Invalid("invalid scheduling or robots limits")
  }
  if self.max_depth < 0 ||
    self.max_depth > 100 ||
    self.max_pages <= 0 ||
    self.max_pages > 100000 ||
    self.concurrency <= 0 ||
    self.concurrency > 128 ||
    self.per_host <= 0 ||
    self.per_host > self.concurrency ||
    self.delay_ms < 0 ||
    self.timeout_ms <= 0 ||
    self.timeout_ms > 300000 ||
    self.max_body_bytes <= 0 ||
    self.max_body_bytes > 16777216 ||
    self.max_header_bytes <= 0 ||
    self.max_header_bytes > 1048576 ||
    self.max_redirects < 0 ||
    self.max_redirects > 20 ||
    self.max_attempts <= 0 ||
    self.max_attempts > 10 ||
    self.lease_ms.to_int64() <= self.timeout_ms.to_int64() * 2L ||
    self.user_agent.is_empty() ||
    self.user_agent.contains_any(chars="\r\n") {
    raise Invalid("configuration outside supported resource bounds")
  }
  for host in self.allowed_hosts {
    let url = @url.parse("https://" + host) catch {
      _ => raise Invalid("invalid allowed host")
    }
    if url.host != host || url.port != 443 || url.path != "/" {
      raise Invalid("allowed_hosts must contain normalized hostnames")
    }
  }
}

///|
pub fn Config::accepts(self : Config, request : Request) -> Bool {
  self.host_allowed(request.url.host) &&
  request.depth >= 0 &&
  request.depth <= self.max_depth &&
  @url.allowed(
    request.url,
    self.allowed_hosts,
    denied_prefixes=self.denied_paths,
    denied_extensions=self.denied_extensions,
  )
}

///|
pub fn Config::host_allowed(self : Config, host : String) -> Bool {
  if self.allowed_hosts.is_empty() {
    self.allow_any_public_host
  } else {
    self.allowed_hosts.contains(host)
  }
}
