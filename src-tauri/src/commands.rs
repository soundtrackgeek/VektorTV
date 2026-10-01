use crate::{
    credentials,
    player::{Bounds, PlayerStatus},
    AppState,
};
use serde::Serialize;
use std::sync::{atomic::Ordering, Mutex, MutexGuard};
use tauri::{AppHandle, Emitter, Manager, State};
use vektortv_core::{
    provider::{self, Connection},
    ChannelPage, ChannelQuery, Group, Programme,
};

type Result<T> = std::result::Result<T, String>;
fn lock<T>(mutex: &Mutex<T>) -> Result<MutexGuard<'_, T>> {
    mutex
        .lock()
        .map_err(|_| "An app operation failed. Restart VektorTV to recover.".into())
}
fn now() -> i64 {
    chrono::Utc::now().timestamp()
}

// VLC stop/switch can wait for its native video thread. The window message pump
// must remain free, including while another command waits on the player mutex.
async fn blocking<T: Send + 'static>(
    app: AppHandle,
    operation: impl FnOnce(&AppState) -> Result<T> + Send + 'static,
) -> Result<T> {
    tauri::async_runtime::spawn_blocking(move || operation(&app.state::<AppState>()))
        .await
        .map_err(|_| "The app operation was interrupted. Restart VektorTV to recover.".to_owned())?
}

#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncProgress {
    pub phase: String,
    pub active: bool,
    pub message: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppInfo {
    configured: bool,
    connection_kind: Option<String>,
    server: Option<String>,
    source: Option<String>,
    channel_count: usize,
    programme_count: usize,
    channels_updated: Option<i64>,
    guide_updated: Option<i64>,
    player_available: bool,
    player_error: Option<String>,
    progress: SyncProgress,
    version: &'static str,
    platform: &'static str,
    credential_storage: &'static str,
}

#[tauri::command]
pub async fn app_info(app: AppHandle) -> Result<AppInfo> {
    blocking(app, app_info_inner).await
}

fn app_info_inner(state: &AppState) -> Result<AppInfo> {
    let connection = lock(&state.connection)?.clone();
    // Do not nest store/player locks: polling can write decoded-playback history.
    let player_available = lock(&state.player)?.is_some();
    let player_error = lock(&state.player_error)?.clone();
    let progress = lock(&state.progress)?.clone();
    let store = lock(&state.store)?;
    Ok(AppInfo {
        configured: connection.is_some(),
        connection_kind: connection.as_ref().map(|c| c.kind.clone()),
        server: connection
            .as_ref()
            .and_then(|c| {
                provider::validate_url(if c.kind == "xtream" {
                    &c.base_url
                } else {
                    &c.playlist_url
                })
                .ok()
            })
            .map(|u| u.origin().ascii_serialization()),
        source: store.metadata("source").map_err(|e| e.to_string())?,
        channel_count: store.channel_count().map_err(|e| e.to_string())?,
        programme_count: store.programme_count().map_err(|e| e.to_string())?,
        channels_updated: store
            .metadata("channels_updated")
            .map_err(|e| e.to_string())?
            .and_then(|s| s.parse().ok()),
        guide_updated: store
            .metadata("guide_updated")
            .map_err(|e| e.to_string())?
            .and_then(|s| s.parse().ok()),
        player_available,
        player_error,
        progress,
        version: env!("CARGO_PKG_VERSION"),
        platform: std::env::consts::OS,
        credential_storage: credentials::storage_name(),
    })
}

