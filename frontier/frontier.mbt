///|
/// Single async event-loop owner. Mutations never suspend; lease generations fence stale workers.
pub struct Frontier {
  config : @core.Config
  tasks : Map[String, @core.Task]
  priv ready : Map[
    String,
    @priority_queue.PriorityQueue[(Int32, Int32, String, Int32)],
  ]
  priv mut candidate_checks : Int32
  priv delayed : @priority_queue.PriorityQueue[(Int64, String, Int32)]
  priv mut sequence : Int32
  priv mut unfinished : Int32
  priv dirty : Map[String, @core.Task]
}

///|
pub fn Frontier::new(config : @core.Config) -> Frontier raise @core.CrawlError {
  config.validate()
  {
    config,
    tasks: {},
    ready: {},
    candidate_checks: 0,
    delayed: @priority_queue.PriorityQueue([]),
    sequence: 0,
    unfinished: 0,
    dirty: {},
  }
}

///|
pub fn Frontier::enqueue(
  self : Frontier,
  request : @core.Request,
  now : Int64,
) -> Bool {
  let key = request.url.key(include_query=self.config.include_query)
  if !self.config.accepts(request) ||
    self.tasks.contains(key) ||
    self.tasks.length() >= self.config.max_pages {
    return false
  }
  self.tasks[key] = {
    request,
    state: Pending,
    attempts: 0,
    generation: 0,
    ready_at: now,
    lease_until: 0L,
    error: "",
    redirect_url: "",
    redirect_hops: 0,
    continuation: false,
  }
  self.dirty[key] = self.tasks[key]
  self.delayed.push((-now, key, 0))
  self.unfinished += 1
  true
}

///|
pub fn Frontier::claim(
  self : Frontier,
  now : Int64,
  eligible~ : (@core.Request) -> Bool = _ => true,
) -> @core.Task? {
  while self.delayed.peek() is Some((time, key, generation)) && -time <= now {
    ignore(self.delayed.pop())
    if self.tasks.get(key) is Some(task) &&
      task.generation == generation &&
      (task.state == Pending || task.state == RetryPending) {
      self.sequence += 1
      self.ready
      .get_or_init(task.request.url.host, () => {
        @priority_queue.PriorityQueue([])
      })
      .push((task.request.priority, -self.sequence, key, generation))
    }
  }
  let mut winner : (Int32, Int32, String, Int32)? = None
  for _, queue in self.ready {
    while queue.peek() is Some((_, _, key, generation)) {
      let task = self.tasks[key]
      if task.generation == generation &&
        (task.state == Pending || task.state == RetryPending) {
        break
      }
      queue.pop() |> ignore
    }
    if queue.peek() is Some(entry) {
      self.candidate_checks += 1
      if eligible(self.tasks[entry.2].request) {
        if winner is None || entry > winner.unwrap() {
          winner = Some(entry)
        }
      }
    }
  }
  let best = winner.map(entry => {
    let task = self.tasks[entry.2]
    self.ready[task.request.url.host].pop() |> ignore
    (entry.2, task)
  })
  match best {
    None => None
    Some((key, task)) => {
      let running = {
        ..task,
        state: Running,
        attempts: task.attempts + (if task.continuation { 0 } else { 1 }),
        continuation: false,
        generation: task.generation + 1,
        lease_until: now + self.config.lease_ms.to_int64(),
      }
      self.tasks[key] = running
      self.dirty[key] = self.tasks[key]
      Some(running)
    }
  }
}

///|
fn Frontier::current(
  self : Frontier,
  lease : @core.Task,
) -> (String, @core.Task) raise @core.CrawlError {
  let key = lease.request.url.key(include_query=self.config.include_query)
  guard self.tasks.get(key) is Some(current) &&
    current.state == Running &&
    current.generation == lease.generation else {
    raise @core.StaleLease
  }
  (key, current)
}

