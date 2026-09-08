import { Fragment } from 'react'
import Link from 'next/link'
import { TabletHode } from '../tablet-hode'
import { hentInnloggetBruker } from '@/lib/auth/dal'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import { datoLang } from '@/lib/format'
import { Sidehode } from '@/components/ui/side'
import { osloNaa, skjemaAktiv, rutineGjelder, VAKTTYPE_ETIKETT, type Vaktvindu } from '@/lib/rutineskjema'
import { beregnRutinestat } from '@/lib/rutinestat'
import { oversettMange } from '@/lib/oversett'
import { maaVaereHele } from '@/lib/supabase/datobolker'
import { Konfetti } from '../konfetti'
import { Vaktvelger, type Vakt } from './vaktvelger'
import { BildeRad } from './bilderad'
import { kryssAv, kryssAvMedBilde, fjernKryss, lagreNotat } from './handlinger'

type Skjema = { id: string; stasjon_id: string; vakttype: string; navn: string | null; tid_start: string; tid_slutt: string; ukedager: number[] }
type Rutine = { id: string; skjema_id: string | null; stasjon_id: string; tittel: string; beskrivelse: string | null; ukedager: number[]; opprettet_dato: string; paakrevd_bilde: boolean; ikmat_frekvens: string | null }
type IkPunkt = { id: string; stasjon_id: string; frekvens: string }

