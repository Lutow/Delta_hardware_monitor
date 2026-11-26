import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'

// LibreHardwareMonitor's web server, on its default port.
// Set LHM_URL to read from another address.
const lhmUrl = process.env.LHM_URL ?? 'http://localhost:8085'

// https://vite.dev/config/
export default defineConfig({
  plugins: [tailwindcss(), svelte()],
  server: {
    // Used by `npm run dev` and `npm run preview`
    proxy: { '/data.json': { target: lhmUrl, changeOrigin: true } },
  },
})
