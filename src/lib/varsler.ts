import 'server-only'
import type { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { sendPushForVarsel } from '@/lib/push'

type Klient = Awaited<ReturnType<typeof lagSupabaseServerKlient>>

export type NyttVarsel = {
  retailer_id: string
  type: string
  tittel: string
  tekst?: string | null
  lenke?: string | null
  mottaker_id?: string | null
  stasjon_id?: string | null
  /**
   * Hva varselet HANDLER OM — ikke hva det sier.
   *
   * «bemanning:<stasjon>:<maaned>:<slag>». Gis den, opprettes varselet
   * bare én gang per kjede (0201). Uten den oppfører funksjonen seg som
   * før: et nytt varsel hver gang.
   *
   * NØKKELEN KAN IKKE VÆRE TITTELEN. Titlene skrives ut av tallene, og
   * et tall som endrer seg litt mellom to importer ville gitt en ny
   * tittel og dermed et nytt varsel — og da var vi like langt.
   */
  noekkel?: string | null
}

/**
 * Oppretter et in-app-varsel.
 *
 * =====================================================================
 * INGEN NY RAD, INGEN NY PUSH
 * =====================================================================
 *
 * Før 0201 var dette en rett `insert`. Hver regnskapsimport laget derfor
 * bemanningsvarslene på nytt og sendte web-push om igjen — og en
 * re-import av et halvår ga femti–hundre varsler ingen hadde bedt om.
 *
 * Det verste er ikke bråket. Det er at de ekte varslene drukner: et
 * varselsystem man lærer seg å avfeie, er et varselsystem som ikke
 * finnes.
 *
 * Derfor er rekkefølgen viktig her: vi PUSHER BARE NÅR EN RAD FAKTISK
 * BLE OPPRETTET. `ignoreDuplicates` gjør at den andre importen skriver
 * ingenting, og `select` forteller oss om det skjedde. Uten den
 * kontrollen ville sperren stoppet varselet i appen og sluppet pushen
 * gjennom — den verste av alle utganger, siden telefonen da sier fra om
 * noe som ikke står noe sted.
 *
 * Skal aldri velte den utløsende handlingen → svelger feil.
 */
export async function opprettVarsel(supabase: Klient, v: NyttVarsel): Promise<void> {
  let opprettet = true
  try {
    const rad = {
      retailer_id: v.retailer_id,
      type: v.type,
      tittel: v.tittel,
      tekst: v.tekst ?? null,
      lenke: v.lenke ?? null,
      mottaker_id: v.mottaker_id ?? null,
      stasjon_id: v.stasjon_id ?? null,
      noekkel: v.noekkel ?? null,
    }

    if (v.noekkel) {
      // EN RAD INN, HOEYST EN RAD UT. Grensen er ikke et anslag: vi
      // skriver noeyaktig ett varsel, saa svaret er enten tomt eller ett.
      //
      // KOMMENTAREN STAAR OVER KJEDEN, IKKE INNI DEN. Grensevakten leser
      // `.from(...).select(...)` som EN kjede, og en kommentar midt i
      // bryter regexen - da teller spoerringen som en uten grense selv om
      // `.limit()` staar der. Samme felle tok en vakt i dette prosjektet
      // tidligere.
      const { data } = await supabase
        .from('varsler')
        .upsert(rad, { onConflict: 'retailer_id,noekkel', ignoreDuplicates: true })
        .select('id')
        .limit(1)
      // Tom liste = noekkelen fantes. Da er varselet allerede sett, og
      // muligens lukket - se begrunnelsen i 0201 for hvorfor et lukket
      // varsel ikke skal komme tilbake.
      opprettet = (data?.length ?? 0) > 0
    } else {
      await supabase.from('varsler').insert(rad)
    }
  } catch {
    // ignorert med vilje
  }

  if (!opprettet) return

  // Web-push i tillegg (best effort — hopper over hvis VAPID ikke er satt).
  try {
    await sendPushForVarsel(v)
  } catch {
    // ignorert med vilje
  }
}

/**
 * Nøkkelen for et varsel som hører til én stasjon og én periode.
 *
 * Samlet her og ikke skrevet på hvert kallsted: to nøkler som skal være
 * like driver fra hverandre, og da slutter sperren å virke uten at noe
 * blir rødt.
 */
export function varselnoekkel(opts: {
  slag: string
  stasjonId?: string | null
  periode?: string | null
  detalj?: string | null
}): string {
  return [opts.slag, opts.stasjonId ?? 'kjede', opts.periode ?? 'na', opts.detalj]
    .filter((x): x is string => Boolean(x))
    .join(':')
}
