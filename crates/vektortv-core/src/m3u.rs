use crate::{models::stable_id, Channel, Error, Result};
use std::collections::HashMap;

pub struct Playlist {
    pub channels: Vec<Channel>,
    /// Playback locations remain in memory; they must not enter SQLite or UI DTOs.
    pub streams: HashMap<String, String>,
}

fn attribute(line: &str, name: &str) -> Option<String> {
    let needle = format!("{name}=");
    let start = line.find(&needle)? + needle.len();
    let remaining = &line[start..];
    if let Some(rest) = remaining.strip_prefix('"') {
        Some(rest.split('"').next()?.to_owned())
    } else if let Some(rest) = remaining.strip_prefix('\'') {
        Some(rest.split('\'').next()?.to_owned())
    } else {
        Some(remaining.split([' ', ',']).next()?.to_owned())
    }
}

fn display_name(line: &str) -> Option<&str> {
    let mut quote = None;
    for (index, value) in line.char_indices() {
        if matches!(value, '"' | '\'') {
            if quote == Some(value) {
                quote = None;
            } else if quote.is_none() {
                quote = Some(value);
            }
        } else if value == ',' && quote.is_none() {
            return Some(line[index + 1..].trim());
        }
    }
    None
}

pub fn parse(input: &str, namespace: &str) -> Result<Playlist> {
    let text = input.trim_start_matches('\u{feff}').trim_start();
    if !text.starts_with("#EXTM3U") {
        return Err(Error::Invalid(
            "The address did not return an M3U playlist.".into(),
        ));
    }
    let mut channels = Vec::new();
    let mut streams = HashMap::new();
    let mut pending: Option<Channel> = None;
    for line in text.lines().map(str::trim) {
        if line.starts_with("#EXTINF:") {
            let name = display_name(line)
                .filter(|s| !s.is_empty())
                .map(str::to_owned)
                .or_else(|| attribute(line, "tvg-name"))
                .unwrap_or_else(|| "Unnamed channel".into());
            pending = Some(Channel {
                id: String::new(),
                name,
                group: attribute(line, "group-title")
                    .filter(|s| !s.is_empty())
                    .unwrap_or_else(|| "Other".into()),
                logo: attribute(line, "tvg-logo").filter(|s| !s.is_empty()),
                epg_id: attribute(line, "tvg-id").unwrap_or_default(),
                stream_id: None,
            });
        } else if let Some(group) = line.strip_prefix("#EXTGRP:") {
            if let Some(channel) = &mut pending {
                channel.group = group.trim().to_owned();
            }
        } else if !line.is_empty() && !line.starts_with('#') {
            if let Some(mut channel) = pending.take() {
                let parsed = url::Url::parse(line)
                    .map_err(|_| Error::Invalid("A playlist stream address is invalid.".into()))?;
                if !matches!(parsed.scheme(), "http" | "https") {
                    continue;
                }
                channel.id = format!("{namespace}:m3u:{}", stable_id(line));
                if streams
                    .insert(channel.id.clone(), line.to_owned())
                    .is_none()
                {
                    channels.push(channel);
                }
            }
        }
    }
    if channels.is_empty() {
        return Err(Error::Invalid(
            "The playlist contains no playable HTTP channels.".into(),
        ));
    }
    Ok(Playlist { channels, streams })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn quoted_commas_bom_duplicate_urls_and_extgrp() {
        let input = "\u{feff}#EXTM3U\n#EXTINF:-1 tvg-id=nrk tvg-name=\"One, Two\" group-title=\"Norsk, Sverige\",NRK 1, HD\n#EXTGRP:Nordic\nhttps://example.test/one.ts\n#EXTINF:-1,Duplicate\nhttps://example.test/one.ts\n#EXTINF:-1,Unsafe\nfile:///secret\n";
        let parsed = parse(input, "test").unwrap();
        assert_eq!(parsed.channels.len(), 1);
        assert_eq!(parsed.channels[0].name, "NRK 1, HD");
        assert_eq!(parsed.channels[0].group, "Nordic");
        assert_eq!(parsed.channels[0].epg_id, "nrk");
        assert!(!parsed.channels[0].id.contains("example.test"));
    }
    #[test]
    fn provider_error_is_not_a_playlist() {
        assert!(parse("<html>Access denied</html>", "test").is_err());
        assert!(parse("#EXTM3U\n", "test").is_err());
    }
}
