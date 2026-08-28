import Link from 'next/link'
import { kr } from '@/lib/format'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { hentHjemData } from '@/lib/tablethjem'
import { beregnMalekort, tabletKort, type Malekort, type TabletKort } from '@/lib/malekort'
import { oversettTabletOrd } from '@/lib/oversett'
import { VekstKort } from '../vekst-kort'
import { MalekortTablet } from '../maaling-tablet'
import { TabletHode } from '../tablet-hode'

// =====================================================================
// «Vaar stasjon» — sekundaerflata.
//
// HVORFOR DEN FINNES: fire ting sto paa nettbrettets hjem og svarte paa
// et annet spoersmaal enn resten av flata. Premiesaldo i kroner, vekst
// mot i fjor, skills-score og maalekort-rangering forteller hvordan
// butikken LIGGER AN. «I dag» skal fortelle hva hun skal GJOERE naa.
//
// De ble ikke fjernet — det ville vaert aa ta bort engasjementslaget
// nettbrettet ble bygget med. De ble samlet, ett trykk unna, paa en
// flate som eier spoersmaalet.
//
// DEN ER MED VILJE IKKE ET MINI-DASHBORD. Fire seksjoner, i fallende
// rekkefolge etter hvor mye de betyr for den som staar i butikken:
// pengene vi vant, veksten vi har, poengsummen, og hvor vi ligger mot de
// andre. Ingen filtre, ingen perioder, ingen drill-down. Vil man grave,
// er det lederflatens jobb.
//
// MAALEKORTBEREGNINGEN FLYTTET HIT MED INNHOLDET. Den kostet et
// rpc-kall pluss en beregning per kort paa HVER lasting av hjem — flata
// som staar aapen hele dagen og oppdaterer seg hvert 30. sekund. Naa
// betales den bare naar noen faktisk ser paa tallene.
// =====================================================================

export default async function VaarStasjonSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>

  const supabase = await lagSupabaseServerKlient()
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet' ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const ord = await oversettTabletOrd(sprak)
  const t = (s: string) => ord[s] ?? s

  const { data: st } = await supabase
    .from('stasjoner').select('id').is('slettet_tid', null).limit(1).maybeSingle<{ id: string }>()

  const hjem = st
    ? await hentHjemData(supabase, st.id)
    : { skills: null, premie: { vunnet: 0, brukt: 0, igjen: 0 }, produksjon: null, vekst: null }

  let maling: TabletKort[] = []
  if (st) {
    // Samme svelging som /maaling hadde. Nettbrettet har vist maalekortene
    // tomme like lenge, for de samme fem butikkene, uten at noen kunne se
    // hvorfor. Her er det ingen flate aa melde feilen paa - de som staar
    // paa gulvet kan uansett ikke gjore noe med den - saa den logges, og
    // kortene utelates framfor aa vises som nuller.
    const { data: stData, error: stFeil } = await supabase.rpc('malekort_stasjoner')
    if (stFeil) console.error('malekort_stasjoner feilet paa /vaar-stasjon', stFeil)
    const malStasjoner = ((stData ?? []) as { id: string; navn: string; butikknummer: string }[])
      .map((s) => ({ id: s.id, navn: `${s.butikknummer} ${s.navn}` }))
    const { data: kortData } = await supabase
      .from('malekort')
      .select('id, navn, metrikk, normalisering, periode, retning, krev_fullstendig_periode, anonymiser')
      .eq('vis_tablet', true)
      .is('slettet_tid', null)
      .order('sortering')
      .overrideTypes<Malekort[]>()
    const malkort = kortData ?? []
    const malRes = await Promise.all(malkort.map((k) => beregnMalekort(supabase, k, malStasjoner)))
    maling = malkort.map((k, i) => tabletKort(k.navn, malRes[i], st.id))
  }

  return (
    <>
      <TabletHode
        tittel={t('Vår stasjon')}
        undertittel={t('Hvordan vi ligger an. Ikke noe du må gjøre i dag.')}
      />

      <section className="tablet-seksjon premie">
        <h2>{t('Vår premiesaldo')}</h2>
        <div className="premie-saldo">
          <div><span className="premie-tall">{kr.format(hjem.premie.vunnet)}</span><span className="premie-merke">{t('Vunnet')}</span></div>
          <div><span className="premie-tall">{kr.format(hjem.premie.brukt)}</span><span className="premie-merke">{t('Brukt')}</span></div>
          <div><span className="premie-tall gronn">{kr.format(hjem.premie.igjen)}</span><span className="premie-merke">{t('Igjen')}</span></div>
        </div>
      </section>

      {hjem.vekst && <VekstKort metrikker={hjem.vekst.metrikker} sisteDato={hjem.vekst.sisteDato} />}

      {hjem.skills && (
        <section className="tablet-seksjon skills">
          <span className="skills-merke">{t('Skills-score')}</span>
          <span className="skills-tall">{hjem.skills.prosent} %</span>
          <span className="skills-tekst">{t(hjem.skills.tekst)}</span>
        </section>
      )}

      <MalekortTablet kort={maling} />

      {/* MERKER HOERER TIL HER, ikke i et flisrutenett ved siden av
          IK-mat. Det er anerkjennelse, ikke en oppgave. */}
      <Link href="/merker" className="tablet-videre">
        <span className="tablet-videre-tekst">
          <strong>{t('Merker')}</strong>
          <span className="undertittel">{t('Det teamet har fått til')}</span>
        </span>
        <span className="tablet-videre-pil" aria-hidden>›</span>
      </Link>
    </>
  )
}
