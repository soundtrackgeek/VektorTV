#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod commands;
mod credentials;
mod player;
mod player_window;

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
        .manage(player_window::PlayerWindow::default())
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
            commands::list_countries,
            commands::set_country_favorite,
            commands::get_schedule,
            commands::guide_schedules,
            commands::search_programmes,
            commands::set_favorite,
            commands::save_connection,
            commands::disconnect,
            commands::sync_library,
            commands::play_channel,
            commands::player_status,
            commands::player_action,
            commands::set_player_bounds,
            player_window::set_player_popout,
            player_window::set_player_on_top,
            player_window::player_window_mode,
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                shutdown(window.app_handle());
            }
        })
        .build(tauri::generate_context!())
        .expect("VektorTV could not start")
        .run(|app, event| {
            // macOS Quit (Cmd-Q) does not send CloseRequested to the window.
            if let tauri::RunEvent::ExitRequested {
                api, code: None, ..
            } = event
            {
                api.prevent_exit();
                shutdown(app);
            }
        });
}

fn shutdown(app: &tauri::AppHandle) {
    let state = app.state::<AppState>();
    if state
        .closing
        .swap(true, std::sync::atomic::Ordering::SeqCst)
    {
        return;
    }
    let app = app.clone();
    tauri::async_runtime::spawn(async move {
        let worker = app.clone();
        let _ = tauri::async_runtime::spawn_blocking(move || {
            if let Some(window) = worker.get_webview_window("main") {
                // Save the browsing geometry on quit, not the temporary popout size.
                let _ = window.set_fullscreen(false);
                let _ = worker
                    .state::<player_window::PlayerWindow>()
                    .restore(&window);
            }
            let state = worker.state::<AppState>();
            // VLC may need AppKit/Win32 callbacks while releasing its video output.
            let player = state.player.lock().ok().and_then(|mut p| p.take());
            drop(player);
        })
        .await;
        app.exit(0);
    });
}
