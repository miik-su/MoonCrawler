///|
/// On Linux, synchronize the job directory before acknowledging publication
/// or reclaiming records referenced by the old index.
#cfg(platform="linux")
async fn sync_publication(directory : String) -> Unit {
  let handle = @fs.open(directory, mode=ReadOnly)
  defer handle.close()
  handle.sync()
}

///|
#cfg(not(platform="linux"))
fn sync_publication(_directory : String) -> Unit {
  ()
}
