//! Provider group names are hints, not authoritative country metadata. Keep
//! ambiguous/regional groups reachable without inventing a national identity.
use serde::Deserialize;
use std::sync::LazyLock;
use unicode_normalization::{char::is_combining_mark, UnicodeNormalization};

pub const UNASSIGNED: &str = "zz";

#[derive(Deserialize)]
pub struct Definition {
    pub code: String,
    pub name: String,
    alpha3: String,
    aliases: Vec<String>,
}

pub static DEFINITIONS: LazyLock<Vec<Definition>> = LazyLock::new(|| {
    serde_json::from_str(include_str!("countries.json")).expect("bundled country definitions")
});

pub fn sort_key(value: &str) -> String {
    value
        .nfkd()
        .filter(|c| !is_combining_mark(*c))
        .flat_map(char::to_lowercase)
        .collect()
}
fn words(value: &str) -> String {
    sort_key(value)
        .split(|c: char| !c.is_alphanumeric())
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}
static ALIASES: LazyLock<Vec<(String, String)>> = LazyLock::new(|| {
    let mut aliases: Vec<_> = DEFINITIONS
        .iter()
        .flat_map(|d| d.aliases.iter().map(|a| (words(a), d.code.clone())))
        .collect();
    aliases.sort_by_key(|a| std::cmp::Reverse(a.0.len()));
    aliases
});

pub fn name(code: &str) -> Option<&'static str> {
    if code == UNASSIGNED {
        return Some("International & unassigned");
    }
    DEFINITIONS
        .iter()
        .find(|d| d.code == code)
        .map(|d| d.name.as_str())
}

pub fn detect(group: &str) -> &'static str {
    let normalized = format!(" {} ", words(group));
    // Longest names first: South Africa must not also match Africa, and
    // Guinea-Bissau must not become Guinea. Distinct country names are mixed.
    let mut remainder = normalized;
    let mut found: Option<&str> = None;
    for (alias, code) in ALIASES.iter() {
        let needle = format!(" {alias} ");
        if remainder.contains(&needle) {
            if found.is_some_and(|previous| previous != code) {
                return UNASSIGNED;
            }
            found = Some(code);
            remainder = remainder.replace(&needle, " ");
        }
    }
    if let Some(code) = found {
        return code;
    }
    // Only a leading standalone code is meaningful; never match codes inside
    // programme/network names. These provider region/language prefixes collide
    // with ISO codes and require an explicit country name instead.
    let normalized = words(group);
    let prefix = normalized.split_whitespace().next().unwrap_or("");
    if ["ar", "na", "mu", "bh", "cg", "la", "sl"].contains(&prefix) {
        return UNASSIGNED;
    }
    if prefix == "uk" {
        return "gb";
    }
    DEFINITIONS
        .iter()
        .find(|d| d.code == prefix || d.alpha3 == prefix)
        .map_or(UNASSIGNED, |d| d.code.as_str())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn provider_names_regions_and_code_collisions() {
        for (group, code) in [
            ("AFG| AFGHANISTAN", "af"),
            ("AFR| CABO VERDE", "cv"),
            ("AFR| ETHOPIA", "et"),
            ("AFR| SOMALI", "so"),
            ("AL| 24/7 ALBANIA", "al"),
            ("AL| ALBANIA SPORTS PREMIUM", "al"),
            ("AM| ARMENIA", "am"),
            ("AR| ALGERIE AM +6H", "dz"),
            ("AR| BAHRAIN", "bh"),
            ("AR| BEIN SPORTS", "zz"),
            ("AFR| GENERAL", "zz"),
            ("NA| HOCKEY LEAGUE", "zz"),
            ("MU| MUSIC CONCERTS", "zz"),
            ("CG| MONTENEGRO", "me"),
            ("BH| BOSNIA", "ba"),
            ("SL| SLOVENIA", "si"),
            ("NORWAY TV2 PLAY", "no"),
            ("NOR| SPORTS", "no"),
            ("uk: entertainment", "gb"),
            ("[US] News", "us"),
            ("South Africa Sport", "za"),
            ("Guinea-Bissau", "gw"),
            ("France / Germany", "zz"),
            ("24/7 REALITY VIP", "zz"),
            ("Discovery", "zz"),
            ("Côte d’Ivoire", "ci"),
        ] {
            assert_eq!(detect(group), code, "{group}");
        }
    }
    #[test]
    fn definitions_have_unique_codes_and_resolve_their_names() {
        let mut seen = std::collections::HashSet::new();
        for d in DEFINITIONS.iter() {
            assert!(seen.insert(&d.code), "duplicate {}", d.code);
            assert_eq!(detect(&d.name), d.code, "{}", d.name);
        }
    }
}
