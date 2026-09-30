import { useEffect, useRef } from "react";
import {
  Play,
  Pause,
  Square,
  Volume2,
  VolumeX,
  Maximize,
  Minimize,
  Radio,
  LoaderCircle,
  RotateCcw,
  Star,
  ArrowRight,
  AlertCircle,
} from "lucide-react";
import { api, demo } from "../api";
import type { AppInfo, Channel, PlayerStatus, Programme } from "../types";
import { progress, time } from "../utils";
import { ChannelLogo } from "./ChannelBrowser";
import { Mark } from "./Brand";

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
}
export default function PlayerView(p: Props) {
  const surface = useRef<HTMLDivElement>(null);
  const active = ["opening", "buffering", "playing", "paused"].includes(
    p.status.state,
  );
  const busy = ["opening", "buffering"].includes(p.status.state);
  useEffect(() => {
    const position = () => {
      const rect = surface.current?.getBoundingClientRect();
      if (rect) {
        const scale = window.devicePixelRatio;
        void api
          .bounds({
            x: rect.x * scale,
            y: rect.y * scale,
            width: rect.width * scale,
            height: rect.height * scale,
            visible: active,
          })
          .catch(() => {});
      }
    };
    const observer = new ResizeObserver(position);
    if (surface.current) observer.observe(surface.current);
    window.addEventListener("resize", position);
    const timer = window.setTimeout(position, 50);
    position();
    return () => {
      observer.disconnect();
      window.removeEventListener("resize", position);
      window.clearTimeout(timer);
      void api
        .bounds({ x: 0, y: 0, width: 1, height: 1, visible: false })
        .catch(() => {});
    };
  }, [active, p.fullscreen]);
  const current =
    p.schedule.find((s) => s.start <= p.now && s.end > p.now) || p.channel?.now;
  const upcoming = p.schedule.filter((s) => s.start > p.now).slice(0, 5);
  return (
    <section
      className={`viewing-room ${p.fullscreen ? "fullscreen-room" : ""}`}
    >
      <div className="player-card">
        <div className="video-surface" ref={surface}>
          {demo && p.channel && p.status.state === "preview" ? (
            <div className="preview-scene">
              <div className="mountain mountain-one" />
              <div className="mountain mountain-two" />
              <div className="preview-label">
                <Radio size={18} /> Interface preview · playback is available in
                the Windows app
              </div>
            </div>
          ) : (
            <div className="player-idle">
              <Mark className="idle-mark" />
              {p.error ||
              p.status.state === "error" ||
              p.status.state === "ended" ? (
                <>
                  <AlertCircle className="error-icon" size={30} />
                  <h2>
                    {p.status.state === "ended"
                      ? "The stream has ended"
                      : "Unable to play this channel"}
                  </h2>
                  <p>
                    {p.error ||
                      "The provider could not deliver this stream. Try again or choose another channel."}
                  </p>
                  <button className="primary-button" onClick={p.onPlay}>
                    <RotateCcw size={16} />
                    Try again
                  </button>
                </>
              ) : (
                <>
                  <h2>
                    {busy
                      ? "Opening your channel…"
                      : p.channel
                        ? "Ready when you are"
                        : "Your next favorite is on air"}
                  </h2>
                  <p>
                    {!p.info?.configured
                      ? "Connect your IPTV service to start watching."
                      : p.channel
                        ? p.channel.name
                        : "Choose a channel from the list and settle in."}
                  </p>
                  {!p.info?.configured ? (
                    <button className="primary-button" onClick={p.onSettings}>
                      <ArrowRight size={16} />
                      Connect your service
                    </button>
                  ) : p.channel && !active ? (
                    <button className="primary-button" onClick={p.onPlay}>
                      <Play size={16} fill="currentColor" />
                      Watch live
                    </button>
                  ) : busy ? (
                    <LoaderCircle className="spin" size={24} />
                  ) : (
                    <span className="idle-hint">
                      <Radio size={14} />
                      Live television, made personal.
                    </span>
                  )}
                </>
              )}
            </div>
          )}
        </div>
        <div className="playback-controls">
          <button
            className="icon-button play-control"
            aria-label={
              p.status.state === "paused"
                ? "Resume playback"
                : active
                  ? "Pause playback"
                  : "Play channel"
            }
            disabled={!p.channel}
            onClick={() =>
              active
                ? p.onAction(p.status.state === "paused" ? "resume" : "pause")
                : p.onPlay()
            }
          >
            {busy ? (
              <LoaderCircle className="spin" size={20} />
            ) : active && p.status.state !== "paused" ? (
              <Pause size={20} fill="currentColor" />
            ) : (
              <Play size={20} fill="currentColor" />
            )}
          </button>
          <button
            className="icon-button"
            aria-label="Stop playback"
            disabled={!active && p.status.state !== "preview"}
            onClick={() => p.onAction("stop")}
          >
            <Square size={15} />
          </button>
          <span className={`live-indicator ${active ? "active" : ""}`}>
            <i />
            {p.status.state === "paused"
              ? "PAUSED"
              : demo
                ? "PREVIEW"
                : active
                  ? "LIVE"
                  : "READY"}
          </span>
          <span className="playback-status" aria-live="polite">
            {busy
              ? "Connecting…"
              : p.status.state === "playing"
                ? `${p.status.width && p.status.height ? `${p.status.width} × ${p.status.height}` : "Playing"}`
                : p.status.state === "error"
                  ? "Playback unavailable"
                  : ""}
          </span>
          <div className="controls-spacer" />
          <button
            className="icon-button"
            aria-label={p.status.volume ? "Mute audio" : "Unmute audio"}
            onClick={() => p.onAction("volume", p.status.volume ? 0 : 80)}
          >
            {p.status.volume ? <Volume2 size={19} /> : <VolumeX size={19} />}
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
          <span className="control-divider" />
          <button
            className="icon-button"
            aria-label={p.fullscreen ? "Exit fullscreen" : "Enter fullscreen"}
            onClick={p.onFullscreen}
          >
            {p.fullscreen ? <Minimize size={19} /> : <Maximize size={19} />}
          </button>
        </div>
      </div>
      {!p.fullscreen && (
        <div className="programme-area">
          {p.channel ? (
            <>
              <div className="now-heading">
                <ChannelLogo channel={p.channel} large />
                <div>
                  <div className="eyebrow">
                    {p.channel.name}
                    <span className="on-air-dot" />
                    ON AIR
                  </div>
                  <h1>{current?.title || p.channel.name}</h1>
                </div>
                <button
                  className={`outline-button programme-favorite ${p.channel.favorite ? "is-favorite" : ""}`}
                  onClick={p.onFavorite}
                >
                  <Star
                    size={16}
                    fill={p.channel.favorite ? "currentColor" : "none"}
                  />
                  {p.channel.favorite ? "Favorite" : "Add favorite"}
                </button>
              </div>
              {current ? (
                <>
                  <div className="programme-meta">
                    <span>
                      {time(current.start)} – {time(current.end)}
                    </span>
                    <span className="meta-dot" />
                    {current.category && (
                      <>
                        <span>{current.category}</span>
                        <span className="meta-dot" />
                      </>
                    )}
                    <span>
                      {Math.max(1, Math.ceil((current.end - p.now) / 60))} min
                      left
                    </span>
                  </div>
                  <div className="programme-progress">
                    <i style={{ width: `${progress(current, p.now)}%` }} />
                  </div>
                  <p className="programme-description">
                    {current.description ||
                      "No programme description is available."}
                  </p>
                </>
              ) : (
                <p className="programme-description">
                  No programme information is available for this channel. You
                  can still watch live.
                </p>
              )}
              <div className="coming-heading">
                <h2>Coming up</h2>
                <span>Local time</span>
              </div>
              {upcoming.length ? (
                <div className="upcoming-list">
                  {upcoming.map((programme, i) => (
                    <div
                      className="upcoming-row"
                      key={`${programme.start}-${programme.title}`}
                    >
                      <span className="upcoming-time">
                        {time(programme.start)}
                      </span>
                      <div>
                        <strong>{programme.title}</strong>
                        <span>
                          {Math.round((programme.end - programme.start) / 60)}{" "}
                          min
                          {programme.category ? ` · ${programme.category}` : ""}
                        </span>
                      </div>
                      {i === 0 && <span className="next-tag">NEXT</span>}
                    </div>
                  ))}
                </div>
              ) : (
                <p className="muted-text">
                  No upcoming programmes are available. Refresh the guide to
                  check for updates.
                </p>
              )}
            </>
          ) : (
            <div className="viewing-welcome">
              <div>
                <span className="eyebrow">
                  A LITTLE LESS SCROLLING. A LOT MORE WATCHING.
                </span>
                <h1>Make yourself at home.</h1>
                <p>
                  Your channels, live programmes and favorites.
                  <br />
                  Everything you need for a good evening.
                </p>
              </div>
              <span className="welcome-decoration">
                <Radio size={32} />
              </span>
            </div>
          )}
        </div>
      )}
    </section>
  );
}
