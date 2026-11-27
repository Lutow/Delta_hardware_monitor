<script lang="ts">
  import CloudSun from '@lucide/svelte/icons/cloud-sun';

  // Sample value until real weather is connected.
  const temperature = 18;
</script>

<!-- The parent sets the text style -->
<div class="flex items-center gap-2 upright:flex-col upright:gap-1">
  <CloudSun class="size-8 text-white/70 upright:size-10" role="img" aria-label="Weather" />
  <span class="tabular-nums">{temperature} °C</span>
</div>
