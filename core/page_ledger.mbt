///|
pub struct PageLedger {
  priv sizes : Map[String, (Int32, Int32)]
  priv mut bytes : Int32
  priv mut metadata : Int32
}

///|
pub fn PageLedger::new() -> PageLedger {
  { sizes: {}, bytes: 0, metadata: 0, }
}

///|
pub fn PageLedger::check(
  self : PageLedger,
  config : Config,
  pages : Array[Page],
) -> (Int32, Int32) raise CrawlError {
  let seen : Map[String, Bool] = Map([])
  let mut bytes = self.bytes
  let mut metadata = self.metadata
  let mut count = self.sizes.length()
  for page in pages {
    if seen.contains(page.url) {
      raise Invalid("duplicate page identity in batch")
    }
    seen[page.url] = true
    let (size, meta) = validate_page(config, page)
    let old = self.sizes.get(page.url).unwrap_or((0, 0))
    if !self.sizes.contains(page.url) {
      count += 1
    }
    bytes += size - old.0
    metadata += meta - old.1
    if bytes > config.max_total_page_bytes ||
      metadata > config.max_total_metadata_bytes {
      raise Capacity("aggregate stored page budget")
    }
  }
  if count > config.max_pages ||
    bytes > config.max_total_page_bytes ||
    metadata > config.max_total_metadata_bytes {
    raise Capacity("aggregate stored page budget")
  }
  (bytes, metadata)
}

///|
pub fn PageLedger::commit(
  self : PageLedger,
  config : Config,
  pages : Array[Page],
) -> Unit raise CrawlError {
  let (bytes, metadata) = self.check(config, pages)
  for page in pages {
    self.sizes[page.url] = validate_page(config, page)
  }
  self.bytes = bytes
  self.metadata = metadata
}
