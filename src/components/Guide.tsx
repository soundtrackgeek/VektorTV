import { useEffect, useMemo, useState } from "react";
import {
  ChevronLeft,
  ChevronRight,
  CalendarDays,
  Play,
  LoaderCircle,
  Radio,
} from "lucide-react";
import { api } from "../api";
import type { Channel, Programme } from "../types";
import { time, timeline, errorText } from "../utils";
import { ChannelLogo } from "./ChannelBrowser";

export default function Guide({
  channels,
  now,
  onWatch,
}: {
  channels: Channel[];
  now: number;
  onWatch: (channel: Channel) => void;
}) {
  const [offset, setOffset] = useState(0);
  const [page, setPage] = useState(0);
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
    () => channels.slice(page * 8, page * 8 + 8),
    [channels, page],
  );
  useEffect(() => {
    let current = true;
    setLoading(true);
    setError(null);
    Promise.all(
      visible.map(
        async (c) => [c.id, await api.schedule(c.id, start, end)] as const,
      ),
    )
      .then((rows) => {
        if (current) setEvents(Object.fromEntries(rows));
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
  }, [visible, start, end]);
  useEffect(() => {
    setPage(0);
    setSelected(null);
  }, [channels]);
  return (
    <section className="guide-view">
      <div className="section-topline">
        <div>
          <span className="eyebrow">FIND SOMETHING GOOD</span>
          <h1>What's on.</h1>
        </div>
        <div className="guide-navigation">
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
        </div>
      </div>
      {error && (
        <div className="inline-error" role="alert">
          {error}
        </div>
      )}
      <div className="guide-grid">
        <div className="guide-time-row">
          <span>
            {loading ? <LoaderCircle className="spin" size={14} /> : "CHANNEL"}
          </span>
          <div>
            {Array.from({ length: 6 }, (_, i) => (
              <span key={i}>{time(start + i * 1800)}</span>
            ))}
          </div>
        </div>
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
            <div className="guide-programmes">
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
                    style={{ left: `${rect.left}%`, width: `${rect.width}%` }}
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
                  style={{ left: `${((now - start) / (end - start)) * 100}%` }}
                />
              )}
            </div>
          </div>
        ))}
        {!visible.length && (
          <div className="guide-empty">
            <Radio />
            <p>No channels in this view. Adjust the search or group.</p>
          </div>
        )}
      </div>
      <div className="guide-pagination">
        <span>
          Showing {channels.length ? page * 8 + 1 : 0}–
          {Math.min((page + 1) * 8, channels.length)} of {channels.length}{" "}
          loaded channels
        </span>
        <div>
          <button
            className="icon-button"
            aria-label="Previous guide channels"
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
          >
            <ChevronLeft size={17} />
          </button>
          <button
            className="icon-button"
            aria-label="Next guide channels"
            disabled={(page + 1) * 8 >= channels.length}
            onClick={() => setPage((p) => p + 1)}
          >
            <ChevronRight size={17} />
          </button>
        </div>
      </div>
      {selected && (
        <div className="guide-detail">
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
        </div>
      )}
    </section>
  );
}
