'use server'
import { revalidatePath } from 'next/cache'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { gjenkjennRapporttype } from '@/lib/parsere/gjenkjenn'
import { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import { ParserFeil } from '@/lib/parsere/felles'

// Behandler én import-jobb: laster ned rå fil, gjenkjenner rapporttype,
// parser, matcher stasjoner på butikknummer (§6) og upserter daglig_salg.
// Manuell trigger (knapp) inntil kø/arbeider er på plass. Kjører som
// innlogget admin → RLS gjelder.
export async function behandleJobb(formData: FormData) {
  const jobbId = String(formData.get('jobbId') ?? '')
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle !== 'retailer_admin' || !bruker.retailerId) return

  const supabase = await lagSupabaseServerKlient()

  const { data: jobb } = await supabase
    .from('import_jobber')
    .select('id, raa_filer(storage_bucket, storage_sti)')
    .eq('id', jobbId)
    .single<{ id: string; raa_filer: { storage_bucket: string; storage_sti: string } | null }>()

  if (!jobb?.raa_filer) return

  const settFeil = (melding: string) =>
    supabase
      .from('import_jobber')
      .update({ status: 'feilet', feilmelding: melding })
      .eq('id', jobbId)

  await supabase.from('import_jobber').update({ status: 'behandler' }).eq('id', jobbId)

  // 1. Last ned rå fil fra Storage
  const nedlasting = await supabase.storage
    .from(jobb.raa_filer.storage_bucket)
    .download(jobb.raa_filer.storage_sti)
  if (nedlasting.error || !nedlasting.data) {
    await settFeil(`Kunne ikke laste ned fil: ${nedlasting.error?.message ?? 'ukjent'}`)
    revalidatePath('/import')
    return
  }
  const buffer = Buffer.from(await nedlasting.data.arrayBuffer())

  // 2. Gjenkjenn rapporttype
  const rapporttype = await gjenkjennRapporttype(buffer)
  await supabase.from('import_jobber').update({ rapporttype }).eq('id', jobbId)

  // 3. Foreløpig kobler vi kun Salgsstatistikk til lagring (daglig_salg).
  if (rapporttype !== 'st1_salgsstatistikk') {
    await settFeil(`Gjenkjent som «${rapporttype}» – lagring for denne typen kommer i et senere steg.`)
    revalidatePath('/import')
    return
  }

  try {
    const resultat = await parseSalgsstatistikk(buffer)

    // 4. Match stasjoner på 4-sifret butikknummer (§6 – gjett aldri)
    const { data: stasjoner } = await supabase
      .from('stasjoner')
      .select('id, butikknummer')
      .is('slettet_tid', null)
    const idForNr = new Map((stasjoner ?? []).map((s) => [s.butikknummer, s.id]))

    const umatchet: string[] = []
    const rader: Record<string, unknown>[] = []
    for (const st of resultat.stasjoner) {
      const stasjonId = idForNr.get(st.butikknummer)
      if (!stasjonId) {
        umatchet.push(`${st.butikknummer} (${st.navn})`)
        continue
      }
      for (const l of st.linjer) {
        rader.push({
          retailer_id: bruker.retailerId,
          stasjon_id: stasjonId,
          dato: resultat.dato,
          ean: l.ean,
          varenr: l.varenr,
          varenavn: l.varenavn,
          avdeling_kode: l.avdelingKode,
          avdeling_navn: l.avdelingNavn,
          vareomrade_kode: l.vareomradeKode,
          vareomrade_navn: l.vareomradeNavn,
          varegruppe_kode: l.varegruppeKode,
          varegruppe_navn: l.varegruppeNavn,
          antall: l.antallTotalt,
          antall_tilbud: l.antallTilbud,
          omsetning_eks_mva: l.omsetningEksMva,
          bto_fortjeneste_kr: l.btoFortjenesteKr,
          bto_fortjeneste_pct: l.btoFortjenestePct,
          kilde_jobb_id: jobbId,
        })
      }
    }

    // 5. Idempotent upsert (overskriver ved re-opplasting, §6)
    if (rader.length > 0) {
      const { error } = await supabase
        .from('daglig_salg')
        .upsert(rader, { onConflict: 'retailer_id,stasjon_id,dato,ean' })
      if (error) {
        await settFeil(`Lagring feilet: ${error.message}`)
        revalidatePath('/import')
        return
      }
    }

    const alleUmatchet = rader.length === 0
    await supabase
      .from('import_jobber')
      .update({
        status: alleUmatchet ? 'feilet' : 'parset',
        gjelder_dato: resultat.dato,
        antall_rader: rader.length,
        parset_tid: new Date().toISOString(),
        feilmelding:
          umatchet.length > 0
            ? `Ukjente butikknummer (registrer stasjonen): ${umatchet.join(', ')}`
            : null,
      })
      .eq('id', jobbId)
  } catch (e) {
    const melding = e instanceof ParserFeil ? e.message : `Uventet feil: ${String(e)}`
    await settFeil(melding)
  }

  revalidatePath('/import')
}
