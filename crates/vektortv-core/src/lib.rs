//! Portable IPTV domain, provider clients, parsing and SQLite persistence.
//! No Tauri, Win32 or playback-engine dependencies. Secrets are never stored here.
pub mod countries;
pub mod m3u;
pub mod models;
pub mod provider;
pub mod store;
pub mod xmltv;

pub use models::*;
pub use store::Store;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("{0}")]
    Invalid(String),
    #[error("The provider could not be reached. Check the address and connection, then retry.")]
    Network,
    #[error("The provider rejected this request (HTTP {0}). Check the account details.")]
    Http(u16),
    #[error("The provider response is larger than the supported 128 MiB limit.")]
    TooLarge,
    #[error("Local library error: {0}")]
    Database(#[from] rusqlite::Error),
}

pub type Result<T> = std::result::Result<T, Error>;
