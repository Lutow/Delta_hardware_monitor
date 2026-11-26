import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import tailwindcss from '@tailwindcss/vite'

// LibreHardwareMonitor's web server, on its default port.
// Set LHM_URL to read from another address.
const lhmUrl = process.env.LHM_URL ?? 'http://192.168.0.5:8097'

// scripts/now-playing.ps1 on the PC. By default it only answers on the PC
// itself. Set MEDIA_URL to read from another address.
const mediaUrl = process.env.MEDIA_URL ?? 'http://127.0.0.1:8098'

// https://vite.dev/config/
export default defineConfig({
  plugins: [tailwindcss(), svelte()],
  server: {
    // Used by `npm run dev` and `npm run preview`
    proxy: {
      '/data.json': { target: lhmUrl, changeOrigin: true },
      '/media/': { target: mediaUrl, changeOrigin: true },
    },
  },
})
