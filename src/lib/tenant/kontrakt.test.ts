// =====================================================================
// Driftvakten.
//
// Kontrakten er kilden. De genererte SQL-filene er konsekvenser. Har de
// kommet fra hverandre, feller denne PR-en.
//
//   OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant
//
// Den skriver konsekvensene på nytt — og bare dem. Klassifiseringen av
// en ny tabell blir aldri gjettet: den skal føres inn for hånd av noen
// som har tatt stilling. En gjettet rad ville gjort dekningssjekken til
// en formalitet.
// =====================================================================
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import type { Kontrakt } from './kontrakt'
import { rekkevidde, valider } from './kontrakt'
import {
  genererDekning, genererMatrise, genererMatriseDeler, IDENTITETER, maal, tillatt,
} from './generer'
import { forretningsnokler } from './skjema'

const ROT = new URL('../../../', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')
const KONTRAKT_STI = `${ROT}supabase/tenant-kontrakt.json`

const kontrakt = JSON.parse(readFileSync(KONTRAKT_STI, 'utf8')) as Kontrakt

const FILER: Array<[string, (k: Kontrakt) => string]> = [
  ['supabase/tests/tenant_dekning.sql', genererDekning],
  ['supabase/tests/rls_kanarifugl_generert.sql', genererMatrise],
]

describe('tenant-kontrakten', () => {
  it('er gyldig', () => {
    expect(valider(kontrakt)).toEqual([])
  })

  it('har minst én varm ressurs', () => {
    // KANARIFUGL. Uten varme ressurser genereres en tom matrise, og
    // «ingen funn» ville da bety «ingenting ble prøvd».
    expect(kontrakt.ressurser.filter((r) => r.data_class === 'warm').length).toBeGreaterThan(0)
  })

  // FERDIG PORT 2 = 0 UKLASSIFISERTE.
  //
  // Tallet står her, ikke i en kommentar, fordi et krav som ikke måles
  // er en intensjon. Hver gang lista krymper skal dette tallet ned —
  // og den dagen det er 0, byttes hele listemekanismen mot en tom
  // liste og `uklassifisert_tillatt` kan slettes.
  //
  // Går tallet OPP, er det en ny tabell som slapp inn uten å bli
  // klassifisert, og da skal denne si fra før dekningssjekken i CI
  // rekker det.
  const UKLASSIFISERT_NA = 26

  it(`har nøyaktig ${UKLASSIFISERT_NA} uklassifiserte igjen (ferdig Port 2 = 0)`, () => {
    expect(kontrakt.uklassifisert_tillatt.tabeller.length).toBe(UKLASSIFISERT_NA)
  })

  it('ingen uklassifisert tabell står oppført to ganger', () => {
    const t = kontrakt.uklassifisert_tillatt.tabeller
    expect(t.length).toBe(new Set(t).size)
  })

  it('en tabell står aldri både klassifisert og uklassifisert', () => {
    const klassifisert = new Set(kontrakt.ressurser.map((r) => r.tabell))
    const begge = kontrakt.uklassifisert_tillatt.tabeller.filter((t) => klassifisert.has(t))
    expect(begge).toEqual([])
  })
})

describe('forretningsnokler mot skjemaet', () => {
  const noekler = forretningsnokler(`${ROT}supabase/migrations`)

  it('finner noekler i det hele tatt', () => {
    // KANARIFUGL. Parser den ingenting, blir hele sjekken under stille.
    expect(Object.keys(noekler).length).toBeGreaterThan(20)
    expect(noekler.ansatte?.length, 'ansatte har to unike indekser').toBeGreaterThanOrEqual(2)
  })

  it('et uttrykk i en indeks er ikke en kolonne — og skjuler ingen', () => {
    // `signal_lukket_unik` er
    //   (retailer_id, coalesce(stasjon_id, '000…'::uuid), signal_id)
    // fordi null-stasjonen ellers gjør nøkkelen flertydig.
    //
    // TO FEIL PÅ RAD LÅ HER. Regexen stoppet ved den første `)` — altså
    // midt inne i `coalesce(...)` — så `signal_id` forsvant i stillhet,
    // og en nøkkelkolonne vakten ikke ser, er en kolonne kontrakten
    // aldri blir bedt om å kjenne. Splittingen delte i tillegg midt i
    // uttrykket og krevde «coalesce(stasjon_id» som forretningsnøkkel.
    const kol = (noekler.signal_lukket ?? []).find((n) => n.navn === 'signal_lukket_unik')?.kolonner
    expect(kol, 'signal_lukket_unik må være lest').toBeTruthy()
    expect(kol, 'siste kolonne skal ikke falle ut av parentesen').toContain('signal_id')
    expect(kol).toContain('retailer_id')
    expect(kol!.some((k) => k.includes('(')), 'uttrykk skal ikke stå som kolonnenavn').toBe(false)
  })

  it('en droppet kolonne tar med seg noekkelen sin', () => {
    // `puls_svar_ansatt_dag (ansatt_id, dato)` ble laget i 0026 og
    // forsvant i 0044, da kolonnen `dato` ble droppet — uten et
    // `drop index` noe sted. Postgres gjør det selv.
    //
    // Uten denne regelen krevde sjekken under at kontrakten oppga en
    // forretningsnøkkel over `dato`, og eneste vei til grønt ville vært
    // å skrive en kolonne som ikke finnes inn i kontrakten.
    const kolonner = new Set((noekler.puls_svar ?? []).flatMap((n) => n.kolonner))
    expect(kolonner.has('dato'), 'dato ble droppet i 0044').toBe(false)
    // KANARIFUGL. Uten denne ville «ingen nøkkel med dato» også vært
    // sant om parseren sluttet å se puls_svar i det hele tatt.
    expect(kolonner.has('runde_id'), 'puls_svar_runde_ansatt lever').toBe(true)
  })

  it('hver klassifisert ressurs kjenner alle sine forretningsnokler', () => {
    // Jeg overså `ansatte_pin_unik` da jeg skrev kontrakten for hånd.
    // CI fant den etter fire minutter, med 23505. Denne finner den før
    // pushen — og finner den neste jeg overser.
    const feil: string[] = []
    for (const r of kontrakt.ressurser) {
      // Ingen operasjoner = ingen fixture = ingen kollisjon mulig.
      // `oversettelse_cache` naas ikke av noen rolle.
      if (r.operasjoner.length === 0) continue
      const kjent = new Set([
        ...(r.business_unik ?? []),
        ...Object.keys(r.business_unik_unntak ?? {}),
        // Tenantkolonnene varierer med målet og trenger ingen erklæring.
        'retailer_id', 'stasjon_id',
        // Primærnøkkelen er ikke en forretningsnøkkel.
        r.id_kolonne ?? 'id',
      ])
      for (const n of noekler[r.tabell] ?? []) {
        const mangler = n.kolonner.filter((k) => !kjent.has(k))
        if (mangler.length > 0) {
          feil.push(`${r.tabell}: ${n.navn ?? 'unique'} (${n.kolonner.join(', ')}) `
            + `- mangler i business_unik: ${mangler.join(', ')}`)
        }
      }
    }
    expect(feil, feil.join('\n')).toEqual([])
  })
})

describe('rekkevidde', () => {
  it('en operasjon som ikke er nevnt for en rolle, er nektet', () => {
    expect(rekkevidde({ select: 'own_station' }, 'delete', ['select', 'delete'])).toBe('none')
  })

  it('kortformen read_write dekker alle fire', () => {
    for (const op of ['select', 'insert', 'update', 'delete'] as const) {
      expect(rekkevidde('read_write', op, ['select', 'insert', 'update', 'delete'])).toBe('own_station')
    }
  })

  it('en bar rekkevidde gjelder bare operasjoner ressursen har', () => {
    expect(rekkevidde('assigned_stations', 'delete', ['select', 'insert'])).toBe('none')
  })
})

describe('matrisen som genereres', () => {
  const avvik = kontrakt.ressurser.find((r) => r.tabell === 'avvik')!
  const finn = (navn: string) => IDENTITETER.find((i) => i.navn === navn)!

  it('manager_A12 er tillatt på A1 og A2, nektet på A3 og B1', () => {
    const m = finn('manager_A12')
    expect(tillatt(avvik, m, 'select', 'A1')).toBe(true)
    expect(tillatt(avvik, m, 'select', 'A2')).toBe(true)
    expect(tillatt(avvik, m, 'select', 'A3')).toBe(false)
    expect(tillatt(avvik, m, 'select', 'B1')).toBe(false)
  })

  it('nettbrettet leser og melder avvik, men retter dem ikke', () => {
    const t = finn('tablet_A1')
    expect(tillatt(avvik, t, 'select', 'A1')).toBe(true)
    expect(tillatt(avvik, t, 'insert', 'A1')).toBe(true)
    expect(tillatt(avvik, t, 'update', 'A1')).toBe(false)
    expect(tillatt(avvik, t, 'delete', 'A1')).toBe(false)
  })

  it('eieren når hele sin kjede, aldri den andre', () => {
    const o = finn('owner_A')
    for (const s of ['A1', 'A2', 'A3'] as const) expect(tillatt(avvik, o, 'select', s)).toBe(true)
    expect(tillatt(avvik, o, 'select', 'B1')).toBe(false)
  })

  it('hver identitet prøves mot hele egen kjede og én i den andre', () => {
    expect(maal(finn('manager_A1'))).toEqual(['A1', 'A2', 'A3', 'B1'])
    expect(maal(finn('manager_B1'))).toEqual(['B1', 'B2', 'A1'])
  })

  it('positive kontroller finnes for hver varm ressurs', () => {
    // En suite som bare beviser «avvist» kan være grønn fordi alt er
    // ødelagt. Hver varm ressurs skal ha minst én tillatt operasjon
    // for minst én identitet.
    for (const r of kontrakt.ressurser.filter((x) => x.data_class === 'warm')) {
      const positive = IDENTITETER.flatMap((i) =>
        r.operasjoner.flatMap((op) => maal(i).map((s) => tillatt(r, i, op, s))))
        .filter(Boolean).length
      expect(positive, `${r.tabell} har ingen positiv kontroll`).toBeGreaterThan(0)
    }
  })
})

describe('genererte filer', () => {
  for (const [sti, gen] of FILER) {
    it(`${sti} er i takt med kontrakten`, () => {
      const ventet = gen(kontrakt)
      const full = `${ROT}${sti}`

      if (process.env.OPPDATER_KONTRAKT) {
        writeFileSync(full, ventet, 'utf8')
        return
      }

      let faktisk: string
      try {
        faktisk = readFileSync(full, 'utf8')
      } catch {
        throw new Error(`${sti} finnes ikke. Kjør: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant`)
      }
      expect(faktisk.replace(/\r\n/g, '\n'), `${sti} er ute av takt med kontrakten. `
        + 'Kjør: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant').toBe(ventet)
    })
  }

  // -------------------------------------------------------------------
  // DELENE. Hele matrisen er for stor for Supabase SQL Editor (1,0 MB
  // ble avvist 2026-08-26), og prod-kjøringen er hele poenget med den.
  // -------------------------------------------------------------------
  const deler = genererMatriseDeler(kontrakt)
  const DELMAPPE = `${ROT}supabase/tests/deler`

  it('hver del er i takt med kontrakten, og ingen gammel del blir liggende', () => {
    if (process.env.OPPDATER_KONTRAKT) {
      mkdirSync(DELMAPPE, { recursive: true })
      for (const d of deler) writeFileSync(`${ROT}${d.fil}`, d.sql, 'utf8')
      // EN FORELDET DEL ER FARLIGERE ENN EN MANGLENDE. Krymper settet,
      // ville del 07 fra forrige generering blitt liggende igjen med
      // gamle påstander — og sett helt gyldig ut når den limes inn.
      const skalFinnes = new Set(deler.map((d) => d.fil.split('/').pop()))
      for (const f of readdirSync(DELMAPPE)) {
        if (f.endsWith('.sql') && !skalFinnes.has(f)) rmSync(`${DELMAPPE}/${f}`)
      }
      return
    }

    for (const d of deler) {
      let faktisk: string
      try {
        faktisk = readFileSync(`${ROT}${d.fil}`, 'utf8')
      } catch {
        throw new Error(`${d.fil} finnes ikke. Kjør: OPPDATER_KONTRAKT=1 npx vitest run src/lib/tenant`)
      }
      expect(faktisk.replace(/\r\n/g, '\n'), `${d.fil} er ute av takt med kontrakten.`).toBe(d.sql)
    }

    const skalFinnes = new Set(deler.map((d) => d.fil.split('/').pop()))
    const paaDisk = readdirSync(DELMAPPE).filter((f) => f.endsWith('.sql'))
    expect(paaDisk.filter((f) => !skalFinnes.has(f)), 'foreldede delfiler').toEqual([])
  })

  it('delene dekker hver varm ressurs nøyaktig én gang', () => {
    // DEN VIKTIGSTE AV DE TRE. En splitt som mister en ressurs ser
    // nøyaktig ut som en splitt der alt er med: hver del sier «ingen
    // funn», og ingen av dem sier hva de ikke prøvde.
    const varme = kontrakt.ressurser.filter((r) => r.data_class === 'warm').map((r) => r.tabell)
    const sett = deler.flatMap((d) =>
      varme.filter((t) => d.sql.includes(`select pg_temp.sett_gruppe('${t}');`)))
    expect([...sett].sort()).toEqual([...varme].sort())
  })

  it('hver del får plass i SQL-editoren', () => {
    // KANARIFUGL PÅ SELVE GRUNNEN TIL AT DELENE FINNES. Blir én del for
    // stor igjen, er splitten tilbake der den startet — og det skal
    // oppdages her, ikke av en feilmelding i nettleseren.
    for (const d of deler) {
      expect(d.sql.length, `${d.fil} er ${Math.round(d.sql.length / 1000)} kB`).toBeLessThan(800_000)
    }
    expect(deler.length, 'én del er ingen splitt').toBeGreaterThan(1)
  })

  it('en sammensatt identitet peker på raden som faktisk ble seedet', () => {
    // ANTAKELSEN, IKKE SYMPTOMET. `timesalg` har ingen id-kolonne, så
    // raden pekes på med (retailer_id, stasjon_id, dato, time). Verdiene
    // kan ikke utledes av kontrakten — `dato` varierer per forsøk — så
    // generatoren leser dem av raden den nettopp skrev.
    //
    // Går de fra hverandre, finner ingen påstand raden igjen: hver
    // avvisning blir «målraden finnes ikke», og hver lesing blir «ser
    // ikke». Rødt over hele linja, av en grunn ingen ville lett etter i
    // en policy.
    const sql = genererMatrise(kontrakt)
    const seedet = sql.match(/insert into public\.timesalg \(([^)]+)\) values \(([^;]+)\);/)
    expect(seedet, 'timesalg må ha en seedet proberad — flytt kanarifuglen hvis tabellen er borte').toBeTruthy()
    const kolonner = seedet![1].split(', ')
    const verdier = seedet![2].split(', ')
    const dato = verdier[kolonner.indexOf('dato')]

    const lesing = sql.split('\n').find((l) => l.includes("'timesalg owner_A SELECT A1 -> ser'"))
    expect(lesing, 'påstanden må finnes').toBeTruthy()
    expect(lesing, `predikatet må bruke datoen raden fikk (${dato})`).toContain(`"dato" = ${dato}`)
  })

  it('null i stasjon_id betyr ikke det samme på to tabeller', () => {
    // KONTRASTEN ER KANARIFUGLEN. `tablet_meldinger`: null = kjeden, og
    // butikksjefen ser raden. `regnskapslinjer`: null = klyngelinje, og
    // bare eieren ser den.
    //
    // Slutter generatoren å skille, blir den ene av de to påstandene
    // borte — og en riktig base ville blitt rød på den andre.
    const sql = genererMatrise(kontrakt)
    expect(sql).toContain("'tablet_meldinger manager_A1 ser kjedens null-stasjonsrad'")
    expect(sql).toContain("'regnskapslinjer manager_A1 ser IKKE kjedens null-stasjonsrad'")
    expect(sql).toContain("'regnskapslinjer owner_A ser kjedens null-stasjonsrad'")
  })

  it('valider() nekter en flyktig eller uskrevet identitet', () => {
    // Regelen, ikke et tilfelle av den. En `clock_timestamp()` i
    // identiteten gir én verdi ved innsetting og en annen ved oppslag.
    const base = kontrakt.ressurser.find((r) => r.tabell === 'timesalg')!
    const flyktig = {
      ...kontrakt,
      ressurser: [{ ...base, proberad: { ...base.proberad, dato: 'clock_timestamp()::date' } }],
    }
    expect(valider(flyktig).join(' ')).toContain('flyktig')

    const uskrevet = {
      ...kontrakt,
      ressurser: [{ ...base, id_kolonner: [...base.id_kolonner!, 'finnes_ikke'] }],
    }
    expect(valider(uskrevet).join(' ')).toContain('proberaden setter den ikke')
  })

  it('en seed_ekstra dekker proberaden til tabellen den seeder', () => {
    // TO HÅNDHOLDTE BESKRIVELSER AV SAMME RAD, og bare én får korrektur.
    //
    // `malekort_scope` seedet sitt eget målekort med (id, retailer_id,
    // navn). `metrikk` er not-null, så CI stoppet på 23502 etter to
    // minutter — en feil som ikke sier noe om noen policy. Samme form,
    // stillere: seeden for `tildelte_merker` lot `ansatte.ansatt_nr`
    // stå null, altså en forretningsnøkkel, og var grønn bare fordi
    // kolonnen tåler null i dag.
    const seeder = kontrakt.ressurser.filter((r) =>
      (r.seed_ekstra ?? []).some((l) => {
        const m = /insert\s+into\s+public\.([a-z0-9_]+)/i.exec(l)
        return m && kontrakt.ressurser.some((x) => x.tabell === m[1])
      }))

    // KANARIFUGL: uten en seed som peker på en klassifisert tabell
    // måler regelen ingenting, og ser nøyaktig ut som en regel uten funn.
    expect(seeder.length, 'ingen seed_ekstra peker på en klassifisert tabell — regelen er blind')
      .toBeGreaterThan(0)

    const mal = kontrakt.ressurser.find((r) => r.tabell === 'malekort')!
    const scope = kontrakt.ressurser.find((r) => r.tabell === 'malekort_scope')!
    expect(Object.keys(mal.proberad)).toContain('metrikk')
    const brutt = {
      ...kontrakt,
      ressurser: [mal, {
        ...scope,
        seed_ekstra: scope.seed_ekstra!.map((l) => l.replace(', metrikk', '').replace(", 'omsetning'", '')),
      }],
    }
    expect(valider(brutt).join(' ')).toContain('«metrikk»')
  })

  it('matrisen inneholder både en tillatt og en avvist skriving', () => {
    // Kanarifugl på generatoren selv: emitterer den bare negative
    // påstander, er den ødelagt på en måte som ser trygg ut.
    const sql = genererMatrise(kontrakt)
    expect(sql).toContain('pg_temp.skriv_tillatt')
    expect(sql).toContain('pg_temp.skriv_avvist')
    expect(sql).toContain('FLYTTER egen rad')
  })

  it('hver avvist UPDATE/DELETE sender med maalraden', () => {
    // «0 rader» er tvetydig: det er svaret baade naar RLS stopper
    // skrivingen OG naar id-en er feil eller fixturen aldri ble seedet.
    // Uten maalraden ville en oedelagt fixture blitt en gronn
    // sikkerhetstest.
    const sql = genererMatrise(kontrakt)
    const avvisninger = sql.split('\n').filter((l) => l.includes('pg_temp.skriv_avvist('))
    expect(avvisninger.length).toBeGreaterThan(0)
    const utenMaal = avvisninger
      .filter((l) => /'(update|delete) /.test(l))
      // tabell, målrad og kolonnen den identifiseres på — den siste
      // fordi ikke alle tabeller har en `id` (`bemanning_stasjon`).
      .filter((l) => !/, '[a-z_]+', '[0-9a-f-]+', '[a-z_]+'\);$/.test(l.trim()))
    expect(utenMaal, `avvisning uten maalrad:\n${utenMaal.slice(0, 3).join('\n')}`).toEqual([])
  })

  it('dekningens insert har like mange verdier som kolonner', () => {
    // Denne finnes fordi jeg brakk den: kolonnelista fikk et felt til,
    // men verdiradene ble stående på to. Postgres sa «INSERT has more
    // target columns than expressions» — i CI, etter fire minutter.
    // Her tar det millisekunder.
    const sql = genererDekning(kontrakt)
    const kolonner = /insert into kontrakt_tabeller \(([^)]+)\) values/.exec(sql)
    expect(kolonner, 'fant ikke insert-setningen').not.toBeNull()
    const antall = kolonner![1].split(',').length
    const forsteRad = /\n {4}\('[^']+'([^)]*)\),/.exec(sql)
    expect(forsteRad, 'fant ingen verdirad').not.toBeNull()
    expect(forsteRad![1].split(',').length).toBe(antall)
  })

  it('ingen insert antar en id-kolonne som ikke finnes', () => {
    // Id-antakelsen satt på FIRE steder, og jeg fant tre av dem én om
    // gangen gjennom CI. Denne finner den fjerde på millisekunder.
    const sql = genererMatrise(kontrakt)
    const utenId = kontrakt.ressurser
      .filter((r) => (r.id_kolonne ?? 'id') !== 'id' || r.id_kolonner)
    for (const r of utenId) {
      const feil = sql.split('\n')
        .filter((l) => l.includes(`into public.${r.tabell} (id,`))
      expect(feil, `${r.tabell} har ingen id-kolonne, men matrisen setter en`).toEqual([])
    }
    expect(utenId.length, 'ingen ressurs uten surrogatnokkel - maaler testen noe?')
      .toBeGreaterThan(0)
  })

  it('ingen nyrad_* returnerer en id som ikke finnes', () => {
    // FEMTE STEDET, funnet i CI 2026-08-26 — ikke ved generering, men
    // ved KALL: `returning id into ny` mot en tabell uten id-kolonne gir
    // 42703 midt i en ellers gyldig kjøring.
    //
    // Den forrige testen ser bare på insert-linjer, og
    // funksjonskroppens `returning` er ikke en av dem.
    const sql = genererMatrise(kontrakt)
    const sammensatt = kontrakt.ressurser.filter((r) => r.id_kolonner)
    for (const r of sammensatt) {
      const kropp = sql.split(`create or replace function pg_temp.nyrad_${r.tabell}(`)[1]
      if (kropp === undefined) continue // en_rad_per_stasjon lager ingen
      const tilSlutt = kropp.split('end $fn$;')[0]
      expect(tilSlutt, `nyrad_${r.tabell} returnerer en id tabellen ikke har`)
        .not.toContain('returning id')
    }
    expect(sammensatt.length, 'ingen sammensatt identitet - maaler testen noe?')
      .toBeGreaterThan(0)
  })

  it('en_rad_per_stasjon frigjoer plassen foer hvert INSERT-forsoek', () => {
    // Metaregelen: test antakelsen, ikke symptomet.
    //
    // Stasjonen har alt sin faste rad, saa et innslag nummer to
    // kolliderer med primaernokkelen. Uten frigjoering ble den positive
    // kontrollen "ble blokkert: 23505" og den negative "avvist av FEIL
    // grunn" - to feil av samme aarsak, funnet i CI etter fire minutter.
    const sql = genererMatrise(kontrakt)
    const linjer = sql.split('\n')
    const enRad = kontrakt.ressurser.filter((r) => r.en_rad_per_stasjon)

    // PLASSEN ER STASJONEN, IKKE ID-EN. `bemanning_stasjon` har
    // `stasjon_id` som primærnøkkel, så der var de to det samme. På
    // `bemanning_budsjett` er nøkkelen `(stasjon_id, ar, maned)` og id-en
    // en uuid: et tillatt insert lager en rad med NY id, og en opprydding
    // på den faste id-en lot den ligge. Gjeninnsettingen kolliderte med
    // 23505 og felte hele fila — funnet i CI, ikke her.
    for (const r of enRad) {
      linjer.forEach((l, nr) => {
        if (!l.includes(`skriv_tillatt('${r.tabell} `) && !l.includes(`skriv_avvist('${r.tabell} `)) return
        if (!/ INSERT /.test(l)) return
        const foran = linjer.slice(Math.max(0, nr - 3), nr).join(' ')
        expect(foran, `${r.tabell}: INSERT-forsoek uten frigjoering foran (linje ${nr + 1})`)
          .toContain(`delete from public.${r.tabell} where stasjon_id =`)

        // Og plassen skal fylles igjen MED SAMME ID. En fersk uuid ville
        // gjort hver senere påstand i gruppa til «ser ikke» — uten at
        // noen policy var rørt.
        const etter = linjer.slice(nr + 1, nr + 4).join(' ')
        if ((r.id_kolonne ?? 'id') === 'id') {
          expect(etter, `${r.tabell}: gjeninnsettingen mangler den faste id-en (linje ${nr + 1})`)
            .toContain(`insert into public.${r.tabell} (id,`)
        }
      })
    }

    // KANARIFUGL: uten en slik ressurs maaler testen ingenting.
    expect(enRad.length, 'ingen en_rad_per_stasjon-ressurs - maaler testen noe?')
      .toBeGreaterThan(0)
  })

  it('ingen plassholder overlever generatoren', () => {
    // Metaregelen igjen, og denne fanger HELE klassen.
    //
    // `{{n}}` ble erstattet i seedingen, men ikke inne i `nyrad_*` - der
    // sto den igjen som literal tekst, saa hver seedet ansatt fikk samme
    // pin_hash og kolliderte med ansatte_pin_unik. Fire minutter i CI.
    //
    // En uerstattet plassholder er ALLTID en feil, uansett hvilken.
    for (const [sti, gen] of FILER) {
      const rester = gen(kontrakt).split('\n')
        .map((l, nr) => [nr + 1, l] as const)
        .filter(([, l]) => l.includes('{{'))
      expect(rester.map(([nr, l]) => `${sti}:${nr}  ${l.trim().slice(0, 90)}`))
        .toEqual([])
    }
  })

  it('hver kjoretidsteller staar i sitt eget verdirom', () => {
    // TO TELLERE, ETT ROM = KOLLISJON. Generatorens teller lager verdier
    // ved GENERERING (`pin-merke-5`, `2026-01-01 + 5`); sekvensen lager
    // dem ved KJORING. Deler de basis, kolliderer de med hverandre i
    // stedet for med seg selv - og en forretningsnokkel gir 23505.
    //
    // Datoene ble skilt med 2030 som base. Tekst skilles med 'rt'.
    const sql = genererMatrise(kontrakt)
    const uskilt = sql.split('\n')
      .filter((l) => l.includes('nextval('))
      // Tre lovlige separatorer, og alle tre er ekte:
      //
      //   date '2030-01-01'  datoer, mot generatorens 2026-basis
      //   'rt'               tekst fra {{n}}, mot generatorens rå tall
      //   p_merke            «identitet-operasjon», en form generatorens
      //                      {{unik}} aldri produserer (den gir `fastA1`,
      //                      `manager_A1A2` — aldri med bindestrek)
      .filter((l) => !l.includes(`'rt'`)
        && !l.includes(`date '2030-01-01'`)
        && !l.includes('p_merke'))
    expect(uskilt.map((l) => l.trim().slice(0, 90)), 'kjoeretidsteller uten eget verdirom')
      .toEqual([])
    expect(sql.includes('nextval('), 'ingen kjoeretidsteller - maaler testen noe?').toBe(true)
  })

  it('ingen SQL-fil inneholder ikke-ASCII', () => {
    // AGENTS.md: innlimingskjeden legger ellers av og til på et
    // stray-tegn foran linje 1.
    for (const [sti, gen] of FILER) {
      const rare = [...gen(kontrakt)].filter((c) => c.charCodeAt(0) > 127)
      expect(rare, `${sti} har ikke-ASCII: ${rare.slice(0, 5).join('')}`).toEqual([])
    }
  })
})
