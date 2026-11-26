///|
let etag_key = "crawl.http.etag"

///|
let modified_key = "crawl.http.last-modified"

///|
let fingerprint_key = "crawl.http.fingerprint"

///|
fn valid_etag(value : String) -> Bool {
  let tag = if value.has_prefix("W/") { value[2:].to_owned() } else { value }
  tag.length() >= 2 &&
  tag.length() <= 1024 &&
  tag.has_prefix("\"") &&
  tag.has_suffix("\"") &&
  tag[1:tag.length() - 1]
  .to_owned()
  .iter()
  .all(c => c == '!' || (c >= '#' && c <= '~'))
}

///|
fn valid_modified(value : String) -> Bool {
  value.length() <= 64 &&
  value.has_suffix(" GMT") &&
  @retry.retry_after(value, now_ms=@clock.epoch_ms()) is Some(_)
}

///|
fn cacheable(response : @core.Response) -> Bool {
  !response.headers.contains("vary") &&
  !response.headers
  .get("cache-control")
  .unwrap_or("")
  .to_lower()
  .split(",")
  .any(v => v.trim() == "no-store")
}

///|
fn save_validators(page : @core.Page, response : @core.Response) -> Unit {
  page.metadata.remove(etag_key) |> ignore
  page.metadata.remove(modified_key) |> ignore
  page.metadata.remove(fingerprint_key) |> ignore
  if response.status != 200 || !cacheable(response) {
    return
  }
  if response.headers.get("etag") is Some(value) && valid_etag(value) {
    page.metadata[etag_key] = value
  }
  if response.headers.get("last-modified") is Some(value) &&
    valid_modified(value) {
    page.metadata[modified_key] = value
  }
  // Diagnostic only. The result never determines whether to reuse a page.
  let fingerprint = for c in response.body; hash = 14695981039346656037UL {
    continue (hash ^ c.to_int().to_uint64()) * 1099511628211UL
  } nobreak {
    hash
  }
  page.metadata[fingerprint_key] = fingerprint.to_string()
}

///|
/// Attach a stable previous-job reader and the same CurlFetcher used for normal
/// requests. The caller must keep the previous reader open and use the same
/// parser/pipeline. Opening it locks the previous job until the round ends.
pub fn Engine::use_previous(
  self : Engine,
  previous : @storage.PageReader,
  curl : @fetcher.CurlFetcher,
) -> Unit raise @core.CrawlError {
  if previous.config() != self.config {
    raise @core.Invalid(
      "conditional recrawl requires the previous job configuration",
    )
  }
  self.previous = Some((previous, curl))
}

///|
async fn Engine::fetch_page(
  self : Engine,
  url : @url.Url,
) -> (@core.Response, @core.Page?) {
  guard self.previous is Some((reader, curl)) &&
    reader.read_page(url.key()) is Some(page) else {
    return (self.send(url), None)
  }
  let headers : Map[String, String] = Map([])
  if page.metadata.get(etag_key) is Some(value) && valid_etag(value) {
    headers["if-none-match"] = value
  }
  if page.metadata.get(modified_key) is Some(value) && valid_modified(value) {
    headers["if-modified-since"] = value
  }
  if headers.is_empty() {
    return (self.send(url), None)
  }
  let response = self.send(url, validators=(curl, headers))
  if response.status == 304 {
    if response.headers.get("etag") is Some(value) &&
      headers.get("if-none-match") is Some(requested) {
      let actual_tag = if value.has_prefix("W/") {
        value[2:].to_owned()
      } else {
        value
      }
      let expected_tag = if requested.has_prefix("W/") {
        requested[2:].to_owned()
      } else {
        requested
      }
      if !valid_etag(value) || actual_tag != expected_tag {
        raise @core.Protocol("304 validator does not match cached page")
      }
    }
    if !cacheable(response) {
      page.metadata.remove(etag_key) |> ignore
      page.metadata.remove(modified_key) |> ignore
    }
  }
  (response, Some(page))
}
