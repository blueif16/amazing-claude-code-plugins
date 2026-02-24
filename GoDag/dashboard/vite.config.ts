import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      '/state.json': 'http://localhost:4567',
      '/log.jsonl': 'http://localhost:4567',
      '/fixtures': 'http://localhost:4567',
      '/runs': 'http://localhost:4567',
      '/stop': 'http://localhost:4567',
    },
  },
  build: { outDir: 'dist', emptyOutDir: true },
})
