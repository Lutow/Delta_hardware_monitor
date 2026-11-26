<script lang="ts">
  import Disc3 from '@lucide/svelte/icons/disc-3';
  import Pause from '@lucide/svelte/icons/pause';
  import Play from '@lucide/svelte/icons/play';
  import SkipBack from '@lucide/svelte/icons/skip-back';
  import SkipForward from '@lucide/svelte/icons/skip-forward';
  import { onMount } from 'svelte';
  import { coverUrl, startNowPlayingPolling, type Track } from '../nowPlaying';

  let track = $state<Track | null>(null);
  // False while the PC's script doesn't answer.
  let reachable = $state(true);
  // The cover that failed to load, if any.
  let brokenCover = $state<string | null>(null);

  onMount(() =>
    startNowPlayingPolling({
      onTrack: (next) => {
        track = next;
        reachable = true;
      },
      onLost: () => {
        track = null;
        reachable = false;
      },
    }),
  );

  const title = $derived(track?.title ?? (reachable ? 'Nothing playing' : 'No music data'));
  const artist = $derived(
    track?.artist ?? (reachable ? 'Play something on Deezer' : 'Start now-playing.ps1 on the PC'),
  );
  const cover = $derived(
    track?.coverId && track.coverId !== brokenCover ? track.coverId : null,
  );
  const progress = $derived(
    track?.duration ? ((track.position ?? 0) / track.duration) * 100 : 0,
  );

  const time = (seconds: number | null | undefined) =>
    seconds == null
      ? '-:--'
      : `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
</script>

<div class="flex w-full flex-col gap-3">
  <div class="flex items-center gap-4">
    <div class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-white/10">
      {#if cover}
        <img
          src={coverUrl(cover)}
          alt=""
          class="size-full object-cover"
          onerror={() => (brokenCover = cover)}
        />
      {:else}
        <Disc3 class="size-8 text-white/70" aria-hidden="true" />
      {/if}
    </div>
    <!-- min-w-0 lets long names shorten instead of widening the panel -->
    <div class="min-w-0">
      <p class="truncate text-lg font-bold">{title}</p>
      <p class="truncate text-sm text-white/70">{artist}</p>
    </div>
  </div>

  <div class="flex flex-col gap-1">
    <div class="h-1 overflow-hidden rounded-full bg-white/15">
      <div class="h-full rounded-full bg-white" style:width="{progress}%"></div>
    </div>
    <div class="flex justify-between text-xs text-white/70 tabular-nums">
      <span>{time(track?.position)}</span>
      <span>{time(track?.duration)}</span>
    </div>
  </div>

  <!-- Decoration only: these aren't buttons. The middle one shows what pressing
       it would do: pause while a track plays, play otherwise. -->
  <div class="flex items-center justify-center gap-8" aria-hidden="true">
    <SkipBack class="size-6" />
    {#if track?.playing}
      <Pause class="size-7" />
    {:else}
      <Play class="size-7" />
    {/if}
    <SkipForward class="size-6" />
  </div>
</div>
