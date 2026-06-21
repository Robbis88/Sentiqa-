// ============================================================================
//  KONTROLLROM-KOBLING (R-G Invest)
//  Sender hendelser + heartbeat til kontrollrommet. Svelger alle feil med vilje
//  — logging skal ALDRI kunne dra ned Sentiqa.
//
//  .env: KONTROLLROM_URL, KONTROLLROM_KEY, KONTROLLROM_PRODUKT=sentiqa
// ============================================================================

type HendelseType = "support" | "onboarding" | "feil" | "system" | "lead";

export async function loggHendelse(h: {
  type: HendelseType;
  alvorlighet?: "info" | "warning" | "critical";
  tittel: string;
  detaljer?: Record<string, unknown>;
  bruker_ref?: string;
  ekstern_lenke?: string;
}): Promise<void> {
  const url = process.env.KONTROLLROM_URL;
  const key = process.env.KONTROLLROM_KEY;
  if (!url || !key) return;
  try {
    await fetch(`${url}/api/hendelse`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-api-key": key },
      body: JSON.stringify({
        produkt: process.env.KONTROLLROM_PRODUKT ?? "sentiqa",
        alvorlighet: "info",
        ...h,
      }),
    });
  } catch {
    // stille — kontrollrommet skal aldri kunne velte produktet
  }
}

export async function sendHeartbeat(): Promise<boolean> {
  const url = process.env.KONTROLLROM_URL;
  const key = process.env.KONTROLLROM_KEY;
  if (!url || !key) return false;
  try {
    const res = await fetch(
      `${url}/api/heartbeat?produkt=${process.env.KONTROLLROM_PRODUKT ?? "sentiqa"}`,
      { method: "POST", headers: { "x-api-key": key } },
    );
    return res.ok;
  } catch {
    return false;
  }
}
