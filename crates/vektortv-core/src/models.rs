use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Channel {
    pub id: String,
    pub name: String,
    pub group: String,
    pub logo: Option<String>,
    pub epg_id: String,
    pub stream_id: Option<i64>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Programme {
    pub channel_id: String,
    pub title: String,
    pub description: String,
    pub start: i64,
    pub end: i64,
    pub category: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChannelView {
    #[serde(flatten)]
    pub channel: Channel,
    pub favorite: bool,
    pub last_watched: Option<i64>,
    pub now: Option<Programme>,
    pub next: Option<Programme>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChannelPage {
    pub channels: Vec<ChannelView>,
    pub total: usize,
    pub offset: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Group {
    pub name: String,
    pub count: usize,
}

#[derive(Clone, Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChannelQuery {
    #[serde(default)]
    pub search: String,
    pub group: Option<String>,
    #[serde(default)]
    pub favorites_only: bool,
    #[serde(default)]
    pub history_only: bool,
    #[serde(default)]
    pub offset: usize,
    pub limit: Option<usize>,
}

pub fn normalized(value: &str) -> String {
    value
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

pub fn stable_id(value: &str) -> String {
    use sha2::{Digest, Sha256};
    format!("{:x}", Sha256::digest(value.as_bytes()))[..24].to_owned()
}
