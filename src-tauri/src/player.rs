use libloading::Library;
use serde::{Deserialize, Serialize};
use std::{
    ffi::{c_char, c_int, c_void, CString},
    path::Path,
};
use tauri::WebviewWindow;
mod surface;
use surface::Surface;

type Pointer = *mut c_void;

#[repr(C)]
#[derive(Default)]
struct MediaStats {
    read_bytes: c_int,
    input_bitrate: f32,
    demux_read_bytes: c_int,
    demux_bitrate: f32,
    demux_corrupted: c_int,
    demux_discontinuity: c_int,
    decoded_video: c_int,
    decoded_audio: c_int,
    displayed_pictures: c_int,
    lost_pictures: c_int,
    played_abuffers: c_int,
    lost_abuffers: c_int,
    sent_packets: c_int,
    sent_bytes: c_int,
    send_bitrate: f32,
}

struct Api {
    _library: Library,
    _core: Library,
    new: unsafe extern "C" fn(c_int, *const *const c_char) -> Pointer,
    release: unsafe extern "C" fn(Pointer),
    player_new: unsafe extern "C" fn(Pointer) -> Pointer,
    player_release: unsafe extern "C" fn(Pointer),
    media_new_location: unsafe extern "C" fn(Pointer, *const c_char) -> Pointer,
    media_release: unsafe extern "C" fn(Pointer),
    set_media: unsafe extern "C" fn(Pointer, Pointer),
    set_drawable: unsafe extern "C" fn(Pointer, Pointer),
    play: unsafe extern "C" fn(Pointer) -> c_int,
    stop: unsafe extern "C" fn(Pointer),
    set_pause: unsafe extern "C" fn(Pointer, c_int),
    get_state: unsafe extern "C" fn(Pointer) -> c_int,
    audio_set_volume: unsafe extern "C" fn(Pointer, c_int) -> c_int,
    set_key_input: unsafe extern "C" fn(Pointer, u32),
    set_mouse_input: unsafe extern "C" fn(Pointer, u32),
    video_get_size: unsafe extern "C" fn(Pointer, u32, *mut u32, *mut u32) -> c_int,
    media_get_stats: unsafe extern "C" fn(Pointer, *mut MediaStats) -> c_int,
}

impl Api {
    fn load(directory: &Path) -> Result<Self, String> {
        // Libraries are loaded from an explicit trusted runtime directory, never PATH.
        unsafe {
            let core = Library::new(surface::core_library(directory))
                .map_err(|_| "The VLC core runtime could not be loaded.".to_owned())?;
            let library = Library::new(surface::player_library(directory))
                .map_err(|_| "The VLC playback runtime could not be loaded.".to_owned())?;
            macro_rules! function {
                ($name:literal) => {
                    *library
                        .get(concat!($name, "\0").as_bytes())
                        .map_err(|_| "The VLC runtime is incompatible.".to_owned())?
                };
            }
            Ok(Self {
                new: function!("libvlc_new"),
                release: function!("libvlc_release"),
                player_new: function!("libvlc_media_player_new"),
                player_release: function!("libvlc_media_player_release"),
                media_new_location: function!("libvlc_media_new_location"),
                media_release: function!("libvlc_media_release"),
                set_media: function!("libvlc_media_player_set_media"),
                #[cfg(target_os = "windows")]
                set_drawable: function!("libvlc_media_player_set_hwnd"),
                #[cfg(target_os = "macos")]
                set_drawable: function!("libvlc_media_player_set_nsobject"),
                play: function!("libvlc_media_player_play"),
                stop: function!("libvlc_media_player_stop"),
                set_pause: function!("libvlc_media_player_set_pause"),
                get_state: function!("libvlc_media_player_get_state"),
                audio_set_volume: function!("libvlc_audio_set_volume"),
                set_key_input: function!("libvlc_video_set_key_input"),
                set_mouse_input: function!("libvlc_video_set_mouse_input"),
                video_get_size: function!("libvlc_video_get_size"),
                media_get_stats: function!("libvlc_media_get_stats"),
                _core: core,
                _library: library,
            })
        }
    }
}

#[derive(Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PlayerStatus {
    pub state: String,
    pub channel_id: Option<String>,
    pub volume: u32,
    pub width: u32,
    pub height: u32,
    pub decoded_video: i32,
    pub decoded_audio: i32,
}

#[derive(Deserialize)]
pub struct Bounds {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub visible: bool,
}

/// libVLC calls and handles are serialized by AppState's mutex. Opaque native
/// handles are held as addresses, never dereferenced by Rust.
pub struct Player {
    api: Api,
    instance: usize,
    player: usize,
    media: Option<usize>,
    surface: Surface,
    pub channel_id: Option<String>,
    pub history_recorded: bool,
    last_request: u64,
    volume: u32,
}

