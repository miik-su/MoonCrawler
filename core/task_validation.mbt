///|
pub fn validate_task(config : Config, t : Task) -> Unit raise CrawlError {
  if t.continuation &&
    (t.attempts < 1 || t.redirect_hops < 1 || t.redirect_url.is_empty()) {
    raise Invalid("invalid redirect continuation")
  }
  if t.redirect_hops < 0 || t.redirect_hops > config.max_redirects {
    raise Invalid("invalid redirect checkpoint")
  }
  if !t.redirect_url.is_empty() {
    let target = @url.parse(t.redirect_url) catch {
      _ => raise Invalid("invalid redirect URL")
    }
    if !config.accepts({ ..t.request, url: target, }) {
      raise Invalid("redirect checkpoint outside crawl policy")
    }
  }
  let parsed = @url.parse(t.request.url.key()) catch {
    _ => raise Invalid("corrupt task URL")
  }
  if parsed != t.request.url ||
    !config.accepts(t.request) ||
    t.attempts < 0 ||
    t.attempts > config.max_attempts ||
    t.generation < t.attempts ||
    t.ready_at < 0L {
    raise Invalid("invalid task")
  }
}
