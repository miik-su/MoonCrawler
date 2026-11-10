///|
pub(all) suberror DnsError {
  Temporary
  NotFound
  Unknown
} derive(Debug)

///|
pub(open) trait Resolver {
  async fn resolve(Self, String, Int32) -> @socket.Addr raise DnsError
}

///|
pub(all) struct SystemResolver {}

///|
pub extend SystemResolver with Resolver::{resolve}

///|
pub extend DnsError with @debug.Debug::{to_repr}

///|
pub impl Resolver for SystemResolver with fn resolve(_self, host, port) {
  @socket.Addr::resolve(host, port~, protocol=OnlyV4) catch {
    _ => raise Unknown
  }
}
