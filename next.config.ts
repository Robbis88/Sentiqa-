import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    serverActions: {
      // Regnskapsrapporter/Excel kan være flere MB (Azets-fila er ~1,2 MB),
      // og St1s forretningsplan er ~27 MB. Standard er 1 MB → hev for
      // opplasting via drop-zone. Vercel tar imot inntil 100 MB.
      bodySizeLimit: '50mb',
    },
  },
};

export default nextConfig;
