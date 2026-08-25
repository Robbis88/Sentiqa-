import Link from 'next/link'
import type { HjemData } from '@/lib/tablethjem'
import { TabletOpplaering, type Opplaering } from './opplaring/tablet-opplaering'
import { TabletHero } from './tablet-hero'
import { TabletSkiftet } from './tablet-skiftet'
import { PulsPopp } from './puls-popp'
import { SjekkpunktPopp } from './sjekkpunkt-popp'
import { SendTilSjef } from './send-til-sjef'
import { StemplingRad, type Stemplingstilstand } from './stempling-rad'
import { MeldingerFraSjef, type SjefMelding } from './meldinger-sjef'

// =====================================================================
// NIVAA 1 — «I dag». Hva skal jeg gjore naa?
//
// FLISENE ER BORTE. De var fem lenker — Rutiner, Produksjon, IK-mat,
// Merker, Anvisninger — i et rutenett der alt saa like viktig ut, ved
// siden av en fanerad som lenket til to av de samme stedene. To
// navigasjonslag over hverandre: ni innganger til aatte ruter.
//
// Rutiner og Anvisninger er faner. Produksjon og IK-mat kommer TIL
// henne gjennom koen naar de krever arbeid i dag, og staar i foten under
// Rutiner naar hun oppsoker dem selv. Merker hoerer til «Vaar stasjon».
// Ingen destinasjon mistet en vei; de mistet en DUBLETT.
//
// OG OKONOMIEN ER FLYTTET. Premiesaldo i kroner, vekst mot i fjor,
// skills-score og maalekort-rangering sto her — under det hun skulle
// gjore. Fire blokker som svarer paa «hvordan ligger butikken an», paa
// en flate som skal svare paa «hva skal jeg gjore naa». De er ikke
// fjernet: de er samlet paa `/vaar-stasjon`, som naas herfra med en rad.
//
// Tolv blokker ble sju. Rekkefolgen er aerendets:
//
//   1. hilsen + klokke      rammen. Hvem er paa, og naar er det.
//   2. det som haster       viktige beskjeder avbryter.
//   3. koen                 det hun kom for.
//   4. dagens fremdrift     hvor langt er vi.
//   5. beskjeder            fra butikksjefen, og de vanlige.
//   6. stempling            timene. Under koen, ikke over.
//   7. vaar stasjon         engasjementet, ett trykk unna.
// =====================================================================

type Melding = { id: string; tekst: string; viktig: boolean }
type PulsRunde = { id: string; tekst: string } | null
type Sjekk = { id: string; sporsmaal: string; kritisk: boolean; stasjon_id: string }

function Beskjed({ m, t }: { m: Melding; t: (s: string) => string }) {
  return (
    <div className={`tablet-melding ${m.viktig ? 'viktig' : ''}`}>
      {/* Alvoret laa i en roed bakgrunn og et utropstegn-emoji. Naa staar
          det i ord: en beskjed som haster skal kunne skilles fra en
          vanlig av den som ikke ser farge. */}
      <span className="tablet-melding-merke">
        {m.viktig ? t('Viktig') : t('Beskjed')}
      </span>
      <span>{m.tekst}</span>
    </div>
  )
}

export function TabletHjem({
  navn,
  meldinger = [],
  sjefMeldinger = [],
  idag,
  pulsRunde = null,
  sjekkpunkter = [],
  hjem,
  rutinerIgjen = 0,
  stempling = { slag: 'ukjent' },
  ord = {},
  opplaeringer = [],
}: {
  navn?: string
  meldinger?: Melding[]
  sjefMeldinger?: SjefMelding[]
  idag: string
  pulsRunde?: PulsRunde
  sjekkpunkter?: Sjekk[]
  hjem: HjemData
  rutinerIgjen?: number
  stempling?: Stemplingstilstand
  ord?: Record<string, string>
  opplaeringer?: Opplaering[]
}) {
  const t = (s: string) => ord[s] ?? s

  // VIKTIG OVER KOEN, VANLIG UNDER. En kringkastet beskjed merket viktig
  // er et avbrudd — den skal leses for hun begynner. En vanlig beskjed er
  // ikke det, og sto likevel over alt hun skulle gjore.
  const viktige = meldinger.filter((m) => m.viktig)
  const vanlige = meldinger.filter((m) => !m.viktig)

  return (
    <>
      <PulsPopp runde={pulsRunde} />
      <SjekkpunktPopp punkter={sjekkpunkter} />

      <TabletHero navn={navn} />

      {viktige.length > 0 && (
        <div className="tablet-meldinger">
          {viktige.map((m) => <Beskjed key={m.id} m={m} t={t} />)}
        </div>
      )}

      <TabletSkiftet
        kilder={{
          sjekkpunkter,
          rutinerIgjen,
          oppgaver: sjefMeldinger.map((m) => ({
            id: m.id, tittel: m.tittel, fullfort: m.fullfort, frist: m.frist,
          })),
          produksjon: hjem.produksjon
            ? { plan: hjem.produksjon.plan, lagd: hjem.produksjon.lagd }
            : null,
        }}
        ord={ord}
      />

      {/* DAGENS FREMDRIFT. Koen sier hva som gjenstaar; denne sier hvor
          langt vi er kommet. Den staar bare naar det finnes en publisert
          plan — en tom fremdriftslinje er stoy. */}
      {/* OPPLAERING STAAR FOER PRODUKSJONSPLANEN, og bare paa de dagene
          den er planlagt. En som laerer bort i dag har det som sin
          viktigste oppgave; en tom seksjon resten av uka ville vaert
          stoey. Skift-kalenderen avgjoer - den finnes ikke her. */}
      <TabletOpplaering opplaeringer={opplaeringer} />

      {hjem.produksjon && hjem.produksjon.plan > 0 && (() => {
        const pst = Math.min(100, Math.round((hjem.produksjon.lagd / hjem.produksjon.plan) * 100))
        return (
          <Link href="/produksjonsplan" className="tablet-seksjon pp-hjem">
            <div className="pp-hjem-topp">
              <span className="pp-hjem-tekst">
                <strong>{t('Produksjonsplan')}</strong>
                <span>{t('I dag')}: {hjem.produksjon.antall} {t('produkter')} · {hjem.produksjon.lagd}/{hjem.produksjon.plan} {t('lagd')}</span>
              </span>
              <span className="pp-hjem-pst">{pst} %</span>
            </div>
            <div className="pp-hjem-bar"><span style={{ width: `${pst}%` }} /></div>
          </Link>
        )
      })()}

      <MeldingerFraSjef meldinger={sjefMeldinger} idag={idag} ord={ord} />

      {vanlige.length > 0 && (
        <div className="tablet-meldinger">
          {vanlige.map((m) => <Beskjed key={m.id} m={m} t={t} />)}
        </div>
      )}

      <StemplingRad tilstand={stempling} ord={ord} />

      {/* SEKUNDAERFLATA, IKKE EN FJERDE FANE. Den staar som EN rad, under
          dagens arbeid — plasseringen er selve beskjeden om rangordenen. */}
      <Link href="/vaar-stasjon" className="tablet-videre">
        <span className="tablet-videre-tekst">
          <strong>{t('Vår stasjon')}</strong>
          <span className="undertittel">{t('Premie, vekst, skills og måling')}</span>
        </span>
        <span className="tablet-videre-pil" aria-hidden>›</span>
      </Link>

      <div className="tablet-seksjon send-sjef-boks">
        <SendTilSjef />
      </div>
    </>
  )
}
