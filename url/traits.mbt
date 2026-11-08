///|
pub extend UrlError with @debug.Debug::{to_repr}

///|
pub extend Url with @debug.Debug::{to_repr}

///|
pub extend Url with Eq::{equal, not_equal}

///|
pub extend Url with ToJson::{to_json}

///|
pub extend Url with @json.FromJson::{from_json}
