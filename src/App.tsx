import { useCallback, useEffect, useRef, useState } from "react";
import {
  Tv,
  CalendarDays,
  Star,
  History,
  Settings as SettingsIcon,
  RefreshCw,
  ChevronRight,
  CircleHelp,
  LoaderCircle,
  X,
  AlertCircle,
  Radio,
  Play,
} from "lucide-react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { listen } from "@tauri-apps/api/event";
import Brand from "./components/Brand";
import ChannelBrowser from "./components/ChannelBrowser";
import PlayerView from "./components/PlayerView";
import Guide from "./components/Guide";
import Settings from "./components/Settings";
import { api, native, demo } from "./api";
import type {
  AppInfo,
  Channel,
  ChannelPage,
  Group,
  PlayerStatus,
  Programme,
  SyncProgress,
  View,
} from "./types";
import { errorText, RequestSequence } from "./utils";

const navigation = [
  { id: "live", label: "Live TV", icon: Tv },
  { id: "guide", label: "TV Guide", icon: CalendarDays },
  { id: "favorites", label: "Favorites", icon: Star },
  { id: "history", label: "History", icon: History },
] as const;
const initialStatus: PlayerStatus = {
  state: "idle",
  channelId: null,
  volume: 80,
  width: 0,
  height: 0,
  decodedVideo: 0,
  decodedAudio: 0,
};
export default function App() {
  const [view, setView] = useState<View>(() => {
    const saved = localStorage.getItem("vektortv.view");
    return ["live", "guide", "favorites", "history", "settings"].includes(
      saved || "",
    )
      ? (saved as View)
      : "live";
  });
  const [info, setInfo] = useState<AppInfo | null>(null);
  const [groups, setGroups] = useState<Group[]>([]);
  const [group, setGroup] = useState(
    () => localStorage.getItem("vektortv.group") || "",
  );
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [page, setPage] = useState<ChannelPage>({
    channels: [],
    total: 0,
    offset: 0,
  });
  const [selected, setSelected] = useState<Channel | null>(null);
  const [schedule, setSchedule] = useState<Programme[]>([]);
  const [status, setStatus] = useState(initialStatus);
  const [progress, setProgress] = useState<SyncProgress>({
    phase: "",
    active: false,
    message: "",
  });
  const [loading, setLoading] = useState(true);
  const [revision, setRevision] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [playError, setPlayError] = useState<string | null>(null);
  const [fullscreen, setFullscreen] = useState(false);
  const [now, setNow] = useState(Math.floor(Date.now() / 1000));
  const [elapsed, setElapsed] = useState(0);
  const [help, setHelp] = useState(false);
  const searchRef = useRef<HTMLInputElement>(null);
  const queries = useRef(new RequestSequence());
  const plays = useRef(new RequestSequence());
  const moreBusy = useRef(false);
  const refreshing = useRef(false);
  const statusSequence = useRef(new RequestSequence());

  const refreshInfo = useCallback(async () => {
    const [nextInfo, nextGroups] = await Promise.all([
      api.info(),
      api.groups(),
    ]);
    setInfo(nextInfo);
    setGroups(nextGroups);
    return nextInfo;
  }, []);
  const sync = useCallback(async () => {
    if (refreshing.current) return;
    refreshing.current = true;
    setError(null);
    setElapsed(0);
    setProgress({
      phase: "channels",
      active: true,
      message: "Connecting and loading live channels…",
    });
    try {
      const result = await api.sync();
      setProgress(result);
      await refreshInfo();
      setRevision((v) => v + 1);
    } catch (e) {
      const message = errorText(e);
      setError(message);
      setProgress({ phase: "error", active: false, message });
    } finally {
      refreshing.current = false;
    }
  }, [refreshInfo]);
  useEffect(() => {
    let current = true;
    refreshInfo()
      .then((next) => {
        if (!current) return;
        setProgress(next.progress);
        if (
          next.configured &&
          native &&
          (!next.channelsUpdated ||
            Date.now() / 1000 - next.channelsUpdated > 21600)
        )
          void sync();
      })
      .catch((e) => {
        if (current) setError(errorText(e));
      });
    let unlisten: (() => void) | undefined;
    if (native)
      void listen<SyncProgress>("sync-progress", (e) => {
        if (current) {
          setProgress(e.payload);
          if (e.payload.phase === "guide") {
            void refreshInfo().then(() => setRevision((v) => v + 1));
          }
        }
      }).then((fn) => {
        if (current) unlisten = fn;
        else fn();
      });
    return () => {
      current = false;
      unlisten?.();
    };
  }, [refreshInfo, sync]);
  useEffect(() => {
    const timer = window.setInterval(
      () => setNow(Math.floor(Date.now() / 1000)),
      15000,
    );
    return () => window.clearInterval(timer);
  }, []);
  useEffect(() => {
    if (!progress.active) return;
    const started = Date.now();
    const timer = window.setInterval(
      () => setElapsed(Math.floor((Date.now() - started) / 1000)),
      1000,
    );
    return () => window.clearInterval(timer);
  }, [progress.active]);
  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedSearch(search), 180);
    return () => window.clearTimeout(timer);
  }, [search]);
  useEffect(() => {
    localStorage.setItem("vektortv.view", view);
    localStorage.setItem("vektortv.group", group);
  }, [view, group]);
  const query = {
    search: debouncedSearch,
    group: group || null,
    favoritesOnly: view === "favorites",
    historyOnly: view === "history",
    offset: 0,
    limit: 100,
  };
  const selectedId = selected?.id;
  useEffect(() => {
    const token = queries.current.next();
    moreBusy.current = false;
    setLoading(true);
    api
      .list({
        search: debouncedSearch,
        group: group || null,
        favoritesOnly: view === "favorites",
        historyOnly: view === "history",
        offset: 0,
        limit: 100,
      })
      .then((result) => {
        if (queries.current.current(token)) setPage(result);
      })
      .catch((e) => {
        if (queries.current.current(token)) setError(errorText(e));
      })
      .finally(() => {
        if (queries.current.current(token)) setLoading(false);
      });
  }, [debouncedSearch, group, view, revision]);
  const loadMore = async () => {
    if (moreBusy.current || loading || page.channels.length >= page.total)
      return;
    moreBusy.current = true;
    const token = queries.current.next();
    setLoading(true);
    try {
      const result = await api.list({ ...query, offset: page.channels.length });
      if (queries.current.current(token))
        setPage((p) => ({
          ...result,
          channels: [...p.channels, ...result.channels],
        }));
    } catch (e) {
      if (queries.current.current(token)) setError(errorText(e));
    } finally {
      if (queries.current.current(token)) {
        moreBusy.current = false;
        setLoading(false);
      }
    }
  };
  useEffect(() => {
    let current = true;
    setSchedule([]);
    if (!selectedId) return;
    api
      .schedule(selectedId, now - 3600, now + 86400)
      .then((result) => {
        if (current) setSchedule(result);
      })
      .catch((e) => {
        if (current) setError(errorText(e));
      });
    return () => {
      current = false;
    };
  }, [selectedId, now, revision]);
  useEffect(() => {
    if (!selected) return;
    const updated = page.channels.find((c) => c.id === selected.id);
    if (updated && updated !== selected) setSelected(updated);
  }, [page.channels, selected]);
  useEffect(() => {
    let current = true;
    let busy = false;
    const sequence = statusSequence.current;
    const poll = async () => {
      if (busy) return;
      busy = true;
      const token = sequence.next();
      try {
        const next = await api.status();
        if (current && sequence.current(token)) setStatus(next);
      } catch (e) {
        if (current) setPlayError(errorText(e));
      } finally {
        busy = false;
      }
    };
    void poll();
    const timer = window.setInterval(() => {
      void poll();
    }, 1000);
    return () => {
      current = false;
      sequence.next();
      window.clearInterval(timer);
    };
  }, []);
  const play = useCallback(async (channel: Channel) => {
    const token = plays.current.next();
    statusSequence.current.next();
    setSelected(channel);
    setPlayError(null);
    setStatus((s) => ({ ...s, state: "opening", channelId: channel.id }));
    try {
      await api.play(channel.id, token);
      if (plays.current.current(token)) {
        const next = await api.status();
        if (plays.current.current(token)) setStatus(next);
      }
    } catch (e) {
      if (plays.current.current(token)) {
        setPlayError(errorText(e));
        setStatus((s) => ({ ...s, state: "error" }));
      }
    }
  }, []);
  const action = useCallback(async (action: string, value?: number) => {
    const requestId = action === "stop" ? plays.current.next() : undefined;
    statusSequence.current.next();
    if (action === "volume") setStatus((s) => ({ ...s, volume: value ?? 80 }));
    try {
      await api.action(action, value, requestId);
      const next = await api.status();
      setStatus(next);
    } catch (e) {
      setPlayError(errorText(e));
    }
  }, []);
  const toggleFullscreen = useCallback(async () => {
    const next = !fullscreen;
    try {
      if (native) await getCurrentWindow().setFullscreen(next);
      setFullscreen(next);
    } catch (e) {
      setError(errorText(e));
    }
  }, [fullscreen]);
  const favorite = async (channel: Channel) => {
    try {
      await api.favorite(channel.id, !channel.favorite);
      setSelected((c) =>
        c?.id === channel.id ? { ...c, favorite: !channel.favorite } : c,
      );
      setRevision((v) => v + 1);
    } catch (e) {
      setError(errorText(e));
    }
  };
  useEffect(() => {
    const key = (event: KeyboardEvent) => {
      if (event.key === "Escape" && fullscreen) {
        void toggleFullscreen();
        return;
      }
      if (event.ctrlKey && event.key.toLowerCase() === "k") {
        event.preventDefault();
        if (view === "settings") setView("live");
        window.setTimeout(() => searchRef.current?.focus(), 0);
        return;
      }
      if (
        event.target instanceof HTMLElement &&
        event.target.closest("input,textarea,select,button")
      )
        return;
      if (event.key.toLowerCase() === "f") {
        event.preventDefault();
        void toggleFullscreen();
      }
      if (event.code === "Space" && selected) {
        event.preventDefault();
        if (status.state === "idle" || status.state === "error")
          void play(selected);
        else void action(status.state === "paused" ? "resume" : "pause");
      }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, [
    fullscreen,
    toggleFullscreen,
    view,
    selected,
    status.state,
    action,
    play,
  ]);
  const go = (target: View) => {
    setView(target);
    setError(null);
    setHelp(false);
  };
  const titles = {
    live: "Live television",
    guide: "Programme guide",
    favorites: "Your favorites",
    history: "Recently watched",
    settings: "Your workspace",
  };
  return (
    <div className={`app-shell ${fullscreen ? "is-fullscreen" : ""}`}>
      {!fullscreen && (
        <aside className="navigation">
          <Brand />
          <div className="nav-caption">YOUR TELEVISION</div>
          <nav>
            {navigation.map((item) => (
              <button
                key={item.id}
                className={view === item.id ? "active" : ""}
                onClick={() => go(item.id)}
              >
                <item.icon size={19} />
                <span>{item.label}</span>
                {view === item.id && <i />}
              </button>
            ))}
          </nav>
          <div className="nav-bottom">
            {selected && status.channelId && (
              <button className="mini-now-playing" onClick={() => go("live")}>
                <span className="mini-playing-icon">
                  <Play size={12} fill="currentColor" />
                </span>
                <span>
                  <small>NOW PLAYING</small>
                  <strong>{selected.name}</strong>
                </span>
                <ChevronRight size={14} />
              </button>
            )}
            <button
              className={`nav-settings ${view === "settings" ? "active" : ""}`}
              onClick={() => go("settings")}
            >
              <SettingsIcon size={19} />
              <span>Settings</span>
            </button>
            <button className="help-button" onClick={() => setHelp((v) => !v)}>
              <CircleHelp size={17} />
              <span>Quick help</span>
            </button>
            <div className="nav-signoff">
              A better way to tune in.<span>VEKTORTV · WINDOWS</span>
            </div>
          </div>
        </aside>
      )}
      <div className="workspace">
        {!fullscreen && (
          <header className="workspace-header">
            <div className="breadcrumb">
              <span>{titles[view]}</span>
              <ChevronRight size={12} />
              <strong>{group || "All channels"}</strong>
            </div>
            <div className="header-end">
              {demo && <span className="preview-badge">INTERFACE PREVIEW</span>}
              <span
                className={`connection-dot ${info?.configured ? "connected" : ""}`}
              />
              <span>{info?.configured ? "Connected" : "Add a connection"}</span>
              <span className="header-divider" />
              <time>
                {new Date(now * 1000).toLocaleTimeString([], {
                  hour: "2-digit",
                  minute: "2-digit",
                })}
              </time>
              <button
                className="icon-button"
                aria-label="Refresh library"
                disabled={!info?.configured || progress.active}
                onClick={() => void sync()}
              >
                <RefreshCw
                  size={16}
                  className={progress.active ? "spin" : ""}
                />
              </button>
            </div>
          </header>
        )}
        {!fullscreen && progress.active && (
          <div className="sync-banner" role="status">
            <LoaderCircle size={16} className="spin" />
            <span>{progress.message}</span>
            <small>{elapsed}s</small>
          </div>
        )}
        {!fullscreen && error && (
          <div className="error-banner" role="alert">
            <AlertCircle size={16} />
            <span>{error}</span>
            <button aria-label="Dismiss error" onClick={() => setError(null)}>
              <X size={15} />
            </button>
          </div>
        )}
        {!fullscreen && !progress.active && progress.phase === "warning" && (
          <div className="warning-banner">
            <AlertCircle size={15} />
            <span>{progress.message}</span>
            <button
              aria-label="Dismiss guide warning"
              onClick={() => setProgress((p) => ({ ...p, phase: "" }))}
            >
              <X size={15} />
            </button>
          </div>
        )}
        {help && !fullscreen && (
          <div className="help-banner">
            <Radio size={18} />
            <p>
              Choose a channel to watch live. Star channels to save them. Use
              the TV Guide to browse programmes, and Settings to connect your
              service.
            </p>
            <button
              className="icon-button"
              aria-label="Close help"
              onClick={() => setHelp(false)}
            >
              <X size={16} />
            </button>
          </div>
        )}
        <div
          className={`content ${view === "settings" ? "settings-content" : ""}`}
        >
          {view !== "settings" && !fullscreen && (
            <ChannelBrowser
              channels={page.channels}
              groups={groups}
              group={group}
              setGroup={setGroup}
              search={search}
              setSearch={setSearch}
              selected={selected?.id || null}
              onSelect={(c) => {
                void play(c);
              }}
              onFavorite={(c) => {
                void favorite(c);
              }}
              total={page.total}
              loading={loading}
              onMore={() => {
                void loadMore();
              }}
              view={view}
              now={now}
              searchRef={searchRef}
            />
          )}
          {view === "settings" && !fullscreen ? (
            <Settings
              info={info ? { ...info, progress } : null}
              onSaved={() => {
                void refreshInfo().then(() => sync());
              }}
              onRefresh={() => {
                void sync();
              }}
              onDisconnected={() => {
                setStatus(initialStatus);
                void refreshInfo();
              }}
            />
          ) : view === "guide" && !fullscreen ? (
            <Guide
              channels={page.channels}
              now={now}
              onWatch={(c) => {
                setView("live");
                void play(c);
              }}
            />
          ) : (
            <PlayerView
              channel={selected}
              schedule={schedule}
              status={status}
              info={info}
              onPlay={() => {
                if (selected) void play(selected);
              }}
              onAction={(a, v) => {
                void action(a, v);
              }}
              onFullscreen={() => {
                void toggleFullscreen();
              }}
              fullscreen={fullscreen}
              now={now}
              onFavorite={() => {
                if (selected) void favorite(selected);
              }}
              error={playError}
              onSettings={() => go("settings")}
            />
          )}
        </div>
        {!fullscreen && (
          <footer className="workspace-footer">
            <span>
              <i className={progress.active ? "busy" : ""} />
              {progress.active
                ? "Refreshing library"
                : info?.channelCount
                  ? `${info.channelCount.toLocaleString()} channels in your library`
                  : "Welcome to VektorTV"}
            </span>
            <span>
              {demo
                ? "Illustrative data · no stream connection"
                : info?.guideUpdated
                  ? `Guide updated ${new Date(info.guideUpdated * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
                  : "Your television, on your terms."}
              <span className="footer-brand">
                VEKTOR<span>TV</span>
              </span>
            </span>
          </footer>
        )}
      </div>
    </div>
  );
}
