import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// The base path is configurable so the same build works on GitHub Pages
// (e.g. "/fundo-escola/") or at a domain root ("/").
// https://vite.dev/config/
export default defineConfig({
  base: process.env.VITE_BASE_PATH || "/",
  plugins: [vue()],
  server: { port: 5173 },
});
