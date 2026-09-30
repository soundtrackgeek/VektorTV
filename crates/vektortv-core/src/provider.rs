use crate::{m3u, models::stable_id, Channel, Error, Programme, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{collections::HashMap, time::Duration};
use url::Url;

/// The native shell stores this in its OS keyring. Never log or return it to the UI.
#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Connection {
    pub kind: String,
    pub base_url: String,
    pub username: String,
    pub password: String,
    pub playlist_url: String,
    pub epg_url: String,
}

impl Connection {
    pub fn validate(&self) -> Result<()> {
        if self.kind == "xtream" {
            validate_url(&self.base_url)?;
            if self.username.trim().is_empty() || self.password.is_empty() {
                return Err(Error::Invalid(
                    "Enter both the username and password.".into(),
                ));
            }
        } else if self.kind == "m3u" {
            validate_url(&self.playlist_url)?;
        } else {
            return Err(Error::Invalid(
                "Choose Xtream or M3U as the connection type.".into(),
            ));
        }
        if !self.epg_url.trim().is_empty() {
            validate_url(&self.epg_url)?;
        }
        Ok(())
    }
    pub fn namespace(&self) -> String {
        stable_id(&if self.kind == "xtream" {
            format!("{}|{}", self.base_url.trim_end_matches('/'), self.username)
        } else {
            self.playlist_url.clone()
        })
    }
    pub fn stream_url(&self, id: i64) -> Result<String> {
        self.live_url(id, "ts")
    }
    /// Native Apple playback uses an HLS playlist rather than a continuous TS stream.
    pub fn hls_url(&self, id: i64) -> Result<String> {
        self.live_url(id, "m3u8")
    }
    fn live_url(&self, id: i64, extension: &str) -> Result<String> {
        let mut url = validate_url(&self.base_url)?;
        let mut segments = url
            .path_segments_mut()
            .map_err(|_| Error::Invalid("The server address is invalid.".into()))?;
        segments
            .pop_if_empty()
            .push("live")
            .push(&self.username)
            .push(&self.password)
            .push(&format!("{id}.{extension}"));
        drop(segments);
        Ok(url.to_string())
    }
    pub fn guide_url(&self) -> Result<Option<Url>> {
        if !self.epg_url.trim().is_empty() {
            return Ok(Some(validate_url(&self.epg_url)?));
        }
        if self.kind == "m3u" {
            return Ok(None);
        }
        Ok(Some(self.endpoint("xmltv.php", None)?))
    }
    pub fn endpoint(&self, path: &str, action: Option<&str>) -> Result<Url> {
        let base = format!("{}/", self.base_url.trim_end_matches('/'));
        let mut url = validate_url(&base)?
            .join(path)
            .map_err(|_| Error::Invalid("The server address is invalid.".into()))?;
        url.query_pairs_mut()
            .append_pair("username", &self.username)
            .append_pair("password", &self.password);
        if let Some(action) = action {
            url.query_pairs_mut().append_pair("action", action);
        }
        Ok(url)
    }
}

pub fn validate_url(input: &str) -> Result<Url> {
    let url = Url::parse(input.trim())
        .map_err(|_| Error::Invalid("Enter a complete http:// or https:// address.".into()))?;
    if !matches!(url.scheme(), "http" | "https")
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
    {
        return Err(Error::Invalid(
            "Use an HTTP address without embedded user information.".into(),
        ));
    }
    Ok(url)
}

pub struct Catalog {
    pub channels: Vec<Channel>,
    pub streams: HashMap<String, String>,
}

pub fn client() -> Result<reqwest::Client> {
    reqwest::Client::builder()
        .user_agent(concat!("VektorTV/", env!("CARGO_PKG_VERSION")))
        .connect_timeout(Duration::from_secs(15))
        .timeout(Duration::from_secs(600))
        .build()
        .map_err(|_| Error::Network)
}

pub async fn download(client: &reqwest::Client, url: Url) -> Result<Vec<u8>> {
    const LIMIT: usize = 128 * 1024 * 1024;
    let mut response = client.get(url).send().await.map_err(|_| Error::Network)?;
    if !response.status().is_success() {
        return Err(Error::Http(response.status().as_u16()));
    }
    if response
        .content_length()
        .is_some_and(|len| len > LIMIT as u64)
    {
        return Err(Error::TooLarge);
    }
    let mut bytes = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(|_| Error::Network)? {
        if bytes.len() + chunk.len() > LIMIT {
            return Err(Error::TooLarge);
        }
        bytes.extend_from_slice(&chunk);
    }
    Ok(bytes)
}

