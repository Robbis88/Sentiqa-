import Link from 'next/link'
import { TabletHode } from '../tablet-hode'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { Sidehode } from '@/components/ui/side'
import { osloNaa, skjemaAktiv, rutineGjelder, VAKTTYPE_ETIKETT, type Vaktvindu } from '@/lib/rutineskjema'
import { beregnRutinestat } from '@/lib/rutinestat'
import { oversettMange } from '@/lib/oversett'
import { Konfetti } from '../konfetti'
import { kryssAv, kryssAvMedBilde, fjernKryss } from './handlinger'

type Skjema = { id: string; stasjon_id: string; vakttype: string; navn: string | null; tid_start: string; tid_slutt: string; ukedager: number[] }
type Rutine = { id: string; skjema_id: string | null; stasjon_id: string; tittel: string; beskrivelse: string | null; ukedager: number[]; opprettet_dato: string; paakrevd_bilde: boolean; ikmat_frekvens: string | null }
type IkPunkt = { id: string; stasjon_id: string; frekvens: string }

export default async function RutinerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const naa = osloNaa(new Date())

  const [{ data: stasjoner }, { data: skjemaer }, { data: rutiner }, { data: ikPunkter }, { data: ikIdag }] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer'),
    supabase.from('rutineskjemaer').select('id, stasjon_id, vakttype, navn, tid_start, tid_slutt, ukedager').eq('aktiv', true).is('slettet_tid', null).overrideTypes<Skjema[]>(),
    supabase.from('rutiner').select('id, skjema_id, stasjon_id, tittel, beskrivelse, ukedager, opprettet_dato, paakrevd_bilde, ikmat_frekvens').not('skjema_id', 'is', null).is('slettet_tid', null).order('sortering').overrideTypes<Rutine[]>(),
    supabase.from('ik_kontrollpunkter').select('id, stasjon_id, frekvens').is('slettet_tid', null).overrideTypes<IkPunkt[]>(),
    supabase.from('ik_avlesninger').select('kontrollpunkt_id').eq('dato', naa.dato).overrideTypes<{ kontrollpunkt_id: string }[]>(),
  ])

  // IK-mat: enheter pr stasjon + hva som er målt i dag (for auto-haking).
  const ikPerStasjon = new Map<string, IkPunkt[]>()
  for (const p of ikPunkter ?? []) { const l = ikPerStasjon.get(p.stasjon_id) ?? []; l.push(p); ikPerStasjon.set(p.stasjon_id, l) }
  const maaltIdag = new Set((ikIdag ?? []).map((a) => a.kontrollpunkt_id))
  // Due-enheter for en IK-mat-rutine, og hvor mange som er målt.
  const ikmatStatus = (r: Rutine) => {
    const due = (ikPerStasjon.get(r.stasjon_id) ?? []).filter((p) => p.frekvens === r.ikmat_frekvens)
    const malt = due.filter((p) => maaltIdag.has(p.id)).length
    return { antall: due.length, malt, ferdig: due.length > 0 && malt === due.length }
  }

  // Aktive skjemaer nå (med vaktvindu)
  const aktive: { skjema: Skjema; vindu: Vaktvindu }[] = []
  for (const s of (skjemaer ?? []) as unknown as Skjema[]) {
    const vindu = skjemaAktiv(s, naa)
    if (vindu.aktiv) aktive.push({ skjema: s, vindu })
  }

  // Rutiner pr skjema, filtrert på vakten
  const rutinerForSkjema = new Map<string, Rutine[]>()
  for (const r of (rutiner ?? []) as unknown as Rutine[]) {
    if (!r.skjema_id) continue
    const l = rutinerForSkjema.get(r.skjema_id) ?? []
    l.push(r)
    rutinerForSkjema.set(r.skjema_id, l)
  }

  // Hent utføringer for de aktuelle vaktdatoene
  const datoer = [...new Set(aktive.map((a) => a.vindu.vaktdato))]
  const utfortMap = new Map<string, string | null>() // key -> bilde_sti
  if (datoer.length > 0) {
    const { data } = await supabase.from('rutine_utforinger').select('rutine_id, dato, bilde_sti').in('dato', datoer)
    for (const u of (data ?? []) as { rutine_id: string; dato: string; bilde_sti: string | null }[]) {
      utfortMap.set(`${u.rutine_id}|${u.dato}`, u.bilde_sti)
    }
  }
  // Gjort = vanlig rutine avhuket, ELLER IK-mat-gruppe ferdig målt i dag.
  const erGjort = (r: Rutine, vaktdato: string) => (r.ikmat_frekvens ? ikmatStatus(r).ferdig : utfortMap.has(`${r.id}|${vaktdato}`))
  // Batchede signerte URL-er for bildebevis (aldri i loop, §15)
  const stier = [...utfortMap.values()].filter((s): s is string => Boolean(s))
  const signertFor = new Map<string, string>()
  if (stier.length > 0) {
    const { data } = await supabase.storage.from('rutinebilder').createSignedUrls(stier, 60 * 30)
    for (const s of data ?? []) if (s.signedUrl && s.path) signertFor.set(s.path, s.signedUrl)
  }

  const navnFor = new Map((stasjoner ?? []).map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
  // Grupper aktive skjemaer pr stasjon
  const perStasjon = new Map<string, { skjema: Skjema; vindu: Vaktvindu }[]>()
  for (const a of aktive) {
    const l = perStasjon.get(a.skjema.stasjon_id) ?? []
    l.push(a)
    perStasjon.set(a.skjema.stasjon_id, l)
  }

  // Streak pr aktiv stasjon (motivasjon)
  const streaks = new Map<string, number>()
  await Promise.all(
    [...perStasjon.keys()].map(async (sid) => {
      const st = await beregnRutinestat(supabase, sid, naa.dato)
      streaks.set(sid, st.streak)
    }),
  )

  // Flerspråk: oversett rutinetekstene til valgt språk (cache + Haiku).
  // Oversettelse kun for tableten; admin/butikksjef ser alltid norsk.
  const { cookies } = await import('next/headers')
  const sprak = bruker.rolle === 'butikkbruker_tablet' ? ((await cookies()).get('sprak')?.value ?? 'no') : 'no'
  const tekster: string[] = [
    'Alt klart!', '1 igjen — nesten i mål!', 'igjen', 'Ferdige',
    'Alt er gjort', 'Ingen rutiner på vakta nå', 'dager på rad',
    'Lagre bilde', 'krever bilde', 'målt', 'trykk for å måle',
    // Foten som gir vei til IK-mat og Produksjon (bolge 5).
    'Mer rutinearbeid', 'IK-mat', 'Alle kontrollpunkter, gruppert',
    'Produksjon', 'Dagens plan',
    ...Object.values(VAKTTYPE_ETIKETT),
  ]
  for (const { skjema, vindu } of aktive) {
    for (const r of (rutinerForSkjema.get(skjema.id) ?? []).filter((rr) => rutineGjelder(rr, vindu))) {
      tekster.push(r.tittel)
      if (r.beskrivelse) tekster.push(r.beskrivelse)
    }
  }
  const oversatt = await oversettMange(tekster, sprak)
  const o = (t: string | null) => (t ? oversatt.get(t) ?? t : t)

  // NIVÅ 1 på nettbrettet: hva gjenstår på skiftet mitt.
  //
  // Sida åpnet med «Rutiner» og «Aktiv vakt nå · 18. august» — modulnavnet
  // og datoen. Den som står der med hansker på vil vite ett tall: hvor
  // mange igjen. Regnestykket lå inne i JSX-en, per skjema, og fantes
  // aldri som en sum.
  const perSkjema = new Map<string, { rs0: Rutine[]; aapne: Rutine[]; ferdige: Rutine[] }>()
  for (const { skjema, vindu } of aktive) {
    const rs0 = (rutinerForSkjema.get(skjema.id) ?? [])
      .filter((r) => rutineGjelder(r, vindu))
      // Skjul IK-mat-kort uten enheter å måle for gruppen.
      .filter((r) => !r.ikmat_frekvens || ikmatStatus(r).antall > 0)
    perSkjema.set(skjema.id, {
      rs0,
      aapne: rs0.filter((r) => !erGjort(r, vindu.vaktdato)),
      ferdige: rs0.filter((r) => erGjort(r, vindu.vaktdato)),
    })
  }
  const igjenTotalt = [...perSkjema.values()].reduce((n, v) => n + v.aapne.length, 0)
  const totaltPaaVakt = [...perSkjema.values()].reduce((n, v) => n + v.rs0.length, 0)
  // Nettbrettet står i én butikk, og hun som holder det vet hvilken.
  // Styrt av ROLLE, ikke av antall stasjoner: en leder som ser på klokka
  // 07 når bare Bønes har aktiv vakt, skal fortsatt se hvilken butikk
  // tallene gjelder.
  const paaNettbrett = bruker.rolle === 'butikkbruker_tablet'

  // Svaret er det samme for begge rollene; bare rammen rundt er ulik.
  const svaret = totaltPaaVakt === 0
    ? o('Ingen rutiner på vakta nå') ?? 'Ingen rutiner på vakta nå'
    : igjenTotalt === 0
      ? o('Alt er gjort') ?? 'Alt er gjort'
      : `${igjenTotalt} ${o('igjen')}`

  return (
    <>
      {/* DEN SISTE STIL-LEKKASJEN. `.tablet-hode` er tegnet for moerkt
          underlag, og sto paa BEGGE roller her - paa lederens lyse side
          ga det samme 1,9:1 som /ikmat hadde, og den sto oppfoert som et
          kjent unntak i port0-4b.spec.ts fram til bolge 5.
          Svaret er det samme for begge: hvor mange igjen. Formen er det
          ikke. */}
      {paaNettbrett ? (
        <TabletHode tittel={svaret} undertittel={datoLang.format(new Date(naa.dato))} />
      ) : (
        <Sidehode
          tittel={svaret}
          undertittel={datoLang.format(new Date(naa.dato))}
          handlinger={erLeder
            ? <Link href="/rutiner/oppsett" className="sq-knapp">Rutineoppsett</Link>
            : undefined}
        />
      )}

      {perStasjon.size === 0 ? (
        <section className="kort">
          <p className="undertittel">
            Ingen aktiv vakt akkurat nå.{erLeder ? <> Sett opp vakttype-skjemaer under <Link href="/rutiner/oppsett">Rutineoppsett</Link>.</> : ''}
          </p>
        </section>
      ) : (
        [...perStasjon.entries()].map(([sid, liste]) => (
          <section className="kort" key={sid}>
            {/* Stasjonsnavnet er for lederen. Står nettbrettet på én
                stasjon, vet den som holder det hvilken butikk hun er i. */}
            {!paaNettbrett && <h2>{navnFor.get(sid) ?? '—'}</h2>}
            {(streaks.get(sid) ?? 0) > 0 && (
              <p className="streak">{streaks.get(sid)} {o('dager på rad')}</p>
            )}
            {liste.map(({ skjema, vindu }) => {
              const { rs0, aapne, ferdige } = perSkjema.get(skjema.id)!
              const ferdigN = ferdige.length
              const totalt = rs0.length
              const alleFerdig = totalt > 0 && ferdigN === totalt
              const pst = totalt > 0 ? Math.round((ferdigN / totalt) * 100) : 0
              const igjen = totalt - ferdigN
              const mikro = alleFerdig ? o('Alt klart!') : igjen === 1 ? o('1 igjen — nesten i mål!') : `${igjen} ${o('igjen')}`
              // Én rutine-rad (gjenbrukes for åpne + ferdige).
              const rad = (r: Rutine) => {
                const key = `${r.id}|${vindu.vaktdato}`
                if (r.ikmat_frekvens) {
                  const st = ikmatStatus(r)
                  return (
                    <li key={r.id} className={`ikmat-rutine ${st.ferdig ? 'gjort' : ''}`}>
                      {/* Sto med termometer-emoji naar den ikke var gjort.
                          Ruta er tom til den er haket av, akkurat som de
                          andre - det er formen som sier hva som gjenstaar. */}
                      <span className={`kryss ${st.ferdig ? 'av' : ''}`} aria-hidden>{st.ferdig ? '✓' : ''}</span>
                      <Link href={`/ikmat/maaling?stasjon=${r.stasjon_id}&frekvens=${r.ikmat_frekvens}`} className="rutine-tekst ikmat-lenke">
                        <strong>{o(r.tittel)}</strong>
                        <span className="undertittel"> — {st.malt}/{st.antall} {o('målt')}{st.ferdig ? '' : ` · ${o('trykk for å måle')}`}</span>
                      </Link>
                    </li>
                  )
                }
                const gjort = utfortMap.has(key)
                const lagretSti = utfortMap.get(key)
                const bildeUrl = lagretSti ? signertFor.get(lagretSti) : undefined
                return (
                  <li key={r.id} className={gjort ? 'gjort' : ''}>
                    {r.paakrevd_bilde && !gjort ? (
                      <form action={kryssAvMedBilde} className="bilde-kryss">
                        <input type="hidden" name="rutine_id" value={r.id} />
                        <input type="hidden" name="stasjon_id" value={r.stasjon_id} />
                        <input type="hidden" name="dato" value={vindu.vaktdato} />
                        <input type="file" name="bilde" accept="image/*" capture="environment" required aria-label="Ta bilde" />
                        <button type="submit" className="sq-knapp" aria-label="Kryss av med bilde">{o('Lagre bilde')}</button>
                      </form>
                    ) : (
                      <form action={gjort ? fjernKryss : kryssAv}>
                        <input type="hidden" name="rutine_id" value={r.id} />
                        <input type="hidden" name="stasjon_id" value={r.stasjon_id} />
                        <input type="hidden" name="dato" value={vindu.vaktdato} />
                        <button type="submit" className={`kryss ${gjort ? 'av' : ''}`} aria-label="Kryss av">{gjort ? '✓' : ''}</button>
                      </form>
                    )}
                    <div className="rutine-tekst">
                      <strong>{o(r.tittel)}</strong>
                      {r.beskrivelse ? <span className="undertittel"> — {o(r.beskrivelse)}</span> : null}
                      {r.paakrevd_bilde ? <span className="bilde-merke">{o('krever bilde')}</span> : null}
                    </div>
                    {bildeUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <a href={bildeUrl} target="_blank" rel="noopener" className="bevis-lenke"><img src={bildeUrl} alt="Bevis" className="bevis-bilde" /></a>
                    )}
                  </li>
                )
              }
              return (
                <div className="ik-gruppe" key={skjema.id}>
                  <Konfetti aktiv={alleFerdig} nokkel={`${skjema.id}-${vindu.vaktdato}`} />
                  <h3>{o(VAKTTYPE_ETIKETT[skjema.vakttype])}{skjema.navn ? ` · ${skjema.navn}` : ''} <span className="undertittel">{skjema.tid_start}–{skjema.tid_slutt}</span></h3>
                  {totalt > 0 && (
                    <div className="fremdrift">
                      <div className="fremdrift-bar"><div className={`fremdrift-fyll ${alleFerdig ? 'full' : ''}`} style={{ width: `${pst}%` }} /></div>
                      <span className="fremdrift-tekst">{mikro}</span>
                    </div>
                  )}
                  {rs0.length === 0 ? (
                    <p className="undertittel">Ingen rutiner for denne vakten i dag.</p>
                  ) : (
                    <>
                      {aapne.length > 0 && <ul className="rutine-liste">{aapne.map(rad)}</ul>}
                      {ferdige.length > 0 && (
                        <details className="ferdige-rutiner">
                          <summary>✓ {o('Ferdige')} ({ferdige.length})</summary>
                          <ul className="rutine-liste">{ferdige.map(rad)}</ul>
                        </details>
                      )}
                    </>
                  )}
                </div>
              )
            })}
          </section>
        ))
      )}

      {/* FOTEN SOM GJOER AT IK-MAT OG PRODUKSJON IKKE TRENGER EN FANE.
          De var to av fem fliser paa hjem, i et rutenett der alt saa
          like viktig ut. Naa gjelder to veier inn, og de svarer paa
          hvert sitt sporsmaal:

            KREVER DE ARBEID I DAG   koen paa «I dag» henter dem fram,
                                     sortert etter hva som haster.
            OPPSOEKER HUN DEM SELV   herfra, fra flata der rutinearbeid
                                     hoerer hjemme.

          En fane er for et aerend man har hele tiden. «Har jeg maalt
          kjolen i dag» er ikke det — det er en rutine, og staar her. */}
      {paaNettbrett && (
        <nav className="tablet-fot" aria-label={o('Mer rutinearbeid') ?? 'Mer rutinearbeid'}>
          <Link href="/ikmat" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('IK-mat')}</strong>
              <span className="undertittel">{o('Alle kontrollpunkter, gruppert')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
          <Link href="/produksjonsplan" className="tablet-videre">
            <span className="tablet-videre-tekst">
              <strong>{o('Produksjon')}</strong>
              <span className="undertittel">{o('Dagens plan')}</span>
            </span>
            <span className="tablet-videre-pil" aria-hidden>›</span>
          </Link>
        </nav>
      )}
    </>
  )
}
