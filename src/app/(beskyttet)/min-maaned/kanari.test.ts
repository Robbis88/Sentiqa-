import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { easyatworkNiva } from '@/lib/lonnskost/easyatwork'
import { styringsavvik } from '@/lib/lonnskost/rom'
import { skjermFor, type Felt, type Okonomibilde } from '@/lib/okonomi/bilde'
import { hvaBoerJegViteNaa } from '@/lib/okonomi/vite'
import {
  byggMaanedsbilde, hentBildegrunnlag, maanederMedBilde, standardmaaned,
  type Bildegrunnlag,
} from '@/lib/okonomi/sammenstill'
import { reisen, naavaerendeFase } from './reise'

// =====================================================================
// PRODUKSJONSKANARIFUGL — MIN MÅNED MOT MOTORENS EGNE TALL
// =====================================================================
//
// Enhetstestene beviser at reglene holder på fiksturer. Denne beviser to
// ting som fiksturer aldri kan:
//
//   1  HVERT TALL MIN MÅNED VISER ER MOTORENS. Ikke «ser rimelig ut» —
//      identisk med `Lonnsrom`, `Maanedslonn`, `easyatworkNiva` og
//      `styringsavvik`, felt for felt. Et velformulert bilde med et tall
//      som har flyttet seg én krone er rødt.
//
//   2  HVA SOM FAKTISK KAN VISES i dagens produksjonsdata, per stasjon
//      og måned. Den skriver dekningsmatrisen ut, slik at «royalty
//      mangler» kan skilles fra «royalty finnes ikke i denne kjeden».
//
// ---------------------------------------------------------------------
// TO MÅNEDER PER STASJON, OG DET ER IKKE GRUNDIGHET FOR SIN EGEN SKYLD
// ---------------------------------------------------------------------
//
// Første kjøring målte bare standardmåneden. Den var ÅPEN på alle fem
// stasjonene, så halve bildet sto `mangler` og reisen stanset på
// PROGNOSE. Royalty, påvirkbar drift og styringskost ble aldri prøvd med
// et tall i det hele tatt — og «mangler på en åpen måned» beviser ikke at
// feltet noen gang fylles.
//
// Derfor måles også NYESTE AVLAGTE måned. Det er den halvdelen av reisen
// som heter FASIT, og uten den er den ikke prøvd mot produksjon.
//
// ---------------------------------------------------------------------
// HVA DEN IKKE BEVISER
// ---------------------------------------------------------------------
//
// ROLLESKJERMINGEN ER IKKE EN RLS-TEST. Den kjøres som eieren, og
// `skjermFor('butikksjef', ...)` er en REN funksjon på et bilde eieren
// allerede har hentet. At butikksjefen ikke NÅR royaltylinja håndheves
// av policyen i `0192`, og bevises i fixture/transaksjon — ikke her.
// Det som prøves her er at skjermingen merker feltet `skjult` og ikke
// `mangler`, altså at UI-laget ikke gjør tilgang om til datakvalitet.
//
// KREVER KANARI_EPOST og KANARI_PASSORD. Passordet skal aldri i git.
// =====================================================================

const EPOST = process.env.KANARI_EPOST
const PASSORD = process.env.KANARI_PASSORD
const kjor = EPOST && PASSORD ? it : it.skip

function env(navn: string): string {
  const fil = readFileSync('.env.local', 'utf8')
  const l = fil.split(/\r?\n/).find((x) => x.startsWith(`${navn}=`))
  if (!l) throw new Error(`${navn} mangler i .env.local`)
  return l.slice(navn.length + 1).trim().replace(/^["']|["']$/g, '')
}

const FRA = new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth() - 12, 1))
  .toISOString().slice(0, 10)

/** «4 200 000» eller «—». Aldri «0» for et tall som mangler. */
const kr = (v: number | null) =>
  (v === null ? '—' : Math.round(v).toLocaleString('nb-NO'))

const merke = (f: Felt) => `${kr(f.verdi)} [${f.kilde}]`

