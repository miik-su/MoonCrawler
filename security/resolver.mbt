///|
pub(all) suberror DnsError {
  Temporary
  NotFound
  Unknown
} derive(Debug)

///|
pub(open) trait Resolver {
  async fn resolve(Self, String, Int32) -> @socket.Addr raise DnsError
  async fn resolve_all(Self, String, Int32) -> Array[@socket.Addr] raise DnsError = _
}

///|
/// Adapters exposing full answer sets should override this method. The native
/// socket resolver currently exposes one selected IPv4 address, not the DNS RRset.
impl Resolver with fn resolve_all(self, host, port) {
  [self.resolve(host, port)]
}

///|
pub(all) struct SystemResolver {}

///|
pub extend SystemResolver with Resolver::{resolve, resolve_all}

///|
pub extend DnsError with @debug.Debug::{to_repr}

///|
pub impl Resolver for SystemResolver with fn resolve(_self, host, port) {
  @socket.Addr::resolve(host, port~, protocol=OnlyV4) catch {
    _ => raise Unknown
  }
}
