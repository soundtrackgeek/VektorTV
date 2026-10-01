import { useEffect, useRef } from "react";
import {
  Play,
  Pause,
  Square,
  Volume2,
  VolumeX,
  Maximize,
  Minimize,
  Tv,
  LoaderCircle,
  RotateCcw,
  Star,
  CalendarDays,
  AlertCircle,
} from "lucide-react";
import { api, demo } from "../api";
import type { AppInfo, Channel, PlayerStatus, Programme } from "../types";
import { progress, time } from "../utils";

interface Props {
  channel: Channel | null;
  schedule: Programme[];
  status: PlayerStatus;
  info: AppInfo | null;
  onPlay: () => void;
  onAction: (action: string, value?: number) => void;
  onFullscreen: () => void;
  fullscreen: boolean;
  now: number;
  onFavorite: () => void;
  error: string | null;
  onSettings: () => void;
  onGuide: () => void;
}
export default function PlayerView(p: Props) {
  const surface = useRef<HTMLDivElement>(null);
  const room = useRef<HTMLElement>(null);
  const active = ["opening", "buffering", "playing", "paused"].includes(
    p.status.state,
  );
  const busy = ["opening", "buffering"].includes(p.status.state);
  const failed =
    !!p.error || ["error", "ended", "unavailable"].includes(p.status.state);
  useEffect(() => {
    let frame = 0;
    const position = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const rect = surface.current?.getBoundingClientRect();
        const viewport = room.current?.getBoundingClientRect();
        if (!rect || !viewport) return;
        const scale = window.devicePixelRatio;
        // Native video must never paint over the header when the pane scrolls.
        const visible =
          active &&
          rect.top >= viewport.top - 1 &&
          rect.bottom <= viewport.bottom + 1;
        void api
          .bounds({
            x: rect.x * scale,
            y: rect.y * scale,
            width: rect.width * scale,
            height: rect.height * scale,
            visible,
          })
          .catch(() => {});
      });
    };
    const observer = new ResizeObserver(position);
    if (surface.current) observer.observe(surface.current);
    if (room.current) observer.observe(room.current);
    window.addEventListener("resize", position);
    window.addEventListener("scroll", position, true);
    position();
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
      window.removeEventListener("resize", position);
      window.removeEventListener("scroll", position, true);
      void api
        .bounds({ x: 0, y: 0, width: 1, height: 1, visible: false })
        .catch(() => {});
    };
  }, [active, p.fullscreen]);
  const current =
    p.schedule.find((s) => s.start <= p.now && s.end > p.now) ||
    (p.channel?.now && p.channel.now.start <= p.now && p.channel.now.end > p.now
      ? p.channel.now
      : null);
  const next =
    p.schedule.find((s) => s.start > p.now) ||
    (p.channel?.next && p.channel.next.start > p.now ? p.channel.next : null);
  const stateLabel = busy
    ? "CONNECTING"
    : p.status.state === "paused"
      ? "PAUSED"
      : p.status.state === "playing"
        ? "LIVE"
        : demo && p.channel
          ? "PREVIEW"
          : "READY";
  return (
    <section
      ref={room}
      className={`viewing-room ${p.fullscreen ? "fullscreen-room" : ""}`}
      aria-label="Viewing room"
    >
      <div className="viewing-content">
        <div className="video-surface" ref={surface}>
          {(!active || busy) && (
            <div className="player-idle">
              {failed ? (
                <AlertCircle size={38} />
              ) : busy ? (
                <LoaderCircle size={34} className="spin" />
              ) : (
                <Tv size={52} strokeWidth={1} />
              )}
              <h2>
                {failed
                  ? "Playback unavailable"
                  : busy
                    ? "Connecting to live stream…"
                    : demo && p.channel
                      ? "Interface preview"
                      : "Your viewing room"}
              </h2>
              <p>
                {failed
                  ? p.error ||
                    p.info?.playerError ||
                    "Try again or choose another channel."
                  : demo && p.channel
                    ? "Live playback is available in the desktop app."
                    : p.channel
                      ? p.channel.name
                      : "Choose a channel and settle in."}
              </p>
              {!p.info?.configured ? (
                <button className="primary-button" onClick={p.onSettings}>
                  Connect your service
                </button>
              ) : failed && p.channel ? (
                <button className="primary-button" onClick={p.onPlay}>
                  <RotateCcw size={17} />
                  Retry channel
                </button>
              ) : null}
            </div>
          )}
        </div>
        {!p.fullscreen && (
          <div className="programme-area">
            {p.channel ? (
              <>
                <div className="programme-channel">
                  <span>{p.channel.name}</span>
                  <span className={active ? "live-label" : ""}>
                    {failed ? "UNAVAILABLE" : stateLabel}
                  </span>
                </div>
                <h1>{current?.title || "Live television"}</h1>
                {current ? (
                  <>
                    <p className="programme-meta">
                      {time(current.start)}–{time(current.end)} ·{" "}
                      {Math.max(0, Math.ceil((current.end - p.now) / 60))} min
                      left
                    </p>
                    <div
                      className="programme-progress"
                      role="progressbar"
                      aria-label="Programme elapsed"
                      aria-valuemin={0}
                      aria-valuemax={100}
                      aria-valuenow={Math.round(progress(current, p.now))}
                    >
                      <i style={{ width: `${progress(current, p.now)}%` }} />
                    </div>
                    {current.description && (
                      <p className="programme-description">
                        {current.description}
                      </p>
                    )}
                  </>
                ) : (
                  <p className="programme-description">
                    Programme information unavailable
                  </p>
                )}
              </>
            ) : (
              <>
                <h1>Your viewing room</h1>
                <p className="programme-description">
                  Choose a channel to watch live. Your programme and what's on
                  next will appear here.
                </p>
              </>
            )}
          </div>
        )}
        <div className="playback-controls">
          <button
            className="primary-button full-screen-button"
            onClick={p.onFullscreen}
            disabled={!p.channel}
          >
            {p.fullscreen ? <Minimize size={19} /> : <Maximize size={19} />}
            {p.fullscreen ? "Exit full screen" : "Full screen"}
          </button>
          {!p.fullscreen && (
            <>
              <button
                className={`icon-button ${p.channel?.favorite ? "is-favorite" : ""}`}
                disabled={!p.channel}
                aria-label={
                  p.channel?.favorite
                    ? "Remove from favorites"
                    : "Add to favorites"
                }
                onClick={p.onFavorite}
              >
                <Star
                  size={22}
                  fill={p.channel?.favorite ? "currentColor" : "none"}
                />
              </button>
              <button
                className="icon-button"
                aria-label="Programme guide"
                onClick={p.onGuide}
              >
                <CalendarDays size={21} />
              </button>
            </>
          )}
          <button
            className="icon-button"
            disabled={!p.channel || busy}
            aria-label={
              p.status.state === "paused"
                ? "Resume playback"
                : active
                  ? "Pause playback"
                  : "Play channel"
            }
            onClick={() =>
              active
                ? p.onAction(p.status.state === "paused" ? "resume" : "pause")
                : p.onPlay()
            }
          >
            {active && p.status.state !== "paused" ? (
              <Pause size={19} />
            ) : (
              <Play size={19} />
            )}
          </button>
          <button
            className="icon-button"
            aria-label="Stop playback"
            disabled={!active && p.status.state !== "preview"}
            onClick={() => p.onAction("stop")}
          >
            <Square size={17} fill="currentColor" />
          </button>
          <div className="volume-controls">
            <button
              className="icon-button"
              aria-label={p.status.volume ? "Mute audio" : "Unmute audio"}
              onClick={() => p.onAction("volume", p.status.volume ? 0 : 80)}
            >
              {p.status.volume ? <Volume2 size={20} /> : <VolumeX size={20} />}
            </button>
            <input
              className="volume-slider"
              type="range"
              min="0"
              max="100"
              aria-label="Volume"
              value={p.status.volume}
              onChange={(e) => p.onAction("volume", Number(e.target.value))}
            />
          </div>
          {p.fullscreen && (
            <span className="playback-status">{stateLabel}</span>
          )}
        </div>
        {!p.fullscreen && next && (
          <div className="up-next">
            <span>UP NEXT</span>
            <time>{time(next.start)}</time>
            <strong>{next.title}</strong>
          </div>
        )}
        {!p.fullscreen &&
          p.status.state === "playing" &&
          p.status.width > 0 && (
            <span className="stream-detail">
              {p.status.width} × {p.status.height}
            </span>
          )}
      </div>
    </section>
  );
}
