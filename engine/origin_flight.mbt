///|
priv struct OriginFlight {
  lock : @async.Mutex
  mut waiters : Int32
}
