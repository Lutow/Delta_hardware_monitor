<script lang="ts">
  import MonitorOff from '@lucide/svelte/icons/monitor-off';

  // Optional illustration from public/, e.g. "/waiting.svg".
  // The placeholder icon shows when it isn't set.
  let { image }: { image?: string } = $props();
</script>

<!-- Covers its parent, which needs `relative`. -->
<div class="absolute inset-0 flex items-center justify-center p-6">
  <div class="glass-block h-72 w-full max-w-md">
    <div
      class="glass-card flex h-full flex-col items-center justify-center gap-5 text-center"
      role="status"
    >
      <!-- Only opacity is animated, which is cheap enough for the Pi -->
      <div class="motion-safe:animate-pulse">
        {#if image}
          <img src={image} alt="" class="size-24 object-contain" />
        {:else}
          <MonitorOff class="size-24 text-white/70" strokeWidth={1.5} />
        {/if}
      </div>

      <div class="flex flex-col gap-1">
        <p class="text-2xl font-bold">Waiting for PC</p>
        <p class="text-sm text-white/70">No data received</p>
      </div>
    </div>
  </div>
</div>
