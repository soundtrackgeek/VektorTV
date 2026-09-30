import { useState } from "react";
import {
  Link2,
  ShieldCheck,
  RefreshCw,
  Database,
  MonitorPlay,
  CheckCircle2,
  LoaderCircle,
} from "lucide-react";
import type { AppInfo, Connection } from "../types";
import { api, native, demo } from "../api";
import { errorText } from "../utils";

export default function Settings({
  info,
  onSaved,
  onRefresh,
  onDisconnected,
}: {
  info: AppInfo | null;
  onSaved: () => void;
  onRefresh: () => void;
  onDisconnected: () => void;
}) {
  const [connection, setConnection] = useState<Connection>({
    kind: "xtream",
    baseUrl: "",
    username: "",
    password: "",
    playlistUrl: "",
    epgUrl: "",
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const change = (field: keyof Connection, value: string) =>
    setConnection((c) => ({ ...c, [field]: value }));
  const date = (value: number | null | undefined) =>
    value ? new Date(value * 1000).toLocaleString() : "Not refreshed yet";
  const save = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setSaving(true);
    try {
      await api.save(connection);
      setConnection((c) => ({
        ...c,
        username: "",
        password: "",
        playlistUrl: "",
        epgUrl: "",
      }));
      onSaved();
    } catch (e) {
      setError(errorText(e));
    } finally {
      setSaving(false);
    }
  };
  return (
    <section className="settings-view">
      <div className="section-topline">
        <div>
          <span className="eyebrow">MAKE IT YOURS</span>
          <h1>Settings.</h1>
        </div>
        <span className="version-tag">v{info?.version || "0.1.0"}</span>
      </div>
      <div className="settings-section">
        <div className="settings-section-title">
          <Link2 size={20} />
          <div>
            <h2>Your IPTV connection</h2>
            <p>Bring your service. We'll take care of the viewing.</p>
          </div>
        </div>
        {info?.configured && (
          <div className="connected-banner">
            <CheckCircle2 size={19} />
            <div>
              <strong>Connection saved</strong>
              <span>
                {info.server} ·{" "}
                {info.connectionKind === "xtream"
                  ? "Xtream API"
                  : "M3U playlist"}
              </span>
            </div>
            <button
              className="text-button"
              disabled={saving || info.progress.active || !native}
              onClick={async () => {
                try {
                  await api.disconnect();
                  onDisconnected();
                } catch (e) {
                  setError(errorText(e));
                }
              }}
            >
              Disconnect
            </button>
          </div>
        )}
        {!native && (
          <div className="preview-notice">
            {demo ? "This is an illustrative interface preview. " : ""}Connect
            your service in the Windows app.
          </div>
        )}
        <form onSubmit={save}>
          <div className="connection-tabs">
            <button
              type="button"
              className={connection.kind === "xtream" ? "active" : ""}
              onClick={() => change("kind", "xtream")}
            >
              Xtream login
            </button>
            <button
              type="button"
              className={connection.kind === "m3u" ? "active" : ""}
              onClick={() => change("kind", "m3u")}
            >
              M3U playlist
            </button>
          </div>
          {connection.kind === "xtream" ? (
            <>
              <label>
                Server address
                <input
                  required
                  type="url"
                  placeholder="http://your-provider.com:8080"
                  value={connection.baseUrl}
                  onChange={(e) => change("baseUrl", e.target.value)}
                />
              </label>
              <div className="form-columns">
                <label>
                  Username
                  <input
                    required
                    autoComplete="off"
                    placeholder="Your IPTV username"
                    value={connection.username}
                    onChange={(e) => change("username", e.target.value)}
                  />
                </label>
                <label>
                  Password
                  <input
                    required
                    type="password"
                    autoComplete="new-password"
                    placeholder="Your IPTV password"
                    value={connection.password}
                    onChange={(e) => change("password", e.target.value)}
                  />
                </label>
              </div>
            </>
          ) : (
            <label>
              M3U playlist address
              <input
                required
                type="url"
                placeholder="https://your-provider.com/playlist.m3u"
                value={connection.playlistUrl}
                onChange={(e) => change("playlistUrl", e.target.value)}
              />
            </label>
          )}
          <label>
            XMLTV guide address{" "}
            <span className="field-optional">
              {connection.kind === "xtream" ? "optional override" : "optional"}
            </span>
            <input
              type="url"
              placeholder={
                connection.kind === "xtream"
                  ? "Automatically supplied by your Xtream service"
                  : "https://your-provider.com/guide.xml"
              }
              value={connection.epgUrl}
              onChange={(e) => change("epgUrl", e.target.value)}
            />
          </label>
          <div className="credential-note">
            <ShieldCheck size={16} />
            <span>
              Account details are saved in Windows Credential Manager.
            </span>
          </div>
          {error && (
            <div className="inline-error" role="alert">
              {error}
            </div>
          )}
          <button
            className="primary-button"
            type="submit"
            disabled={saving || !native || info?.progress.active}
          >
            {saving ? (
              <LoaderCircle className="spin" size={16} />
            ) : (
              <Link2 size={16} />
            )}{" "}
            {saving
              ? "Checking connection…"
              : info?.configured
                ? "Save new connection"
                : "Connect & load channels"}
          </button>
        </form>
      </div>
      <div className="settings-section">
        <div className="settings-section-title">
          <Database size={20} />
          <div>
            <h2>Library & programme guide</h2>
            <p>Cached locally, ready when you open the app.</p>
          </div>
          <button
            className="outline-button"
            onClick={onRefresh}
            disabled={!info?.configured || info?.progress.active}
          >
            <RefreshCw size={15} />
            Refresh
          </button>
        </div>
        <dl className="settings-facts">
          <div>
            <dt>Live channels</dt>
            <dd>{info?.channelCount.toLocaleString() || "0"}</dd>
          </div>
          <div>
            <dt>Cached programmes</dt>
            <dd>{info?.programmeCount.toLocaleString() || "0"}</dd>
          </div>
          <div>
            <dt>Channels refreshed</dt>
            <dd>{date(info?.channelsUpdated)}</dd>
          </div>
          <div>
            <dt>Guide refreshed</dt>
            <dd>{date(info?.guideUpdated)}</dd>
          </div>
        </dl>
        <p className="settings-note">
          Favorites and history survive refreshes. A failed refresh keeps the
          previous library. Watching requires an active service connection.
        </p>
      </div>
      <div className="settings-section">
        <div className="settings-section-title">
          <MonitorPlay size={20} />
          <div>
            <h2>Windows playback</h2>
            <p>Embedded VLC engine for live MPEG-TS and HLS streams.</p>
          </div>
          <span
            className={`engine-badge ${info?.playerAvailable ? "ready" : ""}`}
          >
            {info?.playerAvailable ? "Ready" : "Unavailable"}
          </span>
        </div>
        {info?.playerError && (
          <p className="inline-error">{info.playerError}</p>
        )}
        <div className="keyboard-hints">
          <span>
            <kbd>Space</kbd> Pause / resume
          </span>
          <span>
            <kbd>F</kbd> Fullscreen
          </span>
          <span>
            <kbd>Esc</kbd> Exit fullscreen
          </span>
          <span>
            <kbd>Ctrl K</kbd> Search
          </span>
        </div>
      </div>
    </section>
  );
}
