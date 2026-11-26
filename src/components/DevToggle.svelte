<script lang="ts">
  // Development helper: switches between the idle and active screens.
  let { active = $bindable() }: { active: boolean } = $props();
</script>

<!-- Fixed to the browser window, so it stays out of the dashboard layout -->
<button
  type="button"
  role="switch"
  aria-checked={active}
  aria-label="Show active state"
  onclick={() => (active = !active)}
  class="fixed right-4 bottom-4 z-50 flex cursor-pointer items-center gap-3 rounded-full border border-white/20 bg-neutral-900 px-4 py-2 font-mono text-xs text-white"
>
  <span class="text-white/50">DEV</span>
  <span
    class={['flex h-5 w-9 rounded-full p-0.5 transition-colors', active ? 'bg-emerald-500' : 'bg-neutral-600']}
  >
    <span class={['size-4 rounded-full bg-white transition-transform', active && 'translate-x-4']}></span>
  </span>
  <span class="w-12 text-left">{active ? 'Active' : 'Idle'}</span>
</button>
