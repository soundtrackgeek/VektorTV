import {
  Search,
  Star,
  ChevronDown,
  Tv,
  LoaderCircle,
  RefreshCw,
  X,
  History,
  Volume2,
} from "lucide-react";
import { useRef } from "react";
import { CountryFlag } from "./CountryBrowser";
import type { Channel, Country, Group, View } from "../types";

export function ChannelLogo({
  channel,
  large = false,
}: {
  channel: Channel;
  large?: boolean;
}) {
  return (
    <div className={`channel-logo ${large ? "large" : ""}`} aria-hidden="true">
      <Tv size={20} />
      {channel.logo && (
        <img
          src={channel.logo}
          alt=""
          loading="lazy"
          referrerPolicy="no-referrer"
          onError={(e) => {
            e.currentTarget.style.display = "none";
          }}
        />
      )}
    </div>
  );
}
interface Props {
  country?: Country;
  onCountries: () => void;
  onClearCountry: () => void;
  channels: Channel[];
  groups: Group[];
  group: string;
  setGroup: (value: string) => void;
  search: string;
  setSearch: (value: string) => void;
  selected: string | null;
  onSelect: (channel: Channel) => void;
  onFavorite: (channel: Channel) => void;
  total: number;
  loading: boolean;
  onMore: () => void;
  view: View;
  onView: (view: View) => void;
  now: number;
  searchRef: React.RefObject<HTMLInputElement | null>;
  onRefresh: () => void;
  refreshing: boolean;
  configured: boolean;
}
export default function ChannelBrowser(p: Props) {
  const listRef = useRef<HTMLDivElement>(null);
  const resetScroll = () => listRef.current?.scrollTo(0, 0);
  return (
    <aside className="channel-browser" aria-label="Channel browser">
      {p.country && (
        <div className="country-scope">
          <button onClick={p.onCountries} aria-label="Back to countries">
            <CountryFlag code={p.country.code} />
            <span>{p.country.name}</span>
          </button>
          <button
            className="icon-button"
            onClick={p.onClearCountry}
            aria-label="Clear country filter"
          >
            <X size={16} />
          </button>
        </div>
      )}
      <div className="browser-heading">
        <h2>
          {p.country
            ? p.group
              ? "Country channels"
              : "All channels A–Z"
            : "Your channels"}
        </h2>
        <button
          className="icon-button"
          aria-label="Refresh library"
          disabled={!p.configured || p.refreshing}
          onClick={p.onRefresh}
        >
          <RefreshCw size={18} className={p.refreshing ? "spin" : ""} />
        </button>
      </div>
      <div className="library-tabs" aria-label="Channel library">
        <button
          className={
            p.view !== "favorites" && p.view !== "history" ? "active" : ""
          }
          aria-pressed={p.view !== "favorites" && p.view !== "history"}
          onClick={() => {
            p.onView("live");
            resetScroll();
          }}
        >
          All channels
        </button>
        <button
          className={p.view === "favorites" ? "active" : ""}
          aria-pressed={p.view === "favorites"}
          onClick={() => {
            p.onView("favorites");
            resetScroll();
          }}
        >
          Favorites
        </button>
        <button
          className={`history-filter ${p.view === "history" ? "active" : ""}`}
          aria-label="Recently watched"
          title="Recently watched"
          aria-pressed={p.view === "history"}
          onClick={() => {
            p.onView("history");
            resetScroll();
          }}
        >
          <History size={18} />
        </button>
      </div>
      <label className="search-field">
        <Search size={18} />
        <input
          ref={p.searchRef}
          aria-label="Search channels"
          placeholder="Find a channel"
          value={p.search}
          onChange={(e) => {
            p.setSearch(e.target.value);
            resetScroll();
          }}
        />
        {p.search && (
          <button
            className="icon-button"
            aria-label="Clear channel search"
            onClick={() => {
              p.setSearch("");
              resetScroll();
            }}
          >
            <X size={16} />
          </button>
        )}
      </label>
      <div className="group-select">
        <select
          aria-label="Channel group"
          value={p.group}
          onChange={(e) => {
            p.setGroup(e.target.value);
            resetScroll();
          }}
        >
          <option value="">
            {p.country ? "All channels A–Z" : "All groups"}
          </option>
          {p.groups.map((g) => (
            <option key={g.name} value={g.name}>
              {g.name} ({g.count})
            </option>
          ))}
        </select>
        <ChevronDown size={16} />
      </div>
      <div
        className="channel-list"
        ref={listRef}
        onScroll={(e) => {
          const el = e.currentTarget;
          if (
            el.scrollHeight - el.scrollTop - el.clientHeight < 150 &&
            p.channels.length < p.total &&
            !p.loading
          )
            p.onMore();
        }}
      >
        {p.channels.map((channel) => (
          <div
            className={`channel-row ${p.selected === channel.id ? "selected" : ""}`}
            key={channel.id}
          >
            <button
              className="channel-select"
              onClick={() => p.onSelect(channel)}
              aria-label={`Watch ${channel.name}`}
              aria-pressed={p.selected === channel.id}
            >
              <ChannelLogo channel={channel} />
              <div className="channel-copy">
                <strong title={channel.name}>{channel.name}</strong>
                <span title={channel.now?.title}>
                  {channel.now && channel.now.end > p.now
                    ? channel.now.title
                    : channel.group}
                </span>
              </div>
              {p.selected === channel.id && (
                <Volume2 className="playing-mark" size={18} />
              )}
            </button>
            <button
              className={`favorite-button ${channel.favorite ? "is-favorite" : ""}`}
              aria-label={`${channel.favorite ? "Unfavorite" : "Favorite"} ${channel.name}`}
              title={
                channel.favorite ? "Remove from favorites" : "Add to favorites"
              }
              onClick={() => p.onFavorite(channel)}
            >
              <Star
                size={17}
                fill={channel.favorite ? "currentColor" : "none"}
              />
            </button>
          </div>
        ))}
        {!p.channels.length && (
          <div className="list-empty">
            {p.loading ? (
              <>
                <LoaderCircle className="spin" />
                Loading channels…
              </>
            ) : (
              <>
                <Tv />
                {p.search
                  ? "No channels match your search."
                  : p.view === "favorites"
                    ? "Star a channel to keep it here."
                    : p.view === "history"
                      ? "Channels appear here after playback starts."
                      : "Connect or refresh your library to load channels."}
              </>
            )}
          </div>
        )}
        {p.channels.length > 0 && p.channels.length < p.total && (
          <button className="load-more" disabled={p.loading} onClick={p.onMore}>
            {p.loading ? "Loading…" : "Load more channels"}
          </button>
        )}
      </div>
      <div className="browser-footer">
        {p.view === "history" ? "Recently watched · " : ""}
        {p.channels.length.toLocaleString()} of {p.total.toLocaleString()}{" "}
        channels
      </div>
    </aside>
  );
}
