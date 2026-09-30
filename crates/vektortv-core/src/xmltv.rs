use crate::{models::normalized, Channel, Error, Programme, Result};
use quick_xml::{events::Event, Reader};
use std::{collections::HashMap, io::BufRead};

pub fn timestamp(input: &str) -> Option<i64> {
    let text = input.trim();
    chrono::DateTime::parse_from_str(text, "%Y%m%d%H%M%S %z")
        .ok()
        .map(|t| t.timestamp())
        .or_else(|| {
            chrono::NaiveDateTime::parse_from_str(text, "%Y%m%d%H%M%S")
                .ok()
                .map(|t| t.and_utc().timestamp())
        })
}

pub fn parse<R: BufRead>(
    input: R,
    channels: &[Channel],
    from: i64,
    until: i64,
) -> Result<Vec<Programme>> {
    let mut exact: HashMap<String, Vec<String>> = HashMap::new();
    let mut names: HashMap<String, Vec<String>> = HashMap::new();
    for channel in channels {
        if !channel.epg_id.is_empty() {
            exact
                .entry(channel.epg_id.clone())
                .or_default()
                .push(channel.id.clone());
        }
        names
            .entry(normalized(&channel.name))
            .or_default()
            .push(channel.id.clone());
    }
    let mut reader = Reader::from_reader(input);
    // Preserve spaces on either side of split XML entity events ("Wild & Free").
    reader.config_mut().trim_text(false);
    let mut buffer = Vec::new();
    let mut current: Option<Programme> = None;
    let mut field = String::new();
    let mut programmes = Vec::new();
    let mut saw_root = false;
    let mut closed_root = false;
    let mut retained_bytes = 0usize;
    loop {
        match reader.read_event_into(&mut buffer) {
            Ok(Event::Start(event)) => {
                let tag = String::from_utf8_lossy(event.name().as_ref()).into_owned();
                if tag == "tv" {
                    saw_root = true;
                }
                if tag == "programme" {
                    let mut source_id = String::new();
                    let mut start = None;
                    let mut end = None;
                    for attribute in event.attributes().flatten() {
                        let value = attribute
                            .decode_and_unescape_value(reader.decoder())
                            .map_err(|_| {
                                Error::Invalid("The guide contains invalid XML attributes.".into())
                            })?;
                        match attribute.key.as_ref() {
                            b"channel" => source_id = value.into_owned(),
                            b"start" => start = timestamp(&value),
                            b"stop" => end = timestamp(&value),
                            _ => {}
                        }
                    }
                    current = start
                        .zip(end)
                        .filter(|(s, e)| e > s && *e > from && *s < until)
                        .map(|(start, end)| Programme {
                            channel_id: source_id,
                            title: String::new(),
                            description: String::new(),
                            start,
                            end,
                            category: String::new(),
                        });
                }
                field = tag;
            }
            Ok(Event::Text(text)) => {
                if let Some(programme) = &mut current {
                    let decoded = text
                        .decode()
                        .map_err(|_| Error::Invalid("The guide contains invalid text.".into()))?;
                    append_field(programme, &field, &decoded);
                }
            }
            Ok(Event::GeneralRef(reference)) => {
                if let Some(programme) = &mut current {
                    let name = reference.decode().map_err(|_| {
                        Error::Invalid("The guide contains an invalid entity.".into())
                    })?;
                    let entity = format!("&{name};");
                    let value = quick_xml::escape::unescape(&entity).map_err(|_| {
                        Error::Invalid("The guide contains an unknown entity.".into())
                    })?;
                    append_field(programme, &field, &value);
                }
            }
            Ok(Event::CData(text)) => {
                if let Some(programme) = &mut current {
                    let value = text
                        .decode()
                        .map_err(|_| Error::Invalid("The guide contains invalid text.".into()))?;
                    append_field(programme, &field, &value);
                }
            }
            Ok(Event::End(event)) => {
                if event.name().as_ref() == b"tv" {
                    closed_root = true;
                }
                if event.name().as_ref() == b"programme" {
                    if let Some(programme) = current.take() {
                        let mapped = exact.get(&programme.channel_id).or_else(|| {
                            names
                                .get(&normalized(&programme.channel_id))
                                .filter(|ids| ids.len() == 1)
                        });
                        if let Some(ids) = mapped {
                            for id in ids {
                                let mut entry = programme.clone();
                                entry.channel_id = id.clone();
                                entry.title = entry.title.trim().to_owned();
                                entry.description = entry.description.trim().to_owned();
                                entry.category = entry.category.trim().to_owned();
                                if !entry.title.is_empty() {
                                    retained_bytes += entry.title.len()
                                        + entry.description.len()
                                        + entry.category.len()
                                        + entry.channel_id.len()
                                        + 160;
                                    if retained_bytes > 384 * 1024 * 1024 {
                                        return Err(Error::Invalid("The matched guide exceeds the supported 384 MiB working-set limit. The previous guide has been kept.".into()));
                                    }
                                    programmes.push(entry);
                                }
                            }
                        }
                    }
                }
                field.clear();
            }
            Ok(Event::Empty(event)) if event.name().as_ref() == b"tv" => {
                saw_root = true;
                closed_root = true;
            }
            Ok(Event::Eof) => break,
            Err(_) => {
                return Err(Error::Invalid(
                    "The XMLTV guide is incomplete or malformed. The previous guide has been kept."
                        .into(),
                ))
            }
            _ => {}
        }
        buffer.clear();
    }
    if !saw_root || !closed_root {
        return Err(Error::Invalid(
            "The address did not return a complete XMLTV guide.".into(),
        ));
    }
    Ok(programmes)
}

fn append_field(programme: &mut Programme, field: &str, value: &str) {
    match field {
        "title" => programme.title.push_str(value),
        "desc" => programme.description.push_str(value),
        "category" => programme.category.push_str(value),
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn channel() -> Channel {
        Channel {
            id: "one".into(),
            name: "NRK 1".into(),
            group: "Nordic".into(),
            logo: None,
            epg_id: "nrk.no".into(),
            stream_id: Some(1),
        }
    }
    #[test]
    fn offsets_entities_cdata_and_matching() {
        let xml = br#"<tv><programme channel="nrk.no" start="20260930180000 +0200" stop="20260930190000 +0200"><title>Wild &amp; Free</title><desc><![CDATA[Nature <live>]]></desc></programme><programme channel="missing" start="20260930180000 +0200" stop="20260930190000 +0200"><title>Other</title></programme></tv>"#;
        let result = parse(&xml[..], &[channel()], 0, i64::MAX).unwrap();
        assert_eq!(result.len(), 1);
        assert_eq!(result[0].title, "Wild & Free");
        assert_eq!(result[0].description, "Nature <live>");
        assert_eq!(result[0].start, timestamp("20260930160000 +0000").unwrap());
    }
    #[test]
    fn malformed_and_out_of_window() {
        assert!(parse(&b"<tv><programme>"[..], &[channel()], 0, i64::MAX).is_err());
        assert!(parse(&b"Access denied"[..], &[channel()], 0, i64::MAX).is_err());
        assert!(timestamp("not a time").is_none());
    }
}
