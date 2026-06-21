import { sendHeartbeat } from "@/lib/kontrollrom";

/**
 * Heartbeat-cron (se vercel.json). Forteller kontrollrommet at Sentiqa lever.
 * Krever CRON_SECRET kun hvis den er satt — ellers åpen (heartbeat er ufarlig).
 */
export async function GET(request: Request) {
  if (process.env.CRON_SECRET) {
    const auth = request.headers.get("authorization");
    if (auth !== `Bearer ${process.env.CRON_SECRET}`) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  const ok = await sendHeartbeat();
  return Response.json({ ok });
}
