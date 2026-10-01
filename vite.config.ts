import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    host: "127.0.0.1",
    port: 1437,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**", "**/target/**", "**/apps/apple/build/**"],
    },
  },
  envPrefix: ["VITE_"],
});
