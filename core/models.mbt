///|
pub(all) suberror CrawlError {
  Invalid(String)
  Security(String)
  Capacity(String)
  Protocol(String)
  Network(String)
  Storage(String)
  StaleLease
} derive(Debug)

///|
pub(all) struct Request {
  url : @url.Url
  depth : Int
  priority : Int
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
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Task {
  request : Request
  state : State
  attempts : Int
  generation : Int
  ready_at : Int64
  lease_until : Int64
  error : String
} derive(Debug, ToJson, FromJson)

///|
pub(all) struct Response {
  url : @url.Url
  status : Int
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
  max_depth : Int
  max_pages : Int
  concurrency : Int
  per_host : Int
  delay_ms : Int
  timeout_ms : Int
  max_body_bytes : Int
  max_header_bytes : Int
  max_redirects : Int
  max_attempts : Int
  lease_ms : Int
  user_agent : String
  allowed_hosts : Array[String]
  denied_paths : Array[String]
  denied_extensions : Array[String]
  include_query : Bool
  robots : Bool
  allow_loopback : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn Config::default() -> Config {
  { max_depth: 3, max_pages: 1000, concurrency: 4, per_host: 1,
    delay_ms: 1000, timeout_ms: 15000, max_body_bytes: 2097152,
    max_header_bytes: 65536, max_redirects: 5, max_attempts: 3,
    lease_ms: 120000, user_agent: "MoonCrawler/0.1",
    allowed_hosts: [], denied_paths: [],
    denied_extensions: [".pdf", ".zip", ".png", ".jpg", ".js", ".css"],
    include_query: true, robots: true, allow_loopback: false }
}

///|
pub fn Config::validate(self : Config) -> Unit raise CrawlError {
  if self.max_depth < 0 || self.max_depth > 100 || self.max_pages <= 0 || self.max_pages > 1000000 ||
    self.concurrency <= 0 || self.concurrency > 128 || self.per_host <= 0 || self.per_host > self.concurrency ||
    self.delay_ms < 0 || self.timeout_ms <= 0 || self.timeout_ms > 300000 ||
    self.max_body_bytes <= 0 || self.max_body_bytes > 16777216 || self.max_header_bytes <= 0 || self.max_header_bytes > 1048576 ||
    self.max_redirects < 0 || self.max_redirects > 20 || self.max_attempts <= 0 || self.max_attempts > 10 ||
    self.lease_ms.to_int64() <= self.timeout_ms.to_int64() * 2L || self.user_agent.is_empty() ||
    self.user_agent.contains_any(chars="\r\n") {
    raise Invalid("configuration outside supported resource bounds")
  }
  for host in self.allowed_hosts {
    let url = @url.parse("https://" + host) catch { _ => raise Invalid("invalid allowed host") }
    if url.host != host || url.port != 443 || url.path != "/" { raise Invalid("allowed_hosts must contain normalized hostnames") }
  }
}

///|
pub fn Config::accepts(self : Config, request : Request) -> Bool {
  request.depth >= 0 && request.depth <= self.max_depth &&
  @url.allowed(request.url, self.allowed_hosts, denied_prefixes=self.denied_paths, denied_extensions=self.denied_extensions)
}
