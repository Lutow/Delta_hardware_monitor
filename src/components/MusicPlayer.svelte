<script lang="ts">
  import Disc3 from '@lucide/svelte/icons/disc-3';
  import Pause from '@lucide/svelte/icons/pause';
  import Play from '@lucide/svelte/icons/play';
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

<div class="flex w-full flex-col gap-3 upright:gap-4">
  <div class="flex items-center gap-4 upright:gap-3">
    <div
      class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-white/10 upright:size-24"
    >
      {#if cover}
        <img
          src={coverUrl(cover)}
          alt=""
          class="size-full object-cover"
          onerror={() => (brokenCover = cover)}
        />
      {:else}
        <Disc3 class="size-8 text-white/70 upright:size-12" aria-hidden="true" />
      {/if}
    </div>
    <!-- min-w-0 lets long names shorten instead of widening the panel.
         In portrait the title can take two lines. -->
    <div class="min-w-0">
      <p
        class="truncate text-lg font-bold upright:line-clamp-2 upright:text-2xl upright:leading-7 upright:wrap-anywhere upright:whitespace-normal"
      >{title}</p>
      <p class="truncate text-sm text-white/70 upright:text-lg">{artist}</p>
    </div>
  </div>

  <div class="flex flex-col gap-1">
    <div class="h-1 overflow-hidden rounded-full bg-white/15 upright:h-2">
      <div class="h-full rounded-full bg-white" style:width="{progress}%"></div>
    </div>
    <div class="flex justify-between text-xs text-white/70 tabular-nums upright:text-lg">
      <span>{time(track?.position)}</span>
      <span>{time(track?.duration)}</span>
    </div>
  </div>

  <!-- Decoration only: these aren't buttons. The middle one shows what pressing
       it would do: pause while a track plays, play otherwise. -->
  <div class="flex items-center justify-center -mt-1 upright:-mt-4 mb-4" aria-hidden="true">
    {#if track?.playing}
      <Pause class="size-7 upright:size-11" />
    {:else}
      <Play class="size-7 upright:size-11" />
    {/if}
  </div>
</div>
