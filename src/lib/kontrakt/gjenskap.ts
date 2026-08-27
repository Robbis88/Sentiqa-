// =====================================================================
// Hent fram igjen en kontrakt som er skrevet.
//
// Dokumentet lagres ikke som fil. Det trengs ikke: `ansatt_kontrakt`
// bærer både verdiene som ble fylt inn og hvilken malversjon de ble fylt
// inn i, og utfyllingen er deterministisk. Samme mal + samme verdier gir
// samme dokument, hver gang.
//
// Det var hele grunnen til å lagre dem. En kopi av fila i tillegg ville
// vært en andre sannhet å holde i synk — og den dagen de to spriker, vet
// ingen hvilken hun faktisk signerte.
//
// Forutsetningen er at malversjoner aldri overskrives. Det er de ikke:
// en ny opplasting blir en ny rad, og den gamle blir stående med
// aktiv = false.
// =====================================================================

import type { SupabaseClient } from '@supabase/supabase-js'
import { fyllUt } from './docx'

export type Gjenskapt =
  | { ok: true; docx: Uint8Array; navn: string; ansattNavn: string; stasjonId: string }
  | { ok: false; feil: string; status: number }

type Rad = {
  ansatt_navn: string
  // Stasjonen foelger med fordi TILGANGSLOGGEN trenger den. En
  // logglinje uten stasjon kan ikke tilskrives noen butikksjefs
  // ansvarsomraade, og faller da til eieren alene (0148).
  stasjon_id: string
  verdier: Record<string, string>
  mal_versjon: number | null
  kontraktmal: { storage_sti: string; ansettelsesform: string } | null
}

/**
 * Bygger dokumentet på nytt fra det som er lagret.
 *
 * RLS avgjør om raden er synlig — treffer oppslaget ingenting, har
 * brukeren ikke tilgang, og da er 404 riktigere enn 403.
 */
export async function gjenskapKontrakt(
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  supabase: SupabaseClient<any, any, any>,
  id: string,
): Promise<Gjenskapt> {
  const { data } = await supabase
    .from('ansatt_kontrakt')
    .select('ansatt_navn, stasjon_id, verdier, mal_versjon, kontraktmal(storage_sti, ansettelsesform)')
    .eq('id', id)
    .maybeSingle()
  const rad = data as Rad | null
  if (!rad) return { ok: false, feil: 'Fant ikke kontrakten.', status: 404 }

  if (!rad.kontraktmal) {
    return {
      ok: false,
      status: 410,
      feil: 'Malen denne kontrakten ble skrevet fra er slettet. '
        + 'Dokumentet kan ikke gjenskapes — bare verdiene står igjen.',
    }
  }

  const ned = await supabase.storage.from('raa-filer').download(rad.kontraktmal.storage_sti)
  if (ned.error || !ned.data) {
    return { ok: false, feil: 'Fant ikke malfila i Storage.', status: 404 }
  }

  const docx = fyllUt(new Uint8Array(await ned.data.arrayBuffer()), rad.verdier ?? {})
  const rent = rad.ansatt_navn.replace(/[^\wÆØÅæøå -]/g, '')
  return {
    ok: true,
    docx,
    ansattNavn: rad.ansatt_navn,
    stasjonId: rad.stasjon_id,
    navn: `${rent} - ${rad.kontraktmal.ansettelsesform}.docx`,
  }
}