///|
pub fn Frontier::complete(
  self : Frontier,
  lease : @core.Task,
) -> Unit raise @core.CrawlError {
  let (key, current) = self.current(lease)
  self.tasks[key] = { ..current, state: Succeeded, lease_until: 0L, error: "", }
  self.dirty[key] = self.tasks[key]
  self.unfinished -= 1
}

///|
pub fn Frontier::fail(
  self : Frontier,
  lease : @core.Task,
  now : Int64,
  message : String,
  retry_delay? : Int32,
) -> Unit raise @core.CrawlError {
  let (key, current) = self.current(lease)
  let state : @core.State = if retry_delay is Some(_) &&
    current.attempts < self.config.max_attempts {
    RetryPending
  } else {
    PermanentlyFailed
  }
  self.tasks[key] = {
    ..current,
    state,
    lease_until: 0L,
    ready_at: now + retry_delay.unwrap_or(0).max(0).to_int64(),
    error: message,
  }
  self.dirty[key] = self.tasks[key]
  if state == RetryPending {
    self.delayed.push(
      (
        -(now + retry_delay.unwrap_or(0).max(0).to_int64()),
        key,
        current.generation,
      ),
    )
  } else {
    self.unfinished -= 1
  }
}

///|
pub fn Frontier::recover_expired(self : Frontier, now : Int64) -> Int32 {
  let mut count = 0
  for key, task in self.tasks {
    if task.state == Running && task.lease_until <= now {
      self.tasks[key] = {
        ..task,
        state: if task.attempts < self.config.max_attempts {
          RetryPending
        } else {
          PermanentlyFailed
        },
        ready_at: now,
        lease_until: 0L,
        error: "lease expired",
      }
      self.dirty[key] = self.tasks[key]
      if task.attempts < self.config.max_attempts {
        self.delayed.push((-now, key, task.generation))
      } else {
        self.unfinished -= 1
      }
      count += 1
    }
  }
  count
}

///|
pub fn Frontier::snapshot(self : Frontier) -> Array[@core.Task] {
  self.tasks.values().to_array()
}

///|
pub fn Frontier::count(self : Frontier, state : @core.State) -> Int32 {
  self.tasks.values().filter(t => t.state == state).count()
}

///|
pub fn Frontier::has_work(self : Frontier) -> Bool {
  self.unfinished > 0
}

///|
pub fn Frontier::cancel(self : Frontier, url : @url.Url) -> Bool {
  let key = url.key(include_query=self.config.include_query)
  if self.tasks.get(key) is Some(task) &&
    (task.state == Pending || task.state == RetryPending) {
    self.tasks[key] = { ..task, state: Cancelled, }
    self.dirty[key] = self.tasks[key]
    self.unfinished -= 1
    true
  } else {
    false
  }
}

///|
/// Restore validates into a new frontier, then converts interrupted running tasks to retries.
pub fn restore(
  config : @core.Config,
  tasks : Array[@core.Task],
  now : Int64,
) -> Frontier raise @core.CrawlError {
  let frontier = Frontier::new(config)
  for t in tasks {
    @core.validate_task(config, t)
    let key = t.request.url.key(include_query=config.include_query)
    if frontier.tasks.contains(key) ||
      frontier.tasks.length() >= config.max_pages {
      raise @core.Invalid("duplicate or oversized checkpoint")
    }
    let was_running = t.state == Running
    let t = if was_running {
      {
        ..t,
        state: if t.attempts < config.max_attempts {
          RetryPending
        } else {
          PermanentlyFailed
        },
        ready_at: now,
        lease_until: 0L,
      }
    } else {
      t
    }
    frontier.tasks[key] = t
    if was_running {
      frontier.dirty[key] = t
    }
    if t.state == Pending || t.state == RetryPending {
      frontier.delayed.push((-t.ready_at, key, t.generation))
      frontier.unfinished += 1
    }
  }
  frontier
}
