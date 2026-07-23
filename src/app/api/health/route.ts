import { NextResponse, type NextRequest } from "next/server";
import { lagSupabaseAdminKlient } from "@/lib/supabase/admin";

// Health-sjekk må ALDRI prerendes/caches — i Next 16 kan en GET-route bli
// prerendret ved build om den ikke rører runtime-data. force-dynamic + no-store
// garanterer at hvert kall faktisk treffer databasen på nytt.
export const dynamic = "force-dynamic";
export const revalidate = 0;

/**
 * Helse-endepunkt for ekstern overvåking (Better Stack, se kontrollrommets
 * PROSJEKT_driftsovervaking.md).
 *
 *   GET /api/health           → rask sjekk: database + prosess (hvert 60. s)
 *   GET /api/health?deep=1     → i tillegg ekte ping mot eksterne API-er (~hvert 5. min)
 *
 * Kontrakt:
 *   200 + { ok: true,  status: "healthy"   }  alt friskt
 *   200 + { ok: true,  status: "degraded"  }  DB oppe, en ekstern avhengighet nede
 *   503 + { ok: false, status: "unhealthy" }  DB nede — tjenesten er reelt ute
 *
 * Kun databasen er kritisk for oppe/nede. Eksterne degraderer, men feller ikke
 * tjenesten. Lekker aldri nøkler — kun ja/nei + latens per avhengighet.
 */

type Sjekk = { ok: boolean; latency_ms?: number; error?: string };

const TIMEOUT_MS = 2500;

async function pingHttp(
  url: string,
  headers: Record<string, string>,
): Promise<Sjekk> {
  const start = Date.now();
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      headers,
      signal: ctrl.signal,
      cache: "no-store",
    });
    return {
      ok: res.ok,
      latency_ms: Date.now() - start,
      error: res.ok ? undefined : `HTTP ${res.status}`,
    };
  } catch (e) {
    return {
      ok: false,
      latency_ms: Date.now() - start,
      error: e instanceof Error ? e.message : "ukjent",
    };
  } finally {
    clearTimeout(t);
  }
}

async function sjekkDatabase(): Promise<Sjekk> {
  const start = Date.now();
  try {
    const sb = lagSupabaseAdminKlient();
    const { error } = await sb
      .from("ansatte")
      .select("id", { count: "exact", head: true })
      .limit(1);
    return { ok: !error, latency_ms: Date.now() - start, error: error?.message };
  } catch (e) {
    return {
      ok: false,
      latency_ms: Date.now() - start,
      error: e instanceof Error ? e.message : "ukjent",
    };
  }
}

export async function GET(req: NextRequest) {
  const start = Date.now();
  const deep = req.nextUrl.searchParams.get("deep") === "1";
  const checks: Record<string, Sjekk> = {};

  checks.database = await sjekkDatabase();

  if (deep) {
    const eksterne: Promise<[string, Sjekk]>[] = [];
    if (process.env.ANTHROPIC_API_KEY) {
      eksterne.push(
        pingHttp("https://api.anthropic.com/v1/models", {
          "x-api-key": process.env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        }).then((s) => ["anthropic", s]),
      );
    }
    for (const [navn, sjekk] of await Promise.all(eksterne)) checks[navn] = sjekk;
  }

  const kritiskOk = checks.database.ok;
  const alleOk = Object.values(checks).every((c) => c.ok);
  const status = !kritiskOk ? "unhealthy" : alleOk ? "healthy" : "degraded";

  return NextResponse.json(
    {
      ok: kritiskOk,
      status,
      product: "sentiqa",
      version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev",
      timestamp: new Date().toISOString(),
      latency_ms: Date.now() - start,
      checks,
    },
    {
      status: kritiskOk ? 200 : 503,
      headers: { "Cache-Control": "no-store" },
    },
  );
}
