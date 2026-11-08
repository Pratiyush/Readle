import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Relative base so the build works from any sub-path (GitHub Pages, a file share…).
export default defineConfig({
  base: "./",
  plugins: [react()],
  test: { environment: "jsdom", globals: true, setupFiles: ["src/test-setup.ts"], include: ["src/**/*.test.ts"] },
});
