import { useEffect, useMemo, useRef, useState } from "react";
import {
  ChevronLeft,
  ChevronRight,
  CalendarDays,
  Play,
  LoaderCircle,
  Radio,
  Search,
  X,
} from "lucide-react";
import { api } from "../api";
import type { Channel, Programme, Country, Group } from "../types";
import { time, timeline, errorText } from "../utils";
import ProgrammeSearch from "./ProgrammeSearch";
import { ChannelLogo } from "./ChannelBrowser";

export default function Guide({
  channels,
  now,
  total,
  loadingChannels,
  onLoadMore,
  countries,
  groups,
  revision,
  onWatch,
}: {
  channels: Channel[];
  now: number;
  total: number;
  loadingChannels: boolean;
  onLoadMore: () => void;
  countries: Country[];
  groups: Group[];
  revision: number;
  onWatch: (channel: Channel) => void;
}) {
  const [offset, setOffset] = useState(0);
  const [searching, setSearching] = useState(false);
  const viewport = useRef<HTMLDivElement>(null);
  const [scrollTop, setScrollTop] = useState(0);
  const [height, setHeight] = useState(600);
  const [attempt, setAttempt] = useState(0);
  const requestedLength = useRef(-1);
  const rowHeight = 76;
  const first = Math.max(
    0,
    Math.floor(Math.max(0, scrollTop - 42) / rowHeight) - 5,
  );
  const last = Math.min(
    channels.length,
    first + Math.ceil(height / rowHeight) + 12,
  );
  const [events, setEvents] = useState<Record<string, Programme[]>>({});
  const [selected, setSelected] = useState<{
    channel: Channel;
    programme: Programme;
  } | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const start = Math.floor(now / 1800) * 1800 + offset * 7200;
  const end = start + 10800;
  const visible = useMemo(
    () => channels.slice(first, last),
    [channels, first, last],
  );
  useEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const observer = new ResizeObserver(() => setHeight(element.clientHeight));
    observer.observe(element);
    return () => observer.disconnect();
  }, [searching]);
  useEffect(() => {
    if (
      !searching &&
      last >= channels.length - 5 &&
      channels.length < total &&
      !loadingChannels &&
      requestedLength.current !== channels.length
    ) {
      requestedLength.current = channels.length;
      onLoadMore();
    }
  }, [searching, last, channels.length, total, loadingChannels, onLoadMore]);
  useEffect(() => {
    if (searching) return;
    let current = true;
    setLoading(true);
    setError(null);
    setEvents({});
    api
      .schedules(
        visible.map((c) => c.id),
        start,
        end,
      )
      .then((rows) => {
        if (current) setEvents(rows);
      })
      .catch((e) => {
        if (current) setError(errorText(e));
      })
      .finally(() => {
        if (current) setLoading(false);
      });
    return () => {
      current = false;
    };
  }, [visible, start, end, revision, searching, attempt]);
  return (
    <section className="guide-view">
      <div className="section-topline">
        <div>
          <h1>TV Guide</h1>
        </div>
        <div className="guide-navigation">
          <button
            id="guide-search-toggle"
            className="outline-button"
            onClick={() => {
              setSearching(true);
              setSelected(null);
              window.setTimeout(
                () => document.getElementById("programme-search")?.focus(),
                0,
              );
            }}
          >
            <Search size={16} />
            Search programmes
          </button>
          {searching && (
            <button
              className="outline-button"
              onClick={() => {
                setSearching(false);
                setSelected(null);
                setScrollTop(0);
              }}
            >
              Channel guide
            </button>
          )}
          {!searching && (
            <>
              <button
                className="icon-button"
                aria-label="Earlier programmes"
                onClick={() => setOffset((v) => Math.max(-3, v - 1))}
              >
                <ChevronLeft size={18} />
              </button>
              <button className="outline-button" onClick={() => setOffset(0)}>
                <CalendarDays size={15} />
                {new Date(start * 1000).toLocaleDateString([], {
                  weekday: "short",
                  day: "numeric",
                  month: "short",
                })}
              </button>
              <button
                className="icon-button"
                aria-label="Later programmes"
                onClick={() => setOffset((v) => Math.min(20, v + 1))}
              >
                <ChevronRight size={18} />
              </button>
            </>
          )}
        </div>
      </div>
      {searching ? (
        <ProgrammeSearch
          countries={countries}
          groups={groups}
          now={now}
          revision={revision}
          onSelect={setSelected}
          onWatch={(result) => onWatch(result.channel)}
        />
      ) : (
        <>
          {error && (
            <div className="inline-error" role="alert">
              {error}
              <button
                className="outline-button"
                onClick={() => setAttempt((v) => v + 1)}
              >
                Retry guide
              </button>
            </div>
          )}
          <p className="guide-hint">
            {total.toLocaleString()} channels · Scroll to browse · Double-click
            a programme to watch live
          </p>
          <div
            className="guide-grid"
            ref={viewport}
            onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
            tabIndex={0}
            aria-label="Scrollable channel guide"
          >
            <div className="guide-time-row">
              <span>
                {loading ? (
                  <LoaderCircle className="spin" size={14} />
                ) : (
                  "CHANNEL"
                )}
              </span>
              <div>
                {Array.from({ length: 6 }, (_, i) => (
                  <span key={i}>{time(start + i * 1800)}</span>
                ))}
              </div>
            </div>
            <div aria-hidden="true" style={{ height: first * rowHeight }} />
            {visible.map((channel) => (
              <div className="guide-row" key={channel.id}>
                <button
                  className="guide-channel"
                  onClick={() => onWatch(channel)}
                  title={`Watch ${channel.name}`}
                >
                  <ChannelLogo channel={channel} />
                  <strong>{channel.name}</strong>
                </button>
                <div
                  className="guide-programmes"
                  onDoubleClick={() => onWatch(channel)}
                >
                  {!events[channel.id]?.length && (
                    <span className="no-guide">
                      {loading ? "Loading guide…" : "No programme information"}
                    </span>
                  )}
                  {events[channel.id]?.map((programme) => {
                    const rect = timeline(programme, start, end);
                    if (!rect) return null;
                    const live = programme.start <= now && programme.end > now;
                    return (
                      <button
                        className={`guide-event ${live ? "on-now" : ""} ${selected?.programme === programme ? "chosen" : ""}`}
                        style={{
                          left: `${rect.left}%`,
                          width: `${rect.width}%`,
                        }}
                        key={`${programme.start}-${programme.title}`}
                        title={`${programme.title} · ${time(programme.start)} – ${time(programme.end)}`}
                        onClick={() => setSelected({ channel, programme })}
                      >
                        <strong>{programme.title}</strong>
                        <span>
                          {time(programme.start)} – {time(programme.end)}
                        </span>
                      </button>
                    );
                  })}
                  {now >= start && now < end && (
                    <i
                      className="now-line"
                      style={{
                        left: `${((now - start) / (end - start)) * 100}%`,
                      }}
                    />
                  )}
                </div>
              </div>
            ))}
            <div
              aria-hidden="true"
              style={{
                height: Math.max(0, channels.length - last) * rowHeight,
              }}
            />
            {loadingChannels && (
              <p className="guide-hint" role="status">
                Loading channels…
              </p>
            )}
            {!channels.length && !loadingChannels && (
              <div className="guide-empty">
                <Radio />
                <p>No channels in this view. Adjust the search or group.</p>
              </div>
            )}
          </div>
        </>
      )}
      <div className="guide-inspector">
        {selected ? (
          <div
            className="guide-detail"
            role="region"
            aria-label="Programme details"
          >
            <div>
              <div className="eyebrow">
                {selected.channel.name} · {time(selected.programme.start)} –{" "}
                {time(selected.programme.end)}
              </div>
              <h2>{selected.programme.title}</h2>
              <p>
                {selected.programme.description ||
                  "No description is available for this programme."}
              </p>
            </div>
            <button
              className="primary-button"
              onClick={() => onWatch(selected.channel)}
            >
              <Play size={15} fill="currentColor" />
              Watch channel live
            </button>
            <button
              className="icon-button"
              aria-label="Close programme details"
              onClick={() => setSelected(null)}
            >
              <X size={18} />
            </button>
          </div>
        ) : (
          <p className="guide-hint">
            Select a programme for details. Double-click to start live playback,
            or use the Watch button in the details.
          </p>
        )}
      </div>
    </section>
  );
}
