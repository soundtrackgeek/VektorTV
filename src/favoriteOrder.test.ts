import { describe, expect, it } from "vitest";
import { dropAnchor, moveInOrder } from "./favoriteOrder";

describe("favorite drop positions", () => {
  it("moves in either direction and derives a neighboring saved anchor", () => {
    const order = ["a", "b", "c", "d"];
    const down = moveInOrder(order, "a", "c");
    expect(down).toEqual(["b", "c", "a", "d"]);
    expect(dropAnchor(down, "a")).toEqual({ targetId: "c", before: false });
    const up = moveInOrder(down, "d", "b");
    expect(up).toEqual(["d", "b", "c", "a"]);
    expect(dropAnchor(up, "d")).toEqual({ targetId: "b", before: true });
    expect(order).toEqual(["a", "b", "c", "d"]);
  });
  it("ignores missing channels and handles a single favorite", () => {
    expect(moveInOrder(["a"], "gone", "a")).toEqual(["a"]);
    expect(dropAnchor(["a"], "a")).toBeNull();
  });
});
