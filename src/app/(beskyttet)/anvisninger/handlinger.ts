'use server'
import type { SlettTilstand } from '@/components/ui/slett-knapp'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { maaLykkes } from '@/lib/skriv-svar'
import { finnDuplikat, lagFilsti, lesStikkord, sjekkFil } from '@/lib/anvisningssok'
import { kvitter, type Kvittering } from '@/lib/kvittering'

export async function leggTilAnvisning(formData: FormData) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) return
  const kategori = String(formData.get('kategori') ?? '').trim() || 'Generelt'
  const tittel = String(formData.get('tittel') ?? '').trim()
  const innhold = String(formData.get('innhold') ?? '').trim()
  if (!tittel || !innhold) return
  const supabase = await lagSupabaseServerKlient()
  maaLykkes(await supabase.from('anvisninger').insert({ retailer_id: bruker.retailerId, kategori, tittel, innhold, opprettet_av: bruker.id }), 'opprette anvisninger')
  revalidatePath('/anvisninger')
}

export async function slettAnvisning(
  _t: SlettTilstand, formData: FormData,
): Promise<SlettTilstand> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) return { feil: 'Ikke tilgang.' }
  const id = String(formData.get('id') ?? '')
  if (!id) return { feil: 'Mangler id.' }
  const supabase = await lagSupabaseServerKlient()
  // FEILEN SKAL VAERE SYNLIG. Ble raden avvist av RLS, skjedde
  // det ingenting - og sida sa ingenting. Da er «slettet» og
  // «gikk ikke» to tilstander som ser helt like ut.
  const { error } = await supabase.from('anvisninger').update({ slettet_tid: new Date().toISOString() }).eq('id', id)
  if (error) return { feil: `Kunne ikke slette: ${error.message}` }
  revalidatePath('/anvisninger')
  return { ok: 'Anvisningen slettet' }
}


// =====================================================================
// Last opp et PDF-ark.
//
// VALIDER FOER STORAGE. Sjekker vi stoerrelse og type foerst, faar
// brukeren én setning paa norsk. Lar vi storage avvise fila, faar hun
// en API-feil paa engelsk om noe hun ikke kan gjoere noe med.
//
// DUPLIKATET BLOKKERER IKKE. En ny versjon av samme ark har som regel
// identisk tittel - og det er nettopp da man vil laste opp. Advarselen
// finnes for aa bli sett, ikke for aa stoppe noen. `likevel` i skjemaet
// er overstyringen.
//
// RADEN FOERST ETTER FILA. Feiler innsettingen, ligger det en foreldreloes
// fil i bucketen - det koster ingenting. Motsatt rekkefoelge ville gitt
// en rad som peker paa en fil som ikke finnes, og den ser ut som et
// oedelagt ark for den som proever aa aapne det.
// =====================================================================
export async function lastOppAnvisning(
  _t: Kvittering, fd: FormData,
): Promise<Kvittering> {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle) || !bruker.retailerId) {
    return { feil: 'Bare ledere kan laste opp anvisninger.' }
  }

  const tittel = String(fd.get('tittel') ?? '').trim()
  if (!tittel) return { feil: 'Anvisningen mangler tittel.' }
  const kategori = String(fd.get('kategori') ?? '').trim() || 'Generelt'
  const stikkord = lesStikkord(String(fd.get('stikkord') ?? ''))
  const dato = String(fd.get('dato') ?? '') || null
  const erstatter = String(fd.get('erstatter_dato') ?? '') || null
  const likevel = fd.get('likevel') === 'ja'

  const fil = fd.get('fil')
  if (!(fil instanceof File) || fil.size === 0) {
    return { feil: 'Velg en PDF-fil.' }
  }
  const filfeil = sjekkFil({ size: fil.size, type: fil.type, name: fil.name })
  if (filfeil) return { feil: filfeil }

  const supabase = await lagSupabaseServerKlient()

  if (!likevel) {
    const { data: finnes } = await supabase
      .from('anvisninger')
      .select('id, tittel, original_filnavn')
      .is('slettet_tid', null)
      .overrideTypes<{ id: string; tittel: string; original_filnavn: string | null }[]>()
    const d = finnDuplikat(finnes ?? [], { tittel, filnavn: fil.name })
    if (d) {
      return {
        feil:
          `«${d.tittel}» finnes allerede (samme ${d.grunn}). `
          + 'Huk av «Last opp likevel» hvis dette er en ny versjon.',
      }
    }
  }

  // Generert navn, aldri brukerens eget: kollisjoner paa «horn.pdf»,
  // tegnsettproblemer paa aeoeaa, og stier andre kan gjette seg til.
  const sti = lagFilsti(
    bruker.retailerId,
    Date.now(),
    Math.random().toString(36).slice(2, 8),
  )

  const { error: opplast } = await supabase.storage
    .from('anvisninger')
    .upload(sti, fil, { contentType: 'application/pdf', upsert: false })
  if (opplast) return { feil: `Kunne ikke laste opp fila: ${opplast.message}` }

  return kvitter(supabase.from('anvisninger').insert({
    retailer_id: bruker.retailerId,
    kategori,
    tittel,
    stikkord,
    fil_sti: sti,
    original_filnavn: fil.name,
    dato,
    erstatter_dato: erstatter,
    opprettet_av: bruker.id,
  }, { count: 'exact' }), {
    hva: 'lagre anvisningen',
    ok: `«${tittel}» er lastet opp`,
    oppfrisk: ['/anvisninger'],
  })
}