#[tauri::command]
pub fn list_channels(state: State<'_, AppState>, query: ChannelQuery) -> Result<ChannelPage> {
    lock(&state.store)?
        .list(&query, now())
        .map_err(|e| e.to_string())
}
#[tauri::command]
pub fn list_groups(state: State<'_, AppState>) -> Result<Vec<Group>> {
    lock(&state.store)?.groups().map_err(|e| e.to_string())
}
#[tauri::command]
pub async fn get_schedule(
    app: AppHandle,
    channel_id: String,
    from: i64,
    until: i64,
) -> Result<Vec<Programme>> {
    if until <= from || until - from > 604800 {
        return Err("Choose a guide range of up to seven days.".into());
    }
    let state = app.state::<AppState>();
    let (existing, channel, fetched) = {
        let store = lock(&state.store)?;
        (
            store
                .schedule(&channel_id, from, until)
                .map_err(|e| e.to_string())?,
            store.channel(&channel_id).map_err(|e| e.to_string())?,
            store
                .metadata(&format!("epg:{channel_id}"))
                .map_err(|e| e.to_string())?
                .and_then(|s| s.parse::<i64>().ok())
                .unwrap_or(0),
        )
    };
    if !existing.is_empty() || now() - fetched < 900 {
        return Ok(existing);
    }
    let connection = lock(&state.connection)?.clone();
    if let Some(c) = connection
        .filter(|c| c.kind == "xtream" && channel.id.starts_with(&format!("{}:", c.namespace())))
    {
        let client = provider::client().map_err(|e| e.to_string())?;
        match provider::short_guide(&client, &c, &channel).await {
            Ok(programmes) => {
                let mut store = lock(&state.store)?;
                store
                    .merge_programmes(&programmes)
                    .map_err(|e| e.to_string())?;
                store
                    .set_metadata(&format!("epg:{channel_id}"), &now().to_string())
                    .map_err(|e| e.to_string())?;
                return store
                    .schedule(&channel_id, from, until)
                    .map_err(|e| e.to_string());
            }
            Err(_) => return Ok(existing), // Missing short EPG must never prevent live playback.
        }
    }
    Ok(existing)
}
#[tauri::command]
pub fn set_favorite(state: State<'_, AppState>, channel_id: String, favorite: bool) -> Result<()> {
    lock(&state.store)?
        .favorite(&channel_id, favorite)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn save_connection(app: AppHandle, connection: Connection) -> Result<()> {
    let state = app.state::<AppState>();
    if state.syncing.load(Ordering::SeqCst) {
        return Err(
            "Wait for the current library refresh to finish before changing the connection.".into(),
        );
    }
    let client = provider::client().map_err(|e| e.to_string())?;
    provider::check_account(&client, &connection)
        .await
        .map_err(|e| e.to_string())?;
    if state.syncing.load(Ordering::SeqCst) {
        return Err(
            "The library is refreshing. Try saving the connection again when it finishes.".into(),
        );
    }
    credentials::save(&connection)?;
    if let Some(player) = lock(&state.player)?.as_mut() {
        player.stop();
    }
    *lock(&state.connection)? = Some(connection);
    lock(&state.streams)?.clear();
    Ok(())
}

#[tauri::command]
pub async fn disconnect(app: AppHandle) -> Result<()> {
    blocking(app, disconnect_inner).await
}

fn disconnect_inner(state: &AppState) -> Result<()> {
    if state.syncing.load(Ordering::SeqCst) {
        return Err("Wait for the library refresh to finish before disconnecting.".into());
    }
    credentials::delete()?;
    if let Some(player) = lock(&state.player)?.as_mut() {
        player.stop();
    }
    *lock(&state.connection)? = None;
    lock(&state.streams)?.clear();
    Ok(())
}

fn progress(app: &AppHandle, phase: &str, message: &str, active: bool) {
    let p = SyncProgress {
        phase: phase.into(),
        message: message.into(),
        active,
    };
    if let Ok(mut stored) = app.state::<AppState>().progress.lock() {
        *stored = p.clone();
    }
    let _ = app.emit("sync-progress", p);
}

#[tauri::command]
pub async fn sync_library(app: AppHandle) -> Result<SyncProgress> {
    let state = app.state::<AppState>();
    if state
        .syncing
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        return Err("A library refresh is already running.".into());
    }
    struct Guard<'a>(&'a std::sync::atomic::AtomicBool);
    impl Drop for Guard<'_> {
        fn drop(&mut self) {
            self.0.store(false, Ordering::SeqCst);
        }
    }
    let _guard = Guard(&state.syncing);
    progress(
        &app,
        "channels",
        "Connecting and loading live channels…",
        true,
    );
    let result = refresh(&app).await;
    match &result {
        Ok(p) => progress(&app, &p.phase, &p.message, false),
        Err(error) => progress(&app, "error", error, false),
    }
    result
}

