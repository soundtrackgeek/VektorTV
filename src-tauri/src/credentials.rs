use vektortv_core::provider::Connection;

fn entry() -> Result<keyring::Entry, String> {
    keyring::Entry::new("com.vektortv.desktop", "primary-provider-v1")
        .map_err(|_| "Windows Credential Manager is unavailable.".to_owned())
}

pub fn save(connection: &Connection) -> Result<(), String> {
    let value = serde_json::to_string(connection)
        .map_err(|_| "Could not prepare the connection.".to_owned())?;
    entry()?
        .set_password(&value)
        .map_err(|_| "The connection could not be saved in Windows Credential Manager.".to_owned())
}

pub fn load() -> Result<Option<Connection>, String> {
    match entry()?.get_password() {
        Ok(value) => serde_json::from_str(&value)
            .map(Some)
            .map_err(|_| "The saved connection is unreadable. Reconnect in Settings.".to_owned()),
        Err(keyring::Error::NoEntry) => development_connection(),
        Err(_) => {
            Err("The saved connection could not be opened from Windows Credential Manager.".into())
        }
    }
}

fn development_connection() -> Result<Option<Connection>, String> {
    // A packaged app never reads .env, and credentials never enter Vite's environment.
    if !cfg!(debug_assertions) {
        return Ok(None);
    }
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../.env");
    if !path.is_file() {
        return Ok(None);
    }
    let values: std::collections::HashMap<_, _> = dotenvy::from_path_iter(path)
        .map_err(|_| "Could not read the development .env.".to_owned())?
        .collect::<Result<_, _>>()
        .map_err(|_| "The development .env format is invalid.".to_owned())?;
    let Some(username) = values.get("iptv_username") else {
        return Ok(None);
    };
    let Some(password) = values.get("iptv_password") else {
        return Ok(None);
    };
    let connection = Connection {
        kind: "xtream".into(),
        base_url: values
            .get("iptv_url")
            .cloned()
            .unwrap_or_else(|| "http://ourxtream.com".into()),
        username: username.clone(),
        password: password.clone(),
        playlist_url: String::new(),
        epg_url: String::new(),
    };
    connection.validate().map_err(|e| e.to_string())?;
    save(&connection)?;
    Ok(Some(connection))
}

pub fn delete() -> Result<(), String> {
    match entry()?.delete_credential() {
        Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
        Err(_) => Err("The saved connection could not be removed.".into()),
    }
}
