import Link from 'next/link'
import { kr } from '@/lib/format'
import type { HjemData } from '@/lib/tablethjem'
import { TabletHero } from './tablet-hero'
import { TabletSkiftet } from './tablet-skiftet'
import { PulsPopp } from './puls-popp'
import { SjekkpunktPopp } from './sjekkpunkt-popp'
import { SendTilSjef } from './send-til-sjef'
import { VekstKort } from './vekst-kort'
import { MalekortTablet } from './maaling-tablet'
import type { TabletKort } from '@/lib/malekort'
import { MeldingerFraSjef, type SjefMelding } from './meldinger-sjef'

// FLISENE ER ORD NAA, IKKE EMOJI.
//
// Avveiningen er verdt aa skrive ned, for den gaar begge veier: en
// emoji kjennes igjen paa avstand og krever ikke lesing, og nettbrettet
// brukes av folk som ikke alle leser norsk godt. Men ETIKETTENE
// oversettes (`useT`), og emojien gjorde ikke det - den sto som et
// bilde ved siden av et ord som byttet spraak.
//
// Og de fem emojiene var ikke ett formsprak: en hake, et bakverk, et
// termometer, en medalje og en bok, hver med sine egne farger fra
// systemfonten. Alternativet var aa tegne fem strekikoner til
// `ikoner.tsx`, men et ikon som skal si «IK-mat & avvik» finnes ikke -
// og et daarlig ikon over et riktig ord gjor ordet mindre, ikke stoerre.
const TILES = [
  { sti: '/rutiner', tekst: 'Rutiner' },
  { sti: '/produksjonsplan', tekst: 'Produksjon' },
  { sti: '/ikmat', tekst: 'IK-mat & avvik' },
  { sti: '/merker', tekst: 'Merker' },
  { sti: '/anvisninger', tekst: 'Anvisninger' },
]

type Melding = { id: string; tekst: string; viktig: boolean }
type PulsRunde = { id: string; tekst: string } | null
type Sjekk = { id: string; sporsmaal: string; kritisk: boolean; stasjon_id: string }

export function TabletHjem({
  navn,
  streak,
  meldinger = [],
  sjefMeldinger = [],
  idag,
  pulsRunde = null,
  sjekkpunkter = [],
  hjem,
  maling = [],
  rutinerIgjen = 0,
  ord = {},
}: {
  navn?: string
  streak: number
  meldinger?: Melding[]
  sjefMeldinger?: SjefMelding[]
  idag: string
  pulsRunde?: PulsRunde
  sjekkpunkter?: Sjekk[]
  hjem: HjemData
  maling?: TabletKort[]
  rutinerIgjen?: number
  ord?: Record<string, string>
}) {
  const t = (s: string) => ord[s] ?? s
  return (
    <>
      <PulsPopp runde={pulsRunde} />
      <SjekkpunktPopp punkter={sjekkpunkter} />

      {meldinger.length > 0 && (
        <div className="tablet-meldinger">
          {meldinger.map((m) => (
            <div className={`tablet-melding ${m.viktig ? 'viktig' : ''}`} key={m.id}>
              {/* Alvoret laa i en roed bakgrunn og et utropstegn-emoji.
                  Naa staar det i ord: en beskjed som haster skal kunne
                  skilles fra en vanlig av den som ikke ser farge. */}
              <span className="tablet-melding-merke">
                {m.viktig ? t('Viktig') : t('Beskjed')}
              </span>
              <span>{m.tekst}</span>
            </div>
          ))}
        </div>
      )}

      {/* Skiftlista staar FORAN hero og fliser: det man kom for, forst. */}
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

      <TabletHero navn={navn} streak={streak} />

      <div className="tablet-tiles">
        {TILES.map((flis) => (
          <Link key={flis.sti} href={flis.sti} className="tablet-tile">
            <span className="tablet-tile-tekst">{t(flis.tekst)}</span>
          </Link>
        ))}
      </div>

      <MeldingerFraSjef meldinger={sjefMeldinger} idag={idag} ord={ord} />

      {hjem.vekst && <VekstKort metrikker={hjem.vekst.metrikker} />}

      <MalekortTablet kort={maling} />

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

      <section className="tablet-seksjon premie">
        <h2>{t('Vår premiesaldo')}</h2>
        <div className="premie-saldo">
          <div><span className="premie-tall">{kr.format(hjem.premie.vunnet)}</span><span className="premie-merke">{t('Vunnet')}</span></div>
          <div><span className="premie-tall">{kr.format(hjem.premie.brukt)}</span><span className="premie-merke">{t('Brukt')}</span></div>
          <div><span className="premie-tall gronn">{kr.format(hjem.premie.igjen)}</span><span className="premie-merke">{t('Igjen')}</span></div>
        </div>
      </section>

      {hjem.skills && (
        <section className="tablet-seksjon skills">
          <span className="skills-merke">{t('Skills-score')}</span>
          <span className="skills-tall">{hjem.skills.prosent} %</span>
          <span className="skills-tekst">{t(hjem.skills.tekst)}</span>
        </section>
      )}

      <div className="tablet-seksjon send-sjef-boks">
        <SendTilSjef />
      </div>
    </>
  )
}