async fn refresh(app: &AppHandle) -> Result<SyncProgress> {
    let state = app.state::<AppState>();
    let connection = lock(&state.connection)?
        .clone()
        .ok_or("Add an IPTV connection in Settings first.")?;
    let client = provider::client().map_err(|e| e.to_string())?;
    let mut catalog = provider::catalog(&client, &connection)
        .await
        .map_err(|e| e.to_string())?;
    for channel in &mut catalog.channels {
        channel.logo = provider::safe_logo(channel.logo.take(), &connection);
    }
    let count = catalog.channels.len();
    {
        let mut store = lock(&state.store)?;
        store
            .replace_channels(&catalog.channels, now())
            .map_err(|e| e.to_string())?;
        let label = provider::validate_url(if connection.kind == "xtream" {
            &connection.base_url
        } else {
            &connection.playlist_url
        })
        .map_err(|e| e.to_string())?
        .origin()
        .ascii_serialization();
        store
            .set_metadata("source", &label)
            .map_err(|e| e.to_string())?;
    }
    *lock(&state.streams)? = catalog.streams;
    progress(
        app,
        "guide",
        &format!("{count} channels ready. Loading the programme guide…"),
        true,
    );
    let Some(guide_url) = connection.guide_url().map_err(|e| e.to_string())? else {
        return Ok(SyncProgress {
            phase: "complete".into(),
            active: false,
            message: format!(
                "{count} channels refreshed. Add an XMLTV address in Settings for the guide."
            ),
        });
    };
    // Guide failures never discard the successful channel import or previous guide.
    let guide_result = async {
        progress(
            app,
            "guide",
            "Streaming the guide and matching programmes…",
            true,
        );
        let timestamp = now();
        let programmes = provider::guide(
            &client,
            guide_url,
            catalog.channels,
            timestamp - 21600,
            timestamp + 172800,
        )
        .await
        .map_err(|e| e.to_string())?;
        let count = programmes.len();
        progress(
            app,
            "finalizing",
            &format!("Saving {count} matched programmes…"),
            true,
        );
        lock(&state.store)?
            .replace_programmes(&programmes, now())
            .map_err(|e| e.to_string())?;
        Ok::<_, String>(count)
    }
    .await;
    match guide_result {
        Ok(programmes) => Ok(SyncProgress {
            phase: "complete".into(),
            active: false,
            message: format!("{count} channels and {programmes} programmes refreshed."),
        }),
        Err(error) => Ok(SyncProgress {
            phase: "warning".into(),
            active: false,
            message: format!("{count} channels refreshed. Guide unavailable: {error}"),
        }),
    }
}

#[tauri::command]
pub async fn play_channel(app: AppHandle, channel_id: String, request_id: u64) -> Result<()> {
    blocking(app, move |state| {
        play_channel_inner(state, channel_id, request_id)
    })
    .await
}

fn play_channel_inner(state: &AppState, channel_id: String, request_id: u64) -> Result<()> {
    let connection = lock(&state.connection)?
        .clone()
        .ok_or("Reconnect your IPTV service in Settings to watch.")?;
    let channel = lock(&state.store)?
        .channel(&channel_id)
        .map_err(|e| e.to_string())?;
    if !channel
        .id
        .starts_with(&format!("{}:", connection.namespace()))
    {
        return Err("Refresh the library to load channels from your current connection.".into());
    }
    let url = if let Some(id) = channel.stream_id {
        connection.stream_url(id).map_err(|e| e.to_string())?
    } else {
        lock(&state.streams)?
            .get(&channel_id)
            .cloned()
            .ok_or("Refresh the playlist before playing this cached channel.")?
    };
    lock(&state.player)?
        .as_mut()
        .ok_or("The playback engine is unavailable. Restart the app after installing VLC.")?
        .play(channel_id, &url, request_id)
}

#[tauri::command]
pub async fn player_status(app: AppHandle) -> Result<PlayerStatus> {
    blocking(app, player_status_inner).await
}

fn player_status_inner(state: &AppState) -> Result<PlayerStatus> {
    let mut player = lock(&state.player)?;
    let Some(player) = player.as_mut() else {
        return Ok(PlayerStatus {
            state: "unavailable".into(),
            ..Default::default()
        });
    };
    let status = player.status();
    if status.state == "playing"
        && status.decoded_video + status.decoded_audio > 0
        && !player.history_recorded
    {
        if let Some(id) = &player.channel_id {
            lock(&state.store)?
                .watched(id, now())
                .map_err(|e| e.to_string())?;
        }
        player.history_recorded = true;
    }
    Ok(status)
}

#[tauri::command]
pub async fn player_action(
    app: AppHandle,
    action: String,
    value: Option<u32>,
    request_id: Option<u64>,
) -> Result<()> {
    blocking(app, move |state| {
        player_action_inner(state, action, value, request_id)
    })
    .await
}

fn player_action_inner(
    state: &AppState,
    action: String,
    value: Option<u32>,
    request_id: Option<u64>,
) -> Result<()> {
    lock(&state.player)?
        .as_mut()
        .ok_or("The playback engine is unavailable.")?
        .action(&action, value, request_id)
}
#[tauri::command]
pub async fn set_player_bounds(app: AppHandle, bounds: Bounds) -> Result<()> {
    blocking(app, move |state| set_player_bounds_inner(state, bounds)).await
}

fn set_player_bounds_inner(state: &AppState, bounds: Bounds) -> Result<()> {
    if let Some(player) = lock(&state.player)?.as_ref() {
        player.bounds(bounds)?;
    }
    Ok(())
}
