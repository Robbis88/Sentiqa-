'use client'
import { datoLang } from '@/lib/format'
import { useT } from '../oversett-kontekst'
import type { TabletGruppe } from './tablet-plan'

// =====================================================================
// MORGENDAGENS PLAN — SÅ DE VET HVA SOM SKAL TAS OPP I KVELD
// =====================================================================
//
// Startpartiet skal være ferdig når døra åpner (`0149`). Det betyr at
// noe må tas opp kvelden før — og fram til nå kunne de ikke se hvor
// mye før dagen det gjaldt.
//
// ---------------------------------------------------------------------
// LESEVISNING VED KONSTRUKSJON, IKKE BARE VISUELT
// ---------------------------------------------------------------------
//
// Her finnes ingen stepper, ingen knapper og ingen `loggLagd`. Det er
// ikke en stilvalg — det er det eneste vernet som finnes.
//
// `loggLagd(stasjon, dato, varenavn, lagd)` tar datoen som ARGUMENT og
// sjekker aldri at den er i dag. `logg_lagd` i basen vokter stasjon og
// at linja finnes, ikke datoen. Fantes det en knapp her, ville et trykk
// skrevet produksjon på en dag som ikke har begynt. Registrert produksjon
// er driftsdata; dagens treffsikkerhet måler råprognosen mot salg.
//
// Skal morgendagen noen gang bli klikkbar, må datovernet ligge i
// `logg_lagd` FØRST. Ikke i denne fila.
//
// ---------------------------------------------------------------------
// DATOEN STÅR I OVERSKRIFTEN
// ---------------------------------------------------------------------
//
// To lister med tall på samme skjerm, der den ene gjelder en annen dag.
// Det er samme form som feilslippet i «Venter på deg», der juni ble
// sluppet i stedet for juli fordi begge sto der uten å si hvilken
// måned de var. Datoen er ikke pynt.
// =====================================================================

export function TabletMorgendag({
  dato,
  notat,
  grupper,
}: {
  dato: string
  notat: string | null
  grupper: TabletGruppe[]
}) {
  const t = useT()

  // STARTPARTIET ER SVARET PÅ SPØRSMÅLET. «Hva skal tas opp?» besvares
  // av det som må være klart til åpning, ikke av dagens totale plan.
  // Totalen står ved siden av, fordi den sier hvor stor dagen blir.
  const start = grupper.reduce(
    (n, g) => n + g.produkter.reduce((m, p) => m + p.start_antall, 0), 0,
  )

  return (
    <section className="tablet-seksjon pp-morgendag">
      <h2>
        {t('I morgen')} · {datoLang.format(new Date(`${dato}T00:00:00Z`))}
      </h2>
      <p className="undertittel">
        {start > 0
          ? `${t('Klart til åpning')}: ${start}`
          : t('Ingen startparti i morgen')}
      </p>

      {notat && (
        <div className="tablet-melding">
          <span className="tablet-melding-merke">{t('Beskjed')}</span>
          <span>{notat}</span>
        </div>
      )}

      {grupper.map((g) => (
        <div className="pp-tab-liste" key={g.navn}>
          <h3 className="pp-morgendag-gruppe">{g.navn}</h3>
          {g.produkter.map((p) => (
            <div className="pp-tab-rad lesevisning" key={p.varenavn}>
              <div className="pp-tab-topp">
                <span className="pp-tab-navn">{p.varenavn}</span>
                {/* STARTPARTIET STÅR STORT. Er det null, er det ingenting
                    å ta opp for det produktet, og da skal tallet heller
                    ikke rope. */}
                <span className="pp-tab-tall">
                  {p.start_antall > 0 ? p.start_antall : '—'}
                </span>
              </div>
              <div className="pp-tab-bunn">
                <span className="pp-tab-start">
                  {t('Hele dagen')}: {p.planlagt}
                </span>
              </div>
            </div>
          ))}
        </div>
      ))}
    </section>
  )
}