export default async function RutinerSide() {
  const bruker = await hentInnloggetBruker()
  if (bruker.rolle === 'plattform_redaktor') return <p>Ingen tilgang.</p>
  const erLeder = bruker.rolle === 'retailer_admin' || bruker.rolle === 'butikksjef'

  const supabase = await lagSupabaseServerKlient()
  const naa = osloNaa(new Date())

  // =================================================================
  // INGEN AV DISSE HADDE EN GRENSE, OG DET KOSTET
  // =================================================================
  // PostgREST kutter paa tusen rader UTEN aa feile. Boenes meldte 68
  // rutiner igjen som folk nettopp hadde gjort ferdig: utfoeringene for
  // dagens vaktdatoer, over alle stasjoner, ligger rundt tusen rader, og
  // da falt Boenes sine utenfor. Det ser ikke ut som en feil - det ser
  // ut som at ingen har gjort jobben sin.
  //
  // Grensene under er ikke oensker om faerre rader. De er steder aa
  // OPPDAGE at det ble for mange: `maaVaereHele` kaster naar en
  // spoerring naar sin egen grense, framfor aa svare halvt.
  const [stasjonSvar, skjemaSvar, rutineSvar, ikPunktSvar, ikIdagSvar] = await Promise.all([
    supabase.from('stasjoner').select('id, navn, butikknummer').is('slettet_tid', null).order('butikknummer').limit(500),
    supabase.from('rutineskjemaer').select('id, stasjon_id, vakttype, navn, tid_start, tid_slutt, ukedager').eq('aktiv', true).is('slettet_tid', null).limit(2000).overrideTypes<Skjema[]>(),
    // 336 rutiner hos Kelsar i dag. Grensen er satt der den ikke kan naas
    // av en kjede paa fem stasjoner, men vil naas av en paa femti - og
    // da skal den si fra, ikke lyve.
    supabase.from('rutiner').select('id, skjema_id, stasjon_id, tittel, beskrivelse, ukedager, opprettet_dato, paakrevd_bilde, ikmat_frekvens').not('skjema_id', 'is', null).is('slettet_tid', null).order('sortering').limit(10000).overrideTypes<Rutine[]>(),
    supabase.from('ik_kontrollpunkter').select('id, stasjon_id, frekvens').is('slettet_tid', null).limit(2000).overrideTypes<IkPunkt[]>(),
    supabase.from('ik_avlesninger').select('kontrollpunkt_id').eq('dato', naa.dato).limit(5000).overrideTypes<{ kontrollpunkt_id: string }[]>(),
  ])
  const stasjoner = maaVaereHele(stasjonSvar, 'stasjonene', 500)
  const skjemaer = maaVaereHele(skjemaSvar, 'rutineskjemaene', 2000)
  const rutiner = maaVaereHele(rutineSvar, 'rutinene', 10000)
  const ikPunkter = maaVaereHele(ikPunktSvar, 'IK-kontrollpunktene', 2000)
  const ikIdag = maaVaereHele(ikIdagSvar, 'dagens IK-avlesninger', 5000)

  // IK-mat: enheter pr stasjon + hva som er målt i dag (for auto-haking).
  const ikPerStasjon = new Map<string, IkPunkt[]>()
  for (const p of ikPunkter) { const l = ikPerStasjon.get(p.stasjon_id) ?? []; l.push(p); ikPerStasjon.set(p.stasjon_id, l) }
  const maaltIdag = new Set(ikIdag.map((a) => a.kontrollpunkt_id))
  // Due-enheter for en IK-mat-rutine, og hvor mange som er målt.
  const ikmatStatus = (r: Rutine) => {
    const due = (ikPerStasjon.get(r.stasjon_id) ?? []).filter((p) => p.frekvens === r.ikmat_frekvens)
    const malt = due.filter((p) => maaltIdag.has(p.id)).length
    return { antall: due.length, malt, ferdig: due.length > 0 && malt === due.length }
  }

  // Aktive skjemaer nå (med vaktvindu)
  const aktive: { skjema: Skjema; vindu: Vaktvindu }[] = []
  for (const s of skjemaer as unknown as Skjema[]) {
    const vindu = skjemaAktiv(s, naa)
    if (vindu.aktiv) aktive.push({ skjema: s, vindu })
  }

  // Rutiner pr skjema, filtrert på vakten
  const rutinerForSkjema = new Map<string, Rutine[]>()
  for (const r of rutiner as unknown as Rutine[]) {
    if (!r.skjema_id) continue
    const l = rutinerForSkjema.get(r.skjema_id) ?? []
    l.push(r)
    rutinerForSkjema.set(r.skjema_id, l)
  }

  // Hent utføringer for de aktuelle vaktdatoene
  const datoer = [...new Set(aktive.map((a) => a.vindu.vaktdato))]
  // Stasjonene som faktisk har vakt naa. Uten dette filteret hentes
  // utfoeringer for hver stasjon i kjeden, ogsaa dem ingen ser paa.
  const aktiveStasjoner = [...new Set(aktive.map((a) => a.skjema.stasjon_id))]
  const utfortMap = new Map<string, string | null>() // key -> bilde_sti
  if (datoer.length > 0) {
    // DEN SOM MELDTE 68 IGJEN. Uten grense kuttet PostgREST paa tusen,
    // og Boenes sine avhukinger falt utenfor. Begrenset til stasjonene
    // som faktisk har vakt naa, og med et tak som ikke kan naas av dem.
    const svar = await supabase
      .from('rutine_utforinger')
      .select('rutine_id, dato, bilde_sti')
      .in('dato', datoer)
      .in('stasjon_id', aktiveStasjoner)
      .limit(20000)
    for (const u of maaVaereHele(svar, 'utførte rutiner', 20000) as { rutine_id: string; dato: string; bilde_sti: string | null }[]) {
      utfortMap.set(`${u.rutine_id}|${u.dato}`, u.bilde_sti)
    }
  }
  // Gjort = vanlig rutine avhuket, ELLER IK-mat-gruppe ferdig målt i dag.
  const erGjort = (r: Rutine, vaktdato: string) => (r.ikmat_frekvens ? ikmatStatus(r).ferdig : utfortMap.has(`${r.id}|${vaktdato}`))
  // Notatene for de samme vaktdatoene. Egen tabell (0170), aldri
  // `rutine_utforinger` - et notat betyr ikke at rutinen er gjort.
  const notatFor = new Map<string, string>()
  if (datoer.length > 0) {
    const svar = await supabase
      .from('rutine_notat')
      .select('rutine_id, dato, tekst')
      .in('dato', datoer)
      .in('stasjon_id', aktiveStasjoner)
      .limit(20000)
    for (const n of maaVaereHele(svar, 'rutinenotatene', 20000) as { rutine_id: string; dato: string; tekst: string }[]) {
      notatFor.set(`${n.rutine_id}|${n.dato}`, n.tekst)
    }
  }

  // Batchede signerte URL-er for bildebevis (aldri i loop, §15)
  const stier = [...utfortMap.values()].filter((s): s is string => Boolean(s))
  const signertFor = new Map<string, string>()
  if (stier.length > 0) {
    const { data } = await supabase.storage.from('rutinebilder').createSignedUrls(stier, 60 * 30)
    for (const s of data ?? []) if (s.signedUrl && s.path) signertFor.set(s.path, s.signedUrl)
  }

  const navnFor = new Map(stasjoner.map((s) => [s.id, `${s.butikknummer} ${s.navn}`]))
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
    'Mer om rutinen', 'Lagre kommentar', 'Kommentar til rutinen',
    'Kommentar — f.eks. hva som ikke lot seg gjøre',
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
  // =================================================================
  // TALLET GJELDER ÉN STASJON, IKKE SUMMEN OVER ALLE
  // =================================================================
  // «104 igjen» sto i tittelen paa Boenes. Femtifem av dem var Boenes;
  // resten var de andre stasjonene. `igjenTotalt` summerte over hver
  // stasjon med aktiv vakt, og for en eier med fem butikker er det et
  // svar paa et spoersmaal ingen stilte.
  //
  // Paa nettbrettet finnes bare én stasjon, saa der er det samme tall.
  // For lederen sier tittelen naa hvor mange stasjoner det gjelder,
  // framfor aa la ett tall se ut som ett sted.
  const igjenPerStasjon = new Map<string, number>()
  const totaltPerStasjon = new Map<string, number>()
  for (const [sid, liste] of perStasjon) {
    let igjen = 0
    let totalt = 0
    for (const { skjema } of liste) {
      const v = perSkjema.get(skjema.id)
      igjen += v?.aapne.length ?? 0
      totalt += v?.rs0.length ?? 0
    }
    igjenPerStasjon.set(sid, igjen)
    totaltPerStasjon.set(sid, totalt)
  }
  const igjenTotalt = [...igjenPerStasjon.values()].reduce((a, b) => a + b, 0)
  const totaltPaaVakt = [...totaltPerStasjon.values()].reduce((a, b) => a + b, 0)
  // Nettbrettet står i én butikk, og hun som holder det vet hvilken.
  // Styrt av ROLLE, ikke av antall stasjoner: en leder som ser på klokka
  // 07 når bare Bønes har aktiv vakt, skal fortsatt se hvilken butikk
  // tallene gjelder.
  const paaNettbrett = bruker.rolle === 'butikkbruker_tablet'

  // Svaret er det samme for begge rollene; bare rammen rundt er ulik.
  //
  // ETT TALL SKAL GJELDE ETT STED. Ser lederen flere stasjoner samtidig,
  // sier tittelen det - ellers leses summen som én butikks arbeidsmengde.
  const antallStasjoner = perStasjon.size
  const svaret = totaltPaaVakt === 0
    ? o('Ingen rutiner på vakta nå') ?? 'Ingen rutiner på vakta nå'
    : igjenTotalt === 0
      ? o('Alt er gjort') ?? 'Alt er gjort'
      : !paaNettbrett && antallStasjoner > 1
        ? `${igjenTotalt} igjen på ${antallStasjoner} stasjoner`
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
            {/* ÉN VAKT OM GANGEN PAA NETTBRETTET, STABLET FOR LEDEREN.
                Overlappen paa +/- 60 min gjoer at to vakter er aktive
                rundt skiftet. Den som staar i butikken skal se sitt eget
                skift; lederen ser paa flere vakter samtidig med vilje, og
                for henne er stabelen fortsatt riktig form. */}
            {(() => {
            const vakter: Vakt[] = liste.map(({ skjema, vindu }) => {
              const { rs0, aapne, ferdige } = perSkjema.get(skjema.id)!
              const ferdigN = ferdige.length
              const totalt = rs0.length
              const alleFerdig = totalt > 0 && ferdigN === totalt
              const pst = totalt > 0 ? Math.round((ferdigN / totalt) * 100) : 0
              const igjen = totalt - ferdigN
              const mikro = alleFerdig ? o('Alt klart!') : igjen === 1 ? o('1 igjen — nesten i mål!') : `${igjen} ${o('igjen')}`
              // =========================================================
              // NETTBRETTETS RAD
              // =========================================================
              // Robert: «rutiner der er veldig lite oversiktelig».
              //
              // Tre ting sto i veien, og alle tre var plassering:
              //
              //   BESKRIVELSEN LAA BAK ET «?» paa 26 piksler. Det er
              //   instruksjonen en ny ansatt trenger - «hva betyr rydd
              //   bakrom» - og det var det vanskeligste aa treffe paa
              //   hele skjermen. Naa staar den paa raden.
              //
              //   BARE RUTA VAR TRYKKFLATE. 56 piksler av en rad paa
              //   flere hundre. Med hansker paa bommer man, og da hakes
              //   ingenting av - eller feil rad. Naa er hele raden
              //   knappen.
              //
              //   BILDERUTINENE SAA UT SOM NOE ANNET. De byttet form
              //   helt: filvelger og egen knapp, ingen avkryssingsrute.
              //   Naa er raden lik, og hele flaten aapner kameraet.
              //
              // KOMMENTAREN BLIR IGJEN BAK ET IKON, og det er riktig -
              // aa LESE og aa SKRIVE er to forskjellige aerend. Det som
              // flyttet ut er lesingen.
              //
              // BARE NETTBRETTET. Lederen har en tett liste hun skanner;
              // to linjer per rad ville gjort femtifem rutiner til en
              // rulletur. `rad` under er hennes, uendret.
              const radNettbrett = (r: Rutine) => {
                const key = `${r.id}|${vindu.vaktdato}`
                const felt = (
                  <>
                    <input type="hidden" name="rutine_id" value={r.id} />
                    <input type="hidden" name="stasjon_id" value={r.stasjon_id} />
                    <input type="hidden" name="dato" value={vindu.vaktdato} />
                  </>
                )
                if (r.ikmat_frekvens) {
                  const st = ikmatStatus(r)
                  return (
                    <li key={r.id} className={`tr-rad ${st.ferdig ? 'gjort' : ''}`}>
                      <Link
                        href={`/ikmat/maaling?stasjon=${r.stasjon_id}&frekvens=${r.ikmat_frekvens}`}
                        className="tr-trykk"
                      >
                        <span className={`tr-hak ${st.ferdig ? 'av' : ''}`} aria-hidden>{st.ferdig ? '✓' : ''}</span>
                        <span className="tr-tekst">
                          <span className="tr-tittel">{o(r.tittel)}</span>
                          {r.beskrivelse ? <span className="tr-hjelp">{o(r.beskrivelse)}</span> : null}
                          <span className="tr-merker">
                            <span className="tr-merke maaling">{st.malt}/{st.antall} {o('målt')}</span>
                          </span>
                        </span>
                        <span className="tr-pil" aria-hidden>›</span>
                      </Link>
                    </li>
                  )
                }
                const gjort = utfortMap.has(key)
                const lagretSti = utfortMap.get(key)
                const bildeUrl = lagretSti ? signertFor.get(lagretSti) : undefined
                const kropp = (
                  <>
                    <span className={`tr-hak ${gjort ? 'av' : ''}`} aria-hidden>{gjort ? '✓' : ''}</span>
                    <span className="tr-tekst">
                      <span className="tr-tittel">{o(r.tittel)}</span>
                      {r.beskrivelse ? <span className="tr-hjelp">{o(r.beskrivelse)}</span> : null}
                      {r.paakrevd_bilde ? (
                        <span className="tr-merker">
                          <span className="tr-merke bilde">{o('Ta bilde')}</span>
                        </span>
                      ) : null}
                    </span>
                  </>
                )
                return (
                  <li key={r.id} className={`tr-rad ${gjort ? 'gjort' : ''}`}>
                    {r.paakrevd_bilde && !gjort ? (
                      /* HELE RADEN AAPNER KAMERAET, og skjemaet sender
                         seg selv naar bildet er valgt. `required` sto her
                         paa et USYNLIG felt: nettleseren nekter aa sende
                         et ugyldig felt den ikke kan vise, og skriver
                         det i en konsoll ingen har aapen. Da skjer
                         ingenting, og eneste utvei er aa laste paa nytt.
                         Kravet ligger paa serveren, som kan svare. */
                      <BildeRad
                        handling={kryssAvMedBilde}
                        felt={felt}
                        kropp={kropp}
                        etikett={o('Ta bilde') ?? 'Ta bilde'}
                        lagreOrd={o('Lagre bilde') ?? 'Lagre bilde'}
                      />
                    ) : (
                      <form action={gjort ? fjernKryss : kryssAv} className="tr-form">
                        {felt}
                        <button
                          type="submit" className="tr-trykk"
                          aria-label={gjort ? 'Fjern kryss' : 'Kryss av'}
                        >
                          {kropp}
                        </button>
                      </form>
                    )}
                    {/* AA LESE OG AA SKRIVE ER TO AERENDER. Beskrivelsen
                        staar paa raden; kommentaren blir igjen her. */}
                    <details className="rutine-mer tr-mer">
                      <summary aria-label={o('Kommentar til rutinen') ?? 'Kommentar til rutinen'}>⋯</summary>
                      <form action={lagreNotat} className="rutine-notat">
                        {felt}
                        <textarea
                          name="tekst"
                          rows={2}
                          defaultValue={notatFor.get(key) ?? ''}
                          placeholder={o('Kommentar — f.eks. hva som ikke lot seg gjøre') ?? ''}
                          aria-label={o('Kommentar til rutinen') ?? 'Kommentar til rutinen'}
                        />
                        <button type="submit" className="sq-knapp">{o('Lagre kommentar')}</button>
                      </form>
                    </details>
                    {bildeUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <a href={bildeUrl} target="_blank" rel="noopener" className="bevis-lenke"><img src={bildeUrl} alt="Bevis" className="bevis-bilde" /></a>
                    )}
                  </li>
                )
              }

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
                        <button type="submit" className="sq-knapp primar" aria-label="Kryss av med bilde">{o('Lagre bilde')}</button>
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
                      {r.paakrevd_bilde ? <span className="bilde-merke">{o('krever bilde')}</span> : null}
                      {/* NOTISEN STAAR BAK ?-IKONET, ikke inline. Skjemaet
                          lover det («vises bak ?-ikon paa tableten»), og
                          en utfyllende fremgangsmaate paa hver linje ville
                          gjort lista uleselig paa en vakt. Kommentaren
                          ligger samme sted: den hoerer til rutinen, og skal
                          kunne skrives ENTEN den ble gjort eller ikke. */}
                      <details className="rutine-mer">
                        <summary aria-label={o('Mer om rutinen') ?? 'Mer om rutinen'}>?</summary>
                        {r.beskrivelse ? <p className="rutine-notis">{o(r.beskrivelse)}</p> : null}
                        <form action={lagreNotat} className="rutine-notat">
                          <input type="hidden" name="rutine_id" value={r.id} />
                          <input type="hidden" name="stasjon_id" value={r.stasjon_id} />
                          <input type="hidden" name="dato" value={vindu.vaktdato} />
                          <textarea
                            name="tekst"
                            rows={2}
                            defaultValue={notatFor.get(`${r.id}|${vindu.vaktdato}`) ?? ''}
                            placeholder={o('Kommentar — f.eks. hva som ikke lot seg gjøre') ?? ''}
                            aria-label={o('Kommentar til rutinen') ?? 'Kommentar til rutinen'}
                          />
                          <button type="submit" className="sq-knapp">{o('Lagre kommentar')}</button>
                        </form>
                      </details>
                    </div>
                    {bildeUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <a href={bildeUrl} target="_blank" rel="noopener" className="bevis-lenke"><img src={bildeUrl} alt="Bevis" className="bevis-bilde" /></a>
                    )}
                  </li>
                )
              }
              const innhold = (
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
                      {aapne.length > 0 && (
                        <ul className={paaNettbrett ? 'tr-liste' : 'rutine-liste'}>
                          {aapne.map(paaNettbrett ? radNettbrett : rad)}
                        </ul>
                      )}
                      {ferdige.length > 0 && (
                        <details className="ferdige-rutiner">
                          <summary>✓ {o('Ferdige')} ({ferdige.length})</summary>
                          <ul className={paaNettbrett ? 'tr-liste' : 'rutine-liste'}>
                            {ferdige.map(paaNettbrett ? radNettbrett : rad)}
                          </ul>
                        </details>
                      )}
                    </>
                  )}
                </div>
              )
              return {
                id: skjema.id,
                etikett: `${o(VAKTTYPE_ETIKETT[skjema.vakttype])}${skjema.navn ? ` · ${skjema.navn}` : ''}`,
                tid: `${skjema.tid_start}–${skjema.tid_slutt}`,
                igjen, totalt, kjerne: vindu.kjerne, innhold,
              }
            })
            // ET TOMT SKJEMA ER IKKE EN VAKT AA JOBBE PAA.
            //
            // Boenes hadde et «morgen»-skjema 06:00-14:00 med NULL
            // rutiner ved siden av det ekte paa 04:00-15:00. Det gjorde
            // ingenting annet enn aa telle som en aktiv vakt og gi en
            // tredje fane som aapnet seg til ingenting.
            //
            // Skjult BARE paa nettbrettet. For lederen er et tomt skjema
            // et funn - det er hun som kan rydde det bort i
            // Rutineoppsett - og der staar «Ingen rutiner for denne
            // vakten i dag» fortsatt.
            const synlige = paaNettbrett ? vakter.filter((v) => v.totalt > 0) : vakter
            if (!paaNettbrett) {
              return <>{vakter.map((v) => <Fragment key={v.id}>{v.innhold}</Fragment>)}</>
            }
            return synlige.length > 0
              ? <Vaktvelger vakter={synlige} igjenOrd={o('igjen') ?? 'igjen'} />
              : <p className="undertittel">{o('Ingen rutiner på vakta nå')}</p>
            })()}
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
