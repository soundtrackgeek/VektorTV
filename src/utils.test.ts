import { describe, it, expect } from "vitest";
import { timeline, progress, RequestSequence } from "./utils";
import type { Programme } from "./types";
const p: Programme = {
  channelId: "one",
  title: "Programme",
  description: "",
  start: 100,
  end: 200,
  category: "",
};
describe("programme boundaries", () => {
  it("clips events crossing either edge of the guide", () => {
    expect(timeline(p, 150, 250)).toEqual({ left: 0, width: 50 });
    expect(timeline(p, 0, 150)?.left).toBeCloseTo((100 * 2) / 3);
    expect(timeline(p, 0, 150)?.width).toBeCloseTo(100 / 3);
    expect(timeline(p, 200, 300)).toBeNull();
    expect(progress(p, 300)).toBe(100);
    expect(progress(p, 0)).toBe(0);
  });
});
describe("overlapping native responses", () => {
  it("rejects old responses after a new search, selection or navigation", () => {
    const sequence = new RequestSequence();
    const slow = sequence.next();
    const fast = sequence.next();
    expect(sequence.current(fast)).toBe(true);
    expect(sequence.current(slow)).toBe(false);
    sequence.next();
    expect(sequence.current(fast)).toBe(false);
  });
});