/** Feltene siden viser, i samme rekkefølge som `page.tsx`. */
const RADER: { navn: string; les: (b: Okonomibilde) => Felt }[] = [
  { navn: 'omsetning', les: (b) => b.omsetning },
  { navn: 'brutto', les: (b) => b.brutto },
  { navn: 'lonnsrom', les: (b) => b.lonnsrom },
  { navn: 'styringskost', les: (b) => b.styringskost },
  { navn: 'lonn (alle ni)', les: (b) => b.lonn },
  { navn: 'bp-lonn', les: (b) => b.bpLonn },
  { navn: 'paavirkbar drift', les: (b) => b.paavirkbarDrift },
  { navn: 'royalty', les: (b) => b.royalty },
]

describe('KANARIFUGL — Min måned mot produksjon', () => {
  kjor('hvert felt er motorens eget tall, og matrisen skrives ut', async () => {
    const supabase = createClient(
      env('NEXT_PUBLIC_SUPABASE_URL'), env('NEXT_PUBLIC_SUPABASE_ANON_KEY'),
    ) as SupabaseClient
    const { error } = await supabase.auth.signInWithPassword({
      email: EPOST!, password: PASSORD!,
    })
    if (error) throw new Error(`Innlogging feilet: ${error.message}`)

    // LEVENDE STASJONER. `slettet_tid is null` — uten det leses lukkede
    // stasjoner som levende, og matrisen får rader ingen flate viser.
    const { data: stasjoner, error: sfeil } = await supabase
      .from('stasjoner')
      .select('id, navn, butikknummer')
      .is('slettet_tid', null)
      .order('butikknummer')
      .limit(200)
    if (sfeil) throw new Error(`Stasjonene: ${sfeil.message}`)
    const liste = (stasjoner ?? []) as { id: string; navn: string; butikknummer: string }[]
    expect(liste.length, 'ingen stasjoner — da måler kanarifuglen ingenting').toBeGreaterThan(0)

    const naa = new Date()
    const L: string[] = ['', '  MIN MAANED — PRODUKSJONSMATRISE', '']
    let maalteBilder = 0
    let maalteFelt = 0
    let avlagteMaalt = 0
    let medRoyalty = 0
    let medDrift = 0

    /** Måler én stasjonsmåned: påstander mot motoren, og en matriserad. */
    async function maal(
      navn: string, stasjonId: string, grunnlag: Bildegrunnlag, maaned: string, merkelapp: string,
    ) {
      const valgt = byggMaanedsbilde(grunnlag, { maaned, rolle: 'retailer_admin', naa })
      expect(valgt, `${navn}: ${maaned} ga ikke noe bilde`).not.toBeNull()
      const { bilde } = valgt!
      maalteBilder++

      // ---------------------------------------------------------------
      // FELT FOR FELT MOT MOTOREN
      // ---------------------------------------------------------------
      const rom = grunnlag.lonnsbilde.rom.find((r) => r.maaned === maaned)!
      const mnd = grunnlag.lonnsbilde.maaneder.find((m) => m.maaned === maaned)
      const ea = grunnlag.lonnsbilde.easyatwork.find((e) => e.maaned === maaned)
      const avlagt = mnd?.avlagt ?? false
      if (avlagt) avlagteMaalt++

      // Brutto, rom og BP-lønn kommer RETT fra `Lonnsrom`.
      expect(bilde.brutto.verdi, `${navn} brutto`).toBe(rom.bruttoKr)
      expect(bilde.lonnsrom.verdi, `${navn} lonnsrom`).toBe(rom.romKr)
      expect(bilde.bpLonn.verdi, `${navn} bp-lonn`).toBe(rom.bpLonnKr)
      // Og kilden følger `anslaatt` — lov 1 og 2, ikke en mening her.
      if (rom.bruttoKr !== null) {
        expect(bilde.brutto.kilde, `${navn} bruttokilde`)
          .toBe(rom.anslaatt ? 'prognose' : 'fasit')
        expect(bilde.lonnsrom.kilde, `${navn} romkilde`).toBe(bilde.brutto.kilde)
      }

      // Lønn og styringskost: regnskapet når det er avlagt, ellers
      // easy@work. Nøyaktig samme rekkefølge som motoren.
      const ventetLonn = avlagt ? mnd!.lonnskostKr : ea?.lonnskostKr ?? null
      const ventetStyring = avlagt
        ? mnd!.niva?.styringskostKr ?? null
        : ea ? easyatworkNiva(ea).styringskostKr : null
      expect(bilde.lonn.verdi, `${navn} lonn`).toBe(ventetLonn)
      expect(bilde.styringskost.verdi, `${navn} styringskost`).toBe(ventetStyring)

      // AVVIKET ER E2 SIN, IKKE EN NY UTREGNING.
      expect(bilde.styringsavvik.avvik, `${navn} styringsavvik`)
        .toEqual(styringsavvik(rom, bilde.styringskost.verdi))

      // Omsetning: fasit bare når måneden er avlagt.
      const fasit = grunnlag.fasit.get(maaned)
      if (avlagt && fasit !== undefined && fasit.omsetningKr !== null) {
        expect(bilde.omsetning.kilde, `${navn} omsetningskilde`).toBe('fasit')
        expect(bilde.omsetning.verdi, `${navn} omsetning`).toBe(fasit.omsetningKr)
      } else {
        expect(bilde.omsetning.kilde, `${navn} omsetningskilde`).not.toBe('fasit')
      }

      // EN IKKE-AVLAGT MÅNED HAR INGEN FASITKRONER. Dette er `coalesce
      // (..., 0)`-fella i `v_kurs_maanedstall`, målt mot ekte data.
      if (!avlagt) {
        expect(bilde.paavirkbarDrift.verdi, `${navn} drift paa aapen maaned`).toBeNull()
        expect(bilde.royalty.verdi, `${navn} royalty paa aapen maaned`).toBeNull()
      }
      if (bilde.royalty.verdi !== null) medRoyalty++
      if (bilde.paavirkbarDrift.verdi !== null) medDrift++
      maalteFelt += RADER.length

      // ---------------------------------------------------------------
      // ROYALTY KRYSSJEKKES MOT RÅDATA
      // ---------------------------------------------------------------
      //
      // Bildet leser royaltyen gjennom `begrep`. Her leses de samme
      // linjene rått. Spriker de, er det filteret som har flyttet seg —
      // og da skal det ropes, ikke pyntes.
      let raalinje = ''
      if (avlagt) {
        const { data: raa, error: rfeil } = await supabase
          .from('regnskapslinjer')
          .select('kode, begrep, regnskap')
          .eq('stasjon_id', stasjonId)
          .eq('seksjon', 'driftskostnader')
          .gte('periode', `${maaned}-01`)
          .lte('periode', `${maaned}-28`)
          .is('slettet_tid', null)
          .limit(500)
        if (rfeil) throw new Error(`Raa driftslinjer: ${rfeil.message}`)
        const linjer = (raa ?? []) as
          { kode: string; begrep: string | null; regnskap: number | null }[]
        const roy = linjer.filter((l) => l.begrep === 'royalty')
        const sumRoyalty = roy.length === 0
          ? null
          : roy.reduce((a, l) => a + Number(l.regnskap ?? 0), 0)
        expect(bilde.royalty.verdi, `${navn} royalty mot raadata`).toBe(sumRoyalty)

        // ET TOMT `begrep` ER IKKE EN MANGLENDE KOSTNAD. Kolonnen kom i
        // `0203`; rader importert FOER den staar med `begrep = null`, og
        // et filter paa begrep ser da ut som en maaned uten royalty.
        // DIAGNOSE, ikke paastand.
        const utenBegrep = linjer.filter((l) => l.begrep === null)
        const k622 = utenBegrep.filter((l) => l.kode === '622')
        raalinje = `    raa driftslinjer ....... ${linjer.length}`
          + `  royaltylinjer ${roy.length}`
          + (roy.length > 0 ? ` (kode ${[...new Set(roy.map((l) => l.kode))].join(',')})` : '')
          + `  uten begrep ${utenBegrep.length}`
          + (k622.length > 0 ? `  <- ${k622.length} ER KONTO 622 ROYALTY` : '')
      }

      // ---------------------------------------------------------------
      // SKJERMINGEN MERKER, DEN SKJULER IKKE ET HULL
      // ---------------------------------------------------------------
      const somButikksjef = skjermFor('butikksjef', bilde)
      expect(somButikksjef.royalty.kilde, `${navn} butikksjefens royalty`).toBe('skjult')
      if (bilde.sikkerhet === 'hoy') {
        expect(somButikksjef.sikkerhet, `${navn}: skjerming ble til datakvalitet`).toBe('hoy')
      }

      // ---------------------------------------------------------------
      // MATRISEN
      // ---------------------------------------------------------------
      const faser = reisen(bilde, RADER.map((r) => r.les(bilde)))
      L.push(`    ${merkelapp}  ${maaned}  avlagt=${avlagt}`)
      L.push(`      reise ................ ${faser.map((f) => `${f.tittel}:${f.tilstand}`).join('  ')}`
        + `   staar paa ${naavaerendeFase(faser)?.id ?? 'ingenting'}`
        + `   sikkerhet ${bilde.sikkerhet}`)
      for (const r of RADER) L.push(`      ${r.navn.padEnd(20, '.')} ${merke(r.les(bilde))}`)
      L.push(`      styringsavvik ........ ${kr(bilde.styringsavvik.avvik.kroner)}`
        + ` [${bilde.styringsavvik.kilde}] alvor=${bilde.styringsavvik.avvik.alvor}`
        + (bilde.styringsavvik.avvik.mangler ? ` (${bilde.styringsavvik.avvik.mangler})` : ''))
      L.push(`      dekning .............. salgsdager ${bilde.dekning.salgsdager.har}/${bilde.dekning.salgsdager.av}`
        + `  bilvask ${bilde.dekning.bilvaskUker.har}/${bilde.dekning.bilvaskUker.av}`
        + `  lonnsfil=${bilde.dekning.lonnsfil}  regnskap=${bilde.dekning.regnskap}`)
      if (bilde.dekning.mangler.length > 0) {
        L.push(`      mangler .............. ${bilde.dekning.mangler.join(', ')}`
          + ` (${bilde.dekning.retningPaaFeil})`)
      }

      // ===============================================================
      // «HVA BØR JEG VITE NÅ?» — MOT TALLENE VED SIDEN AV
      // ===============================================================
      //
      // PRODUKSJONSFUNN 2026-09-16. Laguneparken juli sto med
      // `styringsavvik −1 611 [fasit]` og samtidig «Uten den finnes det
      // ingen lønn å måle mot rommet». easy@work-kronefila finnes bare
      // på tre av fem stasjoner, så tilstanden er normal.
      //
      // Dette er den ene påstanden flaten kan gjøre som MOTSIER et tall
      // på samme skjerm, og den måles derfor mot produksjon — ikke bare
      // mot en fikstur.
      const beskjeder = hvaBoerJegViteNaa(bilde)
      L.push(`      vite ................. ${beskjeder.length === 0 ? '(ingenting - alt i orden)'
        : beskjeder.map((b) => b.tittel).join(' | ')}`)
      if (bilde.styringsavvik.avvik.mangler === null) {
        for (const b of beskjeder) {
          expect(`${b.tittel} ${b.folge ?? ''}`,
            `${navn} ${maaned}: avviket ER regnet (${bilde.styringsavvik.avvik.kroner}),`
            + ' men beskjeden sier at det ikke finnes noe aa maale')
            .not.toMatch(/ingen lønn å måle mot rommet/i)
        }
      }
      // ===============================================================
      // DE TO BP-VEIENE, MOT HVERANDRE
      // ===============================================================
      //
      // `rom.bpLonnKr` kommer fra `bp_maaned_for_mine_stasjoner` (0183).
      // `maaned.bpBudsjettKr` kommer fra `bp_linje` filtrert paa
      // `BP_LONNSKODER`. To veier til samme tall - og /lonnskost har alt
      // en stille sjekk paa at de stemmer.
      //
      // MAALT OG SKREVET UT, IKKE PAASTAATT. Dale sto med 56 204 der de
      // fire andre laa paa 260-430 tusen; det kan vaere ekte og det kan
      // vaere et hull i BP-importen, og en kanarifugl skal vise
      // forskjellen i stedet for aa mene noe om den.
      if (mnd) {
        L.push(`      bp-veier ............. rom.bpLonnKr ${kr(rom.bpLonnKr)}`
          + `  bp_linje ${kr(mnd.bpBudsjettKr)}`
          + `  St1-budsjett ${kr(mnd.budsjettKr)}`
          + (rom.bpLonnKr !== null && mnd.bpBudsjettKr !== null
            && Math.abs(rom.bpLonnKr - mnd.bpBudsjettKr) >= 1000 ? '   <- SPRIKER' : ''))
      }
      if (raalinje) L.push(raalinje)
      L.push('')
    }

    for (const st of liste) {
      const navn = `${st.butikknummer} ${st.navn}`
      const grunnlag = await hentBildegrunnlag(supabase, st.id, FRA)
      const alle = maanederMedBilde(grunnlag)
      const standard = standardmaaned(grunnlag)

      L.push(`  ${navn}`)
      L.push(`    maaneder i velgeren .... ${alle.length}`
        + ` (${alle[0] ?? '-'} .. ${alle[alle.length - 1] ?? '-'})`)

      if (!standard) {
        L.push('    INGEN MAANED MED RAMME — siden viser tomtilstand')
        L.push('')
        continue
      }
      // VELGEREN SKAL IKKE TILBY NOE SIDEN IKKE KAN TEGNE. Maalt mot
      // produksjon, ikke bare mot en fikstur.
      for (const m of alle) {
        expect(byggMaanedsbilde(grunnlag, { maaned: m, rolle: 'retailer_admin', naa }),
          `${navn}: velgeren tilbyr ${m}, men siden kan ikke tegne den`).not.toBeNull()
      }
      expect(alle[0], `${navn}: standardmaaneden staar ikke i sin egen velger`).toBe(standard)

      await maal(navn, st.id, grunnlag, standard, 'STANDARD (siden aapner her)')

      // NYESTE AVLAGTE MAANED. Det er FASIT-halvdelen av reisen, og uten
      // den er royalty, paavirkbar drift og styringskost aldri proevd
      // med et tall.
      const avlagte = grunnlag.lonnsbilde.maaneder
        .filter((m) => m.avlagt && alle.includes(m.maaned))
        .map((m) => m.maaned)
        .sort((a, b) => b.localeCompare(a))
      if (avlagte.length === 0) {
        L.push('    INGEN AVLAGT MAANED i vinduet — fasitsiden av reisen kan ikke vises')
        L.push('')
      } else if (avlagte[0] !== standard) {
        await maal(navn, st.id, grunnlag, avlagte[0], 'NYESTE AVLAGTE (fasit)')
      }

      // MÅNEDSPLANEN: finnes det en handling å vise?
      const { data: planer, error: pfeil } = await supabase
        .from('maanedsplan')
        .select('maaned, dom, status')
        .eq('stasjon_id', st.id)
        .in('status', ['sluppet', 'sendt'])
        .order('maaned', { ascending: false })
        .limit(60)
      if (pfeil) throw new Error(`Maanedsplanene: ${pfeil.message}`)
      const p = (planer ?? []) as { maaned: string; dom: string; status: string }[]
      L.push(`    sluppet plan ........... ${p.length === 0 ? 'INGEN'
        : `${p[0].maaned.slice(0, 7)} ${p[0].dom} (${p[0].status}), ${p.length} totalt`
          + `${p[0].maaned.slice(0, 7) === standard ? '' : '  <- ANNEN MAANED ENN STANDARDMAANEDEN'}`}`)
      L.push('')
    }

    L.push(`  bilder ${maalteBilder}  (avlagte ${avlagteMaalt})   felt ${maalteFelt}`)
    L.push(`  bilder med royalty ${medRoyalty}   med paavirkbar drift ${medDrift}`)
    L.push('')
    console.log(L.join('\n'))

    // KANARIFUGLER FOR KANARIFUGLEN. Uten disse ville en kjøring som
    // ikke nådde en eneste stasjon — eller bare åpne måneder — stått
    // grønn. En test som ikke måler noe ser nøyaktig ut som en test som
    // ikke finner noe.
    expect(maalteBilder, 'ingen stasjon hadde et bilde — da er ingenting bevist')
      .toBeGreaterThan(0)
    expect(avlagteMaalt,
      'ingen AVLAGT maaned ble maalt — fasitsiden av reisen er da ikke proevd')
      .toBeGreaterThan(0)
  }, 300_000)
})
