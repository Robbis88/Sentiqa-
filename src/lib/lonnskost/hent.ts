import 'server-only'
import type { SupabaseClient } from '@supabase/supabase-js'
import { byggLonnskost, type Kontolinje, type Maanedslonn } from './maaned'
import { BP_LONNSKODER, ukjenteLonnskoder } from './bp'
import {
  byggEasyatwork, medOppdagetSykelonn, medFastlonn,
  type EasyatworkMaaned, type Lonnsartsum, type Sykelonnskilde,
} from './easyatwork'
import { byggLonnsrom, erAvdelingsniva, erDrivstoff, type Lonnsrom } from './rom'
import { bruttoPerMaaned, type Ukebelop } from './bilvask'

// =====================================================================
// Henter lønnskosten for én stasjon, måned for måned.
//
// ÉN SPØRRING, TRE SEKSJONER. `driftskostnader` bærer avlagte måneder,
// `bp_kostnad` de åpne, `nokkeltall` timene. To kall mot samme tabell
// kunne dessuten gitt to ulike svar hvis en import lander imellom.
//
// STASJONEN FILTRERES I SPØRRINGEN, ikke etterpå. RLS gir butikksjefen
// sine egne stasjoner og eieren kjeden; et valg her er en innsnevring
// av det, aldri en utvidelse.
// =====================================================================

export type Lonnsbilde = {
  maaneder: Maanedslonn[]
  /** BP-personalkoder ingen har tatt stilling til. Skal være tom. */
  ukjenteKoder: string[]
  /**
   * Anslaget fra easy@work, per måned. Tomt til fila er lastet opp.
   *
   * ET ANSLAG, IKKE EN FASIT. Det mangler fastlønn, refundert sykelønn
   * og bonus per konstruksjon — se `easyatwork.ts`. Verdien er at det
   * finnes dagen etter måneden, ikke midt i den neste.
   */
  easyatwork: EasyatworkMaaned[]
  /**
   * Hva regnskapet FAKTISK gjorde med sykelønna, målt mot easy@work.
   *
   * `forrige_maaned` betyr at den ikke er periodisert — den bokføres
   * måneden etter fraværet. Det er en praksis som kan endres, og siden
   * skal si fra om den, ikke anta den.
   */
  sykelonn: { moenster: Sykelonnskilde; maalte: number; forsinkede: number }
  /**
   * Hvor mye lønn stasjonen faktisk har råd til, måned for måned.
   *
   * BP-lønn delt på BP-brutto, ganget med den brutto måneden faktisk
   * fikk. For en avlagt måned står den i regnskapet; for den
   * inneværende anslås den av omsetning, lært margin og svinn.
   */
  rom: Lonnsrom[]
  /**
   * Det som er lagt inn for haand, saa det kan SES.
   *
   * Noekkelen er unik for aa hindre dobbeltfoering, men uten en liste
   * kan ingen bekrefte at uka kom inn - eller oppdage at noen alt hadde
   * lagt den inn. En unik noekkel uten en oversikt loeser halve
   * problemet og skjuler den andre halvparten.
   */
  bilvaskUker: {
    ar: number
    uke: number
    belopKr: number
    /**
     * Om ukas kroner allerede staar i regnskapet.
     *
     * EN UKE SOM IKKE FLYTTER NOE ER IKKE EN UKE SOM IKKE KOM INN.
     * Er maaneden avlagt, har regnskapet alt bilvasken - det er derfor
     * bilvask der alltid er hoeyere enn kassaomsetningen - og bidraget
     * holdes utenfor for aa unngaa dobbelfoering. Uten dette ordet ser
     * en korrekt lagret uke ut som en uke som ble borte, og neste steg
     * er at noen legger den inn en gang til.
     *
     * `delvis` finnes fordi en uke kan krysse maanedsskiftet: uke 36 i
     * 2026 er 31. august pluss seks dager i september.
     */
    iRegnskapet: 'ja' | 'nei' | 'delvis'
  }[]
  fastlonnMaaneder: { ar: number; maned: number; grunnlonnKr: number }[]
}

