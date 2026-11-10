///|
struct FakeResolver {
  mode : Int32
}

///|
impl @security.Resolver for FakeResolver with fn resolve(self, _host, _port) {
  match self.mode {
    0 => raise @security.Temporary
    1 => raise @security.NotFound
    _ =>
      @socket.Addr::parse("127.0.0.1:80") catch {
        _ => raise @security.Unknown
      }
  }
}

///|
async test "typed DNS failures and private addresses stay distinct" {
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let url = @url.parse("http://example.com/")
  assert_true(
    try
      @security.resolve_checked(url, config, resolver=FakeResolver::{ mode: 0, })
    catch {
      @core.Network(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
  assert_true(
    try
      @security.resolve_checked(url, config, resolver=FakeResolver::{ mode: 1, })
    catch {
      @core.Protocol(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
  assert_true(
    try
      @security.resolve_checked(url, config, resolver=FakeResolver::{ mode: 2, })
    catch {
      @core.Security(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
}
