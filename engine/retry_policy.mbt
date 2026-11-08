///|
fn Engine::defer_response(
  self : Engine,
  response : @core.Response,
  host : String,
) -> Unit {
  if response.headers.get("retry-after") is Some(value) {
    if @retry.retry_after(value, now_ms=@clock.epoch_ms()) is Some(delay) {
      self.scheduler.defer_host(host, @clock.tick_ms() + delay.to_int64())
    }
  }
}
