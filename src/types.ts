export interface Programme {
  channelId: string;
  title: string;
  description: string;
  start: number;
  end: number;
  category: string;
}
export interface Channel {
  id: string;
  name: string;
  group: string;
  logo: string | null;
  epgId: string;
  streamId: number | null;
  favorite: boolean;
  lastWatched: number | null;
  now: Programme | null;
  next: Programme | null;
}
export interface ChannelPage {
  channels: Channel[];
  total: number;
  offset: number;
}
export interface Group {
  name: string;
  count: number;
}
export interface Country {
  code: string;
  name: string;
  count: number;
  groups: Group[];
  favorite: boolean;
}
export interface Query {
  country?: string | null;
  alphabetical?: boolean;
  search: string;
  group: string | null;
  favoritesOnly: boolean;
  historyOnly: boolean;
  offset: number;
  limit: number;
}
export interface SyncProgress {
  phase: string;
  active: boolean;
  message: string;
}
export interface AppInfo {
  configured: boolean;
  connectionKind: string | null;
  server: string | null;
  source: string | null;
  channelCount: number;
  programmeCount: number;
  channelsUpdated: number | null;
  guideUpdated: number | null;
  guideNeedsRefresh: boolean;
  playerAvailable: boolean;
  playerError: string | null;
  progress: SyncProgress;
  version: string;
  platform: string;
  credentialStorage: string;
}
export interface PlayerStatus {
  state: string;
  channelId: string | null;
  volume: number;
  width: number;
  height: number;
  decodedVideo: number;
  decodedAudio: number;
}
export interface Connection {
  kind: string;
  baseUrl: string;
  username: string;
  password: string;
  playlistUrl: string;
  epgUrl: string;
}
export type View =
  | "countries"
  | "live"
  | "guide"
  | "favorites"
  | "history"
  | "settings";

export interface ProgrammeQuery {
  search: string;
  country: string | null;
  group: string | null;
  favoritesOnly: boolean;
  from: number | null;
  until: number | null;
  offset: number;
  limit: number;
}
export interface ProgrammeMatch {
  channel: Channel;
  programme: Programme;
}
export interface ProgrammePage {
  results: ProgrammeMatch[];
  total: number;
  offset: number;
}
