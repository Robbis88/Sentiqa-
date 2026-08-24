import { hentInnloggetBruker } from '@/lib/auth/dal'
import { erLeder } from '@/lib/auth/roller'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { kr, tall, manedAar } from '@/lib/format'
import Link from 'next/link'
import { AiKontekst } from '../ai-kontekst'
import { Sidehode, Tomtilstand, Nokkeltall, Forklaring, Datatabell } from '@/components/ui/side'
import { Knapp } from '@/components/ui/knapp'
import { husketStasjon } from '@/lib/stasjonskontekst'
import { stasjonFraUrl, tillatAlleFor } from '@/lib/stasjonsvalg'
import { Maanedsvelger } from '@/components/ui/periode'
import { lesMaaned, maanederI } from '@/lib/periode'
import {
  byggAlle, totaltFor, nokGrunnlag, MIN_BONGER,
  type Kassererrad, type Kassererbilde,
} from '@/lib/kasserer/rate'

// =====================================================================
// Kasserer: hva kassa gjorde, ikke hvem som er mistenkt.
//
// DEN GAMLE SIDA HADDE EN GRENSE PÅ 2 % AV OMSETNINGEN. Sonden mot
// produksjon 2026-08-24 målte den: den ville felt **771 av 775**
// kasserermåneder. Det er ikke en streng grense, det er en konstant som
// forteller hver butikksjef at hver kasserer er over streken.
//
// Og en grense lenger ute ville ikke hjulpet, for tallet skiller ikke
// personer i det hele tatt:
//
//   spredning INNI én kasserer  >  spennet MELLOM kasserere
//   på alle fem stasjonene
//
// Den samme kassereren svinger mer fra måned til måned enn kasserere
// flest gjør fra hverandre. Å rangere på det ville vært å rangere
// tilfeldighet — og navnet øverst ville blitt lest som en anklage.
//
// Derfor viser denne siden **volum og sammensetning**, ikke folk mot
// hverandre. Makulert er 71–83 % av kronene, og det er en rutine, ikke
// en person. Det er der en butikksjef faktisk kan gjøre noe.
// =====================================================================

type Sok = { stasjon?: string; maned?: string }

/** Rate, eller «for lite grunnlag». Aldri et tall systemet ikke kan stå inne for. */
function Rate({ v, bonger }: { v: number | null; bonger: number }) {
  if (!nokGrunnlag(bonger)) {
    return (
      <span className="sq-dempet" title={`Under ${MIN_BONGER} bonger — raten sier mer om vaktlengde enn om kassa`}>
        for lite grunnlag
      </span>
    )
  }
  if (v == null) return <span className="sq-dempet">ingen bonger</span>
  return <>{kr.format(Math.round(v))}</>
}

