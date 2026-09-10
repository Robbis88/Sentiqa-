import { NextResponse, type NextRequest } from 'next/server'
import { loggHendelse } from '@/lib/kontrollrom'

// Klient-feilgrensene (error.tsx / global-error.tsx) og 404-melderen
// (meld-404.tsx) POSTer hit. Ruten kjører server-side og videresender til
// kontrollrommet, så KONTROLLROM_KEY aldri havner i nettleseren.
//
// Offentlig endepunkt uten innlogging → alt under kommer fra nettleseren og må
// behandles som fiendtlig. Kontrollrommet deles med de andre produktene, og
// nøkkelen vår er det eneste som står mellom en klient og alarmene der inne.
// En feillogger som kan spammes er en forsterker, ikke et vern.
type Innkommende = {
  tittel?: string
  alvorlighet?: 'info' | 'warning' | 'critical'
  detaljer?: Record<string, unknown>
}

const TAK_PER_IP = 20
const VINDU_MS = 5 * 60 * 1000

// I minnet, altså per instans. Ikke vanntett på tvers av lambdaer, men stopper
// den realistiske flommen: én klient i loop mot én instans.
const teller = new Map<string, { antall: number; nullstilles: number }>()

function overGrense(ip: string): boolean {
  const naa = Date.now()
  const rad = teller.get(ip)
  if (!rad || naa > rad.nullstilles) {
    teller.set(ip, { antall: 1, nullstilles: naa + VINDU_MS })
    // Rydd utgåtte rader så kartet ikke vokser i det uendelige.
    if (teller.size > 5000) {
      for (const [k, v] of teller) if (naa > v.nullstilles) teller.delete(k)
    }
    return false
  }
  rad.antall += 1
  return rad.antall > TAK_PER_IP
}

function hentIp(req: NextRequest): string {
  return (
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    req.headers.get('x-real-ip') ||
    'ukjent'
  )
}

export async function POST(req: NextRequest) {
  // Over taket: slipp hendelsen stille. 429 hadde bare gitt feilgrensa en ny
  // feil å håndtere, og ruten lover å alltid svare ok.
  if (overGrense(hentIp(req))) {
    return NextResponse.json({ ok: true })
  }

  let body: Innkommende
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ feil: 'Ugyldig JSON' }, { status: 400 })
  }

  // En anonym klient skal ALDRI kunne heve alvorlighet til 'critical' — det
  // ville latt hvem som helst utløse kontrollrommets kritiske alarmer.
  const GYLDIGE = ['info', 'warning', 'critical']
  const paastatt = typeof body.alvorlighet === 'string' && GYLDIGE.includes(body.alvorlighet)
    ? body.alvorlighet
    : null
  const alvorlighet = paastatt === 'info' ? 'info' : 'warning'

  let detaljer: Record<string, unknown> =
    body.detaljer && typeof body.detaljer === 'object' ? body.detaljer : {}
  try {
    if (JSON.stringify(detaljer).length > 2000) {
      detaljer = { note: 'detaljer utelatt (for store)' }
    }
  } catch {
    detaljer = {}
  }

  // ==========================================================================
  // KLEMMEN SKAL IKKE SLETTE PÅSTANDEN
  //
  // `global-error.tsx` er rot-feilgrensa — den fyrer når HELE appen ikke
  // klarer å rendre — og den sender 'critical'. Klemmen over gjorde den om
  // til 'warning' uten spor, så den alvorligste hendelsen produktet kan
  // sende ble liggende i feeden på linje med en vanlig komponentfeil.
  //
  // Det er ikke klemmen som er feil. Det er tapet: en nedgradering ingen
  // ser er samme form som alt annet som har bitt oss her — noe som ser ut
  // som normal drift, og som derfor ikke blir sett på.
  //
  // MEN LES DENNE FØR DU KOBLER EN ALARM PÅ FELTET: `paastatt_alvorlighet`
  // kommer fra en uinnlogget klient og kan skrives av hvem som helst med
  // curl. Den er et HINT til den som leser feeden, ikke et grunnlag for
  // automatisk eskalering. Kobles den rett på en kritisk alarm, er
  // endepunktet nøyaktig den forsterkeren klemmen ble skrevet for å
  // hindre — bare med et ekstra ledd imellom.
  //
  // Settes ETTER størrelseskuttet: en påstand som forsvant fordi detaljene
  // var for store, ville vært det samme tapet en gang til.
  // ==========================================================================
  if (paastatt && paastatt !== alvorlighet) {
    detaljer = { ...detaljer, paastatt_alvorlighet: paastatt }
  }

  await loggHendelse({
    type: 'feil',
    alvorlighet,
    tittel: (body.tittel ?? 'Ukjent klientfeil').slice(0, 200),
    detaljer,
  })

  // Svar alltid ok – en feilende feil-logger skal aldri lage ny feil hos brukeren.
  return NextResponse.json({ ok: true })
}
