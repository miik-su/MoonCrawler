///|
pub extend Snapshot with @debug.Debug::{to_repr}

///|
pub extend Snapshot with ToJson::{to_json}

///|
pub extend Snapshot with @json.FromJson::{from_json}

///|
pub extend MemoryStore with Storage::{save, load}

///|
pub extend FileStore with Storage::{save, load}
