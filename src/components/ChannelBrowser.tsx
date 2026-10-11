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
  GripVertical,
  ArrowUp,
  ArrowDown,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { dropAnchor, moveInOrder } from "../favoriteOrder";
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
  onMoveFavorite: (
    id: string,
    targetId: string,
    before: boolean,
  ) => Promise<boolean>;
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
  const [moving, setMoving] = useState<string | null>(null);
  const [order, setOrder] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);
  const hold = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pressPoint = useRef<{ x: number; y: number } | null>(null);
  const suppressClick = useRef(false);
  const edgeSpeed = useRef(0);
  useEffect(() => {
    setMoving(null);
    setOrder([]);
    if (hold.current) clearTimeout(hold.current);
    hold.current = null;
    pressPoint.current = null;
    suppressClick.current = false;
  }, [p.search]);
  const clearHold = () => {
    if (hold.current) clearTimeout(hold.current);
    hold.current = null;
    pressPoint.current = null;
  };
  useEffect(
    () => () => {
      if (hold.current) clearTimeout(hold.current);
    },
    [],
  );
  useEffect(() => {
    const released = () => {
      window.setTimeout(() => {
        suppressClick.current = false;
      }, 0);
    };
    window.addEventListener("pointerup", released);
    return () => window.removeEventListener("pointerup", released);
  }, []);
  useEffect(() => {
    if (!moving) return;
    const timer = window.setInterval(() => {
      if (edgeSpeed.current) listRef.current?.scrollBy(0, edgeSpeed.current);
    }, 30);
    return () => {
      clearInterval(timer);
      edgeSpeed.current = 0;
    };
  }, [moving]);
  const byId = new Map(p.channels.map((channel) => [channel.id, channel]));
  const visibleIds = moving
    ? [
        ...order.filter((id) => byId.has(id)),
        ...p.channels.filter((c) => !order.includes(c.id)).map((c) => c.id),
      ]
    : p.channels.map((c) => c.id);
  const displayed = visibleIds.map((id) => byId.get(id)!);
  const picked = moving ? byId.get(moving) : undefined;
  const pickUp = (id: string) => {
    if (saving || p.loading) return;
    setOrder(p.channels.map((c) => c.id));
    setMoving(id);
    requestAnimationFrame(() =>
      listRef.current
        ?.querySelector<HTMLButtonElement>(
          `[data-channel-id="${CSS.escape(id)}"] .channel-select`,
        )
        ?.focus(),
    );
  };
  const cancel = () => {
    setMoving(null);
    setOrder([]);
    clearHold();
    suppressClick.current = false;
  };
  const drop = async (ids = visibleIds) => {
    if (!moving || saving) return;
    const anchor = dropAnchor(ids, moving);
    setSaving(true);
    try {
      if (
        !anchor ||
        (await p.onMoveFavorite(moving, anchor.targetId, anchor.before))
      )
        cancel();
    } finally {
      setSaving(false);
    }
  };
  const step = (direction: number) => {
    if (!moving || saving) return;
    const target = visibleIds[visibleIds.indexOf(moving) + direction];
    if (target) {
      setOrder(moveInOrder(visibleIds, moving, target));
      requestAnimationFrame(() =>
        listRef.current
          ?.querySelector(`[data-channel-id="${CSS.escape(moving)}"]`)
          ?.scrollIntoView({ block: "nearest" }),
      );
    }
  };
  const resetScroll = () => listRef.current?.scrollTo(0, 0);
  return (
    <aside
      className="channel-browser"
      aria-label="Channel browser"
      onKeyDown={(event) => {
        if (!moving) return;
        if (
          ["Escape", "ArrowUp", "ArrowDown", "Enter", " "].includes(event.key)
        ) {
          event.preventDefault();
          event.stopPropagation();
          if (event.key === "Escape" && !saving) cancel();
          else if (event.key === "ArrowUp") step(-1);
          else if (event.key === "ArrowDown") step(1);
          else if (event.key === "Enter" || event.key === " ") void drop();
        }
      }}
    >
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
      {p.view === "favorites" && (
        <div className="favorite-arrangement">
          <p role="status" aria-live="polite">
            {picked
              ? `Moving ${picked.name} · ${visibleIds.indexOf(picked.id) + 1} of ${visibleIds.length}. Move, then click to drop.`
              : "Hold a channel to arrange Favorites, or use its move button."}
          </p>
          {picked && (
            <div className="arrangement-actions">
              <button
                className="icon-button"
                aria-label="Move favorite up"
                disabled={saving || visibleIds[0] === moving}
                onClick={() => step(-1)}
              >
                <ArrowUp size={17} />
              </button>
              <button
                className="icon-button"
                aria-label="Move favorite down"
                disabled={saving || visibleIds.at(-1) === moving}
                onClick={() => step(1)}
              >
                <ArrowDown size={17} />
              </button>
              <button disabled={saving} onClick={() => void drop()}>
                {saving ? "Saving…" : "Drop"}
              </button>
              <button disabled={saving} onClick={cancel}>
                Cancel
              </button>
            </div>
          )}
        </div>
      )}
      <div
        className="channel-list"
        ref={listRef}
        onPointerLeave={() => {
          clearHold();
          edgeSpeed.current = 0;
        }}
        onPointerMove={(event) => {
          if (!moving || saving || event.pointerType !== "mouse") return;
          const bounds = event.currentTarget.getBoundingClientRect();
          edgeSpeed.current =
            event.clientY < bounds.top + 40
              ? -10
              : event.clientY > bounds.bottom - 40
                ? 10
                : 0;
          const row = (event.target as HTMLElement).closest<HTMLElement>(
            "[data-channel-id]",
          );
          const target = row?.dataset.channelId;
          if (!row || !target || target === moving) return;
          const rect = row.getBoundingClientRect();
          const from = visibleIds.indexOf(moving),
            to = visibleIds.indexOf(target);
          if (
            (to < from && event.clientY < rect.top + rect.height / 2) ||
            (to > from && event.clientY > rect.top + rect.height / 2)
          )
            setOrder(moveInOrder(visibleIds, moving, target));
        }}
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
        {displayed.map((channel) => (
          <div
            className={`channel-row ${p.selected === channel.id ? "selected" : ""} ${moving === channel.id ? "is-moving" : ""}`}
            key={channel.id}
            data-channel-id={channel.id}
          >
            <button
              className="channel-select"
              disabled={saving}
              onPointerDown={(event) => {
                if (
                  p.view !== "favorites" ||
                  moving ||
                  event.button !== 0 ||
                  p.loading
                )
                  return;
                suppressClick.current = false;
                pressPoint.current = { x: event.clientX, y: event.clientY };
                hold.current = setTimeout(() => {
                  suppressClick.current = true;
                  pickUp(channel.id);
                  clearHold();
                }, 450);
              }}
              onPointerMove={(event) => {
                const point = pressPoint.current;
                if (
                  point &&
                  Math.hypot(event.clientX - point.x, event.clientY - point.y) >
                    8
                )
                  clearHold();
              }}
              onPointerUp={clearHold}
              onPointerCancel={clearHold}
              onPointerLeave={clearHold}
              onContextMenu={(event) => {
                if (p.view === "favorites") event.preventDefault();
              }}
              onClick={() => {
                if (suppressClick.current) {
                  suppressClick.current = false;
                  return;
                }
                if (moving) {
                  const next = moveInOrder(visibleIds, moving, channel.id);
                  setOrder(next);
                  void drop(next);
                } else p.onSelect(channel);
              }}
              aria-label={`${moving ? "Drop at" : "Watch"} ${channel.name}`}
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
            {p.view === "favorites" && (
              <button
                className="icon-button favorite-move"
                aria-label={`Arrange ${channel.name}`}
                title="Arrange favorite (then use ↑/↓ and Enter; Escape cancels)"
                disabled={saving || p.loading || !!moving}
                onClick={() => pickUp(channel.id)}
              >
                <GripVertical size={17} />
              </button>
            )}
            <button
              className={`favorite-button ${channel.favorite ? "is-favorite" : ""}`}
              aria-label={`${channel.favorite ? "Unfavorite" : "Favorite"} ${channel.name}`}
              title={
                channel.favorite ? "Remove from favorites" : "Add to favorites"
              }
              onClick={() => p.onFavorite(channel)}
              disabled={!!moving || saving}
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
