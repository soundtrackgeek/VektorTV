import type { Channel, Query } from "./types";

/** Keep channel lookup order separate from network/player startup. */
export class ChannelNavigator {
  private scope: Query | null = null;
  private cursor: string | null = null;
  private generation = 0;
  private pending: Promise<unknown> = Promise.resolve();

  constructor(
    private resolve: (
      scope: Query,
      id: string,
      direction: number,
    ) => Promise<Channel | null>,
  ) {}

  get active() {
    return this.scope !== null;
  }

  begin(scope: Query, id: string) {
    this.clear();
    this.scope = { ...scope };
    this.cursor = id;
  }

  clear() {
    this.generation += 1;
    this.scope = null;
    this.cursor = null;
    this.pending = Promise.resolve();
  }

  next(direction: number): Promise<Channel | null> {
    const generation = this.generation;
    const request = this.pending
      .catch(() => {})
      .then(async () => {
        if (generation !== this.generation || !this.scope || !this.cursor)
          return null;
        const next = await this.resolve(this.scope, this.cursor, direction);
        if (generation !== this.generation) return null;
        if (next) this.cursor = next.id;
        return next;
      });
    this.pending = request;
    return request;
  }
}
