///|
pub fn retryable(status : Int) -> Bool {
  status == 408 || status == 429 || status == 500 || status == 502 || status == 503 || status == 504
}

///|
/// Retry-After delta seconds. HTTP dates are handled by the transport in a future adapter.
pub fn retry_after(value : String) -> Int? {
  let s = value.trim().to_owned()
  if s.is_empty() || s.iter().any(c => c < '0' || c > '9') { return None }
  let n = @string.parse_int(s) catch { _ => return None }
  if n > 86400 { Some(86400000) } else { Some(n * 1000) }
}

///|
/// Injected entropy makes retry schedules deterministic in tests. Delay is capped at 60 seconds.
pub fn delay(attempt : Int, entropy : UInt, retry_after_ms? : Int) -> Int {
  let exponent = attempt.max(1).min(7) - 1
  let base = (1000 << exponent).min(60000)
  let jitter = (entropy % (base / 4 + 1).to_uint()).to_int()
  (base + jitter).min(60000).max(retry_after_ms.unwrap_or(0).max(0).min(86400000))
}
