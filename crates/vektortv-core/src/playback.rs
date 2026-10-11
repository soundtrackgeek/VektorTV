//! Bounded live-stream preflight. Never include authenticated URLs in errors.
use crate::{provider::validate_url, Error, Result};
use reqwest::Client;
use std::time::Duration;

const MAX_PLAYLIST: usize = 64 * 1024;
pub const ENDED_STREAM: &str = "The provider returned an ended stream instead of a live broadcast. This channel may be offline. Retry later or choose another channel.";

/// Xtream live endpoints can return HTTP 200 with an offline, finite HLS clip,
/// even when requested as .ts. Inspect the response rather than the extension.
pub async fn check_live_stream(client: &Client, address: &str) -> Result<()> {
    let mut url = validate_url(address)?;
    for _ in 0..4 {
        let mut response = client
            .get(url.clone())
            .timeout(Duration::from_secs(12))
            .send()
            .await
            .map_err(|_| Error::Network)?;
        let status = response.status();
        if !status.is_success() {
            return Err(Error::Invalid(format!(
                "The provider could not serve this channel (HTTP {}). Retry later or choose another channel.",
                status.as_u16()
            )));
        }
        let final_url = response.url().clone();
        let mut bytes = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(|_| Error::Network)? {
            bytes.extend_from_slice(&chunk[..chunk.len().min(MAX_PLAYLIST + 1 - bytes.len())]);
            let text = String::from_utf8_lossy(&bytes);
            let start = text.trim_start_matches('\u{feff}').trim_start();
            if bytes.len() >= 8 && !start.starts_with('#') {
                // A TS packet starts with 0x47; other binary formats go to VLC.
                if start.starts_with('<') {
                    return Err(Error::Invalid("The provider returned a web page instead of a channel stream. Retry later or choose another channel.".into()));
                }
                return Ok(());
            }
            if bytes.len() > MAX_PLAYLIST {
                return Err(Error::Invalid(
                    "The channel playlist exceeds the supported size.".into(),
                ));
            }
        }
        let text = std::str::from_utf8(&bytes).map_err(|_| {
            Error::Invalid("The provider returned an invalid channel stream.".into())
        })?;
        let variant = inspect_playlist(text)?;
        if let Some(variant) = variant {
            url = final_url.join(variant).map_err(|_| {
                Error::Invalid("The channel playlist contains an invalid address.".into())
            })?;
            validate_url(url.as_str())?;
        } else {
            return Ok(());
        }
    }
    Err(Error::Invalid(
        "The channel playlist redirects through too many nested playlists.".into(),
    ))
}

fn inspect_playlist(text: &str) -> Result<Option<&str>> {
    let mut lines = text
        .trim_start_matches('\u{feff}')
        .trim()
        .lines()
        .map(str::trim);
    if lines.next() != Some("#EXTM3U") {
        return Err(Error::Invalid(
            "The provider returned an invalid channel playlist.".into(),
        ));
    }
    let lines: Vec<_> = lines.collect();
    if lines.contains(&"#EXT-X-ENDLIST") {
        return Err(Error::Invalid(ENDED_STREAM.into()));
    }
    let uri = lines.iter().copied().find(|line| !line.is_empty() && !line.starts_with('#'))
        .ok_or_else(|| Error::Invalid("The provider returned an empty channel playlist. Retry later or choose another channel.".into()))?;
    Ok(lines
        .iter()
        .any(|line| line.starts_with("#EXT-X-STREAM-INF:"))
        .then_some(uri))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn distinguishes_live_media_master_and_offline_clip() {
        assert_eq!(
            inspect_playlist(
                "\u{feff}#EXTM3U\r\n#EXT-X-MEDIA-SEQUENCE:42\r\n#EXTINF:10,\r\nsegment.ts\r\n"
            )
            .unwrap(),
            None
        );
        assert_eq!(
            inspect_playlist("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nlow/index.m3u8\n").unwrap(),
            Some("low/index.m3u8")
        );
        assert_eq!(
            inspect_playlist("#EXTM3U\n#EXTINF:15,\nblack.ts\n#EXT-X-ENDLIST\n")
                .unwrap_err()
                .to_string(),
            ENDED_STREAM
        );
        assert!(inspect_playlist("#EXTM3U\n#EXT-X-TARGETDURATION:10\n").is_err());
        assert!(inspect_playlist("<html>offline</html>").is_err());
    }

    #[tokio::test]
    async fn detects_offline_hls_even_at_a_ts_address_without_leaking_credentials() {
        use std::io::{Read, Write};
        let server = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = server.local_addr().unwrap();
        let thread = std::thread::spawn(move || {
            let (mut socket, _) = server.accept().unwrap();
            let mut request = [0; 2048];
            assert!(socket.read(&mut request).unwrap() > 0);
            let body = "#EXTM3U\n#EXTINF:15,\nblack.ts\n#EXT-X-ENDLIST\n";
            write!(
                socket,
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            )
            .unwrap();
        });
        let error = check_live_stream(
            &crate::provider::client().unwrap(),
            &format!("http://{addr}/live/secret-user/secret-password/1.ts"),
        )
        .await
        .unwrap_err()
        .to_string();
        thread.join().unwrap();
        assert_eq!(error, ENDED_STREAM);
        assert!(!error.contains("secret"));
    }
}
