import type { Programme } from "./types";

export const time = (timestamp: number) =>
  new Date(timestamp * 1000).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
export const progress = (programme: Programme, now: number) =>
  Math.max(
    0,
    Math.min(
      100,
      ((now - programme.start) / Math.max(1, programme.end - programme.start)) *
        100,
    ),
  );
export const errorText = (error: unknown) =>
  typeof error === "string"
    ? error
    : error instanceof Error
      ? error.message
      : "Something went wrong. Please try again.";
export function timeline(programme: Programme, start: number, end: number) {
  if (end <= start || programme.end <= start || programme.start >= end)
    return null;
  const left = Math.max(start, programme.start);
  const right = Math.min(end, programme.end);
  return {
    left: ((left - start) / (end - start)) * 100,
    width: ((right - left) / (end - start)) * 100,
  };
}
export class RequestSequence {
  private version = 0;
  next() {
    return ++this.version;
  }
  current(version: number) {
    return version === this.version;
  }
}
