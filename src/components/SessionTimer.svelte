<script lang="ts">
  import Timer from '@lucide/svelte/icons/timer';
  import { formatDuration } from '../duration';

  // A performance.now() value, or null while no data arrives from the PC.
  // This clock ignores changes to the date and time.
  let { startedAt }: { startedAt: number | null } = $props();

  let now = $state(performance.now());

  $effect(() => {
    if (startedAt === null) return;
    const tick = () => (now = performance.now());
    tick();
    // Read more than once a second, so a late tick can't skip a second.
    // The text only changes once a second.
    const interval = setInterval(tick, 250);
    return () => clearInterval(interval);
  });
</script>

<!-- The parent sets the text style -->
<div class="flex items-center gap-2 upright:flex-col upright:gap-1">
  <Timer class="size-7 text-white/70 upright:size-10" role="img" aria-label="Time since PC data started" />
  <span class="tabular-nums">
    {startedAt === null ? '--:--:--' : formatDuration(now - startedAt)}
  </span>
</div>