impl Player {
    pub fn new(window: &WebviewWindow, resources: &Path) -> Result<Self, String> {
        let directory = surface::runtime_directory(resources)?;
        std::env::set_var("VLC_PLUGIN_PATH", directory.join("plugins"));
        let api = Api::load(&directory)?;
        let options = [
            "--quiet",
            "--no-video-title-show",
            "--no-osd",
            "--network-caching=1200",
            "--avcodec-hw=any",
        ]
        .map(|s| CString::new(s).unwrap());
        let pointers: Vec<_> = options.iter().map(|s| s.as_ptr()).collect();
        let surface = Surface::new(window)?;
        unsafe {
            let instance = (api.new)(pointers.len() as c_int, pointers.as_ptr());
            if instance.is_null() {
                return Err("The VLC playback engine could not start.".into());
            }
            let player = (api.player_new)(instance);
            if player.is_null() {
                (api.release)(instance);
                return Err("The video player could not start.".into());
            }
            (api.set_drawable)(player, surface.handle());
            (api.set_key_input)(player, 0);
            (api.set_mouse_input)(player, 0);
            (api.audio_set_volume)(player, 80);
            Ok(Self {
                api,
                instance: instance as usize,
                player: player as usize,
                media: None,
                surface,
                channel_id: None,
                history_recorded: false,
                last_request: 0,
                volume: 80,
            })
        }
    }
    pub fn play(&mut self, channel_id: String, url: &str, request: u64) -> Result<(), String> {
        if request < self.last_request {
            return Ok(());
        }
        self.last_request = request;
        let location =
            CString::new(url).map_err(|_| "The channel address is invalid.".to_owned())?;
        unsafe {
            (self.api.stop)(self.player as Pointer);
            if let Some(media) = self.media.take() {
                (self.api.media_release)(media as Pointer);
            }
            let media = (self.api.media_new_location)(self.instance as Pointer, location.as_ptr());
            if media.is_null() {
                return Err("This channel could not be opened.".into());
            }
            self.media = Some(media as usize);
            (self.api.set_media)(self.player as Pointer, media);
            self.channel_id = Some(channel_id);
            self.history_recorded = false;
            if (self.api.play)(self.player as Pointer) != 0 {
                return Err("Playback could not start. Try another channel or reconnect.".into());
            }
        }
        Ok(())
    }
    pub fn stop(&mut self) {
        unsafe {
            (self.api.stop)(self.player as Pointer);
            self.surface.hide();
        }
        self.channel_id = None;
    }
    pub fn action(
        &mut self,
        action: &str,
        value: Option<u32>,
        request: Option<u64>,
    ) -> Result<(), String> {
        if action == "stop" {
            if let Some(request) = request {
                if request < self.last_request {
                    return Ok(());
                }
                self.last_request = request;
            }
        }
        unsafe {
            match action {
                "stop" => self.stop(),
                "pause" => (self.api.set_pause)(self.player as Pointer, 1),
                "resume" => (self.api.set_pause)(self.player as Pointer, 0),
                "volume" => {
                    self.volume = value.unwrap_or(80).min(100);
                    (self.api.audio_set_volume)(self.player as Pointer, self.volume as c_int);
                }
                _ => return Err("Unknown playback control.".into()),
            }
        }
        Ok(())
    }
    pub fn bounds(&self, bounds: Bounds) -> Result<(), String> {
        if [bounds.x, bounds.y, bounds.width, bounds.height]
            .iter()
            .any(|n| !n.is_finite() || n.abs() > 20000.0)
        {
            return Err("The video surface dimensions are invalid.".into());
        }
        self.surface.bounds(Bounds {
            visible: bounds.visible && self.channel_id.is_some(),
            ..bounds
        });
        Ok(())
    }
    pub fn status(&self) -> PlayerStatus {
        let mut width = 0;
        let mut height = 0;
        let mut stats = MediaStats::default();
        unsafe {
            let state = if self.channel_id.is_none() {
                "idle"
            } else {
                match (self.api.get_state)(self.player as Pointer) {
                    1 => "opening",
                    2 => "buffering",
                    3 => "playing",
                    4 => "paused",
                    5 => "stopped",
                    6 => "ended",
                    7 => "error",
                    _ => "opening",
                }
            };
            (self.api.video_get_size)(self.player as Pointer, 0, &mut width, &mut height);
            if let Some(media) = self.media {
                (self.api.media_get_stats)(media as Pointer, &mut stats);
            }
            PlayerStatus {
                state: state.into(),
                channel_id: self.channel_id.clone(),
                volume: self.volume,
                width,
                height,
                decoded_video: stats.decoded_video,
                decoded_audio: stats.decoded_audio,
            }
        }
    }
}

impl Drop for Player {
    fn drop(&mut self) {
        unsafe {
            (self.api.stop)(self.player as Pointer);
            (self.api.player_release)(self.player as Pointer);
            if let Some(media) = self.media {
                (self.api.media_release)(media as Pointer);
            }
            (self.api.release)(self.instance as Pointer);
        }
    }
}
