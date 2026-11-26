<script lang="ts">
  // Development helper: an on/off switch for previewing the dashboard's states.
  let {
    active = $bindable(),
    label,
    onText,
    offText,
  }: { active: boolean; label: string; onText: string; offText: string } = $props();
</script>

<!-- The parent positions it -->
<button
  type="button"
  role="switch"
  aria-checked={active}
  aria-label={label}
  onclick={() => (active = !active)}
  class="flex cursor-pointer items-center gap-3 rounded-full border border-white/20 bg-neutral-900 px-4 py-2 font-mono text-xs text-white"
>
  <span class="text-white/50">DEV</span>
  <span
    class={['flex h-5 w-9 rounded-full p-0.5 transition-colors', active ? 'bg-emerald-500' : 'bg-neutral-600']}
  >
    <span class={['size-4 rounded-full bg-white transition-transform', active && 'translate-x-4']}></span>
  </span>
  <span class="w-18 text-left">{active ? onText : offText}</span>
</button>
