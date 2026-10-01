import { useEffect, useRef, useState } from "react";
import { Search, Play, LoaderCircle } from "lucide-react";
import { api } from "../api";
import type { Country, Group, ProgrammeMatch, ProgrammePage } from "../types";
import { errorText, time } from "../utils";

export default function ProgrammeSearch({
  countries,
  groups,
  now,
  revision,
  onSelect,
  onWatch,
}: {
  countries: Country[];
  groups: Group[];
  now: number;
  revision: number;
  onSelect: (result: ProgrammeMatch) => void;
  onWatch: (result: ProgrammeMatch) => void;
}) {
  const [search, setSearch] = useState("");
  const [country, setCountry] = useState("");
  const [group, setGroup] = useState("");
  const [when, setWhen] = useState("all");
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [offset, setOffset] = useState(0);
  const [page, setPage] = useState<ProgrammePage>({
    results: [],
    total: 0,
    offset: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const minute = Math.floor(now / 60) * 60;
  const from = when === "all" ? null : minute;
  const until =
    when === "live" ? minute + 1 : when === "day" ? minute + 86400 : null;
  const filterKey = JSON.stringify([
    search,
    country,
    group,
    when,
    favoritesOnly,
    revision,
    from,
    until,
  ]);
  const activeFilter = useRef(filterKey);
  const effectiveOffset = activeFilter.current === filterKey ? offset : 0;
  useEffect(() => {
    input.current?.focus();
  }, []);
  useEffect(() => {
    let current = true;
    if (activeFilter.current !== filterKey) {
      activeFilter.current = filterKey;
      setOffset(0);
    }
    setLoading(true);
    setError(null);
    setPage({ results: [], total: 0, offset: effectiveOffset });
    const timer = window.setTimeout(() => {
      void api
        .searchProgrammes({
          search,
          country: country || null,
          group: group || null,
          favoritesOnly,
          from,
          until,
          offset: effectiveOffset,
          limit: 100,
        })
        .then((result) => {
          if (current) setPage(result);
        })
        .catch((e) => {
          if (current) setError(errorText(e));
        })
        .finally(() => {
          if (current) setLoading(false);
        });
    }, 250);
    return () => {
      current = false;
      window.clearTimeout(timer);
    };
  }, [
    filterKey,
    search,
    country,
    group,
    favoritesOnly,
    from,
    until,
    effectiveOffset,
    attempt,
  ]);
  const availableGroups = country
    ? (countries.find((c) => c.code === country)?.groups ?? [])
    : groups;
  return (
    <div className="programme-search">
      <label className="search-field">
        <Search size={19} />
        <input
          id="programme-search"
          ref={input}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search programme titles, descriptions or genres"
          aria-label="Search all programmes"
        />
      </label>
      <div className="programme-filters">
        <label>
          When
          <select value={when} onChange={(e) => setWhen(e.target.value)}>
            <option value="all">All guide times</option>
            <option value="live">On now</option>
            <option value="day">Next 24 hours</option>
            <option value="upcoming">Now & upcoming</option>
          </select>
        </label>
        <label>
          Country
          <select
            value={country}
            onChange={(e) => {
              setCountry(e.target.value);
              setGroup("");
            }}
          >
            <option value="">All countries</option>
            {countries.map((c) => (
              <option key={c.code} value={c.code}>
                {c.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Group
          <select value={group} onChange={(e) => setGroup(e.target.value)}>
            <option value="">All groups</option>
            {availableGroups.map((g) => (
              <option key={g.name}>{g.name}</option>
            ))}
          </select>
        </label>
        <label className="programme-favorites">
          <input
            type="checkbox"
            checked={favoritesOnly}
            onChange={(e) => setFavoritesOnly(e.target.checked)}
          />
          Favorite channels
        </label>
      </div>
      <p className="guide-hint">
        Searches every channel with imported guide data, independently of the
        channel sidebar. Double-click a result to watch its channel live.
      </p>
      {loading ? (
        <p role="status">
          <LoaderCircle size={16} className="spin" /> Searching programmes…
        </p>
      ) : error ? (
        <div className="inline-error" role="alert">
          {error}
          <button
            className="outline-button"
            onClick={() => setAttempt((a) => a + 1)}
          >
            Retry search
          </button>
        </div>
      ) : (
        <>
          <p className="guide-hint" role="status">
            {page.total.toLocaleString()} programmes found
            {page.total > 0
              ? ` · ${page.offset + 1}–${Math.min(page.offset + page.results.length, page.total)}`
              : ". Try a different search or filter, or refresh the guide in Settings."}
          </p>
          <div className="programme-results">
            {page.results.map((result) => (
              <div
                className="programme-result"
                key={`${result.channel.id}-${result.programme.start}-${result.programme.end}-${result.programme.title}`}
              >
                <button
                  className="programme-result-info"
                  onClick={() => onSelect(result)}
                  onDoubleClick={() => onWatch(result)}
                >
                  <span className="eyebrow">
                    {result.channel.name} ·{" "}
                    {new Date(result.programme.start * 1000).toLocaleDateString(
                      [],
                      { weekday: "short", month: "short", day: "numeric" },
                    )}{" "}
                    · {time(result.programme.start)} –{" "}
                    {time(result.programme.end)}
                  </span>
                  <strong>{result.programme.title}</strong>
                  <span>
                    {result.programme.category || result.channel.group}
                    {result.programme.start <= now && result.programme.end > now
                      ? " · On now"
                      : ""}
                  </span>
                  {result.programme.description && (
                    <p>{result.programme.description}</p>
                  )}
                </button>
                <button
                  className="icon-button"
                  aria-label={`Watch ${result.channel.name} live`}
                  onClick={() => onWatch(result)}
                >
                  <Play size={18} />
                </button>
              </div>
            ))}
          </div>
          {page.total > 100 && (
            <div className="guide-pagination">
              <button
                className="outline-button"
                disabled={offset === 0}
                onClick={() => setOffset((v) => Math.max(0, v - 100))}
              >
                Previous results
              </button>
              <button
                className="outline-button"
                disabled={offset + page.results.length >= page.total}
                onClick={() => setOffset((v) => v + 100)}
              >
                More results
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
