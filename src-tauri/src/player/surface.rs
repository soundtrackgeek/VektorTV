use super::{Bounds, Pointer};
use std::path::{Path, PathBuf};
use tauri::WebviewWindow;

#[cfg(target_os = "windows")]
use windows_sys::Win32::UI::WindowsAndMessaging::{
    CreateWindowExW, DestroyWindow, SetWindowPos, ShowWindow, SWP_NOACTIVATE, SW_HIDE, SW_SHOW,
    WS_CHILD, WS_CLIPCHILDREN, WS_CLIPSIBLINGS,
};

pub fn player_library(directory: &Path) -> PathBuf {
    #[cfg(target_os = "windows")]
    {
        directory.join("libvlc.dll")
    }
    #[cfg(target_os = "macos")]
    {
        directory.join("lib/libvlc.dylib")
    }
}

pub fn core_library(directory: &Path) -> PathBuf {
    #[cfg(target_os = "windows")]
    {
        directory.join("libvlccore.dll")
    }
    #[cfg(target_os = "macos")]
    {
        directory.join("lib/libvlccore.dylib")
    }
}

pub fn runtime_directory(resources: &Path) -> Result<PathBuf, String> {
    let mut candidates = vec![resources.join("vlc")];
    #[cfg(debug_assertions)]
    candidates.push(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("resources/vlc"));
    #[cfg(target_os = "windows")]
    candidates.push(
        PathBuf::from(std::env::var("ProgramFiles").unwrap_or_else(|_| "C:\\Program Files".into()))
            .join("VideoLAN/VLC"),
    );
    #[cfg(target_os = "macos")]
    {
        candidates.push(PathBuf::from("/Applications/VLC.app/Contents/MacOS"));
        if let Some(home) = std::env::var_os("HOME") {
            candidates.push(PathBuf::from(home).join("Applications/VLC.app/Contents/MacOS"));
        }
    }
    candidates
        .into_iter()
        .find(|path| player_library(path).is_file())
        .ok_or_else(|| {
            "The VLC 3 runtime is missing. Install VLC from videolan.org and restart VektorTV."
                .into()
        })
}

/// Created on Tauri's setup/main thread. Opaque addresses cross threads, but
/// AppKit changes are always dispatched to its main queue by the native bridge.
pub struct Surface {
    handle: usize,
    #[cfg(target_os = "windows")]
    window: WebviewWindow,
}

impl Surface {
    pub fn new(window: &WebviewWindow) -> Result<Self, String> {
        #[cfg(target_os = "windows")]
        let handle = {
            let parent = window
                .hwnd()
                .map_err(|_| "The video window could not be created.")?
                .0;
            let class: Vec<u16> = "STATIC\0".encode_utf16().collect();
            unsafe {
                CreateWindowExW(
                    0,
                    class.as_ptr(),
                    std::ptr::null(),
                    WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS,
                    0,
                    0,
                    1,
                    1,
                    parent,
                    std::ptr::null_mut(),
                    std::ptr::null_mut(),
                    std::ptr::null(),
                )
            }
        };
        #[cfg(target_os = "macos")]
        let handle = unsafe {
            vektor_surface_new(
                window
                    .ns_view()
                    .map_err(|_| "The video view could not be created.")?,
            )
        };
        if handle.is_null() {
            return Err("The embedded video surface could not start.".into());
        }
        Ok(Self {
            handle: handle as usize,
            #[cfg(target_os = "windows")]
            window: window.clone(),
        })
    }
    pub fn handle(&self) -> Pointer {
        self.handle as Pointer
    }
    pub fn hide(&self) {
        #[cfg(target_os = "windows")]
        unsafe {
            ShowWindow(self.handle(), SW_HIDE);
        }
        #[cfg(target_os = "macos")]
        unsafe {
            vektor_surface_hide(self.handle());
        }
    }
    pub fn bounds(&self, bounds: Bounds) {
        #[cfg(target_os = "windows")]
        unsafe {
            if !bounds.visible {
                self.hide();
            } else {
                SetWindowPos(
                    self.handle(),
                    std::ptr::null_mut(),
                    bounds.x.round() as i32,
                    bounds.y.round() as i32,
                    bounds.width.max(1.0).round() as i32,
                    bounds.height.max(1.0).round() as i32,
                    SWP_NOACTIVATE,
                );
                ShowWindow(self.handle(), SW_SHOW);
            }
        }
        #[cfg(target_os = "macos")]
        unsafe {
            vektor_surface_bounds(
                self.handle(),
                bounds.x,
                bounds.y,
                bounds.width,
                bounds.height,
                bounds.visible,
            );
        }
    }
}

impl Drop for Surface {
    fn drop(&mut self) {
        #[cfg(target_os = "windows")]
        {
            let handle = self.handle;
            let _ = self.window.run_on_main_thread(move || unsafe {
                DestroyWindow(handle as Pointer);
            });
        }
        #[cfg(target_os = "macos")]
        unsafe {
            vektor_surface_destroy(self.handle());
        }
    }
}

#[cfg(target_os = "macos")]
extern "C" {
    fn vektor_surface_new(parent: Pointer) -> Pointer;
    fn vektor_surface_hide(surface: Pointer);
    fn vektor_surface_bounds(
        surface: Pointer,
        x: f64,
        y: f64,
        width: f64,
        height: f64,
        visible: bool,
    );
    fn vektor_surface_destroy(surface: Pointer);
}
