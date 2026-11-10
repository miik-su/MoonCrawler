///|
pub struct Scheduler {
  config : @core.Config
  active : Map[String, Int32]
  next : Map[String, Int64]
  mut running : Int32
  mut paused : Bool
}

///|
pub fn Scheduler::new(
  config : @core.Config,
) -> Scheduler raise @core.CrawlError {
  config.validate()
  { config, active: {}, next: {}, running: 0, paused: false, }
}

///|
pub fn Scheduler::eligible(
  self : Scheduler,
  host : String,
  now : Int64,
) -> Bool {
  !self.paused &&
  self.running < self.config.concurrency &&
  self.active.get(host).unwrap_or(0) < self.config.per_host &&
  self.next.get(host).unwrap_or(0L) <= now
}

///|
pub fn Scheduler::acquire(self : Scheduler, host : String, now : Int64) -> Bool {
  if !self.eligible(host, now) {
    return false
  }
  self.running += 1
  self.active[host] = self.active.get(host).unwrap_or(0) + 1
  self.next[host] = now + self.config.delay_ms.to_int64()
  true
}

///|
pub fn Scheduler::release(self : Scheduler, host : String) -> Unit {
  let n = self.active.get(host).unwrap_or(0)
  if n > 0 {
    self.active[host] = n - 1
    if n == 1 {
      self.active.remove(host) |> ignore
    }
    self.running -= 1
  }
}

///|
pub fn Scheduler::defer_host(
  self : Scheduler,
  host : String,
  until : Int64,
) -> Unit {
  self.next[host] = self.next.get(host).unwrap_or(0L).max(until)
}

///|
pub fn Scheduler::pause(self : Scheduler) -> Unit {
  self.paused = true
}

///|
pub fn Scheduler::unpause(self : Scheduler) -> Unit {
  self.paused = false
}

///|
pub fn Scheduler::prune(self : Scheduler, now : Int64) -> Unit {
  let expired = self.next
    .iter()
    .filter(entry => entry.1 <= now && !self.active.contains(entry.0))
    .map(entry => entry.0)
    .to_array()
  for host in expired {
    self.next.remove(host) |> ignore
  }
}
