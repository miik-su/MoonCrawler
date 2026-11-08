///|
/// Epoch milliseconds are the only timestamps serialized to disk or compared to HTTP dates.
pub fn epoch_ms() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
/// Opaque process timer. Never persist or interpret as a calendar date.
pub fn tick_ms() -> Int64 {
  @async.now()
}