export async function hentLonnskost(
  supabase: SupabaseClient,
  stasjonId: string,
  fraOgMed: string,
): Promise<Lonnsbilde> {
  const [regnskap, bp, lonnsart, brutto, bpMnd, vask, fastlonn, grunnlag] = await Promise.all([
    supabase
      .from('regnskapslinjer')
      .select('periode, seksjon, kode, post, regnskap, budsjett')
      .eq('stasjon_id', stasjonId)
      .gte('periode', fraOgMed)
      .in('seksjon', ['driftskostnader', 'nokkeltall'])
      .is('slettet_tid', null)
      .limit(20000)
      .overrideTypes<Kontolinje[]>(),
    // BP-EN SOM SITT EGET DOKUMENT (`0155`), IKKE `bp_kostnad`.
    //
    // De to bærer de samme tallene, men `bp_kostnad` i regnskapslinjer
    // hopper over hver avlagt måned — importen skriver den ikke når
    // måneden er låst. `bp_linje` er hva fila SA, urørt av låsen, og har
    // derfor alle tolv månedene.
    //
    // Én kilde for BP, ikke to. Sto tallet begge steder, ville de før
    // eller siden svart forskjellig på samme spørsmål.
    supabase
      .from('bp_linje')
      .select('maned, seksjon, kode, post, belop_kr, bp_aar!inner(ar, stasjon_id)')
      .eq('bp_aar.stasjon_id', stasjonId)
      // BARE KOSTNADSSEKSJONEN.
      //
      // Denne sto en periode paa alle tre seksjonene, fordi loennsrommet
      // trengte BP-brutto. Saa tok `0183` over den jobben - og
      // spoerringen ble staaende vid.
      //
      // Prisen var ikke bare treghet: omsetning og varekost er én rad per
      // varekategori per maaned, saa tre seksjoner ganger radtallet med
      // rundt tre. PostgREST kutter paa tusen UTEN aa feile, og et
      // avkortet BP gir et for lavt budsjett - stille, og bare for eieren,
      // siden butikksjefen ikke leser tabellen i det hele tatt.
      .eq('seksjon', 'kostnad')
      // INGEN `slettet_tid` HER. `0155` utelot kolonnen med vilje — se
      // `0154`, der en SELECT-policy som krevde `slettet_tid is null`
      // blokkerte sin egen sletting på 31 tabeller. Et filter på en
      // kolonne som ikke finnes ville gitt en PostgREST-feil, ikke et
      // tomt svar.
      .limit(5000)
      .overrideTypes<{
        maned: number; seksjon: string; kode: string | null; post: string
        belop_kr: number | null; bp_aar: { ar: number; stasjon_id: string }
      }[]>(),
    // FRA VIEWET, IKKE FRA RADENE. Tretten måneder rå lønnsartlinjer er
    // over fem tusen rader, og PostgREST avkorter et for stort svar uten
    // å feile — det ser ut som en liten stasjon (0090, 0166, 0175).
    // `v_lonnsart_maaned` (0180) gjør det til en håndfull rader.
    supabase
      .from('v_lonnsart_maaned')
      .select('maaned, lonnsart, lonnsart_tekst, timer, belop_kr')
      .eq('stasjon_id', stasjonId)
      .gte('maaned', fraOgMed.slice(0, 7))
      .limit(2000)
      .overrideTypes<{
        maaned: string; lonnsart: string; lonnsart_tekst: string
        timer: number; belop_kr: number
      }[]>(),
    // OMSETNING OG BRUTTO I EGEN SPOERRING, ikke slaatt sammen med
    // driftskostnadene over. Begge seksjonene har en rad per
    // avdelingsrollup; lagt til den andre spoerringen ville summen
    // naermet seg PostgREST sitt radtak, og et avkortet svar ser ut som
    // en liten stasjon i stedet for en feil (0090, 0166, 0175).
    supabase
      .from('regnskapslinjer')
      .select('periode, seksjon, post, regnskap')
      .eq('stasjon_id', stasjonId)
      .gte('periode', fraOgMed)
      .in('seksjon', ['omsetning', 'bruttofortjeneste'])
      .is('slettet_tid', null)
      .limit(5000)
      .overrideTypes<{
        periode: string; seksjon: string; post: string; regnskap: number | null
      }[]>(),
    // BP-EN GJENNOM EN SMAL FUNKSJON (0183).
    //
    // `bp_linje` staar med `manager: "none"` i tenantkontrakten - BP-en
    // er kjedens dokument, og en butikksjef som fikk lese den ville sett
    // hver eneste stasjons budsjett. Konsekvensen var utenkt: uten BP
    // forsvant maanedene som bare finnes der, og LOENNSROMMET kunne
    // aldri regnes - funksjonen bygget for butikksjefen virket ikke for
    // butikksjefen.
    //
    // Funksjonen baerer tenantpredikatet selv og gir eieren hele kjeden,
    // butikksjefen sine egne. Spoerringen over staar igjen: den gir
    // eieren kontodetaljen, og svarer tomt for butikksjefen - som er
    // riktig, for hun ser ikke kontoer.
    // FEILEN HAANDTERES DER KALLET STAAR, ikke tretti linjer lenger ned.
    // `supabase.rpc` kaster aldri - den returnerer `{ data: null, error }`
    // - saa et kall mot en funksjon som ikke finnes ville gitt tom liste,
    // og budsjettkolonnen ville staatt tom uten at noe sa fra. «Ingen BP»
    // ser ut akkurat som «BP-en er ikke importert».
    //
    // Innpakket i en async-funksjon i stedet for aa trekkes ut av
    // `Promise.all`: seks spoerringer skal fortsatt gaa parallelt.
    (async () => {
      const { data, error } = await supabase
        .rpc('bp_maaned_for_mine_stasjoner', { fra_maaned: fraOgMed.slice(0, 7) })
      if (error) throw new Error(`Kunne ikke lese BP-månedene: ${error.message}`)
      return (data ?? []) as unknown as {
        stasjon_id: string; maaned: string
        omsetning_kr: number | null; brutto_kr: number | null; lonn_kr: number | null
      }[]
    })(),
    // Bilvaskabonnementene kassa ikke ser (0184). Faa rader - én per uke.
    supabase
      .from('bilvask_abonnement')
      .select('ar, uke, belop_kr')
      .eq('stasjon_id', stasjonId)
      .is('slettet_tid', null)
      .limit(500)
      .overrideTypes<{ ar: number; uke: number; belop_kr: number }[]>(),
    // Butikksjefens oppgitte grunnloenn (0185). Eierens alene - for en
    // butikksjef svarer den tomt, og da faller vi tilbake paa aa baere
    // sist kjente konto 501 framover, som foer.
    supabase
      .from('butikksjef_fastlonn')
      .select('ar, maned, grunnlonn_kr')
      .eq('stasjon_id', stasjonId)
      .is('slettet_tid', null)
      .limit(500)
      .overrideTypes<{ ar: number; maned: number; grunnlonn_kr: number }[]>(),
    // De daglige stoerrelsene, summert i basen (0182).
    supabase
      .from('v_lonnsrom_grunnlag')
      .select('maaned, omsetning_kr, svinn_kr')
      .eq('stasjon_id', stasjonId)
      .gte('maaned', fraOgMed.slice(0, 7))
      .limit(500)
      .overrideTypes<{ maaned: string; omsetning_kr: number; svinn_kr: number }[]>(),
  ])

  // BP-LINJENE STØPES I SAMME FORM som regnskapets, så `byggLonnskost`
  // slipper å kjenne to radtyper. `regnskap: 0` er riktig: en BP-linje
  // er et budsjett, den bærer ingen faktisk kostnad.
  const bpSomKontolinjer: Kontolinje[] = (bp.data ?? [])
    .filter((r) => `${r.bp_aar.ar}-12-31` >= fraOgMed)
    .map((r) => ({
      periode: `${r.bp_aar.ar}-${String(r.maned).padStart(2, '0')}-01`,
      seksjon: 'bp_kostnad',
      kode: r.kode,
      post: r.post,
      regnskap: 0,
      budsjett: r.belop_kr,
    }))
    .filter((r) => r.periode >= fraOgMed)

  const linjer = [...(regnskap.data ?? []), ...bpSomKontolinjer]
  const summer: Lonnsartsum[] = (lonnsart.data ?? []).map((r) => ({
    maaned: r.maaned,
    lonnsart: r.lonnsart,
    lonnsartTekst: r.lonnsart_tekst,
    timer: Number(r.timer),
    belopKr: Number(r.belop_kr),
  }))

  // ===================================================================
  // EN SPØRRING SOM FEILER SKAL ROPE, IKKE BLI TOM
  //
  // Her sto `(grunnlag.data ?? [])` og `(brutto.data ?? [])`. Da `0182`
  // ikke var kjørt mot produksjon, svarte PostgREST «relation
  // v_lonnsrom_grunnlag does not exist» — og koden leste det som «ingen
  // omsetning».
  //
  // Resultatet var en side uten lønnsrom på hver eneste måned, uten et
  // eneste tegn på hvorfor. «Ingen data» og «spørringen feilet» ser helt
  // like ut når feilen svelges — og det er nettopp den formen resten av
  // dette systemet er bygget for å nekte.
  //
  // Kastes den, navngir feilmeldingen den manglende migrasjonen. Det er
  // forskjellen på et kvarter og en halv dag.
  //
  // `hent-feil.test.ts` krever at hver spørring står her.
  // ===================================================================
  for (const [hva, svar] of [
    ['regnskapslinjene', regnskap],
    ['BP-linjene', bp],
    ['lønnsartene', lonnsart],
    ['omsetning og brutto', brutto],
    ['bilvaskabonnementene', vask],
    ['oppgitt grunnlønn', fastlonn],
    ['omsetning og svinn per måned', grunnlag],
  ] as const) {
    if (svar.error) throw new Error(`Kunne ikke lese ${hva}: ${svar.error.message}`)
  }

  const maaneder = byggLonnskost(linjer, BP_LONNSKODER)

  // MAALT MOT REGNSKAPET, IKKE ANTATT.
  //
  // Sykeloenna bokfoeres maaneden etter fravaeret - malt paa juli 2026 til
  // 48 oere. Men det er en PRAKSIS: regnskapskontoret kan periodisere den
  // hvis Kelsar ber om det. En fast forskyvning ville da flyttet den en
  // maaned for langt, hver maaned, uten at noe ble roedt.
  const regnskapSykelonn = new Map(
    maaneder
      .filter((m) => m.avlagt)
      .map((m) => [m.maaned, m.linjer.find((l) => l.kode === '505')?.regnskap ?? 0]),
  )
  // FASTLOENNA FINNES ALDRI I EASY@WORK. En fastloennet stempler ikke
  // for aa faa betalt, saa eksporten har ingen linje - og fravaeret er
  // usynlig. Regnskapet har tallet paa konto 501, og fastloenn er fast,
  // saa sist kjente verdi baeres inn i den aapne maaneden.
  const regnskapFastlonn = new Map(
    maaneder
      .filter((m) => m.avlagt)
      .map((m) => [m.maaned, m.linjer.find((l) => l.kode === '501')?.regnskap ?? 0])
      .filter(([, kr]) => (kr as number) !== 0) as [string, number][],
  )
  // OPPGITT GRUNNLOENN, per maaned. Brukes bare der regnskapet ikke har
  // svart - se `medFastlonn`.
  const oppgittGrunnlonn = new Map(
    (fastlonn.data ?? []).map((r) => [
      `${r.ar}-${String(r.maned).padStart(2, '0')}`,
      Number(r.grunnlonn_kr),
    ]),
  )
  const syk = medOppdagetSykelonn(byggEasyatwork(summer), regnskapSykelonn)

  // DRIVSTOFF UT AV BEGGE SEKSJONENE.
  //
  // Regnskapets `omsetning` og `bruttofortjeneste` per stasjon har en rad
  // per avdelingsrollup, og drivstoff er en av dem. Omsetningen paa den
  // andre siden av marginbroeken kommer fra `v_butikksalg`, som holder
  // drivstoff utenfor. Blandes de, deles brutto MED drivstoff paa
  // omsetning UTEN - og drivstoff er ~68 % av omsetningen, saa marginen
  // hadde blitt nesten tre ganger for hoey.
  const perMaaned = new Map<string, { omsetningKr: number; bruttoKr: number }>()
  for (const r of brutto.data ?? []) {
    // ROLLUPEN OG DELENE ER SAMME KRONER.
    //
    // `40 CR` er summen av `120 Mat`, `140 Kald drikke` og resten, og
    // regnskapet gir begge nivaaene som egne rader. Uten dette filteret
    // telles hver krone to ganger: Dale juli sto med 1 886 352 i brutto
    // der den virkelige er 943 176, og loennsprosenten ble halvparten.
    //
    // Feilen traff BARE de avlagte maanedene - den inneVAERENDE regnes av
    // de daglige salgstallene, som ikke har rollups. Sida saa derfor
    // riktig ut for august og gal for alt foer, som er den vanskeligste
    // formen aa oppdage: den ferske maaneden bekrefter at alt virker.
    if (!erAvdelingsniva(r.post)) continue
    if (erDrivstoff(r.post)) continue
    const m = r.periode.slice(0, 7)
    const rad = perMaaned.get(m) ?? { omsetningKr: 0, bruttoKr: 0 }
    if (r.seksjon === 'omsetning') rad.omsetningKr += r.regnskap ?? 0
    else rad.bruttoKr += r.regnskap ?? 0
    perMaaned.set(m, rad)
  }
  const regnskapsmaaneder = [...perMaaned].map(([maaned, v]) => ({ maaned, ...v }))

  // FRA FUNKSJONEN, IKKE FRA `bp_linje`. Den over gir eieren
  // kontodetaljen; denne gir BEGGE roller maanedstallet. Ville vi brukt
  // `bpPerMaaned` her, ville loennsrommet vaert tomt for butikksjefen -
  // altsaa for den det er bygget for.
  // Formen staar her og ikke som `overrideTypes`: de genererte
  // Supabase-typene kjenner ikke funksjonen fra 0183 enda, og et
  // overstyrt returtypeargument paa `.rpc` kolliderer med den genererte
  // unionen. En smal type ved bruksstedet er aerligere enn en cast som
  // later som den vet mer enn generatoren.
  const bpMaaneder = bpMnd
    .filter((r) => r.stasjon_id === stasjonId)
    .map((r) => ({
      maaned: r.maaned,
      omsetningKr: r.omsetning_kr === null ? null : Number(r.omsetning_kr),
      bruttoKr: r.brutto_kr === null ? null : Number(r.brutto_kr),
      lonnKr: r.lonn_kr === null ? null : Number(r.lonn_kr),
    }))

  // BILVASKENS BRUTTOBIDRAG, per maaned.
  //
  // BARE MAANEDER SOM IKKE ER AVLAGT. Regnskapet har allerede disse
  // kronene naar det kommer - det er derfor bilvask der alltid er
  // hoeyere enn kassaomsetningen. Legges de inn i en avlagt maaned,
  // telles de to ganger.
  const avlagteMaaneder = new Set(
    maaneder.filter((m) => m.avlagt).map((m) => m.maaned),
  )
  const vaskBrutto = new Map(
    [...bruttoPerMaaned(
      (vask.data ?? []).map((r): Ukebelop => ({
        ar: r.ar, uke: r.uke, belopKr: Number(r.belop_kr),
      })),
    )].filter(([m]) => !avlagteMaaneder.has(m)),
  )

  const rom = byggLonnsrom(
    regnskapsmaaneder,
    (grunnlag.data ?? []).map((g) => ({
      maaned: g.maaned,
      omsetningKr: Number(g.omsetning_kr),
      svinnKr: Number(g.svinn_kr),
    })),
    bpMaaneder,
    vaskBrutto,
  )

  return {
    rom,
    bilvaskUker: (vask.data ?? [])
      .map((r) => {
        // Ukas egne maaneder, av samme deling som gir bidraget. Aa telle
        // dagene paa nytt her ville vaert en andre sannhet om hvor uka
        // ligger, og de to ville skilt lag ved neste aarsskifte.
        const iMaaneder = [...bruttoPerMaaned([{
          ar: r.ar, uke: r.uke, belopKr: Number(r.belop_kr),
        }]).keys()]
        const avlagte = iMaaneder.filter((m) => avlagteMaaneder.has(m)).length
        return {
          ar: r.ar,
          uke: r.uke,
          belopKr: Number(r.belop_kr),
          iRegnskapet: (avlagte === 0
            ? 'nei'
            : avlagte === iMaaneder.length ? 'ja' : 'delvis') as 'ja' | 'nei' | 'delvis',
        }
      })
      .sort((a, b) => (b.ar - a.ar) || (b.uke - a.uke)),
    fastlonnMaaneder: (fastlonn.data ?? [])
      .map((r) => ({ ar: r.ar, maned: r.maned, grunnlonnKr: Number(r.grunnlonn_kr) }))
      .sort((a, b) => (b.ar - a.ar) || (b.maned - a.maned)),
    maaneder,
    easyatwork: medFastlonn(syk.maaneder, regnskapFastlonn, oppgittGrunnlonn),
    sykelonn: { moenster: syk.moenster, maalte: syk.maalte, forsinkede: syk.forsinkede },
    ukjenteKoder: ukjenteLonnskoder(
      linjer.filter((l) => l.seksjon === 'bp_kostnad' && l.kode).map((l) => l.kode!),
    ),

  }
}
