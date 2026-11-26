// Reads what is playing on the PC from scripts/now-playing.ps1.
//
// Like the sensor data, it goes through the page's own server: Vite forwards
// /media to the PC during development (see vite.config.ts), and the relay does
// it on the Pi.

const NOW_PLAYING_URL = '/media/now-playing.json';

export type Track = {
  title: string;
  artist: string;
  playing: boolean;
  /** Seconds. Both are null when the app doesn't report the track's length. */
  position: number | null;
  duration: number | null;
  /** Changes with the cover picture. null when there is no cover. */
  coverId: string | null;
};

export const coverUrl = (coverId: string) => `/media/cover?id=${encodeURIComponent(coverId)}`;

async function fetchTrack(timeoutMs: number): Promise<Track | null> {
  const response = await fetch(NOW_PLAYING_URL, {
    cache: 'no-store',
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${NOW_PLAYING_URL}`);

  const { track }: { track?: Track | null } = await response.json();
  if (track === undefined) throw new Error(`Unexpected answer from ${NOW_PLAYING_URL}`);
  return track;
}

type PollingOptions = {
  /** Called after each successful request. null means nothing is playing. */
  onTrack: (track: Track | null) => void;
  /** Called once `maxFailures` requests in a row have failed. */
  onLost: () => void;
  intervalMs?: number;
  /** Delay between requests while the PC's script doesn't answer. */
  retryMs?: number;
  timeoutMs?: number;
  maxFailures?: number;
};

/** Requests the current track until the returned function is called. */
export function startNowPlayingPolling({
  onTrack,
  onLost,
  intervalMs = 1000,
  retryMs = 5000,
  timeoutMs = 3000,
  maxFailures = 3,
}: PollingOptions): () => void {
  let failures = 0;
  let stopped = false;
  let timer: ReturnType<typeof setTimeout> | undefined;

  // The next request is scheduled after this one ends, so they never overlap.
  async function poll() {
    try {
      const track = await fetchTrack(timeoutMs);
      if (stopped) return;
      failures = 0;
      onTrack(track);
    } catch (error) {
      if (stopped) return;
      failures += 1;
      // Logged once per outage, to avoid filling the console.
      if (failures === maxFailures) {
        console.warn('No music data from the PC:', error);
        onLost();
      }
    }
    timer = setTimeout(poll, failures < maxFailures ? intervalMs : retryMs);
  }

  poll();

  return () => {
    stopped = true;
    clearTimeout(timer);
  };
}
