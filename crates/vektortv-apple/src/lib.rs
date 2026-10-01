//! Thread-safe, owned-JSON C boundary for the SwiftUI shells.
//! The shell owns credentials in Keychain and stream URLs only in memory.
use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    ffi::{c_char, CStr, CString},
    panic::{catch_unwind, AssertUnwindSafe},
    sync::{Mutex, MutexGuard},
};
use vektortv_core::{
    provider::{self, Connection},
    Channel, ChannelQuery, Error, ProgrammeQuery, Result, Store,
};

struct State {
    store: Store,
    connection: Option<Connection>,
    streams: HashMap<String, String>,
    revision: u64,
}
pub struct AppleCore {
    state: Mutex<State>,
    runtime: tokio::runtime::Runtime,
}

#[derive(Deserialize)]
#[serde(tag = "command", rename_all = "camelCase")]
enum Request {
    Restore {
        connection: Connection,
    },
    Disconnect,
    Status,
    Refresh {
        connection: Connection,
    },
    List {
        query: ChannelQuery,
    },
    Groups,
    Countries,
    FavoriteCountry {
        id: String,
        favorite: bool,
    },
    Guide,
    ShortGuide {
        id: String,
    },
    Schedule {
        id: String,
    },
    SearchProgrammes {
        #[serde(rename = "programmeQuery")]
        programme_query: ProgrammeQuery,
    },
    Stream {
        id: String,
    },
    Favorite {
        id: String,
        favorite: bool,
    },
    Watched {
        id: String,
    },
}

