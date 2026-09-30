use vektortv_core::{provider, Store};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../.env");
    let values: std::collections::HashMap<_, _> =
        dotenvy::from_path_iter(root)?.collect::<Result<_, _>>()?;
    let connection = provider::Connection {
        kind: "xtream".into(),
        base_url: values
            .get("iptv_url")
            .cloned()
            .unwrap_or_else(|| "http://ourxtream.com".into()),
        username: values
            .get("iptv_username")
            .ok_or("Missing username")?
            .clone(),
        password: values
            .get("iptv_password")
            .ok_or("Missing password")?
            .clone(),
        playlist_url: String::new(),
        epg_url: String::new(),
    };
    let started = std::time::Instant::now();
    let client = provider::client()?;
    let catalog = provider::catalog(&client, &connection).await?;
    println!(
        "Authenticated. Live channels: {}. Catalog: {:.2}s",
        catalog.channels.len(),
        started.elapsed().as_secs_f64()
    );
    let now = chrono::Utc::now().timestamp();
    let programmes = provider::guide(
        &client,
        connection.guide_url()?.ok_or("Missing guide")?,
        catalog.channels.clone(),
        now - 21600,
        now + 172800,
    )
    .await?;
    let temp = tempfile::tempdir()?;
    let mut store = Store::open(temp.path().join("check.db"))?;
    store.replace_channels(&catalog.channels, now)?;
    store.replace_programmes(&programmes, now)?;
    let start = std::time::Instant::now();
    let page = store.list(&Default::default(), now)?;
    println!("Guide records: {}. Groups: {}. First-page query: {:.1}ms. Current programmes on first page: {}.", programmes.len(), store.groups()?.len(), start.elapsed().as_secs_f64()*1000.0, page.channels.iter().filter(|c|c.now.is_some()).count());
    println!("All checks used a disposable database. No account values or stream addresses were printed.");
    Ok(())
}
