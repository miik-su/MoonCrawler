///|
// Saved job statistics are gauges because a restored job may roll back.
fn print_job_metrics(
  counts : Map[String, Int32],
  pages : Int32,
  attempts : Int32,
  retries : Int32,
) -> Unit {
  println("# TYPE mooncrawler_job_tasks gauge")
  for
    (state, label) in [
      (@core.Pending, "pending"),
      (@core.Running, "running"),
      (@core.RetryPending, "retry_pending"),
      (@core.Succeeded, "succeeded"),
      (@core.PermanentlyFailed, "permanently_failed"),
      (@core.Cancelled, "cancelled"),
      (@core.SkippedByPolicy, "skipped_by_policy"),
      (@core.BlockedByRobots, "blocked_by_robots"),
    ] {
    let value = counts.get(@json.to_json(state).stringify()).unwrap_or(0)
    println("mooncrawler_job_tasks{state=\"\{label}\"} \{value}")
  }
  for
    (name, value) in [
      ("mooncrawler_job_pages", pages),
      ("mooncrawler_job_task_attempts", attempts),
      ("mooncrawler_job_task_retries", retries),
    ] {
    println("# TYPE \{name} gauge")
    println("\{name} \{value}")
  }
}
