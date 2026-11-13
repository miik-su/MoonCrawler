///|
struct AnswerSet {
  values : Array[String]
}

///|
impl @security.Resolver for AnswerSet with fn resolve(_self, _host, _port) {
  raise @security.Unknown
}

///|
impl @security.Resolver for AnswerSet with fn resolve_all(self, _host, port) {
  self.values.map(ip => {
    @socket.Addr::parse("\{ip}:\{port}") catch {
      _ => raise @security.Unknown
    }
  })
}

///|
async test "mixed DNS answers fail closed regardless of ordering" {
  let config = { ..@core.Config::default(), allowed_hosts: ["example.com"], }
  let url = @url.parse("https://example.com/")
  for values in [["8.8.8.8", "10.0.0.1"], ["10.0.0.1", "8.8.8.8"], []] {
    assert_true(
      try
        @security.resolve_checked(url, config, resolver=AnswerSet::{ values, })
      catch {
        @core.Security(_) => true
        _ => false
      } noraise {
        _ => false
      },
    )
  }
  assert_eq(
    @security.resolve_checked(url, config, resolver=AnswerSet::{
      values: ["8.8.8.8", "1.1.1.1"],
    }),
    "8.8.8.8",
  )
}

///|
test "persisted page validation is not connection authorization" {
  let config = { ..@core.Config::default(), allowed_hosts: ["10.0.0.1"], }
  let page : @core.Page = {
    url: "http://10.0.0.1/",
    title: "",
    text: "archived",
    description: "",
    canonical: "",
    metadata: {},
    links: [],
    images: [],
  }
  @core.validate_page(config, page) |> ignore
  assert_true(
    try @security.check_url(@url.parse(page.url), config) catch {
      @core.Security(_) => true
      _ => false
    } noraise {
      _ => false
    },
  )
}
