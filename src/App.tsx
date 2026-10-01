import { useCallback, useEffect, useRef, useState } from "react";
import {
  Settings as SettingsIcon,
  Search,
  LoaderCircle,
  X,
  AlertCircle,
  Play,
  Square,
} from "lucide-react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { listen } from "@tauri-apps/api/event";
import Brand from "./components/Brand";
import CountryBrowser from "./components/CountryBrowser";
import ChannelBrowser from "./components/ChannelBrowser";
import PlayerView from "./components/PlayerView";
import Guide from "./components/Guide";
import Settings from "./components/Settings";
import { api, native, demo } from "./api";
import type {
  AppInfo,
  Channel,
  ChannelPage,
  Country,
  Group,
  PlayerStatus,
  Programme,
  SyncProgress,
  View,
} from "./types";
import { errorText, RequestSequence } from "./utils";

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
    return [
      "countries",
      "live",
      "guide",
      "favorites",
      "history",
      "settings",
    ].includes(saved || "")
      ? (saved as View)
      : "live";
  });
  const [info, setInfo] = useState<AppInfo | null>(null);
  const [countries, setCountries] = useState<Country[]>([]);
  const [countryCode, setCountryCode] = useState<string | null>(() =>
    localStorage.getItem("vektortv.country"),
  );
  const country = countries.find((c) => c.code === countryCode);
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
  const searchRef = useRef<HTMLInputElement>(null);
  const queries = useRef(new RequestSequence());
  const plays = useRef(new RequestSequence());
  const moreBusy = useRef(false);
  const refreshing = useRef(false);
  const statusSequence = useRef(new RequestSequence());

  const refreshInfo = useCallback(async () => {
    const [nextInfo, nextGroups, nextCountries] = await Promise.all([
      api.info(),
      api.groups(),
      api.countries(),
    ]);
    setInfo(nextInfo);
    setGroups(nextGroups);
    setCountries(nextCountries);
    return nextInfo;
  }, []);
  const sync = useCallback(
    async (guideOnly = false) => {
      if (refreshing.current) return;
      refreshing.current = true;
      setError(null);
      setElapsed(0);
      setProgress({
        phase: guideOnly ? "guide" : "channels",
        active: true,
        message: guideOnly
          ? "Loading the programme guide for all channels…"
          : "Connecting and loading live channels…",
      });
      try {
        const result = await api.sync(guideOnly);
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
    },
    [refreshInfo],
  );
  useEffect(() => {
    let current = true;
    // Check on launch, resume and during long sessions. Throttle failures as well
    // as successes so repeated focus events cannot hammer the provider.
    let lastCheck = 0;
    const check = () => {
      if (refreshing.current || Date.now() - lastCheck < 300000) return;
      lastCheck = Date.now();
      void refreshInfo()
        .then((next) => {
          if (!current) return;
          setProgress(next.progress);
          if (!native || !next.configured || next.progress.active) return;
          if (
            !next.channelCount ||
            !next.channelsUpdated ||
            Date.now() / 1000 - next.channelsUpdated >= 21600
          ) {
            void sync();
          } else if (next.guideNeedsRefresh) {
            void sync(true);
          }
        })
        .catch((e) => {
          if (current) setError(errorText(e));
        });
    };
    check();
    const timer = window.setInterval(check, 300000);
    window.addEventListener("focus", check);
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
      window.clearInterval(timer);
      window.removeEventListener("focus", check);
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
    if (countryCode) localStorage.setItem("vektortv.country", countryCode);
    else localStorage.removeItem("vektortv.country");
  }, [view, group, countryCode]);
  const query = {
    search: debouncedSearch,
    group: group || null,
    country: countryCode,
    alphabetical: !!countryCode && view !== "history",
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
        country: countryCode,
        alphabetical: !!countryCode && view !== "history",
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
  }, [debouncedSearch, group, countryCode, view, revision]);
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
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        if (view === "settings" || view === "countries") setView("live");
        window.setTimeout(() => {
          if (view === "guide")
            document.getElementById("guide-search-toggle")?.click();
          else searchRef.current?.focus();
        }, 0);
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
  };
  const openSearch = () => {
    if (view === "settings" || view === "countries") setView("live");
    window.setTimeout(() => {
      if (view === "guide")
        document.getElementById("guide-search-toggle")?.click();
      else searchRef.current?.focus();
    }, 0);
  };
  return (
    <div className={`app-shell ${fullscreen ? "is-fullscreen" : ""}`}>
      {!fullscreen && (
        <header className="app-header">
          <Brand />
          <nav className="main-tabs" aria-label="Main navigation">
            <button
              className={
                view !== "guide" && view !== "settings" && view !== "countries"
                  ? "active"
                  : ""
              }
              aria-current={
                view !== "guide" && view !== "settings" && view !== "countries"
                  ? "page"
                  : undefined
              }
              onClick={() => go("live")}
            >
              Watch
            </button>
            <button
              className={view === "guide" ? "active" : ""}
              aria-current={view === "guide" ? "page" : undefined}
              onClick={() => go("guide")}
            >
              TV Guide
            </button>
            <button
              className={view === "countries" ? "active" : ""}
              aria-current={view === "countries" ? "page" : undefined}
              onClick={() => go("countries")}
            >
              Countries
            </button>
          </nav>
          <div className="header-actions">
            {demo && <span className="preview-badge">Interface preview</span>}
            <button
              className="icon-button"
              aria-label="Find a channel"
              title="Find a channel (⌘/Ctrl K)"
              onClick={openSearch}
            >
              <Search size={22} />
            </button>
            <button
              className={`icon-button ${view === "settings" ? "is-active" : ""}`}
              aria-label="Settings"
              onClick={() => go("settings")}
            >
              <SettingsIcon size={22} />
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
          <button
            className="icon-button"
            aria-label="Dismiss error"
            onClick={() => setError(null)}
          >
            <X size={16} />
          </button>
        </div>
      )}
      {!fullscreen && !progress.active && progress.phase === "warning" && (
        <div className="warning-banner" role="status">
          <AlertCircle size={16} />
          <span>{progress.message}</span>
          <button
            className="icon-button"
            aria-label="Dismiss guide warning"
            onClick={() => setProgress((p) => ({ ...p, phase: "" }))}
          >
            <X size={16} />
          </button>
        </div>
      )}
      <main
        className={`content ${view === "settings" ? "settings-content" : ""}`}
      >
        {view !== "settings" && view !== "countries" && !fullscreen && (
          <ChannelBrowser
            channels={page.channels}
            groups={country?.groups ?? groups}
            country={country}
            onCountries={() => go("countries")}
            onClearCountry={() => {
              setCountryCode(null);
              setGroup("");
              setSearch("");
            }}
            group={group}
            setGroup={setGroup}
            search={search}
            setSearch={setSearch}
            selected={status.channelId}
            onSelect={(c) => {
              if (view === "guide") setView("live");
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
            onView={go}
            now={now}
            searchRef={searchRef}
            onRefresh={() => {
              void sync();
            }}
            refreshing={progress.active}
            configured={!!info?.configured}
          />
        )}
        {view === "countries" && !fullscreen ? (
          <CountryBrowser
            countries={countries}
            loading={!info}
            onSettings={() => go("settings")}
            onFavorite={async (c) => {
              try {
                await api.favoriteCountry(c.code, !c.favorite);
                setCountries(await api.countries());
              } catch (e) {
                setError(errorText(e));
              }
            }}
            onOpen={(c, selectedGroup) => {
              setCountryCode(c.code);
              setGroup(selectedGroup ?? "");
              setSearch("");
              setDebouncedSearch("");
              setView("live");
            }}
          />
        ) : view === "settings" && !fullscreen ? (
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
              setSelected(null);
              void refreshInfo();
            }}
          />
        ) : view === "guide" && !fullscreen ? (
          <Guide
            key={`${debouncedSearch}|${group}|${countryCode ?? ""}`}
            total={page.total}
            loadingChannels={loading}
            onLoadMore={() => {
              void loadMore();
            }}
            countries={countries}
            groups={groups}
            revision={revision}
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
            onGuide={() => go("guide")}
          />
        )}
      </main>
      {!fullscreen &&
        (view === "guide" || view === "settings" || view === "countries") &&
        selected &&
        status.channelId && (
          <div className="now-playing-bar">
            <button onClick={() => go("live")}>
              <Play size={17} />
              <span>{selected.name}</span>
              <small>Return to Watch</small>
            </button>
            <button
              className="icon-button"
              aria-label="Stop playback"
              onClick={() => {
                void action("stop");
              }}
            >
              <Square size={16} />
            </button>
          </div>
        )}
    </div>
  );
}
