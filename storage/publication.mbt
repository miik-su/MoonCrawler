///|
/// On Linux, synchronize the job directory before acknowledging publication
/// or reclaiming records referenced by the old index.
async fn sync_publication(directory : String) -> Unit {
  if @async.platform is Linux {
    let handle = @fs.open(directory, mode=ReadOnly)
    defer handle.close()
    handle.sync()
  }
}
