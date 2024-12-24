// vite.config.js
import { vitePlugin as remix } from '@remix-run/dev';
import { defineConfig } from 'vite';
import { flatRoutes } from 'remix-flat-routes';
import { remixDevTools } from 'remix-development-tools';
import tsconfigPaths from 'vite-tsconfig-paths';
import path from 'path';

export default defineConfig({
  build: {
    target: 'ES2022',
    rollupOptions: {
      external: ['@prisma/client'], // Exclude Prisma Client
    },
  },
  optimizeDeps: {
    exclude: ['@prisma/client'], // Prevent Vite from pre-bundling Prisma Client
  },
  plugins: [
    remixDevTools(),
    remix({
      serverModuleFormat: 'esm',
      ignoredRouteFiles: ['**/.*'],
      routes: async (defineRoutes) => {
        return flatRoutes('routes', defineRoutes);
      },
    }),
    tsconfigPaths(),
  ],
  resolve: {
    alias: {
      '@server': path.resolve(__dirname, 'src/api'), // Optional: Server-side alias
    },
  },
});
