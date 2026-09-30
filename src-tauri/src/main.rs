#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod commands;
mod credentials;
mod player;

use std::{
    collections::HashMap,
    sync::{atomic::AtomicBool, Mutex},
};
use tauri::Manager;
use vektortv_core::{provider::Connection, Store};

struct AppState {
    store: Mutex<Store>,
    connection: Mutex<Option<Connection>>,
    streams: Mutex<HashMap<String, String>>,
    player: Mutex<Option<player::Player>>,
    player_error: Mutex<Option<String>>,
    syncing: AtomicBool,
    progress: Mutex<commands::SyncProgress>,
    closing: AtomicBool,
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .setup(|app| {
            let data = app.path().app_data_dir()?;
            std::fs::create_dir_all(&data)?;
            let store = Store::open(data.join("library.sqlite3"))?;
            let connection = credentials::load()?;
            let window = app
                .get_webview_window("main")
                .ok_or("Main window missing")?;
            let resources = app.path().resource_dir()?;
            let player_result = player::Player::new(&window, &resources);
            let (player, error) = match player_result {
                Ok(player) => (Some(player), None),
                Err(error) => (None, Some(error)),
            };
            app.manage(AppState {
                store: Mutex::new(store),
                connection: Mutex::new(connection),
                streams: Mutex::new(HashMap::new()),
                player: Mutex::new(player),
                player_error: Mutex::new(error),
                syncing: AtomicBool::new(false),
                progress: Mutex::new(commands::SyncProgress::default()),
                closing: AtomicBool::new(false),
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::app_info,
            commands::list_channels,
            commands::list_groups,
            commands::get_schedule,
            commands::set_favorite,
            commands::save_connection,
            commands::disconnect,
            commands::sync_library,
            commands::play_channel,
            commands::player_status,
            commands::player_action,
            commands::set_player_bounds,
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let state = window.state::<AppState>();
                if state
                    .closing
                    .swap(true, std::sync::atomic::Ordering::SeqCst)
                {
                    return;
                }
                let app = window.app_handle().clone();
                tauri::async_runtime::spawn(async move {
                    let worker = app.clone();
                    let _ = tauri::async_runtime::spawn_blocking(move || {
                        let state = worker.state::<AppState>();
                        // Drop VLC while the window message pump is still running.
                        let player = state.player.lock().ok().and_then(|mut p| p.take());
                        drop(player);
                    })
                    .await;
                    app.exit(0);
                });
            }
        })
        .run(tauri::generate_context!())
        .expect("VektorTV could not start");
}
