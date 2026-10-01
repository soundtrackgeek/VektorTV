import { invoke, isTauri } from "@tauri-apps/api/core";
import type {
  AppInfo,
  Channel,
  ChannelPage,
  Connection,
  Country,
  Group,
  PlayerStatus,
  Programme,
  ProgrammeQuery,
  ProgrammePage,
  Query,
  SyncProgress,
} from "./types";

export const native = isTauri();
export const demo =
  !native && new URLSearchParams(location.search).get("demo") === "1";
const now = Math.floor(Date.now() / 1000);
const hour = Math.floor(now / 3600) * 3600;
const names = [
  "NRK 1",
  "NRK 2",
  "TV 2",
  "TV 2 Zebra",
  "SVT 1",
  "SVT 2",
  "BBC News",
  "Sky News",
  "Eurosport 1",
  "Eurosport 2",
  "National Geographic",
  "Discovery",
];
const titles = [
  "Wild Scandinavia",
  "A World of Stories",
  "The Evening News",
  "The Great Outdoors",
  "Nordic Journeys",
  "Arts & Culture",
  "World News",
  "The Newsroom",
  "Live Cycling",
  "The Sporting Life",
  "Ocean Explorers",
  "How It Works",
];
const channels: Channel[] = names.map((name, i) => ({
  id: `demo-${i}`,
  name,
  group:
    i < 2
      ? "NO| Norway"
      : i < 4
        ? "NO| Norway Entertainment"
        : i < 6
          ? "SE| Sweden"
          : i < 8
            ? "UK| News"
            : i < 10
              ? "International Sports"
              : "Documentary",
  logo: null,
  epgId: name,
  streamId: i,
  favorite: [0, 2, 6, 8].includes(i),
  lastWatched: i < 3 ? now - i * 1800 : null,
  now: {
    channelId: `demo-${i}`,
    title: titles[i],
    description:
      "A journey through remarkable landscapes, stories and the people who make them extraordinary.",
    start: hour,
    end: hour + 3600,
    category: "Documentary",
  },
  next: {
    channelId: `demo-${i}`,
    title: i === 0 ? "The Evening News" : "Coming up next",
    description: "",
    start: hour + 3600,
    end: hour + 7200,
    category: "",
  },
}));
const demoCountryDefinitions = [
  {
    code: "no",
    name: "Norway",
    groups: ["NO| Norway", "NO| Norway Entertainment"],
  },
  { code: "se", name: "Sweden", groups: ["SE| Sweden"] },
  { code: "gb", name: "United Kingdom", groups: ["UK| News"] },
  {
    code: "zz",
    name: "International & unassigned",
    groups: ["International Sports", "Documentary"],
  },
];
const previewCountryFavorites = new Set<string>(
  JSON.parse(
    localStorage.getItem("vektortv.preview.countryFavorites") || "[]",
  ) as string[],
);
function previewCountries(): Country[] {
  return demoCountryDefinitions
    .map((c) => ({
      ...c,
      groups: c.groups.map((name) => ({
        name,
        count: channels.filter((ch) => ch.group === name).length,
      })),
      count: channels.filter((ch) => c.groups.includes(ch.group)).length,
      favorite: previewCountryFavorites.has(c.code),
    }))
    .sort(
      (a, b) =>
        Number(b.favorite) - Number(a.favorite) ||
        Number(a.code === "zz") - Number(b.code === "zz") ||
        a.name.localeCompare(b.name),
    );
}
let demoPlayer: PlayerStatus = {
  state: "idle",
  channelId: null,
  volume: 80,
  width: 0,
  height: 0,
  decodedVideo: 0,
  decodedAudio: 0,
};
const previewInfo: AppInfo = {
  configured: true,
  connectionKind: "xtream",
  server: "Illustrative preview",
  source: "Illustrative preview",
  channelCount: channels.length,
  programmeCount: 48,
  channelsUpdated: now,
  guideUpdated: now,
  guideNeedsRefresh: false,
  playerAvailable: true,
  playerError: null,
  progress: { phase: "", active: false, message: "" },
  version: "0.6.1",
  platform: "preview",
  credentialStorage: "the operating system credential store",
};
function desktopRequired(): never {
  throw new Error(
    "Open the desktop app to connect your service. Browser previews do not access credentials or play IPTV streams.",
  );
}
export const api = {
  info: () =>
    native
      ? invoke<AppInfo>("app_info")
      : demo
        ? Promise.resolve(previewInfo)
        : Promise.resolve({
            ...previewInfo,
            configured: false,
            playerAvailable: false,
            channelCount: 0,
            programmeCount: 0,
            server: null,
            source: null,
          }),
  groups: () =>
    native
      ? invoke<Group[]>("list_groups")
      : Promise.resolve(
          demo
            ? [...new Set(channels.map((c) => c.group))].map((name) => ({
                name,
                count: channels.filter((c) => c.group === name).length,
              }))
            : [],
        ),
  countries: () =>
    native
      ? invoke<Country[]>("list_countries")
      : Promise.resolve(demo ? previewCountries() : []),
  favoriteCountry: async (code: string, favorite: boolean) => {
    if (native) return invoke<void>("set_country_favorite", { code, favorite });
    if (demo) {
      if (favorite) previewCountryFavorites.add(code);
      else previewCountryFavorites.delete(code);
      localStorage.setItem(
        "vektortv.preview.countryFavorites",
        JSON.stringify([...previewCountryFavorites]),
      );
    }
  },
  list: (query: Query) => {
    if (native) return invoke<ChannelPage>("list_channels", { query });
    const result = demo
      ? channels.filter(
          (c) =>
            c.name
              .toLocaleLowerCase()
              .includes(query.search.toLocaleLowerCase()) &&
            (!query.group || c.group === query.group) &&
            (!query.country ||
              demoCountryDefinitions
                .find((country) => country.code === query.country)
                ?.groups.includes(c.group)) &&
            (!query.favoritesOnly || c.favorite) &&
            (!query.historyOnly || c.lastWatched),
        )
      : [];
    if (query.alphabetical)
      result.sort(
        (a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id),
      );
    return Promise.resolve({
      channels: result.slice(query.offset, query.offset + query.limit),
      total: result.length,
      offset: query.offset,
    });
  },
  schedule: (channelId: string, from: number, until: number) => {
    if (native)
      return invoke<Programme[]>("get_schedule", { channelId, from, until });
    const channel = channels.find((c) => c.id === channelId);
    return Promise.resolve(
      channel
        ? [
            channel.now!,
            channel.next!,
            {
              ...channel.next!,
              title: "A Different Perspective",
              start: hour + 7200,
              end: hour + 10800,
            },
            {
              ...channel.next!,
              title: "Late Night Stories",
              start: hour + 10800,
              end: hour + 14400,
            },
          ].filter((p) => p.end > from && p.start < until)
        : [],
    );
  },
  schedules: async (
    channelIds: string[],
    from: number,
    until: number,
  ): Promise<Record<string, Programme[]>> => {
    if (native) return invoke("guide_schedules", { channelIds, from, until });
    return Object.fromEntries(
      await Promise.all(
        channelIds.map(async (id) => [id, await api.schedule(id, from, until)]),
      ),
    );
  },
  searchProgrammes: async (query: ProgrammeQuery): Promise<ProgrammePage> => {
    if (native) return invoke("search_programmes", { query });
    const fold = (text: string) =>
      text.normalize("NFD").replace(/\p{M}/gu, "").toLocaleLowerCase();
    const results = demo
      ? (
          await Promise.all(
            channels
              .filter(
                (c) =>
                  (!query.country ||
                    demoCountryDefinitions
                      .find((country) => country.code === query.country)
                      ?.groups.includes(c.group)) &&
                  (!query.group || c.group === query.group) &&
                  (!query.favoritesOnly || c.favorite),
              )
              .map(async (channel) =>
                (
                  await api.schedule(
                    channel.id,
                    query.from ?? 0,
                    query.until ?? Number.MAX_SAFE_INTEGER,
                  )
                )
                  .filter((p) =>
                    fold(query.search)
                      .split(/[^\p{L}\p{N}]+/u)
                      .filter(Boolean)
                      .every((term) =>
                        fold(`${p.title} ${p.description} ${p.category}`)
                          .split(/[^\p{L}\p{N}]+/u)
                          .some((word) => word.startsWith(term)),
                      ),
                  )
                  .map((programme) => ({ channel, programme })),
              ),
          )
        )
          .flat()
          .sort(
            (a, b) =>
              a.programme.start - b.programme.start ||
              a.channel.name.localeCompare(b.channel.name) ||
              a.channel.id.localeCompare(b.channel.id),
          )
      : [];
    return {
      results: results.slice(query.offset, query.offset + query.limit),
      total: results.length,
      offset: query.offset,
    };
  },
  favorite: async (channelId: string, favorite: boolean) => {
    if (native) return invoke<void>("set_favorite", { channelId, favorite });
    if (demo) {
      const c = channels.find((c) => c.id === channelId);
      if (c) c.favorite = favorite;
    }
  },
  save: (connection: Connection) =>
    native
      ? invoke<void>("save_connection", { connection })
      : desktopRequired(),
  disconnect: () => (native ? invoke<void>("disconnect") : desktopRequired()),
  sync: (guideOnly = false) =>
    native
      ? invoke<SyncProgress>("sync_library", { guideOnly })
      : demo
        ? Promise.resolve({
            phase: "complete",
            active: false,
            message: "Preview refreshed. These channels are illustrative.",
          })
        : desktopRequired(),
  play: async (channelId: string, requestId: number) => {
    if (native) return invoke<void>("play_channel", { channelId, requestId });
    if (demo) {
      demoPlayer = { ...demoPlayer, state: "preview", channelId };
    } else desktopRequired();
  },
  status: () =>
    native
      ? invoke<PlayerStatus>("player_status")
      : Promise.resolve({ ...demoPlayer }),
  action: async (action: string, value?: number, requestId?: number) => {
    if (native)
      return invoke<void>("player_action", { action, value, requestId });
    if (demo) {
      if (action === "stop")
        demoPlayer = { ...demoPlayer, state: "idle", channelId: null };
      else if (action === "volume") demoPlayer.volume = value ?? 80;
      else demoPlayer.state = action === "pause" ? "paused" : "preview";
    }
  },
  bounds: (bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
    visible: boolean;
  }) =>
    native ? invoke<void>("set_player_bounds", { bounds }) : Promise.resolve(),
};