export default async function KassererSide({ searchParams }: { searchParams: Promise<Sok> }) {
  const bruker = await hentInnloggetBruker()
  if (!erLeder(bruker.rolle)) {
    return <p>Du har ikke tilgang til kassererstatistikk.</p>
  }

  const sp = await searchParams
  const supabase = await lagSupabaseServerKlient()

  // RLS ER AUTORITETEN. Lista kommer fra `stasjoner`, som gir
  // butikksjefen sine egne og eieren hele kjeden. Stasjonsvalget er en
  // innsnevring, aldri en utvidelse.
  const { data: stasjoner } = await supabase
    .from('stasjoner')
    .select('id, navn, butikknummer')
    .is('slettet_tid', null)
    .order('butikknummer')
    .overrideTypes<{ id: string; navn: string; butikknummer: string }[]>()

  const stasjonsliste = stasjoner ?? []
  const sok = new URLSearchParams()
  if (sp.stasjon) sok.set('stasjon', sp.stasjon)
  const valgtStasjon = await husketStasjon(
    stasjonsliste, stasjonFraUrl(sok, stasjonsliste),
    tillatAlleFor('/kasserer', bruker.rolle, stasjonsliste.length),
  )
  const navnFor = new Map(stasjonsliste.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  const erStasjon = valgtStasjon != null && navnFor.has(valgtStasjon)

  const fra = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 12, 1))
    .toISOString().slice(0, 10)

  let q = supabase.from('v_kasserer_maaned')
    .select('stasjon_id, kasserer_nr, maned, dager, bonger, omsetning_kr, retur_kr, retur_antall, makulert_kr, makulert_antall, slettet_kr, slettet_antall, navn, ulike_navn')
    .gte('maned', fra)
  if (erStasjon) q = q.eq('stasjon_id', valgtStasjon!)

  const { data: raa } = await q.limit(20000).overrideTypes<Kassererrad[]>()
  const rader = raa ?? []
  const maaneder = maanederI(rader)

  if (maaneder.length === 0) {
    return (
      <>
        <Sidehode tittel="Kasserer" undertittel="Retur, makulering og sletting i kassa, per måned." />
        <Tomtilstand
          tittel="Ingen kassererdata ennå"
          forklaring="Kassererstatistikk kommer fra St1-rapporten CashierStatistics."
          handling={<Knapp><Link href="/import">Gå til import</Link></Knapp>}
        />
      </>
    )
  }

  const onsket = lesMaaned(sp, maaneder[0])
  const valgtMaaned = maaneder.includes(onsket) ? onsket : maaneder[0]
  const iMaaneden = rader.filter((r) => r.maned === valgtMaaned)
  const { folk, system } = byggAlle(rader, valgtMaaned)
  const total = totaltFor(rader, valgtMaaned)

  const forrige = maaneder[maaneder.indexOf(valgtMaaned) + 1]
  const forrigeTotal = forrige ? totaltFor(rader, forrige) : null

  // Bare de som faktisk var på jobb i måneden. En kasserer uten rader
  // skal ikke stå med tomme kolonner - det ser ut som null avvik.
  const iJobb = folk.filter((k) => k.denne != null)

  const sumType = (t: 'retur' | 'makulert' | 'slettet') =>
    iJobb.reduce((n, k) => n + (k.denne?.perType[t].kr ?? 0), 0)

  const systemBonger = iMaaneden
    .filter((r) => system.some((s) => s.nr === r.kasserer_nr))
    .reduce((n, r) => n + r.bonger, 0)

  const lenke = (m: string) => {
    const u = new URLSearchParams()
    if (sp.stasjon) u.set('stasjon', sp.stasjon)
    if (m !== maaneder[0]) u.set('maned', m)
    const s = u.toString()
    return s ? `/kasserer?${s}` : '/kasserer'
  }

  return (
    <>
      <Sidehode
        tittel="Kasserer"
        undertittel={`${erStasjon ? navnFor.get(valgtStasjon!) : 'Alle stasjoner'} · ${manedAar.format(new Date(valgtMaaned))}`}
      />

      {/* KILDEN BESTEMMER UTVALGET: bare maaneder det finnes kassetall
          i. En dag er for lite til at en rate betyr noe. */}
      <Maanedsvelger maaneder={maaneder} valgt={valgtMaaned} skjulte={{ stasjon: sp.stasjon }} />

      {/* MAKULERT FØRST, fordi det ER først: 71–83 % av avvikskronene.
          Sto de tre summert i ett tall, ville det store skjult at de to
          andre er små - og det er nettopp forholdet mellom dem som sier
          noe om hva slags rutine stasjonen har. */}
      <div className="sq-nokkelrad">
        <Nokkeltall
          merkelapp="Makulert"
          verdi={kr.format(Math.round(sumType('makulert')))}
          sammenlignet={total.avvikKr !== 0
            ? `${Math.round(sumType('makulert') / total.avvikKr * 100)} % av alle avvikskronene`
            : undefined}
        />
        <Nokkeltall
          merkelapp="Retur og slettet"
          verdi={kr.format(Math.round(sumType('retur') + sumType('slettet')))}
          sammenlignet={`${kr.format(Math.round(sumType('retur')))} retur · ${kr.format(Math.round(sumType('slettet')))} slettet`}
        />
        <Nokkeltall
          merkelapp="Per 100 bonger"
          verdi={total.krPer100 == null ? '—' : kr.format(Math.round(total.krPer100))}
          sammenlignet={forrigeTotal?.krPer100 != null
            ? `${kr.format(Math.round(forrigeTotal.krPer100))} i ${manedAar.format(new Date(forrige))}`
            : `${tall.format(total.bonger)} bonger`}
          retning={forrigeTotal?.krPer100 != null && total.krPer100 != null
            ? (total.krPer100 > forrigeTotal.krPer100 ? 'opp'
              : total.krPer100 < forrigeTotal.krPer100 ? 'ned' : 'flat')
            : 'flat'}
          bra={forrigeTotal?.krPer100 != null && total.krPer100 != null
            ? total.krPer100 < forrigeTotal.krPer100
            : undefined}
        />
      </div>

      {/* HVORFOR INGEN STÅR ØVERST. Dette er ikke en unnskyldning for at
          siden mangler noe - det er funnet. En bruker som leter etter
          «hvem er verst» skal møte svaret på hvorfor det spørsmålet ikke
          har et svar her. */}
      <Forklaring sporsmaal="Hvorfor rangeres ikke kassererne?">
        Fordi tallet ikke skiller personer. Målt mot produksjonsdata svinger den
        <strong> samme</strong> kassereren mer fra måned til måned enn kasserere flest
        gjør fra hverandre — på alle fem stasjonene. En liste sortert på avvik ville
        rangert tilfeldighet, og navnet øverst ville blitt lest som en anklage.
        {' '}Lista under står sortert på kassanummer. Hver kasserer måles mot
        <strong> sin egen</strong> historikk, ikke mot kollegaene.
      </Forklaring>

      <Forklaring sporsmaal="Hva betyr makulert, retur og slettet?">
        <strong>Retur</strong> er en vare kunden leverte tilbake.{' '}
        <strong>Makulert</strong> er en bong som ble annullert før betaling.{' '}
        <strong>Slettet</strong> er en linje som ble fjernet fra en bong underveis.
        Alle tre er vanlige i drift: i produksjonsdata har mellom 10 og 25 av
        hver 100 bonger et avvik. Makulering er den klart største, og den handler
        om rutine ved kassa — ikke om enkeltpersoner.
      </Forklaring>

      {/* ÉN TABELL PER STASJON, ikke én samlet.
          Kassanumrene starter på nytt på hver stasjon, så «101» finnes
          fem ganger i kjeden og er fem ulike mennesker. En samlet liste
          ville satt dem under hverandre uten at noe skilte dem — og
          vakthunden fanget at seksjonen forsvant da jeg først slo dem
          sammen. */}
      {stasjonsliste
        .filter((s) => iJobb.some((k) => k.stasjon_id === s.id))
        .map((s) => {
          const mine = iJobb.filter((k) => k.stasjon_id === s.id)
          return (
            <Datatabell
              key={s.id}
              tittel={`${s.butikknummer} ${s.navn}`}
              antall={mine.length}
            >
              <thead>
                <tr>
                  <th>Nummer</th><th>Navn</th><th>Bonger</th>
                  <th>Makulert</th><th>Retur</th><th>Slettet</th>
                  <th>Per 100 bonger</th><th>Mot eget snitt</th>
                </tr>
              </thead>
              <tbody>
                {mine.map((k) => (
                  <tr key={k.nr}>
                    <td>{k.nr}</td>
                    <td>
                      {k.navn ?? '—'}
                      {/* Sonden fant samme navn på to numre. Navnet er en
                          opplysning, ikke en nøkkel, og siden skal si fra
                          når den viser et navn den ikke kan stå inne for. */}
                      {k.navnEtvetydig && (
                        <span className="sq-dempet" title="Nummeret har båret flere navn i perioden"> · flere navn</span>
                      )}
                    </td>
                    <td>{tall.format(k.denne!.bonger)}</td>
                    <td><Kroner v={k.denne!.perType.makulert.kr} /></td>
                    <td><Kroner v={k.denne!.perType.retur.kr} /></td>
                    <td><Kroner v={k.denne!.perType.slettet.kr} /></td>
                    <td><Rate v={k.denne!.krPer100} bonger={k.denne!.bonger} /></td>
                    <td><MotEget k={k} /></td>
                  </tr>
                ))}
              </tbody>
            </Datatabell>
          )
        })}

      {/* SYSTEMNUMRENE FOR SEG. 999999 bærer 18–35 % av alle bonger.
          Blandes de inn, får kassa skylda til en medarbeider; slettes de
          i stillhet, ser stasjonens totale volum lavere ut enn det er. */}
      {system.some((s) => s.denne != null) && (
        <Datatabell tittel="Kassa selv" antall={system.filter((s) => s.denne != null).length}>
          <thead>
            <tr><th>Nummer</th><th>Bonger</th><th>Omsetning</th><th>Avvik</th></tr>
          </thead>
          <tbody>
            {system.filter((s) => s.denne != null).map((s) => (
              <tr key={s.nr}>
                <td>{s.nr}</td>
                <td>{tall.format(s.denne!.bonger)}</td>
                <td><Kroner v={s.denne!.omsetning_kr} /></td>
                <td><Kroner v={s.denne!.avvikKr} /></td>
              </tr>
            ))}
          </tbody>
        </Datatabell>
      )}

      {systemBonger > 0 && (
        <Forklaring sporsmaal="Hva er «kassa selv»?">
          <strong>{tall.format(systemBonger)}</strong> av månedens bonger ligger på
          kassanumre som ikke er en medarbeider — 999999 og liknende.
          Det er{' '}
          {total.bonger + systemBonger > 0
            ? `${Math.round(systemBonger / (total.bonger + systemBonger) * 100)} %`
            : '—'}{' '}
          av alt, og de holdes utenfor tallene per kasserer. De er ikke slettet:
          de står i tabellen over, slik at stasjonens volum fortsatt går opp.
        </Forklaring>
      )}

      <Datatabell tittel="Måned for måned" antall={maaneder.length}>
        <thead>
          <tr>
            <th>Måned</th><th>Bonger</th><th>Makulert</th>
            <th>Retur og slettet</th><th>Per 100 bonger</th>
          </tr>
        </thead>
        <tbody>
          {maaneder.map((m) => {
            const t = totaltFor(rader, m)
            const mak = rader.filter((r) => r.maned === m && !system.some((s) => s.nr === r.kasserer_nr))
              .reduce((n, r) => n + r.makulert_kr, 0)
            const rs = rader.filter((r) => r.maned === m && !system.some((s) => s.nr === r.kasserer_nr))
              .reduce((n, r) => n + r.retur_kr + r.slettet_kr, 0)
            return (
              <tr key={m}>
                <td><Link href={lenke(m)}>{manedAar.format(new Date(m))}</Link></td>
                <td>{tall.format(t.bonger)}</td>
                <td><Kroner v={mak} /></td>
                <td><Kroner v={rs} /></td>
                <td><Rate v={t.krPer100} bonger={t.bonger} /></td>
              </tr>
            )
          })}
        </tbody>
      </Datatabell>

      <AiKontekst
        tekst="Forklar kassererbildet denne måneden"
        sporsmal={`Hvordan ser kassererstatistikken ut i ${manedAar.format(new Date(valgtMaaned))}? `
          + 'Del opp i makulert, retur og slettet, og se på avvik per 100 bonger. '
          + 'Ikke rangér kasserere mot hverandre.'}
      />
    </>
  )
}

function Kroner({ v }: { v: number | null }) {
  return <>{v == null ? '—' : kr.format(Math.round(v))}</>
}

/**
 * Denne måneden mot kassererens eget snitt.
 *
 * TALLET STÅR UTEN FARGE OG UTEN DOM. Det er en observasjon — «du ligger
 * over det du pleier» — ikke en påstand om at noe er galt. Målingen sier
 * at svingningen innenfor én kasserer er stor, så et utslag her er langt
 * oftere en travel måned enn noe annet.
 */
function MotEget({ k }: { k: Kassererbilde }) {
  if (k.motEgetSnitt == null || !nokGrunnlag(k.denne?.bonger ?? 0)) {
    return (
      <span className="sq-dempet" title={k.egneMaaneder === 0 ? 'Ingen tidligere måneder å måle mot' : 'For lite grunnlag denne måneden'}>
        {k.egneMaaneder === 0 ? 'ingen historikk' : '—'}
      </span>
    )
  }
  const d = Math.round(k.motEgetSnitt)
  return (
    <span title={`Eget snitt over ${k.egneMaaneder} tidligere måneder: ${kr.format(Math.round(k.egetSnitt as number))}`}>
      {d > 0 ? '+' : ''}{kr.format(d)}
    </span>
  )
}
