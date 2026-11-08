///|
pub fn Frontier::follow(
  self : Frontier,
  lease : @core.Task,
  target : @url.Url,
  hops : Int32,
  due : Int64,
) -> Unit raise @core.CrawlError {
  let (key, current) = self.current(lease)
  self.tasks[key] = {
    ..current,
    state: RetryPending,
    redirect_url: target.key(),
    redirect_hops: hops,
    continuation: true,
    ready_at: due,
    lease_until: 0L,
  }
  self.dirty[key] = self.tasks[key]
  self.delayed.push((-due, key, current.generation))
}

///|
pub fn Frontier::requeue(
  self : Frontier,
  lease : @core.Task,
  now : Int64,
) -> Unit raise @core.CrawlError {
  let (key, current) = self.current(lease)
  self.tasks[key] = {
    ..current,
    state: Pending,
    attempts: (current.attempts - 1).max(0),
    ready_at: now,
    lease_until: 0L,
  }
  self.dirty[key] = self.tasks[key]
  self.delayed.push((-now, key, current.generation))
}

///|
pub fn Frontier::skip(
  self : Frontier,
  lease : @core.Task,
  state : @core.State,
  message : String,
) -> Unit raise @core.CrawlError {
  if state != SkippedByPolicy && state != BlockedByRobots {
    raise @core.Invalid("invalid skipped state")
  }
  let (key, current) = self.current(lease)
  self.tasks[key] = { ..current, state, error: message, lease_until: 0L, }
  self.dirty[key] = self.tasks[key]
  self.unfinished -= 1
}