pub async fn check_account(client: &reqwest::Client, connection: &Connection) -> Result<()> {
    connection.validate()?;
    if connection.kind == "xtream" {
        let data = download(client, connection.endpoint("player_api.php", None)?).await?;
        let value: Value = serde_json::from_slice(&data).map_err(|_| {
            Error::Invalid("The server did not return an Xtream account response.".into())
        })?;
        let authenticated = value["user_info"]["auth"].as_i64() == Some(1)
            || value["user_info"]["auth"].as_str() == Some("1");
        if !authenticated {
            return Err(Error::Invalid(
                "The account could not be authenticated. Check the username and password.".into(),
            ));
        }
        if value["user_info"]["status"]
            .as_str()
            .is_some_and(|s| s != "Active")
        {
            return Err(Error::Invalid("The IPTV account is not active.".into()));
        }
    }
    Ok(())
}

fn text(value: &Value) -> String {
    value.as_str().map(str::to_owned).unwrap_or_else(|| {
        if value.is_number() {
            value.to_string()
        } else {
            String::new()
        }
    })
}

pub async fn catalog(client: &reqwest::Client, connection: &Connection) -> Result<Catalog> {
    check_account(client, connection).await?;
    if connection.kind == "m3u" {
        let data = download(client, validate_url(&connection.playlist_url)?).await?;
        let input = String::from_utf8_lossy(&data);
        let playlist = m3u::parse(&input, &connection.namespace())?;
        return Ok(Catalog {
            channels: playlist.channels,
            streams: playlist.streams,
        });
    }
    let categories = download(
        client,
        connection.endpoint("player_api.php", Some("get_live_categories"))?,
    )
    .await?;
    let streams = download(
        client,
        connection.endpoint("player_api.php", Some("get_live_streams"))?,
    )
    .await?;
    parse_xtream(&categories, &streams, &connection.namespace())
}

pub fn parse_xtream(
    category_bytes: &[u8],
    stream_bytes: &[u8],
    namespace: &str,
) -> Result<Catalog> {
    let categories: Vec<Value> = serde_json::from_slice(category_bytes)
        .map_err(|_| Error::Invalid("The server did not return a channel-group list.".into()))?;
    let streams: Vec<Value> = serde_json::from_slice(stream_bytes)
        .map_err(|_| Error::Invalid("The server did not return a live-channel list.".into()))?;
    let groups: HashMap<String, String> = categories
        .iter()
        .map(|value| (text(&value["category_id"]), text(&value["category_name"])))
        .collect();
    let mut channels = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for value in streams {
        let Some(stream_id) = value["stream_id"]
            .as_i64()
            .or_else(|| value["stream_id"].as_str()?.parse().ok())
        else {
            continue;
        };
        if !seen.insert(stream_id) {
            continue;
        }
        let logo = text(&value["stream_icon"]);
        channels.push(Channel {
            id: format!("{namespace}:xtream:{stream_id}"),
            name: text(&value["name"]),
            group: groups
                .get(&text(&value["category_id"]))
                .cloned()
                .unwrap_or_else(|| "Other".into()),
            logo: if logo.is_empty() { None } else { Some(logo) },
            epg_id: text(&value["epg_channel_id"]),
            stream_id: Some(stream_id),
        });
    }
    if channels.is_empty() {
        return Err(Error::Invalid(
            "The provider returned no live channels. The previous library has been kept.".into(),
        ));
    }
    Ok(Catalog {
        channels,
        streams: HashMap::new(),
    })
}

pub fn safe_logo(input: Option<String>, connection: &Connection) -> Option<String> {
    let input = input?;
    let parsed = validate_url(&input).ok()?;
    if parsed.query_pairs().any(|(key, _)| {
        matches!(
            key.to_lowercase().as_str(),
            "username" | "password" | "token" | "auth"
        )
    }) || (!connection.password.is_empty() && input.contains(&connection.password))
    {
        return None;
    }
    Some(parsed.to_string())
}

