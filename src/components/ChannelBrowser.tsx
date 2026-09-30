import { Search, Star, ChevronDown, Radio, LoaderCircle } from "lucide-react";
import { useRef } from "react";
import type { Channel, Group, View } from "../types";
import { progress } from "../utils";

export function ChannelLogo({
  channel,
  large = false,
}: {
  channel: Channel;
  large?: boolean;
}) {
  return (
    <div
      className={`channel-logo ${large ? "large" : ""}`}
      style={
        {
          "--channel-hue": `${Array.from(channel.name).reduce((a, c) => a + c.charCodeAt(0), 0) % 360}`,
        } as React.CSSProperties
      }
    >
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
      <span>{channel.name.replace(/^\W+/, "").slice(0, 3).toUpperCase()}</span>
    </div>
  );
}

interface Props {
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
  now: number;
  searchRef: React.RefObject<HTMLInputElement | null>;
}
export default function ChannelBrowser(p: Props) {
  const listRef = useRef<HTMLDivElement>(null);
  const label =
    p.view === "favorites"
      ? "Favorites"
      : p.view === "history"
        ? "Recently watched"
        : "Channels";
  return (
    <aside className="channel-browser">
      <div className="browser-heading">
        <h2>{label}</h2>
        <span className="count-badge">{p.total.toLocaleString()}</span>
      </div>
      <label className="search-field">
        <Search size={17} />
        <input
          ref={p.searchRef}
          aria-label="Search channels"
          placeholder="Search channels…"
          value={p.search}
          onChange={(e) => {
            p.setSearch(e.target.value);
            listRef.current?.scrollTo(0, 0);
          }}
        />
        <kbd>Ctrl K</kbd>
      </label>
      <div className="group-select">
        <select
          aria-label="Channel group"
          value={p.group}
          onChange={(e) => {
            p.setGroup(e.target.value);
            listRef.current?.scrollTo(0, 0);
          }}
        >
          <option value="">All channels</option>
          {p.groups.map((g) => (
            <option key={g.name} value={g.name}>
              {g.name} ({g.count})
            </option>
          ))}
        </select>
        <ChevronDown size={15} />
      </div>
      <div className="list-heading">
        <span>
          {p.view === "history" ? "YOUR RECENT CHANNELS" : "ON AIR NOW"}
        </span>
        <span>
          {p.loading ? (
            <LoaderCircle className="spin" size={13} />
          ) : (
            <Radio size={13} />
          )}
        </span>
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
                  {channel.now?.title || "Programme unavailable"}
                </span>
                {channel.now && (
                  <div className="tiny-progress">
                    <i style={{ width: `${progress(channel.now, p.now)}%` }} />
                  </div>
                )}
              </div>
            </button>
            <button
              className={`favorite-button ${channel.favorite ? "is-favorite" : ""}`}
              title={
                channel.favorite ? "Remove from favorites" : "Add to favorites"
              }
              aria-label={`${channel.favorite ? "Unfavorite" : "Favorite"} ${channel.name}`}
              onClick={() => p.onFavorite(channel)}
            >
              <Star
                size={15}
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
                <Radio />
                {p.search
                  ? "No channels match your search."
                  : p.view === "favorites"
                    ? "Star a channel to keep it here."
                    : p.view === "history"
                      ? "Channels appear here after playback starts."
                      : "Refresh your library to load channels."}
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
        <span className="signal-bars">
          <i />
          <i />
          <i />
        </span>
        <span>
          {p.channels.length.toLocaleString()} of {p.total.toLocaleString()}{" "}
          channels
        </span>
      </div>
    </aside>
  );
}
