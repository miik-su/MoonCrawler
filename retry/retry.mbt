///|
pub fn retryable(status : Int32) -> Bool {
  status == 408 ||
  status == 429 ||
  status == 500 ||
  status == 502 ||
  status == 503 ||
  status == 504
}

///|
/// Retry-After delta seconds or IMF-fixdate, capped to one day.
pub fn retry_after(value : String, now_ms~ : Int64 = 0L) -> Int32? {
  let s = value.trim().to_owned()
  if s.is_empty() {
    return None
  }
  if s.iter().any(c => c < '0' || c > '9') {
    return http_date_delay(s, now_ms)
  }
  let mut n = 0
  for c in s {
    n = (n * 10 + c.to_int() - 48).min(86401)
  }
  if n > 86400 {
    Some(86400000)
  } else {
    Some(n * 1000)
  }
}

///|
/// Injected entropy makes retry schedules deterministic in tests. Delay is capped at 60 seconds.
pub fn delay(
  attempt : Int32,
  entropy : UInt32,
  retry_after_ms? : Int32,
) -> Int32 {
  let exponent = attempt.max(1).min(7) - 1
  let base = (1000 << exponent).min(60000)
  let jitter = (entropy % (base / 4 + 1).reinterpret_as_uint()).reinterpret_as_int()
  (base + jitter)
  .min(60000)
  .max(retry_after_ms.unwrap_or(0).max(0).min(86400000))
}

///|
fn http_date_delay(value : String, now_ms : Int64) -> Int32? {
  let value = normalize_date(value, now_ms).unwrap_or("")
  let fields = value.split(" ").to_array()
  if fields.length() != 6 || fields[5] != "GMT" {
    return None
  }
  if !["Sun,", "Mon,", "Tue,", "Wed,", "Thu,", "Fri,", "Sat,"].contains(
      fields[0].to_owned(),
    ) {
    return None
  }
  let months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let month = for i, m in months {
    if m == fields[2].to_owned() {
      break i + 1
    }
  } nobreak {
    return None
  }
  let day = @string.parse_int(fields[1]) catch { _ => return None }
  let year = @string.parse_int(fields[3]) catch { _ => return None }
  let clock = fields[4].to_owned().split(":").to_array()
  if clock.length() != 3 {
    return None
  }
  let hour = @string.parse_int(clock[0]) catch { _ => return None }
  let minute = @string.parse_int(clock[1]) catch { _ => return None }
  let second = @string.parse_int(clock[2]) catch { _ => return None }
  let date = @time.PlainDateTime::of(year, month, day, hour~, minute~, second~) catch {
    _ => return None
  }
  let delta = date.to_unix_second() * 1000L - now_ms
  Some(delta.max(0L).min(86400000L).to_int())
}
