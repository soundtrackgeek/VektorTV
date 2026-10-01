use serde::{Deserialize, Serialize};
use std::{path::PathBuf, sync::Mutex};
use tauri::{LogicalSize, PhysicalPosition, PhysicalSize, State, WebviewWindow};

#[derive(Deserialize, Serialize)]
struct RestoreBounds {
    size: PhysicalSize<u32>,
    position: PhysicalPosition<i32>,
    maximized: bool,
}

pub struct PlayerWindow {
    saved: Mutex<Option<RestoreBounds>>,
    recovery_path: PathBuf,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowMode {
    popout: bool,
    on_top: bool,
}

#[tauri::command]
pub async fn player_window_mode(
    window: WebviewWindow,
    state: State<'_, PlayerWindow>,
) -> Result<WindowMode, String> {
    Ok(WindowMode {
        popout: state
            .saved
            .lock()
            .map_err(|_| "Window controls are unavailable.")?
            .is_some(),
        on_top: window.is_always_on_top().map_err(window_error)?,
    })
}

impl PlayerWindow {
    pub fn new(window: &WebviewWindow, recovery_path: PathBuf) -> Result<Self, String> {
        // Native macOS termination (including Dock Quit) can bypass Tauri's
        // ExitRequested callback. Recover the browsing window on next launch.
        if let Ok(json) = std::fs::read(&recovery_path) {
            if let Ok(bounds) = serde_json::from_slice::<RestoreBounds>(&json) {
                restore_bounds(window, &bounds).map_err(window_error)?;
            }
            std::fs::remove_file(&recovery_path)
                .map_err(|_| "Window recovery could not be saved.")?;
        }
        Ok(Self {
            saved: Mutex::new(None),
            recovery_path,
        })
    }

    pub fn restore(&self, window: &WebviewWindow) -> Result<(), String> {
        if self
            .saved
            .lock()
            .map_err(|_| "Window controls are unavailable.")?
            .is_none()
        {
            return Ok(());
        }
        if window.is_fullscreen().map_err(window_error)? {
            window.set_fullscreen(false).map_err(window_error)?;
            // AppKit exits a full-screen Space asynchronously. Keep its event
            // loop free while waiting on this shutdown worker, then restore.
            for _ in 0..40 {
                if !window.is_fullscreen().map_err(window_error)? {
                    break;
                }
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
        }
        self.set_popout(window, false)
    }

    fn set_popout(&self, window: &WebviewWindow, enabled: bool) -> Result<(), String> {
        let mut saved = self
            .saved
            .lock()
            .map_err(|_| "Window controls are unavailable.")?;
        if saved.is_some() == enabled {
            return Ok(());
        }
        if window.is_fullscreen().map_err(window_error)? {
            return Err("Exit full screen before changing popout mode.".into());
        }
        if enabled {
            let maximized = window.is_maximized().map_err(window_error)?;
            if maximized {
                window.unmaximize().map_err(window_error)?;
            }
            let bounds = (|| {
                Ok::<_, tauri::Error>(RestoreBounds {
                    size: window.inner_size()?,
                    position: window.outer_position()?,
                    maximized,
                })
            })();
            let bounds = match bounds {
                Ok(bounds) => bounds,
                Err(error) => {
                    if maximized {
                        let _ = window.maximize();
                    }
                    return Err(window_error(error));
                }
            };
            let json =
                serde_json::to_vec(&bounds).map_err(|_| "Window bounds could not be saved.")?;
            if std::fs::write(&self.recovery_path, json).is_err() {
                if maximized {
                    let _ = window.maximize();
                }
                return Err("Window bounds could not be saved. Check available disk space.".into());
            }
            let result = window
                .set_min_size(Some(LogicalSize::new(360.0, 250.0)))
                .and_then(|_| window.set_size(LogicalSize::new(640.0, 408.0)));
            if let Err(error) = result {
                let _ = restore_bounds(window, &bounds);
                let _ = std::fs::remove_file(&self.recovery_path);
                return Err(window_error(error));
            }
            *saved = Some(bounds);
        } else if let Some(bounds) = saved.as_ref() {
            // Keep the snapshot until every operation succeeds so Return can be retried.
            restore_bounds(window, bounds).map_err(window_error)?;
            std::fs::remove_file(&self.recovery_path)
                .map_err(|_| "Window recovery could not be saved.")?;
            *saved = None;
        }
        Ok(())
    }
}

fn restore_bounds(window: &WebviewWindow, bounds: &RestoreBounds) -> tauri::Result<()> {
    window.unmaximize()?;
    window.set_min_size(Some(LogicalSize::new(1024.0, 680.0)))?;
    window.set_position(bounds.position)?;
    window.set_size(bounds.size)?;
    if bounds.maximized {
        window.maximize()?;
    }
    // Setters dispatch asynchronously. A query flushes those operations before
    // the caller saves geometry or exits and destroys the native window.
    let _ = window.inner_size()?;
    Ok(())
}

fn window_error(_: tauri::Error) -> String {
    "The window could not be updated. Try again.".into()
}

// Async commands keep native window queries off the UI thread on Windows.
#[tauri::command]
pub async fn set_player_popout(
    window: WebviewWindow,
    state: State<'_, PlayerWindow>,
    enabled: bool,
) -> Result<(), String> {
    state.set_popout(&window, enabled)
}

#[tauri::command]
pub async fn set_player_on_top(window: WebviewWindow, enabled: bool) -> Result<(), String> {
    window.set_always_on_top(enabled).map_err(window_error)
}
