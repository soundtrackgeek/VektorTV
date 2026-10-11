import { describe, expect, it } from "vitest";
import { ChannelNavigator } from "./channelNavigator";
import type { Channel, Query } from "./types";

const scope: Query = {
  search: "",
  group: "Norway",
  favoritesOnly: true,
  historyOnly: false,
  offset: 0,
  limit: 80,
};
const channel = (id: string) => ({ id }) as Channel;

describe("scoped channel navigation", () => {
  it("serializes rapid mixed inputs from the last requested channel and captures filters", async () => {
    const calls: Array<[string | null, string, number]> = [];
    const navigator = new ChannelNavigator(async (query, id, direction) => {
      calls.push([query.group, id, direction]);
      await Promise.resolve();
      return channel(String(Number(id) + direction));
    });
    const browsing = { ...scope };
    navigator.begin(browsing, "1");
    browsing.group = "Other";
    const results = await Promise.all([
      navigator.next(1),
      navigator.next(1),
      navigator.next(-1),
    ]);
    expect(results.map((result) => result?.id)).toEqual(["2", "3", "2"]);
    expect(calls).toEqual([
      ["Norway", "1", 1],
      ["Norway", "2", 1],
      ["Norway", "3", -1],
    ]);
  });

  it("discards pending lookups after Stop or a new channel selection", async () => {
    let complete!: (value: Channel) => void;
    const navigator = new ChannelNavigator(
      () =>
        new Promise((resolve) => {
          complete = resolve;
        }),
    );
    navigator.begin(scope, "1");
    const pending = navigator.next(1);
    await Promise.resolve();
    await Promise.resolve();
    navigator.clear();
    complete(channel("2"));
    expect(await pending).toBeNull();
    expect(await navigator.next(1)).toBeNull();
    navigator.begin(scope, "3");
    const replaced = navigator.next(1);
    await Promise.resolve();
    await Promise.resolve();
    navigator.begin({ ...scope, favoritesOnly: false }, "10");
    complete(channel("4"));
    expect(await replaced).toBeNull();
  });

  it("keeps its anchor after empty results and can retry a failed lookup", async () => {
    let attempts = 0;
    const navigator = new ChannelNavigator(async (_query, id) => {
      expect(id).toBe("1");
      attempts += 1;
      if (attempts === 1) throw new Error("Lookup failed");
      return attempts === 2 ? null : channel("2");
    });
    navigator.begin(scope, "1");
    await expect(navigator.next(1)).rejects.toThrow("Lookup failed");
    expect(await navigator.next(1)).toBeNull();
    expect((await navigator.next(1))?.id).toBe("2");
  });
});
