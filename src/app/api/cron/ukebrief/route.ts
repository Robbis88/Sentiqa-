import { NextResponse, type NextRequest } from 'next/server'
import { env } from '@/lib/env'
import { lagSupabaseAdminKlient } from '@/lib/supabase/admin'
import { forrigeUke } from '@/lib/ukebrief/bygg'
import { sendUkebriefForRetailer } from '@/lib/ukebrief/send'
import { iDag } from '@/lib/format'

// =====================================================================
// Ukebriefen ut, mandag morgen.
//
// EGEN RUTE, IKKE EN DEL AV NATTJOBBEN. Nattjobben kjoerer hver natt og
// har elleve ting som ikke skal velte hverandre; en utsending som blir
// dratt med der ville sendt brev syv dager i uken, eller blitt stille
// naar noe helt annet feilet. Denne kan dessuten kjoeres om igjen alene.
//
// IKKE SATT OPP I `vercel.json`. Ruta finnes og virker, men ingen plan
// utloeser den — det maa gjoeres bevisst, og av noen som har sett en
// toerrkjoering foerst. Se `?torrkjor=1`.
//
// TRYGG AA GJENTA. `forrigeUke` gir samme uke uansett hvilken dag i uken
// jobben kjoerer, og duplikatsperren i `ukebrief_utsending` kjenner igjen
// det som alt er sendt. En feilet kjoering fikses ved aa kjoere den om.
// =====================================================================

export const maxDuration = 300

export async function GET(req: NextRequest) {
  const auth = req.headers.get('authorization')
  if (!env.CRON_SECRET || auth !== `Bearer ${env.CRON_SECRET}`) {
    return NextResponse.json({ feil: 'uautorisert' }, { status: 401 })
  }

  const sok = req.nextUrl.searchParams
  const torrkjor = sok.get('torrkjor') === '1'
  // `?uke=` finnes for aa kunne sende en uke som ble hoppet over. Uten den
  // maatte en glemt uke sendes ved aa vente et aar.
  const uke = sok.get('uke') ?? forrigeUke(iDag())

  const admin = lagSupabaseAdminKlient()
  const { data: retailers, error } = await admin
    .from('retailers').select('id, navn').is('slettet_tid', null)
    .overrideTypes<{ id: string; navn: string }[]>()
  if (error) {
    return NextResponse.json({ feil: `kunne ikke lese kjeder: ${error.message}` }, { status: 500 })
  }

  const kjeder = []
  for (const r of retailers ?? []) {
    try {
      const stasjoner = await sendUkebriefForRetailer({
        admin, retailerId: r.id, ukeMandag: uke,
        basisUrl: env.UKEBRIEF_BASIS_URL, torrkjor,
      })
      kjeder.push({ kjede: r.navn, stasjoner })
    } catch (e) {
      // En kjede som feiler skal ikke stoppe de andre — men den skal
      // STAA I SVARET. En jobb som returnerer 200 og har droppet en hel
      // kjede ser ut som en jobb som gjorde alt den skulle.
      kjeder.push({ kjede: r.navn, feil: e instanceof Error ? e.message : String(e) })
    }
  }

  const sendt = kjeder.reduce((a, k) => a + (k.stasjoner ?? []).reduce((b, s) => b + s.sendt, 0), 0)
  const feilet = kjeder.reduce((a, k) => a + (k.stasjoner ?? []).reduce((b, s) => b + s.feilet, 0), 0)

  return NextResponse.json({ uke, torrkjor, sendt, feilet, kjeder })
}
