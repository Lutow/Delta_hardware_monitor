<script lang="ts">
  import ChartColumn from '@lucide/svelte/icons/chart-column';
  import MemoryStick from '@lucide/svelte/icons/memory-stick';
  import Thermometer from '@lucide/svelte/icons/thermometer';
  import Zap from '@lucide/svelte/icons/zap';
  import { onMount } from 'svelte';
  import DevToggle from './components/DevToggle.svelte';
  import WaitingState from './components/WaitingState.svelte';
  import { emptyReadings, startPolling } from './fetch';

  let readings = $state(emptyReadings());
  // True while data is arriving from the PC.
  let connected = $state(false);
  // Set by the DEV switch to force a screen. null follows the connection.
  let preview = $state<boolean | null>(null);
  const hasData = $derived(preview ?? connected);

  // Returning the stop function ends polling when the component is removed.
  onMount(() =>
    startPolling({
      onData: (data) => {
        readings = data;
        connected = true;
      },
      onLost: () => {
        readings = emptyReadings();
        connected = false;
      },
    }),
  );

  // Switching back to the real state hands control to the connection again.
  const setPreview = (active: boolean) => {
    preview = active === connected ? null : active;
  };

  const format = (value: number | null) => (value === null ? '--' : Math.round(value));

  type Area = { col: number; row: number; colSpan: number; rowSpan: number };

  // Position and size of every block. col and row start at 1.
  const layout = {
    cpu: { col: 1, row: 1, colSpan: 4, rowSpan: 4 },
    ram: { col: 5, row: 1, colSpan: 4, rowSpan: 4 },
    gpu: { col: 9, row: 1, colSpan: 4, rowSpan: 4 },
    panel: { col: 1, row: 5, colSpan: 7, rowSpan: 9 },
    panel2: { col: 8, row: 5, colSpan: 5, rowSpan: 9 },
  } satisfies Record<string, Area>;

  const place = ({ col, row, colSpan, rowSpan }: Area) =>
    `grid-area: ${row} / ${col} / span ${rowSpan} / span ${colSpan};`;
</script>

<!--
  Dashboard grid: 12 columns, rows of 2rem (32px), 12px gaps.
  Place and size blocks in the `layout` object above, not with classes.
  Blocks don't push each other aside, so check for overlaps after a change.
-->
<main
  class="relative isolate grid h-150 w-256 grid-cols-12 auto-rows-8 content-start gap-3 overflow-hidden bg-black bg-cover bg-center p-6 text-white"
>
  {#if hasData}
    <!-- CPU -->
    <div class="glass-block" style={place(layout.cpu)}>
      <div class="glass-card flex h-full flex-col items-center justify-center gap-5">
        <div class="flex flex-row justify-between items-center">
          <svg class="w-20 h-12 mr-3.5" fill="white" viewBox="0 9.137 24 5.677"xmlns="http://www.w3.org/2000/svg" role="img"><title>AMD icon</title><path d="M18.324 9.137l1.559 1.56h2.556v2.557L24 14.814V9.137zM2 9.52l-2 4.96h1.309l.37-.982H3.9l.408.982h1.338L3.432 9.52zm4.209 0v4.955h1.238v-3.092l1.338 1.562h.188l1.338-1.556v3.091h1.238V9.52H10.47l-1.592 1.845L7.287 9.52zm6.283 0v4.96h2.057c1.979 0 2.88-1.046 2.88-2.472 0-1.36-.937-2.488-2.747-2.488zm1.237.91h.792c1.17 0 1.63.711 1.63 1.57 0 .728-.372 1.572-1.616 1.572h-.806zm-10.985.273l.791 1.932H2.008zm17.137.307l-1.604 1.603v2.25h2.246l1.604-1.607h-2.246z"/></svg>
          <div class="text-2xl font-bold">CPU</div>
        </div>

        <div class="flex w-full flex-row justify-around">
          <div class="flex flex-col items-center gap-1">
            <Thermometer class="w-6 h-6 text-white/70" role="img" aria-label="Temperature" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.cpuTemp)} °C</span>
          </div>
          <div class="flex flex-col items-center gap-1">
            <ChartColumn class="w-6 h-6 text-white/70" role="img" aria-label="Usage" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.cpuLoad)} %</span>
          </div>
          <div class="flex flex-col items-center gap-1">
            <Zap class="w-6 h-6 text-white/70" role="img" aria-label="Power draw" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.cpuPower)} W</span>
          </div>
        </div>
      </div>
    </div>

    <!-- RAM -->
    <div class="glass-block" style={place(layout.ram)}>
      <div class="glass-card flex h-full flex-col items-center justify-center gap-5">
        <div class="flex flex-row justify-between items-center">
          <MemoryStick class="w-12 h-12 mr-4" />
          <div class="text-2xl font-bold">RAM</div>
        </div>

        <div class="flex w-full flex-row justify-around">
          <div class="flex flex-col items-center gap-1">
            <ChartColumn class="w-6 h-6 text-white/70" role="img" aria-label="Usage" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.ramLoad)} %</span>
          </div>
        </div>
      </div>
    </div>

    <!-- GPU -->
    <div class="glass-block" style={place(layout.gpu)}>
      <div class="glass-card flex h-full flex-col items-center justify-center gap-5">
        <div class="flex flex-row justify-between items-center">
          <img src="/ASrock.svg" alt="ASrock" class="w-30 h-12 -ml-3.5" />
          <div class="text-2xl font-bold">GPU</div>
        </div>

        <div class="flex w-full flex-row justify-around">
          <div class="flex flex-col items-center gap-1">
            <Thermometer class="w-6 h-6 text-white/70" role="img" aria-label="Temperature" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.gpuTemp)} °C</span>
          </div>
          <div class="flex flex-col items-center gap-1">
            <ChartColumn class="w-6 h-6 text-white/70" role="img" aria-label="Usage" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.gpuLoad)} %</span>
          </div>
          <div class="flex flex-col items-center gap-1">
            <Zap class="w-6 h-6 text-white/70" role="img" aria-label="Power draw" />
            <span class="text-sm font-semibold tabular-nums">{format(readings.gpuPower)} W</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Bottom panels -->
    <div class="glass-block" style={place(layout.panel)}>
      <div class="glass-card flex h-full flex-col items-center justify-center gap-5"></div>
    </div>
    <div class="glass-block" style={place(layout.panel2)}>
      <!-- Two equal-height rows. Vertical padding or gaps would shift their centres. -->
      <div class="glass-card grid h-full grid-rows-2 px-5">
        <!-- Row 1: two items, pushed to opposite sides -->
        <div class="flex flex-row items-center justify-between">
          <div class="text-2xl font-bold">Panel 2</div>
          <div class="text-2xl font-bold">Panel 2</div>
        </div>

        <!-- Row 2: one block filling its whole half -->
        <div class="flex flex-col items-center justify-center">
          <div class="text-2xl font-bold">Panel 2</div>
        </div>
      </div>
    </div>
  {:else}
    <WaitingState />
  {/if}
</main>

<!-- Vite removes this from production builds -->
{#if import.meta.env.DEV}
  <DevToggle bind:active={() => hasData, setPreview} />
{/if}
