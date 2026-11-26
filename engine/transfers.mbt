///|
priv struct Transfers {
  mut started : Int64
  mut failed : Int64
  mut active : Int32
  mut elapsed_ms : Int64
  mut fetched : Int64
  mut revalidated : Int64
  mut identical : Int64
}

///|
fn Transfers::new() -> Transfers {
  {
    started: 0L,
    failed: 0L,
    active: 0,
    elapsed_ms: 0L,
    fetched: 0L,
    revalidated: 0L,
    identical: 0L,
  }
}

///|
/// Transfer counters are local to the engine instance, including Robots and Sitemap.
pub fn Engine::metrics(self : Engine) -> Json {
  let t = self.transfers
  let finished = t.started - t.active.to_int64()
  let retries = for task in self.frontier.snapshot(); sum = 0 {
    continue sum + (task.attempts - 1).max(0)
  } nobreak {
    sum
  }
  {
    "requests_started": Json::number(t.started.to_double()),
    "requests_failed": Json::number(t.failed.to_double()),
    "task_retries_started": Json::number(retries.to_double()),
    "active_requests": Json::number(t.active.to_double()),
    "average_fetch_ms": Json::number(
      if finished == 0L {
        0.0
      } else {
        t.elapsed_ms.to_double() / finished.to_double()
      },
    ),
    "pages_fetched": Json::number(t.fetched.to_double()),
    "pages_revalidated": Json::number(t.revalidated.to_double()),
    "conditional_200_same_fingerprint": Json::number(t.identical.to_double()),
    "robots_blocked": Json::number(
      self.frontier.count(BlockedByRobots).to_double(),
    ),
    "policy_skipped": Json::number(
      self.frontier.count(SkippedByPolicy).to_double(),
    ),
    "frontier_pending": Json::number(
      (self.frontier.count(Pending) + self.frontier.count(RetryPending)).to_double(),
    ),
    "stored_pages": Json::number(self.page_count().to_double()),
    "stored_page_bytes": Json::number(self.ledger.size().to_double()),
  }
}
