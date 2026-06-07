import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    serverActions: {
      // Regnskapsrapporter/Excel kan være flere MB (Azets-fila er ~1,2 MB).
      // Standard er 1 MB → hev for opplasting via drop-zone.
      bodySizeLimit: '25mb',
    },
  },
};

export default nextConfig;
