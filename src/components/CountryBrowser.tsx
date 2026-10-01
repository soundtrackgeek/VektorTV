import { useState } from "react";
import {
  ArrowLeft,
  ArrowUpAZ,
  ChevronRight,
  Globe2,
  Search,
  Star,
} from "lucide-react";
import type { Country } from "../types";

export function CountryFlag({ code }: { code: string }) {
  return code === "zz" ? (
    <Globe2 className="country-flag unassigned-flag" aria-hidden="true" />
  ) : (
    <img className="country-flag" src={`/flags/${code}.svg`} alt="" />
  );
}

export default function CountryBrowser({
  countries,
  onFavorite,
  onOpen,
  onSettings,
  loading,
}: {
  countries: Country[];
  onFavorite: (country: Country) => Promise<void>;
  onOpen: (country: Country, group?: string) => void;
  onSettings: () => void;
  loading: boolean;
}) {
  const [selected, setSelected] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [saving, setSaving] = useState<string | null>(null);
  const country = countries.find((c) => c.code === selected);
  const filtered = countries.filter((c) =>
    `${c.name} ${c.code}`
      .toLocaleLowerCase()
      .includes(search.toLocaleLowerCase()),
  );
  const favorite = async (c: Country) => {
    setSaving(c.code);
    try {
      await onFavorite(c);
    } finally {
      setSaving(null);
    }
  };
  return (
    <section className="countries-view" aria-label="Country browser">
      {country ? (
        <>
          <button
            className="text-button country-back"
            onClick={() => setSelected(null)}
          >
            <ArrowLeft size={18} /> All countries
          </button>
          <div className="country-detail-heading">
            <CountryFlag code={country.code} />
            <div>
              <p className="eyebrow">EXPLORE YOUR LIBRARY</p>
              <h1>{country.name}</h1>
              <p>
                {country.groups.length}{" "}
                {country.groups.length === 1 ? "group" : "groups"} ·{" "}
                {country.count.toLocaleString()} channels
              </p>
            </div>
            <button
              className={`icon-button ${country.favorite ? "is-favorite" : ""}`}
              disabled={saving !== null}
              aria-label={`${country.favorite ? "Unfavorite" : "Favorite"} country ${country.name}`}
              aria-pressed={country.favorite}
              onClick={() => void favorite(country)}
            >
              <Star fill={country.favorite ? "currentColor" : "none"} />
            </button>
          </div>
          <button
            className="country-all-button"
            onClick={() => onOpen(country)}
          >
            <ArrowUpAZ size={24} />
            <span>
              <strong>All channels A–Z</strong>
              <small>Browse every channel in {country.name}</small>
            </span>
            <ChevronRight />
          </button>
          <h2 className="country-section-title">Channel groups</h2>
          <div className="country-groups">
            {country.groups.map((group) => (
              <button
                key={group.name}
                className="country-group"
                onClick={() => onOpen(country, group.name)}
              >
                <span>
                  {group.name}
                  <small>{group.count.toLocaleString()} channels</small>
                </span>
                <ChevronRight size={18} />
              </button>
            ))}
          </div>
        </>
      ) : (
        <>
          <div className="countries-heading">
            <div>
              <p className="eyebrow">YOUR WORLD OF TELEVISION</p>
              <h1>Countries</h1>
              <p>Choose a country. Find your channels.</p>
            </div>
            <label className="search-field country-search">
              <Search size={18} />
              <input
                aria-label="Find a country"
                placeholder="Find a country"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </label>
          </div>
          {!countries.length ? (
            <div className="list-empty">
              <Globe2 />
              <h2>
                {loading ? "Loading countries…" : "Your world starts here"}
              </h2>
              <p>
                Countries appear when your channel library is connected and
                loaded.
              </p>
              <button className="outline-button" onClick={onSettings}>
                Open Settings
              </button>
            </div>
          ) : !filtered.length ? (
            <div className="list-empty">No countries match “{search}”.</div>
          ) : (
            <>
              {[true, false].map((pinned) => {
                const entries = filtered.filter((c) => c.favorite === pinned);
                return (
                  entries.length > 0 && (
                    <section
                      key={String(pinned)}
                      aria-label={
                        pinned ? "Favorite countries" : "All countries"
                      }
                    >
                      <h2 className="country-section-title">
                        {pinned ? "Favorite countries" : "All countries"}
                        <span>{entries.length}</span>
                      </h2>
                      <div className="country-grid">
                        {entries.map((c) => (
                          <article className="country-card" key={c.code}>
                            <button
                              className="country-open"
                              onClick={() => {
                                setSelected(c.code);
                                setSearch("");
                              }}
                              aria-label={`Explore ${c.name}`}
                            >
                              <CountryFlag code={c.code} />
                              <strong>{c.name}</strong>
                              <small>
                                {c.groups.length}{" "}
                                {c.groups.length === 1 ? "group" : "groups"} ·{" "}
                                {c.count.toLocaleString()} channels
                              </small>
                            </button>
                            <button
                              className={`country-star icon-button ${c.favorite ? "is-favorite" : ""}`}
                              disabled={saving !== null}
                              aria-label={`${c.favorite ? "Unfavorite" : "Favorite"} country ${c.name}`}
                              aria-pressed={c.favorite}
                              onClick={() => void favorite(c)}
                            >
                              <Star
                                size={20}
                                fill={c.favorite ? "currentColor" : "none"}
                              />
                            </button>
                          </article>
                        ))}
                      </div>
                    </section>
                  )
                );
              })}
              <p className="country-note">
                Star countries to keep them at the top. Regional and
                unrecognized groups are under International &amp; unassigned.
              </p>
            </>
          )}
        </>
      )}
    </section>
  );
}