impl AppleCore {
    fn open(path: &str) -> Result<Self> {
        Ok(Self {
            state: Mutex::new(State {
                store: Store::open(path)?,
                connection: None,
                streams: HashMap::new(),
                revision: 0,
            }),
            runtime: tokio::runtime::Builder::new_multi_thread()
                .worker_threads(2)
                .enable_all()
                .build()
                .map_err(|_| Error::Network)?,
        })
    }
    fn state(&self) -> Result<MutexGuard<'_, State>> {
        self.state
            .lock()
            .map_err(|_| Error::Invalid("The library is unavailable. Restart the app.".into()))
    }
    fn channel_context(&self, id: &str) -> Result<(Connection, Channel, u64)> {
        let state = self.state()?;
        if !Self::ready(&state)? {
            return Err(Error::Invalid(
                "Connect and load this account before playing.".into(),
            ));
        }
        let connection = state
            .connection
            .clone()
            .ok_or_else(|| Error::Invalid("Connect your IPTV account in Settings.".into()))?;
        Ok((connection, state.store.channel(id)?, state.revision))
    }
    fn ready(state: &State) -> Result<bool> {
        let namespace = state.store.metadata("namespace")?;
        Ok(state
            .connection
            .as_ref()
            .is_some_and(|c| namespace.as_deref() == Some(c.namespace().as_str())))
    }
    fn request(&self, request: Request) -> Result<Value> {
        let now = chrono::Utc::now().timestamp();
        match request {
            Request::Restore { connection } => {
                connection.validate()?;
                let mut state = self.state()?;
                state.revision += 1;
                state.connection = Some(connection);
                state.streams.clear();
                Ok(json!(true))
            }
            Request::Disconnect => {
                let mut state = self.state()?;
                state.revision += 1;
                state.connection = None;
                state.streams.clear();
                Ok(json!(true))
            }
            Request::Status => {
                let state = self.state()?;
                Ok(
                    json!({"channels": if Self::ready(&state)? { state.store.channel_count()? } else { 0 }, "updated": state.store.metadata("channels_updated")?, "guideUpdated": state.store.metadata("guide_updated")?}),
                )
            }
            Request::Refresh { connection } => {
                connection.validate()?;
                let revision = self.state()?.revision;
                let mut catalog = self.runtime.block_on(async {
                    provider::catalog(&provider::client()?, &connection).await
                })?;
                for channel in &mut catalog.channels {
                    channel.logo = provider::safe_logo(channel.logo.take(), &connection);
                }
                let mut state = self.state()?;
                if state.revision != revision {
                    return Err(Error::Invalid(
                        "The account changed while loading. Reconnect in Settings.".into(),
                    ));
                }
                state
                    .store
                    .replace_catalog(&catalog.channels, now, &connection.namespace())?;
                state.revision += 1;
                state.streams = catalog.streams;
                state.connection = Some(connection);
                Ok(json!(catalog.channels.len()))
            }
            Request::List { query } => {
                let state = self.state()?;
                if !Self::ready(&state)? {
                    return Ok(json!({"channels":[], "total":0, "offset":0}));
                }
                Ok(serde_json::to_value(state.store.list(&query, now)?).unwrap_or(Value::Null))
            }
            Request::Groups => {
                let state = self.state()?;
                if !Self::ready(&state)? {
                    return Ok(json!([]));
                }
                Ok(serde_json::to_value(state.store.groups()?).unwrap_or(Value::Null))
            }
            Request::Countries => {
                let state = self.state()?;
                if !Self::ready(&state)? {
                    return Ok(json!([]));
                }
                Ok(serde_json::to_value(state.store.countries()?).unwrap_or(Value::Null))
            }
            Request::FavoriteCountry { id, favorite } => {
                self.state()?.store.favorite_country(&id, favorite)?;
                Ok(json!(true))
            }
            Request::Guide => {
                let (connection, channels, revision) = {
                    let state = self.state()?;
                    if !Self::ready(&state)? {
                        return Ok(json!(0));
                    }
                    (
                        state.connection.clone().ok_or_else(|| {
                            Error::Invalid("Connect your IPTV account in Settings.".into())
                        })?,
                        state.store.all_channels()?,
                        state.revision,
                    )
                };
                let Some(url) = connection.guide_url()? else {
                    return Ok(json!(0));
                };
                let programmes = self.runtime.block_on(async {
                    provider::guide(
                        &provider::client()?,
                        url,
                        channels,
                        now - 21600,
                        now + 172800,
                    )
                    .await
                })?;
                let mut state = self.state()?;
                if state.revision != revision {
                    return Ok(json!(0));
                }
                state.store.replace_programmes(&programmes, now)?;
                Ok(json!(programmes.len()))
            }
            Request::ShortGuide { id } => {
                let (connection, channel, revision) = self.channel_context(&id)?;
                let programmes = self.runtime.block_on(async {
                    provider::short_guide(&provider::client()?, &connection, &channel).await
                })?;
                let mut state = self.state()?;
                if state.revision == revision {
                    state.store.merge_programmes(&programmes)?;
                }
                Ok(json!(programmes.len()))
            }
            Request::Schedule { id } => {
                Ok(
                    serde_json::to_value(self.state()?.store.schedule(&id, now, now + 172800)?)
                        .unwrap_or(Value::Null),
                )
            }
            Request::SearchProgrammes { programme_query } => {
                let state = self.state()?;
                if !Self::ready(&state)? {
                    return Ok(json!({"results":[], "total":0, "offset":0}));
                }
                Ok(
                    serde_json::to_value(state.store.search_programmes(&programme_query)?)
                        .unwrap_or(Value::Null),
                )
            }
            Request::Stream { id } => {
                let (connection, channel, revision) = self.channel_context(&id)?;
                if connection.kind == "xtream" {
                    return Ok(json!(connection.hls_url(channel.stream_id.ok_or_else(
                        || Error::Invalid("This channel has no stream identifier.".into())
                    )?)?));
                }
                if self.state()?.streams.is_empty() {
                    let catalog = self.runtime.block_on(async {
                        provider::catalog(&provider::client()?, &connection).await
                    })?;
                    let mut state = self.state()?;
                    if state.revision == revision {
                        state.streams = catalog.streams;
                    }
                }
                let state = self.state()?;
                if state.revision != revision {
                    return Err(Error::Invalid(
                        "The account changed before playback. Choose the channel again.".into(),
                    ));
                }
                Ok(json!(state.streams.get(&id).ok_or_else(|| {
                    Error::Invalid("Refresh the playlist before playing this channel.".into())
                })?))
            }
            Request::Favorite { id, favorite } => {
                self.state()?.store.favorite(&id, favorite)?;
                Ok(json!(true))
            }
            Request::Watched { id } => {
                self.state()?.store.watched(&id, now)?;
                Ok(json!(true))
            }
        }
    }
}

