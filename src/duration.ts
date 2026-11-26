/** Formats a duration as HH:MM:SS. Hours keep counting past 24. */
export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  return [Math.floor(total / 3600), Math.floor(total / 60) % 60, total % 60]
    .map((part) => String(part).padStart(2, '0'))
    .join(':');
}
