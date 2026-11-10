///|
pub fn validate_page(
  config : Config,
  page : Page,
) -> (Int32, Int32) raise CrawlError {
  if page.title.length() > 4096 ||
    page.description.length() > 16384 ||
    page.canonical.length() > 8192 {
    raise Capacity("page scalar field budget")
  }
  let url = @url.parse(page.url) catch {
    _ => raise Invalid("invalid page URL")
  }
  if url.key() != page.url ||
    !config.accepts({ url, depth: 0, priority: 0, source: "", }) {
    raise Invalid("page identity outside canonical crawl scope")
  }
  if page.text.length() > 1048576 ||
    page.links.length() > 10000 ||
    page.images.length() > 10000 ||
    page.metadata.length() > 256 {
    raise Capacity("page field budget")
  }
  for key, value in page.metadata {
    if key.length() > 256 || value.length() > 4096 {
      raise Capacity("metadata field budget")
    }
  }
  let mut chars = page.text.length() +
    page.title.length() +
    page.description.length() +
    page.canonical.length()
  for list in [page.links, page.images] {
    for value in list {
      if value.length() > 8192 {
        raise Capacity("link field budget")
      }
      chars += value.length()
      if chars > 1048576 {
        raise Capacity("page character budget")
      }
    }
  }
  let bytes = @utf8.encode(@json.to_json(page).stringify()).length()
  let metadata = @utf8.encode(@json.to_json(page.metadata).stringify()).length()
  if bytes > 4194304 {
    raise Capacity("single page exceeds 4 MiB")
  }
  (bytes, metadata)
}
