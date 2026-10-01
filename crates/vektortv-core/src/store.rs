use crate::{
    countries, models::normalized, Channel, ChannelPage, ChannelQuery, ChannelView, Country, Error,
    Group, Programme, Result,
};
use rusqlite::{params, Connection, OptionalExtension};
use std::path::Path;

pub struct Store {
    connection: Connection,
}

impl Store {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let mut connection = Connection::open(path)?;
        connection.busy_timeout(std::time::Duration::from_secs(5))?;
        connection.execute_batch("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
            CREATE TABLE IF NOT EXISTS channels (id TEXT PRIMARY KEY,name TEXT NOT NULL,search_name TEXT NOT NULL,group_name TEXT NOT NULL,logo TEXT,epg_id TEXT NOT NULL,stream_id INTEGER,position INTEGER NOT NULL);
            CREATE INDEX IF NOT EXISTS channels_group ON channels(group_name,position);
            CREATE TABLE IF NOT EXISTS favourites (channel_id TEXT PRIMARY KEY);
            CREATE TABLE IF NOT EXISTS history (channel_id TEXT PRIMARY KEY,watched_at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS programmes (channel_id TEXT NOT NULL,title TEXT NOT NULL,description TEXT NOT NULL,start INTEGER NOT NULL,end INTEGER NOT NULL,category TEXT NOT NULL,PRIMARY KEY(channel_id,start,end,title));
            CREATE INDEX IF NOT EXISTS programme_lookup ON programmes(channel_id,start,end);
            CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS country_groups (group_name TEXT PRIMARY KEY,country_code TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS country_group_code ON country_groups(country_code);
            CREATE TABLE IF NOT EXISTS country_favourites (country_code TEXT PRIMARY KEY);
            CREATE TABLE IF NOT EXISTS channel_sort (channel_id TEXT PRIMARY KEY,sort_name TEXT NOT NULL);
            PRAGMA user_version=2;")?;
        // Backfill cached libraries once; no provider refresh is required.
        let mapped: bool = connection.query_row(
            "SELECT EXISTS(SELECT 1 FROM metadata WHERE key='country_mapping' AND value='1')",
            [],
            |r| r.get(0),
        )?;
        if !mapped {
            let tx = connection.transaction()?;
            rebuild_countries(&tx)?;
            tx.commit()?;
        }
        Ok(Self { connection })
    }
    pub fn metadata(&self, key: &str) -> Result<Option<String>> {
        Ok(self
            .connection
            .query_row("SELECT value FROM metadata WHERE key=?1", [key], |r| {
                r.get(0)
            })
            .optional()?)
    }
    pub fn set_metadata(&self, key: &str, value: &str) -> Result<()> {
        self.connection.execute("INSERT INTO metadata VALUES (?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [key, value])?;
        Ok(())
    }
    pub fn channel_count(&self) -> Result<usize> {
        Ok(self
            .connection
            .query_row("SELECT COUNT(*) FROM channels", [], |r| r.get(0))?)
    }
    pub fn programme_count(&self) -> Result<usize> {
        Ok(self
            .connection
            .query_row("SELECT COUNT(*) FROM programmes", [], |r| r.get(0))?)
    }
    pub fn all_channels(&self) -> Result<Vec<Channel>> {
        let mut statement = self.connection.prepare(
            "SELECT id,name,group_name,logo,epg_id,stream_id FROM channels ORDER BY position",
        )?;
        let rows = statement
            .query_map([], read_channel)?
            .collect::<std::result::Result<_, _>>()?;
        Ok(rows)
    }
    pub fn channel(&self, id: &str) -> Result<Channel> {
        self.connection
            .query_row(
                "SELECT id,name,group_name,logo,epg_id,stream_id FROM channels WHERE id=?1",
                [id],
                read_channel,
            )
            .optional()?
            .ok_or_else(|| {
                Error::Invalid("This channel is no longer in the current library.".into())
            })
    }
    pub fn replace_channels(&mut self, channels: &[Channel], updated_at: i64) -> Result<()> {
        self.replace_channels_impl(channels, updated_at, None)
    }
    /// Commit the account namespace and its catalog together for native shells.
    pub fn replace_catalog(
        &mut self,
        channels: &[Channel],
        updated_at: i64,
        namespace: &str,
    ) -> Result<()> {
        self.replace_channels_impl(channels, updated_at, Some(namespace))
    }
    fn replace_channels_impl(
        &mut self,
        channels: &[Channel],
        updated_at: i64,
        namespace: Option<&str>,
    ) -> Result<()> {
        if channels.is_empty() {
            return Err(Error::Invalid(
                "An empty import cannot replace the channel library.".into(),
            ));
        }
        let tx = self.connection.transaction()?;
        if let Some(namespace) = namespace {
            let old: Option<String> = tx
                .query_row(
                    "SELECT value FROM metadata WHERE key='namespace'",
                    [],
                    |row| row.get(0),
                )
                .optional()?;
            if old.as_deref() != Some(namespace) {
                tx.execute("DELETE FROM programmes", [])?;
                tx.execute("DELETE FROM metadata WHERE key='guide_updated'", [])?;
            }
            tx.execute("INSERT INTO metadata VALUES ('namespace',?1) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [namespace])?;
        }
        tx.execute("DELETE FROM channels", [])?;
        {
            let mut insert = tx.prepare("INSERT INTO channels VALUES (?1,?2,?3,?4,?5,?6,?7,?8)")?;
            for (index, c) in channels.iter().enumerate() {
                insert.execute(params![
                    c.id,
                    c.name,
                    normalized(&c.name),
                    c.group,
                    c.logo,
                    c.epg_id,
                    c.stream_id,
                    index
                ])?;
            }
        }
        tx.execute("INSERT INTO metadata VALUES ('channels_updated',?1) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [updated_at.to_string()])?;
        rebuild_countries(&tx)?;
        tx.commit()?;
        Ok(())
    }
    pub fn replace_programmes(&mut self, programmes: &[Programme], updated_at: i64) -> Result<()> {
        let tx = self.connection.transaction()?;
        tx.execute("DELETE FROM programmes", [])?;
        {
            let mut insert =
                tx.prepare("INSERT OR IGNORE INTO programmes VALUES (?1,?2,?3,?4,?5,?6)")?;
            for p in programmes {
                insert.execute(params![
                    p.channel_id,
                    p.title,
                    p.description,
                    p.start,
                    p.end,
                    p.category
                ])?;
            }
        }
        tx.execute("INSERT INTO metadata VALUES ('guide_updated',?1) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [updated_at.to_string()])?;
        tx.commit()?;
        Ok(())
    }
    pub fn merge_programmes(&mut self, programmes: &[Programme]) -> Result<()> {
        let tx = self.connection.transaction()?;
        {
            let mut insert = tx.prepare("INSERT INTO programmes VALUES (?1,?2,?3,?4,?5,?6) ON CONFLICT(channel_id,start,end,title) DO UPDATE SET description=excluded.description,category=excluded.category")?;
            for p in programmes {
                insert.execute(params![
                    p.channel_id,
                    p.title,
                    p.description,
                    p.start,
                    p.end,
                    p.category
                ])?;
            }
        }
        tx.commit()?;
        Ok(())
    }
    pub fn groups(&self) -> Result<Vec<Group>> {
        let mut statement = self.connection.prepare("SELECT group_name,COUNT(*) FROM channels GROUP BY group_name ORDER BY group_name COLLATE NOCASE")?;
        let rows = statement
            .query_map([], |r| {
                Ok(Group {
                    name: r.get(0)?,
                    count: r.get(1)?,
                })
            })?
            .collect::<std::result::Result<_, _>>()?;
        Ok(rows)
    }
    pub fn countries(&self) -> Result<Vec<Country>> {
        let mut statement = self.connection.prepare("SELECT g.country_code,c.group_name,COUNT(*),f.country_code IS NOT NULL FROM channels c JOIN country_groups g ON g.group_name=c.group_name LEFT JOIN country_favourites f ON f.country_code=g.country_code GROUP BY g.country_code,c.group_name ORDER BY c.group_name COLLATE NOCASE")?;
        let mut countries = std::collections::BTreeMap::<String, Country>::new();
        for row in statement.query_map([], |r| {
            Ok((
                r.get::<_, String>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, usize>(2)?,
                r.get::<_, bool>(3)?,
            ))
        })? {
            let (code, group, count, favorite) = row?;
            let country = countries.entry(code.clone()).or_insert_with(|| Country {
                name: countries::name(&code)
                    .unwrap_or("International & unassigned")
                    .into(),
                code,
                count: 0,
                groups: vec![],
                favorite,
            });
            country.count += count;
            country.groups.push(Group { name: group, count });
        }
        let mut countries: Vec<_> = countries.into_values().collect();
        countries.sort_by_key(|c| {
            (
                !c.favorite,
                c.code == countries::UNASSIGNED,
                countries::sort_key(&c.name),
            )
        });
        Ok(countries)
    }
    pub fn favorite_country(&self, code: &str, favorite: bool) -> Result<()> {
        if countries::name(code).is_none() {
            return Err(Error::Invalid("Unknown country.".into()));
        }
        if favorite {
            self.connection.execute(
                "INSERT OR IGNORE INTO country_favourites VALUES (?1)",
                [code],
            )?;
        } else {
            self.connection.execute(
                "DELETE FROM country_favourites WHERE country_code=?1",
                [code],
            )?;
        }
        Ok(())
    }
    pub fn list(&self, query: &ChannelQuery, now: i64) -> Result<ChannelPage> {
        let search = normalized(&query.search)
            .replace('\\', "\\\\")
            .replace('%', "\\%")
            .replace('_', "\\_");
        let filter = " FROM channels c LEFT JOIN favourites f ON f.channel_id=c.id LEFT JOIN history h ON h.channel_id=c.id JOIN country_groups g ON g.group_name=c.group_name JOIN channel_sort s ON s.channel_id=c.id
          WHERE (?1='' OR c.search_name LIKE '%'||?1||'%' ESCAPE '\\') AND (?2 IS NULL OR c.group_name=?2)
          AND (?3=0 OR f.channel_id IS NOT NULL) AND (?4=0 OR h.channel_id IS NOT NULL) AND (?5 IS NULL OR g.country_code=?5)";
        let total: usize = self.connection.query_row(
            &format!("SELECT COUNT(*){filter}"),
            params![
                search,
                query.group,
                query.favorites_only,
                query.history_only,
                query.country
            ],
            |r| r.get(0),
        )?;
        let order = if query.history_only {
            "h.watched_at DESC,c.position"
        } else if query.alphabetical {
            "s.sort_name,c.name,c.id"
        } else {
            "c.position"
        };
        let sql = format!("SELECT c.id,c.name,c.group_name,c.logo,c.epg_id,c.stream_id,f.channel_id IS NOT NULL,h.watched_at{filter} ORDER BY {order} LIMIT ?6 OFFSET ?7");
        let mut statement = self.connection.prepare(&sql)?;
        let mut channels = statement
            .query_map(
                params![
                    search,
                    query.group,
                    query.favorites_only,
                    query.history_only,
                    query.country,
                    query.limit.unwrap_or(100).clamp(1, 200),
                    query.offset
                ],
                |r| {
                    Ok(ChannelView {
                        channel: read_channel(r)?,
                        favorite: r.get(6)?,
                        last_watched: r.get(7)?,
                        now: None,
                        next: None,
                    })
                },
            )?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        for c in &mut channels {
            c.now = self.current_programme(&c.channel.id, now)?;
            c.next = self.next_programme(&c.channel.id, now)?;
        }
        Ok(ChannelPage {
            channels,
            total,
            offset: query.offset,
        })
    }
    pub fn schedule(&self, id: &str, from: i64, until: i64) -> Result<Vec<Programme>> {
        let mut statement = self.connection.prepare("SELECT channel_id,title,description,start,end,category FROM programmes WHERE channel_id=?1 AND end>?2 AND start<?3 ORDER BY start LIMIT 200")?;
        let rows = statement
            .query_map(params![id, from, until], read_programme)?
            .collect::<std::result::Result<_, _>>()?;
        Ok(rows)
    }
    fn current_programme(&self, id: &str, now: i64) -> Result<Option<Programme>> {
        Ok(self.connection.query_row("SELECT channel_id,title,description,start,end,category FROM programmes WHERE channel_id=?1 AND start<=?2 AND end>?2 ORDER BY start DESC LIMIT 1", params![id,now], read_programme).optional()?)
    }
    fn next_programme(&self, id: &str, now: i64) -> Result<Option<Programme>> {
        Ok(self.connection.query_row("SELECT channel_id,title,description,start,end,category FROM programmes WHERE channel_id=?1 AND start>?2 ORDER BY start LIMIT 1", params![id,now], read_programme).optional()?)
    }
    pub fn favorite(&self, id: &str, favorite: bool) -> Result<()> {
        self.channel(id)?;
        if favorite {
            self.connection
                .execute("INSERT OR IGNORE INTO favourites VALUES (?1)", [id])?;
        } else {
            self.connection
                .execute("DELETE FROM favourites WHERE channel_id=?1", [id])?;
        }
        Ok(())
    }
    pub fn watched(&self, id: &str, now: i64) -> Result<()> {
        self.channel(id)?;
        self.connection.execute("INSERT INTO history VALUES (?1,?2) ON CONFLICT(channel_id) DO UPDATE SET watched_at=excluded.watched_at", params![id,now])?;
        Ok(())
    }
}

fn rebuild_countries(tx: &rusqlite::Transaction<'_>) -> Result<()> {
    tx.execute("DELETE FROM country_groups", [])?;
    let mut groups = tx.prepare("SELECT DISTINCT group_name FROM channels")?;
    for group in groups.query_map([], |r| r.get::<_, String>(0))? {
        let group = group?;
        tx.execute(
            "INSERT INTO country_groups VALUES (?1,?2)",
            params![group, countries::detect(&group)],
        )?;
    }
    tx.execute("DELETE FROM channel_sort", [])?;
    let mut channels = tx.prepare("SELECT id,name FROM channels")?;
    let mut insert = tx.prepare("INSERT INTO channel_sort VALUES (?1,?2)")?;
    for row in channels.query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?)))? {
        let (id, name) = row?;
        insert.execute(params![id, countries::sort_key(&name)])?;
    }
    tx.execute("INSERT INTO metadata VALUES ('country_mapping','1') ON CONFLICT(key) DO UPDATE SET value=excluded.value", [])?;
    Ok(())
}

fn read_channel(row: &rusqlite::Row<'_>) -> rusqlite::Result<Channel> {
    Ok(Channel {
        id: row.get(0)?,
        name: row.get(1)?,
        group: row.get(2)?,
        logo: row.get(3)?,
        epg_id: row.get(4)?,
        stream_id: row.get(5)?,
    })
}
fn read_programme(row: &rusqlite::Row<'_>) -> rusqlite::Result<Programme> {
    Ok(Programme {
        channel_id: row.get(0)?,
        title: row.get(1)?,
        description: row.get(2)?,
        start: row.get(3)?,
        end: row.get(4)?,
        category: row.get(5)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    fn channels() -> Vec<Channel> {
        vec![
            Channel {
                id: "a".into(),
                name: "Ålesund 100%_HD".into(),
                group: "Nordic".into(),
                logo: None,
                epg_id: "a".into(),
                stream_id: Some(7),
            },
            Channel {
                id: "b".into(),
                name: "Other".into(),
                group: "News".into(),
                logo: None,
                epg_id: "b".into(),
                stream_id: Some(8),
            },
        ]
    }
    #[test]
    fn restart_favourites_history_unicode_search_and_literal_wildcards() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("library.db");
        {
            let mut store = Store::open(&path).unwrap();
            store.replace_channels(&channels(), 10).unwrap();
            store.favorite("a", true).unwrap();
            store.watched("a", 20).unwrap();
        }
        let mut store = Store::open(&path).unwrap();
        for needle in ["ÅLESUND", "100%_"] {
            let result = store
                .list(
                    &ChannelQuery {
                        search: needle.into(),
                        ..Default::default()
                    },
                    100,
                )
                .unwrap();
            assert_eq!(result.total, 1);
            assert!(result.channels[0].favorite);
            assert_eq!(result.channels[0].last_watched, Some(20));
        }
        store.replace_channels(&channels(), 30).unwrap();
        assert_eq!(
            store
                .list(
                    &ChannelQuery {
                        favorites_only: true,
                        ..Default::default()
                    },
                    100
                )
                .unwrap()
                .total,
            1
        );
        assert!(store.replace_channels(&[], 40).is_err());
        assert_eq!(store.channel_count().unwrap(), 2);
    }
    #[test]
    fn countries_filter_before_paging_and_sort_across_all_groups() {
        let mut store = Store::open(":memory:").unwrap();
        let catalog: Vec<_> = [
            ("z", "Zulu", "AL| ALBANIA SPORTS"),
            ("b", "Bravo", "AL| ALBANIA"),
            ("a", "Álpha", "AL| ALBANIA SPORTS"),
            ("g", "Other", "AR| BEIN SPORTS"),
            ("d", "Outside", "AR| ALGERIA"),
        ]
        .into_iter()
        .map(|(id, name, group)| Channel {
            id: id.into(),
            name: name.into(),
            group: group.into(),
            logo: None,
            epg_id: id.into(),
            stream_id: None,
        })
        .collect();
        store.replace_channels(&catalog, 10).unwrap();
        let countries = store.countries().unwrap();
        let albania = countries.iter().find(|c| c.code == "al").unwrap();
        assert_eq!((albania.count, albania.groups.len()), (3, 2));
        assert_eq!(
            countries.iter().map(|c| c.count).sum::<usize>(),
            catalog.len()
        );
        let mut query = ChannelQuery {
            country: Some("al".into()),
            alphabetical: true,
            limit: Some(2),
            ..Default::default()
        };
        let page = store.list(&query, 100).unwrap();
        assert_eq!(page.total, 3);
        assert_eq!(
            page.channels
                .iter()
                .map(|c| c.channel.id.as_str())
                .collect::<Vec<_>>(),
            ["a", "b"]
        );
        query.offset = 2;
        assert_eq!(store.list(&query, 100).unwrap().channels[0].channel.id, "z");
        query.offset = 0;
        query.group = Some("AR| ALGERIA".into());
        assert_eq!(store.list(&query, 100).unwrap().total, 0);
        query.group = None;
        query.search = "ALPHA".into();
        // Existing search keeps its documented accent-sensitive behavior.
        assert_eq!(store.list(&query, 100).unwrap().total, 0);
        query.search = "Bravo".into();
        assert_eq!(store.list(&query, 100).unwrap().total, 1);
        store.favorite("b", true).unwrap();
        query.search.clear();
        query.favorites_only = true;
        assert_eq!(store.list(&query, 100).unwrap().total, 1);
        query.country = Some("zz".into());
        query.favorites_only = false;
        assert_eq!(store.list(&query, 100).unwrap().channels[0].channel.id, "g");
    }
    #[test]
    fn country_favorites_survive_restart_refresh_and_cached_library_upgrade() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("library.db");
        {
            let mut store = Store::open(&path).unwrap();
            let mut catalog = channels();
            catalog[0].group = "Norway".into();
            catalog[1].group = "Albania".into();
            store.replace_channels(&catalog, 10).unwrap();
            store.favorite_country("no", true).unwrap();
            store.replace_channels(&catalog, 20).unwrap();
            assert_eq!(store.countries().unwrap()[0].code, "no");
            // Emulate a pre-countries cache without replacing channel/history data.
            store.connection.execute_batch("DROP TABLE country_groups; DROP TABLE channel_sort; DELETE FROM metadata WHERE key='country_mapping'; PRAGMA user_version=1;").unwrap();
        }
        let store = Store::open(path).unwrap();
        assert_eq!(store.channel_count().unwrap(), 2);
        let country = &store.countries().unwrap()[0];
        assert_eq!(country.code, "no");
        assert!(country.favorite);
        assert_eq!(
            store
                .list(
                    &ChannelQuery {
                        country: Some("no".into()),
                        ..Default::default()
                    },
                    100
                )
                .unwrap()
                .total,
            1
        );
        store.favorite_country("no", false).unwrap();
        assert_eq!(store.countries().unwrap()[0].code, "al");
        assert!(store.favorite_country("invalid", true).is_err());
    }
    #[test]
    fn programme_boundaries_and_duplicate_imports() {
        let mut store = Store::open(":memory:").unwrap();
        store.replace_channels(&channels(), 10).unwrap();
        let p = Programme {
            channel_id: "a".into(),
            title: "Now".into(),
            description: String::new(),
            start: 100,
            end: 200,
            category: String::new(),
        };
        store.replace_programmes(&[p.clone(), p], 100).unwrap();
        assert_eq!(store.programme_count().unwrap(), 1);
        assert!(
            store.list(&ChannelQuery::default(), 100).unwrap().channels[0]
                .now
                .is_some()
        );
        assert!(
            store.list(&ChannelQuery::default(), 200).unwrap().channels[0]
                .now
                .is_none()
        );
        assert!(store.favorite("missing", true).is_err());
    }
    #[test]
    fn failed_import_rolls_back_previous_snapshot() {
        let mut store = Store::open(":memory:").unwrap();
        store.replace_channels(&channels(), 10).unwrap();
        let duplicate = channels()[0].clone();
        assert!(store
            .replace_channels(&[duplicate.clone(), duplicate], 20)
            .is_err());
        assert_eq!(store.channel_count().unwrap(), 2);
        assert_eq!(
            store.metadata("channels_updated").unwrap().as_deref(),
            Some("10")
        );
    }
    #[test]
    fn account_catalog_and_guide_switch_commit_atomically() {
        let mut store = Store::open(":memory:").unwrap();
        store.replace_catalog(&channels(), 10, "account-a").unwrap();
        let programme = Programme {
            channel_id: "a".into(),
            title: "Old guide".into(),
            description: String::new(),
            start: 10,
            end: 100,
            category: String::new(),
        };
        store.replace_programmes(&[programme], 10).unwrap();
        let duplicate = channels()[0].clone();
        assert!(store
            .replace_catalog(&[duplicate.clone(), duplicate], 20, "account-b")
            .is_err());
        assert_eq!(
            store.metadata("namespace").unwrap().as_deref(),
            Some("account-a")
        );
        assert_eq!(store.programme_count().unwrap(), 1);
        store.replace_catalog(&channels(), 30, "account-b").unwrap();
        assert_eq!(
            store.metadata("namespace").unwrap().as_deref(),
            Some("account-b")
        );
        assert_eq!(store.programme_count().unwrap(), 0);
        assert_eq!(store.metadata("guide_updated").unwrap(), None);
    }
}
