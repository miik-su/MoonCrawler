///|
fn normalize_date(value : String, now_ms : Int64) -> String? {
  let f = value
    .split(" ")
    .filter(s => !s.is_empty())
    .map(s => s.to_owned())
    .to_array()
  if f.length() == 6 {
    return Some(f.join(" "))
  }
  if f.length() == 5 {
    return Some("\{f[0]}, \{f[2]} \{f[1]} \{f[4]} \{f[3]} GMT")
  }
  if f.length() != 4 ||
    ![
      "Sunday,", "Monday,", "Tuesday,", "Wednesday,", "Thursday,", "Friday,", "Saturday,",
    ].contains(f[0]) {
    return None
  }
  let d = f[1].split("-").to_array()
  if d.length() != 3 || d[2].length() != 2 {
    return None
  }
  let yy = @string.parse_int(d[2]) catch { _ => return None }
  if yy < 0 || yy > 99 {
    return None
  }
  let current = @time.PlainDate::from_unix_day(now_ms / 86400000L).year() catch {
    _ => return None
  }
  let candidate = current / 100 * 100 + yy
  let year = if candidate > current + 50 { candidate - 100 } else { candidate }
  Some("\{f[0][:3]}, \{d[0]} \{d[1]} \{year} \{f[2]} \{f[3]}")
}
