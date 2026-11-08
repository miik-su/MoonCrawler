///|
pub extend CrawlError with @debug.Debug::{to_repr}

///|
pub extend Request with @debug.Debug::{to_repr}

///|
pub extend Request with ToJson::{to_json}

///|
pub extend Request with @json.FromJson::{from_json}

///|
pub extend State with @debug.Debug::{to_repr}

///|
pub extend State with Eq::{equal, not_equal}

///|
pub extend State with ToJson::{to_json}

///|
pub extend State with @json.FromJson::{from_json}

///|
pub extend Task with @debug.Debug::{to_repr}

///|
pub extend Task with ToJson::{to_json}

///|
pub extend Task with @json.FromJson::{from_json}

///|
pub extend Response with @debug.Debug::{to_repr}

///|
pub extend Page with @debug.Debug::{to_repr}

///|
pub extend Page with ToJson::{to_json}

///|
pub extend Page with @json.FromJson::{from_json}

///|
pub extend Config with @debug.Debug::{to_repr}

///|
pub extend Config with Eq::{equal, not_equal}

///|
pub extend Config with ToJson::{to_json}

///|
pub extend Config with @json.FromJson::{from_json}
