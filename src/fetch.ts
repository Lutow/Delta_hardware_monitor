// Reads sensor data from LibreHardwareMonitor's web server.
//
// The page requests its own server at /data.json, which forwards the request to
// LibreHardwareMonitor on port 8085: Vite does this during development (see
// vite.config.ts), and the relay does it on the Pi.

const DATA_URL = '/data.json';

type SensorQuery = {
  /** Start of the SensorId, which identifies the hardware. */
  hardware: string;
  type: 'Temperature' | 'Load' | 'Power';
  /** Accepted sensor names, in order of preference. */
  names: string[];
};

// Which sensor feeds each value. Edit this if your hardware changes.
const SENSORS = {
  cpuTemp: {
    hardware: '/amdcpu/0/',
    type: 'Temperature',
    names: ['Core (Tctl/Tdie)', 'Core (Tdie)', 'Core (Tctl)'],
  },
  cpuLoad: { hardware: '/amdcpu/0/', type: 'Load', names: ['CPU Total'] },
  cpuPower: { hardware: '/amdcpu/0/', type: 'Power', names: ['Package'] },
  gpuTemp: { hardware: '/gpu-amd/', type: 'Temperature', names: ['GPU Core'] },
  gpuLoad: { hardware: '/gpu-amd/', type: 'Load', names: ['GPU Core'] },
  gpuPower: { hardware: '/gpu-amd/', type: 'Power', names: ['GPU Package'] },
  // Virtual memory (/vram/) also has a load sensor called "Memory".
  ramLoad: { hardware: '/ram/', type: 'Load', names: ['Memory'] },
} satisfies Record<string, SensorQuery>;

export type SensorKey = keyof typeof SENSORS;

/** One value per sensor, or null when it isn't available. */
export type Readings = Record<SensorKey, number | null>;

const sensorKeys = Object.keys(SENSORS) as SensorKey[];

export const emptyReadings = (): Readings =>
  Object.fromEntries(sensorKeys.map((key) => [key, null])) as Readings;

/** A node of the data.json tree. Only sensor nodes have an id and a type. */
type LhmNode = {
  Text?: string;
  SensorId?: string;
  Type?: string;
  Value?: string;
  RawValue?: number | string | null;
  Children?: LhmNode[];
};

function collectSensors(node: LhmNode, found: LhmNode[] = []): LhmNode[] {
  if (node.SensorId) found.push(node);
  for (const child of node.Children ?? []) collectSensors(child, found);
  return found;
}

// Prefer the raw number. The text values follow the PC's regional settings,
// so they can look like "45,2 °C", and "-" means there is no value.
function toNumber(sensor: LhmNode): number | null {
  const value = sensor.RawValue ?? sensor.Value;
  const number =
    typeof value === 'number' ? value : parseFloat(String(value).replace(',', '.'));
  return Number.isFinite(number) ? number : null;
}

export function parseReadings(root: LhmNode): Readings {
  const sensors = collectSensors(root);
  const readings = emptyReadings();

  for (const key of sensorKeys) {
    const { hardware, type, names }: SensorQuery = SENSORS[key];
    const candidates = sensors.filter(
      (s) => s.Type === type && s.SensorId?.startsWith(hardware),
    );
    const match = names
      .map((name) => candidates.find((s) => s.Text === name))
      .find((s) => s !== undefined);
    if (match) readings[key] = toNumber(match);
  }

  return readings;
}

async function fetchReadings(timeoutMs: number): Promise<Readings> {
  const response = await fetch(DATA_URL, {
    cache: 'no-store',
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) throw new Error(`HTTP ${response.status} from ${DATA_URL}`);

  const readings = parseReadings(await response.json());
  if (sensorKeys.every((key) => readings[key] === null)) {
    throw new Error('No matching sensors in data.json: check SENSORS in fetch.ts');
  }
  return readings;
}

type PollingOptions = {
  /** Called after each successful request. */
  onData: (readings: Readings) => void;
  /** Called once `maxFailures` requests in a row have failed. */
  onLost: () => void;
  intervalMs?: number;
  timeoutMs?: number;
  maxFailures?: number;
};

/** Requests new data until the returned function is called. */
export function startPolling({
  onData,
  onLost,
  intervalMs = 1000,
  timeoutMs = 2000,
  maxFailures = 3,
}: PollingOptions): () => void {
  let failures = 0;
  let stopped = false;
  let timer: ReturnType<typeof setTimeout> | undefined;

  // The next request is scheduled after this one ends, so they never overlap.
  async function poll() {
    try {
      const readings = await fetchReadings(timeoutMs);
      if (stopped) return;
      failures = 0;
      onData(readings);
    } catch (error) {
      if (stopped) return;
      failures += 1;
      // Logged once per outage, to avoid filling the console.
      if (failures === maxFailures) {
        console.warn('No data from the PC:', error);
        onLost();
      }
    }
    timer = setTimeout(poll, intervalMs);
  }

  poll();

  return () => {
    stopped = true;
    clearTimeout(timer);
  };
}
