///|
test "Sitemap keeps direct locations and decodes XML escaping" {
  let ns = " xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'"
  let document = @sitemap.parse(
    "<?xml version='1.0'?><urlset" +
    ns +
    "><url><loc>https://example.com/a?x=1&amp;y=2</loc><image:image><image:loc>https://example.com/image</image:loc></image:image></url></urlset>",
  )
  assert_true(document.kind is @sitemap.UrlSet)
  assert_eq(document.locations, ["https://example.com/a?x=1&y=2"])
  assert_true(
    @sitemap.parse("<sitemapindex" + ns + "/>").kind is @sitemap.Index,
  )
}

///|
test "Sitemap rejects unsupported declarations and invalid structure" {
  let root = "<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>"
  for
    value in [
      root + "<url/></urlset>",
      root + "<url><loc>https://example.com/&unknown;</loc></url></urlset>",
      root + "<url><loc>https://example.com/</loc></urlset>",
      "<!DOCTYPE urlset>" + root + "</urlset>",
    ] {
    assert_true(
      try @sitemap.parse(value) catch {
        @core.Protocol(_) => true
        _ => false
      } noraise {
        _ => false
      },
    )
  }
}