/// Parse a large XMLTV response concurrently with downloading it. The network
/// queue holds at most 2 MiB; the raw guide is never collected in memory.
pub async fn guide(
    client: &reqwest::Client,
    url: Url,
    channels: Vec<Channel>,
    from: i64,
    until: i64,
) -> Result<Vec<Programme>> {
    use std::io::{BufReader, Read};
    enum Chunk {
        Data(Vec<u8>),
        Failed,
        Complete,
    }
    struct StreamReader {
        receiver: tokio::sync::mpsc::Receiver<Chunk>,
        current: std::io::Cursor<Vec<u8>>,
    }
    impl Read for StreamReader {
        fn read(&mut self, output: &mut [u8]) -> std::io::Result<usize> {
            loop {
                let count = self.current.read(output)?;
                if count > 0 {
                    return Ok(count);
                }
                match self.receiver.blocking_recv() {
                    Some(Chunk::Data(bytes)) => self.current = std::io::Cursor::new(bytes),
                    Some(Chunk::Complete) => return Ok(0),
                    Some(Chunk::Failed) | None => {
                        return Err(std::io::Error::new(
                            std::io::ErrorKind::UnexpectedEof,
                            "Guide download interrupted",
                        ))
                    }
                }
            }
        }
    }
    let mut response = client.get(url).send().await.map_err(|_| Error::Network)?;
    if !response.status().is_success() {
        return Err(Error::Http(response.status().as_u16()));
    }
    let (sender, receiver) = tokio::sync::mpsc::channel(32);
    let parser = tokio::task::spawn_blocking(move || {
        crate::xmltv::parse(
            BufReader::new(StreamReader {
                receiver,
                current: std::io::Cursor::new(Vec::new()),
            }),
            &channels,
            from,
            until,
        )
    });
    let mut received = 0usize;
    let mut failure = None;
    loop {
        match response.chunk().await {
            Ok(Some(chunk)) => {
                received += chunk.len();
                if received > 1024 * 1024 * 1024 {
                    failure = Some(Error::Invalid(
                        "The XMLTV feed exceeds the supported 1 GiB streamed limit.".into(),
                    ));
                    break;
                }
                let mut closed = false;
                for piece in chunk.chunks(65536) {
                    if sender.send(Chunk::Data(piece.to_vec())).await.is_err() {
                        closed = true;
                        break;
                    }
                }
                if closed {
                    break;
                }
            }
            Ok(None) => {
                let _ = sender.send(Chunk::Complete).await;
                break;
            }
            Err(_) => {
                failure = Some(Error::Network);
                break;
            }
        }
    }
    if failure.is_some() {
        let _ = sender.send(Chunk::Failed).await;
    }
    drop(sender);
    let result = parser
        .await
        .map_err(|_| Error::Invalid("Guide processing was interrupted.".into()))?;
    if let Some(error) = failure {
        return Err(error);
    }
    result
}

pub async fn short_guide(
    client: &reqwest::Client,
    connection: &Connection,
    channel: &Channel,
) -> Result<Vec<Programme>> {
    use base64::Engine;
    let Some(stream_id) = channel.stream_id else {
        return Ok(Vec::new());
    };
    let mut url = connection.endpoint("player_api.php", Some("get_short_epg"))?;
    url.query_pairs_mut()
        .append_pair("stream_id", &stream_id.to_string())
        .append_pair("limit", "64");
    let bytes = download(client, url).await?;
    let value: Value = serde_json::from_slice(&bytes)
        .map_err(|_| Error::Invalid("The provider did not return programme data.".into()))?;
    let Some(entries) = value["epg_listings"].as_array() else {
        return Ok(Vec::new());
    };
    let decode = |value: &Value| {
        let raw = text(value);
        base64::engine::general_purpose::STANDARD
            .decode(&raw)
            .ok()
            .and_then(|b| String::from_utf8(b).ok())
            .unwrap_or(raw)
    };
    let mut programmes = Vec::new();
    for entry in entries {
        let integer = |key: &str| {
            entry[key]
                .as_i64()
                .or_else(|| entry[key].as_str()?.parse().ok())
        };
        if let Some((start, end)) = integer("start_timestamp")
            .zip(integer("stop_timestamp").or_else(|| integer("end_timestamp")))
        {
            if end > start {
                programmes.push(Programme {
                    channel_id: channel.id.clone(),
                    title: decode(&entry["title"]),
                    description: decode(&entry["description"]),
                    start,
                    end,
                    category: String::new(),
                });
            }
        }
    }
    Ok(programmes)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ids_are_scoped_and_credentials_are_encoded() {
        let c = Connection {
            kind: "xtream".into(),
            base_url: "https://example.test".into(),
            username: "a b".into(),
            password: "p&x".into(),
            playlist_url: String::new(),
            epg_url: String::new(),
        };
        assert!(c.stream_url(42).unwrap().contains("a%20b/p&x/42.ts"));
        let pairs: HashMap<_, _> = c
            .endpoint("player_api.php", None)
            .unwrap()
            .query_pairs()
            .map(|(k, v)| (k.into_owned(), v.into_owned()))
            .collect();
        assert_eq!(pairs["password"], "p&x");
        assert!(!c.namespace().contains("a b"));
        assert!(validate_url("file:///private").is_err());
        assert!(safe_logo(Some("https://example.test/logo?password=p".into()), &c).is_none());
    }
    #[test]
    fn xtream_accepts_string_ids_and_retains_group() {
        let catalog = parse_xtream(
            br#"[{"category_id":"3","category_name":"Nordic"}]"#,
            br#"[{"stream_id":"9","category_id":3,"name":"NRK","epg_channel_id":"nrk.no"}]"#,
            "a",
        )
        .unwrap();
        assert_eq!(catalog.channels[0].group, "Nordic");
        assert_eq!(catalog.channels[0].stream_id, Some(9));
        assert!(parse_xtream(b"[]", b"{\"error\":true}", "a").is_err());
    }
}