/// # Safety
/// `path` must point to a valid, NUL-terminated UTF-8 string for the duration of this call.
#[no_mangle]
pub unsafe extern "C" fn vektortv_core_open(path: *const c_char) -> *mut AppleCore {
    catch_unwind(AssertUnwindSafe(|| {
        if path.is_null() {
            return std::ptr::null_mut();
        }
        let Ok(path) = CStr::from_ptr(path).to_str() else {
            return std::ptr::null_mut();
        };
        AppleCore::open(path)
            .map(|core| Box::into_raw(Box::new(core)))
            .unwrap_or(std::ptr::null_mut())
    }))
    .unwrap_or(std::ptr::null_mut())
}
/// # Safety
/// `core` is an open handle; `request` is a valid NUL-terminated UTF-8 JSON string.
/// Calls may run concurrently. The caller frees each returned string exactly once.
#[no_mangle]
pub unsafe extern "C" fn vektortv_core_request(
    core: *mut AppleCore,
    request: *const c_char,
) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if core.is_null() || request.is_null() {
            return Err(Error::Invalid("Invalid core request.".into()));
        }
        let input = CStr::from_ptr(request)
            .to_str()
            .map_err(|_| Error::Invalid("Invalid core request.".into()))?;
        let request = serde_json::from_str(input)
            .map_err(|_| Error::Invalid("Invalid core request.".into()))?;
        (*core).request(request)
    }));
    let response = match result {
        Ok(Ok(value)) => json!({"value":value}),
        Ok(Err(error)) => json!({"error":error.to_string()}),
        Err(_) => json!({"error":"The library operation was interrupted. Restart the app."}),
    };
    CString::new(response.to_string())
        .expect("JSON cannot contain literal NUL")
        .into_raw()
}
/// # Safety
/// `value` is NULL or a string returned by `vektortv_core_request`, freed once.
#[no_mangle]
pub unsafe extern "C" fn vektortv_string_free(value: *mut c_char) {
    if !value.is_null() {
        drop(CString::from_raw(value));
    }
}
/// # Safety
/// Close an open handle exactly once, after all requests have completed.
#[no_mangle]
pub unsafe extern "C" fn vektortv_core_close(core: *mut AppleCore) {
    if !core.is_null() {
        drop(Box::from_raw(core));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn bridge_ownership_invalid_requests_and_cached_queries() {
        unsafe {
            assert!(vektortv_core_open(std::ptr::null()).is_null());
            let path = CString::new(":memory:").unwrap();
            let core = vektortv_core_open(path.as_ptr());
            assert!(!core.is_null());
            for (input, expected) in [
                (r#"{"command":"status"}"#, "value"),
                (r#"{"command":"list","query":{}}"#, "value"),
                (
                    r#"{"command":"searchProgrammes","programmeQuery":{"search":"news"}}"#,
                    "value",
                ),
                ("secret invalid payload", "error"),
            ] {
                let input = CString::new(input).unwrap();
                let result = vektortv_core_request(core, input.as_ptr());
                let output = CStr::from_ptr(result).to_str().unwrap();
                let value: Value = serde_json::from_str(output).unwrap();
                assert!(value.get(expected).is_some());
                assert!(!output.contains("secret"));
                vektortv_string_free(result);
            }
            vektortv_core_close(core);
        }
    }
    #[test]
    fn native_hls_keeps_windows_ts_and_encodes_path_credentials() {
        let c = Connection {
            kind: "xtream".into(),
            base_url: "http://example.test".into(),
            username: "u/name".into(),
            password: "p?word".into(),
            playlist_url: String::new(),
            epg_url: String::new(),
        };
        assert!(c
            .hls_url(42)
            .unwrap()
            .ends_with("/u%2Fname/p%3Fword/42.m3u8"));
        assert!(c.stream_url(42).unwrap().ends_with("42.ts"));
    }
    #[test]
    fn cache_is_account_scoped_and_disconnect_clears_stream_access() {
        let core = AppleCore::open(":memory:").unwrap();
        let connection = Connection {
            kind: "xtream".into(),
            base_url: "http://example.test".into(),
            username: "one".into(),
            password: "private".into(),
            playlist_url: String::new(),
            epg_url: String::new(),
        };
        let channel = Channel {
            id: format!("{}:xtream:7", connection.namespace()),
            name: "News".into(),
            group: "World".into(),
            logo: None,
            epg_id: String::new(),
            stream_id: Some(7),
        };
        core.state()
            .unwrap()
            .store
            .replace_catalog(std::slice::from_ref(&channel), 10, &connection.namespace())
            .unwrap();
        core.request(Request::Restore {
            connection: connection.clone(),
        })
        .unwrap();
        assert_eq!(core.request(Request::Status).unwrap()["channels"], 1);
        core.request(Request::Favorite {
            id: channel.id.clone(),
            favorite: true,
        })
        .unwrap();
        let mut other = connection.clone();
        other.username = "two".into();
        core.request(Request::Restore { connection: other })
            .unwrap();
        assert_eq!(core.request(Request::Status).unwrap()["channels"], 0);
        assert!(core
            .request(Request::Stream {
                id: channel.id.clone()
            })
            .is_err());
        core.request(Request::Restore { connection }).unwrap();
        let page = core
            .request(Request::List {
                query: ChannelQuery {
                    favorites_only: true,
                    ..Default::default()
                },
            })
            .unwrap();
        assert_eq!(page["total"], 1);
        core.request(Request::Disconnect).unwrap();
        assert!(core.request(Request::Stream { id: channel.id }).is_err());
    }
}
