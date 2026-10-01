use serde::Serialize;
use std::sync::Mutex;
use tauri::{LogicalSize, PhysicalPosition, PhysicalSize, State, WebviewWindow};

struct RestoreBounds {
    size: PhysicalSize<u32>,
    position: PhysicalPosition<i32>,
    maximized: bool,
}

#[derive(Default)]
pub struct PlayerWindow(Mutex<Option<RestoreBounds>>);

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
            .0
            .lock()
            .map_err(|_| "Window controls are unavailable.")?
            .is_some(),
        on_top: window.is_always_on_top().map_err(window_error)?,
    })
}

impl PlayerWindow {
    pub fn restore(&self, window: &WebviewWindow) -> Result<(), String> {
        self.set_popout(window, false)
    }

    fn set_popout(&self, window: &WebviewWindow, enabled: bool) -> Result<(), String> {
        let mut saved = self
            .0
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
            let result = window
                .set_min_size(Some(LogicalSize::new(360.0, 250.0)))
                .and_then(|_| window.set_size(LogicalSize::new(640.0, 408.0)));
            if let Err(error) = result {
                let _ = restore_bounds(window, &bounds);
                return Err(window_error(error));
            }
            *saved = Some(bounds);
        } else if let Some(bounds) = saved.as_ref() {
            // Keep the snapshot until every operation succeeds so Return can be retried.
            restore_bounds(window, bounds).map_err(window_error)?;
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
