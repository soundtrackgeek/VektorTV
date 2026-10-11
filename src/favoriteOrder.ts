/** Move within the visible subset without replacing favorites outside it. */
export function moveInOrder(
  ids: string[],
  id: string,
  target: string,
): string[] {
  const from = ids.indexOf(id);
  const to = ids.indexOf(target);
  if (from < 0 || to < 0 || from === to) return ids;
  const next = [...ids];
  next.splice(from, 1);
  next.splice(to, 0, id);
  return next;
}

export function dropAnchor(ids: string[], id: string) {
  const index = ids.indexOf(id);
  if (index < 0 || ids.length < 2) return null;
  return index === 0
    ? { targetId: ids[1], before: true }
    : { targetId: ids[index - 1], before: false };
}
