// =====================================================================
// Tenant-kontrakten: typer og innlesing.
//
// `supabase/tenant-kontrakt.json` er eneste håndholdte kilde for hvem
// som når hva. Alt annet — dekningssjekken, atferdsmatrisen og
// varme/kalde i vakthunden — genereres derfra.
//
// EN ROLLE SOM MANGLER EN OPERASJON ER EN PÅSTAND, ikke en stillhet.
// Står `delete` ikke oppført for nettbrettet, genererer vi en test som
// krever at databasen avviser det. Fravær skal bevises.
// =====================================================================

export type TenantScope =
  | 'retailer'
  | 'station'
  | 'retailer_and_station'
  /**
   * `stasjon_id` er nullbar, og null betyr HELE den autentiserte
   * kjeden — aldri global. `tablet_meldinger` er formen: en melding
   * kan gjelde én stasjon eller alle stasjonene i kjeden.
   *
   * Scopet må derfor alltid kreve riktig `retailer_id` i tillegg. En
   * policy som bare sier `stasjon_id is null or stasjon_id in (...)`
   * uten retailer-predikatet ville gjort null til global.
   */
  | 'retailer_or_station'
  | 'global'
/**
 * Om ressursen dekkes av ATFERDSMATRISEN.
 *
 * `warm` gir rader i matrisen — hver rolle × operasjon × stasjon blir
 * en påstand. `cold` gir ingen: tabellen er *sett* av
 * dekningskontrollen, men grensen er ikke *bevist*.
 *
 * **DETTE ER IKKE `varme`/`kalde` I `rls_vakthund.sql.`** De arrayene er
 * håndholdte og handler om YTELSE: en tabell som vokser med drift tåler
 * ikke et per-rad-funksjonskall i policyen. Det er et helt annet
 * spørsmål enn om kjede B ser kjede A.
 *
 * `puls_sporsmal` sto `cold` med den begrunnelsen — «den står allerede i
 * kalde i rls_vakthund.sql» — og var dermed klassifisert uten at en
 * eneste påstand rørte den. Få rader er ingen grunn til å la være å
 * bevise noe.
 *
 * `cold` er derfor for tabeller uten tenantgrense å bevise:
 * `oversettelse_cache` har RLS på og ingen policy, med vilje.
 */
export type Dataklasse = 'warm' | 'cold'
export type Operasjon = 'select' | 'insert' | 'update' | 'delete'

/** Hvor langt en rolle rekker. `none` betyr at rollen aldri når raden. */
export type Rekkevidde =
  | 'none' | 'own_station' | 'assigned_stations' | 'retailer'
  /** Kortformer for nettbrettet — utvides til operasjoner. */
  | 'read' | 'write' | 'read_write'

export type Rollefelt = Rekkevidde | Partial<Record<Operasjon, Rekkevidde>>

export type Ressurs = {
  tabell: string
  tenant_scope: TenantScope
  data_class: Dataklasse
  operasjoner: Operasjon[]
  tablet: Rollefelt
  manager: Rollefelt
  owner: Rollefelt
  /** Indirekte tenantnøkkel, f.eks. `periode_id` på opplaering_utfort. */
  /**
   * Proberaden ER en rad som fasitverdenen allerede har skrevet.
   *
   * `retailers` er sin egen tenantnøkkel: policyen sier
   * `id = gjeldende_retailer_id()`. En fersk proberad tilhører da INGEN,
   * og påstanden «owner_A ser sin egen rad» kan ikke uttrykkes — den må
   * måle kjederaden som finnes, ikke en ny.
   *
   * Verdien er et uttrykk med `{{retailer}}`/`{{stasjon}}`, og den blir
   * radens identitet. Generatoren seeder da ingenting, lager ingen
   * `nyrad_*`, fyller ingen tenantkolonner, og hopper over flyttetesten
   * — det finnes ingen `retailer_id` å flytte.
   *
   * EN SLIK RAD MÅ VÆRE UDØDELIG. Blir en `delete` tillatt for noen
   * rolle, river matrisen sin egen fasitverden midt i kjøringen, og alt
   * etterpå leser «ser ikke» uten at noen policy er rørt. `valider()`
   * krever derfor at ingen rolle når `insert` eller `delete`.
   */
  /**
   * Kolonnen som holder eierens uid. Grensen er BRUKEREN, ikke kjeden.
   *
   * `personlig_punkt` er `user_id = (select auth.uid())` på alle fire
   * operasjonene. Da måler den vanlige formen feil ting: den seeder en
   * rad per stasjon og spør om kjede B ser kjede A. Spørsmålet her er om
   * Ada ser Bos private liste — og det skarpeste beviset er to brukere
   * på SAMME stasjon, `manager_A1` og `manager_A12`. En negativ mot den
   * andre kjeden ville bestått på tenantgrensen alene.
   *
   * Matrisen seeder da én rad per identitet og prøver hver identitet mot
   * sin egen rad og mot hver av de seks andres.
   *
   * VINNER OVER `tenant_scope`. `personlig_kryss` har ingen
   * tenantkolonner i det hele tatt og er `global` i skjemaet — men
   * grensen er brukeren, og den formen er den virkelige.
   *
   * ROLLEFELTENE ER `none` PÅ EN SLIK RESSURS. De beskriver hvor langt
   * en ROLLE rekker inn i andres rader, og svaret er: ingensteds. At
   * hver bruker når sin egen rad, er ikke en rolleegenskap.
   */
  /**
   * En rad ingen skal se, seedet ved siden av den globale proberaden.
   *
   * Verdiene her overstyrer proberaden. `plattform_innlegg` er formen:
   * `plattform_les` slipper gjennom `publisert or rolle =
   * 'plattform_redaktor'`, så et UPUBLISERT utkast skal være usynlig for
   * alle sju identitetene.
   *
   * Uten en slik rad kan en global tabell ikke skille «åpen for alle»
   * fra «åpen, punktum» — begge deler ser like grønne ut når det eneste
   * som måles er en rad alle skal se.
   */
  usynlig_rad?: Record<string, string>
  /**
   * Kolonnen som må være den innloggede, PÅ EN TABELL SOM OGSÅ HAR
   * stasjon og kjede.
   *
   * Ikke det samme som `bruker_kolonne`. Der ER brukeren hele grensen;
   * her er brukerbindingen ett ledd på toppen av tenantgrensen:
   * `kontrolltiltak_bekreftelse` er stasjonens dokumentasjon, men raden
   * skal tilhøre den som faktisk bekreftet.
   *
   * Gir to negativer per identitet, begge på en rad identiteten ELLERS
   * når — ellers ville avvisningen kunnet komme fra stasjonsleddet, og
   * påstanden bevist noe annet enn den sier:
   *
   *   INSERT med en annens uid   → avvist
   *   FLYTTER raden til en annen → avvist
   */
  bruker_binding?: string
  bruker_kolonne?: string
  fast_rad?: string
  tenant_kolonne?: string
  tenant_join?: string
  /** Rader som må finnes før proberaden kan settes inn. */
  seed_ekstra?: string[]
  /** Minste rad som kan settes inn. Kan ikke utledes — håndholdt. */
  proberad: Record<string, string>
  /**
   * `kolonne = verdi` for update-tester. Trengs når proberaden bare har
   * fremmednøkler (`opplaering_utfort`), eller når feltet som ellers
   * ville blitt valgt inngår i en unique-skranke og en kollisjon ville
   * sett ut som en RLS-avvisning (`rutine_utforinger`).
   */
  oppdaterbart?: string
  /**
   * Kvittering for at ressursen bevisst er uten policy.
   *
   * En tabell uten policy er ikke automatisk trygg og ikke automatisk
   * feil — men den skal aldri være usynlig. Står den her, er den sett
   * og begrunnet; står den ikke, er den et funn.
   */
  ingen_policy?: string
  /**
   * Forretningsnøkkelen — `unique (...)` som IKKE er primærnøkkelen og
   * IKKE tenantnøkkelen.
   *
   * Generatoren må kjenne forskjellen på de tre. Tenantnøkkelen skiller
   * kjeder og stasjoner; primærnøkkelen er en uuid ingen kolliderer på;
   * forretningsnøkkelen er den som gjør at *samme identitet to ganger*
   * eller *to identiteter på samme stasjon* kolliderer med 23505.
   *
   * En 23505 er ikke en sikkerhetsavvisning. Står nøkkelen her, krever
   * `valider()` at hver kolonne i den enten varierer per forsøk eller
   * kommer fra en fersk forutsetningsrad.
   */
  business_unik?: string[]
  /**
   * Kolonner i `business_unik` som IKKE settes av fixturen, med
   * begrunnelse. Typisk et løpenummer en trigger tildeler.
   *
   * Unntaket krever en grunn. En tom unntaksliste ville gjort
   * `business_unik` til dekorasjon.
   */
  business_unik_unntak?: Record<string, string>
  /**
   * Navngitt capability-gjeld: dagens tilgang er bredere enn
   * produktbehovet, og lukkingen krever noe mer enn et predikat.
   *
   * Dette er ikke et avvik fra intensjonen som kan strammes med RLS —
   * det er et sted RLS ikke rekker. Feltet finnes for at gjelden skal ha
   * et navn og en plass, i stedet for å bo i en commit-melding.
   */
  capability_gjeld?: string
  /**
   * Fixturen har ÉN plass per stasjon, og den må frigjøres før hvert
   * forsøk.
   *
   * To grunner, og de er begge om skjemaet:
   *
   *   1. `stasjon_id` *er* primærnøkkelen (`bemanning_stasjon`). Da
   *      finnes det bokstavelig talt bare én rad per stasjon.
   *   2. Forretningsnøkkelen har et LITE DOMENE. `bemanning_vindu` har
   *      `unique (stasjon_id, ukedag)`, og ukedag er 1–7. Matrisen
   *      trenger flere rader per stasjon enn sju — nyrad_* alene lager
   *      fjorten — så ingen fordeling av ukedager kan unngå 23505.
   *      Fixturen pinner ukedagen og gjenbruker plassen i stedet.
   *
   * Styrer bare hvordan generatoren lager gyldige fixtures: den kan
   * ikke lage en fersk rad før hver update/delete-test, for den andre
   * ville kollidert. Sier ingenting om autorisasjon.
   */
  en_rad_per_stasjon?: boolean
  /**
   * Kolonnen som identifiserer én rad. `id` når ikke annet er sagt.
   *
   * Ikke alle tabeller har en surrogatnøkkel: `bemanning_stasjon` har
   * `stasjon_id` som primærnøkkel og *ingen* `id`. Generatoren antok
   * `id` overalt og produserte `insert into ... (id, ...)` mot en
   * tabell uten den kolonnen.
   */
  id_kolonne?: string
  /**
   * Kolonnene som TIL SAMMEN identifiserer én rad, når ingen enkelt
   * kolonne gjør det.
   *
   * `timesalg` har primærnøkkel `(retailer_id, stasjon_id, dato, time)`
   * og ingen `id` i det hele tatt. `where id = …` peker da ikke på noen
   * rad — den feiler med 42703, og en feil som ikke er 42501 blir
   * rapportert som «avvist av FEIL grunn». Rødt, men av feil årsak.
   *
   * Verdiene kan ikke utledes av kontrakten: `dato` varierer per forsøk
   * fordi forretningsnøkkelen krever det. Generatoren leser dem derfor
   * av den faste proberaden den nettopp skrev.
   *
   * Fire varme tabeller sto uklassifisert i pulje 6 utelukkende på
   * grunn av dette — ikke fordi noen var i tvil om hvem som skulle nå
   * dem.
   */
  id_kolonner?: string[]
  /**
   * Hva `stasjon_id is null` BETYR, når scopet er `retailer_or_station`.
   *
   *   kjeden     null gjelder hele den autentiserte kjeden, og alle i
   *              kjeden ser raden. `tablet_meldinger` er formen.
   *   kun_eier   null er en klyngelinje som bare `retailer_admin` ser.
   *              `regnskapslinjer` er formen: policyen krever
   *              `stasjon_id is not null` i stasjonsgrenen, så
   *              butikksjefen faller ut.
   *
   * Uten skillet ville generatoren påstått at butikksjefen ser
   * klyngelinjene — og en helt riktig base ville blitt rød.
   */
  null_stasjon?: 'kjeden' | 'kun_eier'
  /**
   * Dagens tilgang er bredere eller annerledes enn produktkontrakten:
   *
   *   tablet      ingen lederdata
   *   butikksjef  kun tildelte stasjoner
   *   owner       egen retailer
   *
   * Kontrakten beskriver DAGENS SANNHET. Ønsket verdi skal aldri skrives
   * inn som om databasen allerede håndhevet den — da forsvinner avviket,
   * og matrisen ville bevist en tilstand som ikke finnes.
   *
   * Rekkefølgen er: dagens sannhet → avviksliste → produktbeslutning →
   * policyendring → ny sannhet.
   */
  avvik_fra_intensjon?: string
}

export type Kontrakt = {
  uklassifisert_tillatt: { tabeller: string[] }
  ressurser: Ressurs[]
}

const KORTFORM: Record<string, Partial<Record<Operasjon, Rekkevidde>>> = {
  read: { select: 'own_station' },
  write: { insert: 'own_station', update: 'own_station' },
  read_write: {
    select: 'own_station', insert: 'own_station',
    update: 'own_station', delete: 'own_station',
  },
}

/**
 * Rekkevidden en rolle har for én operasjon, eller `none`.
 *
 * En bar streng gjelder alle operasjonene i `operasjoner` — bortsett fra
 * kortformene for nettbrettet, som er definert per operasjon.
 */
export function rekkevidde(
  felt: Rollefelt, op: Operasjon, operasjoner: Operasjon[],
): Rekkevidde {
  if (typeof felt === 'string') {
    if (felt === 'none') return 'none'
    const kort = KORTFORM[felt]
    if (kort) return kort[op] ?? 'none'
    return operasjoner.includes(op) ? felt : 'none'
  }
  return felt[op] ?? 'none'
}

/**
 * Validerer kontrakten. Kastes det her, er det fordi en rad ikke gir
 * mening — ikke fordi basen er feil.
 */
export function valider(k: Kontrakt): string[] {
  const feil: string[] = []
  const sett = new Set<string>()

  for (const r of k.ressurser) {
    if (sett.has(r.tabell)) feil.push(`${r.tabell}: står to ganger`)
    sett.add(r.tabell)

    // En stasjonsrolle på en ressurs uten stasjonsbegrep er meningsløs,
    // og ville gitt en generert test som ikke kan skrives.
    if (r.tenant_scope === 'retailer') {
      for (const [rolle, felt] of Object.entries({ tablet: r.tablet, manager: r.manager })) {
        for (const op of r.operasjoner) {
          const rv = rekkevidde(felt as Rollefelt, op, r.operasjoner)
          if (rv === 'own_station' || rv === 'assigned_stations') {
            feil.push(`${r.tabell}: ${rolle}.${op} er «${rv}», men ressursen har ikke stasjonsbegrep`)
          }
        }
      }
    }

    if (r.tenant_kolonne && !r.tenant_join) {
      feil.push(`${r.tabell}: tenant_kolonne uten tenant_join`)
    }

    // EN SAMMENSATT IDENTITET MÅ VÆRE SKRIVBAR. Nevner den en kolonne
    // proberaden ikke setter — og som ikke er en tenantkolonne
    // generatoren fyller selv — finnes det ingen verdi å peke med.
    for (const k of r.id_kolonner ?? []) {
      if (k === 'retailer_id' || k === 'stasjon_id') continue
      const verdi = r.proberad[k]
      if (verdi === undefined) {
        feil.push(`${r.tabell}: id_kolonner nevner «${k}», men proberaden setter den ikke`)
        continue
      }
      // EN IDENTITET KAN IKKE VÆRE FLYKTIG.
      //
      // Predikatet som peker på raden er det samme UTTRYKKET som skrev
      // den. `clock_timestamp()` gir én verdi ved innsetting og en annen
      // ved oppslag — raden ville aldri blitt funnet igjen, og hver
      // avvisning ville blitt meldt som «målraden finnes ikke».
      //
      // Rødt, og av en grunn ingen ville lett etter i policyen.
      if (/clock_timestamp\(|now\(|gen_random_uuid\(|random\(/.test(verdi)) {
        feil.push(`${r.tabell}: id_kolonner-kolonnen «${k}» er flyktig (${verdi}). `
          + 'Identiteten må være det samme uttrykket hver gang det evalueres — '
          + 'bruk {{unik}}, {{unik_dato}} eller en konstant.')
      }
    }
    // EN USYNLIG RAD MÅ HA ET SCOPE DER DEN BETYR NOE. Den seedes bare
    // for globale ressurser; sto den på en stasjonsscopet tabell, ville
    // den vært en påstand om noe generatoren aldri skriver.
    if (r.usynlig_rad && r.tenant_scope !== 'global') {
      feil.push(`${r.tabell}: usynlig_rad krever tenant_scope global`)
    }

    // BRUKERBINDING ER IKKE BRUKERSCOPE. Den ene legger et ledd på
    // toppen av tenantgrensen; den andre ERSTATTER den. Sto begge, ville
    // ressursen blitt rutet til den brukerscopede formen, og
    // stasjonsleddet aldri målt.
    if (r.bruker_binding && r.bruker_kolonne) {
      feil.push(`${r.tabell}: både bruker_binding og bruker_kolonne — velg én`)
    }
    if (r.bruker_binding && r.proberad[r.bruker_binding] !== '\'{{bruker}}\'') {
      feil.push(`${r.tabell}: bruker_binding «${r.bruker_binding}» krever `
        + 'at proberaden setter den til \'{{bruker}}\' — ellers prøver matrisen '
        + 'aldri å skrive i en annens navn')
    }

    // BRUKERSCOPE ER IKKE ROLLESCOPE. Rollefeltene beskriver hvor langt
    // en rolle rekker inn i ANDRES rader; på en brukerscopet ressurs er
    // svaret ingensteds. Sto det noe annet der, ville matrisen påstått
    // at en butikksjef ser sine ansattes private lister.
    if (r.bruker_kolonne) {
      for (const rolle of ['tablet', 'manager', 'owner'] as const) {
        for (const op of r.operasjoner) {
          if (rekkevidde(r[rolle], op, r.operasjoner) !== 'none') {
            feil.push(`${r.tabell}: bruker_kolonne, men ${rolle} når «${op}» — `
              + 'rollefeltene gjelder andres rader, og der rekker ingen rolle')
          }
        }
      }
      if (r.proberad[r.bruker_kolonne] !== undefined) {
        feil.push(`${r.tabell}: proberaden setter «${r.bruker_kolonne}» selv — `
          + 'generatoren eier den kolonnen, én verdi per identitet')
      }
    }

    // EN FASITVERDEN-RAD MÅ IKKE KUNNE SLETTES ELLER DUPLISERES.
    // Se `fast_rad`: en tillatt delete ville revet grunnlaget for hver
    // senere påstand i kjøringen, og en tillatt insert ville kollidert
    // med raden som alt står der (23505, ikke 42501).
    if (r.fast_rad) {
      for (const rolle of ['tablet', 'manager', 'owner'] as const) {
        for (const op of ['insert', 'delete'] as const) {
          if (!r.operasjoner.includes(op)) continue
          if (rekkevidde(r[rolle], op, r.operasjoner) !== 'none') {
            feil.push(`${r.tabell}: fast_rad, men ${rolle} når «${op}» — `
              + 'en rad fasitverdenen eier kan verken slettes eller settes inn på nytt')
          }
        }
      }
    }

    if (r.id_kolonner && r.id_kolonne) {
      feil.push(`${r.tabell}: både id_kolonne og id_kolonner — velg én`)
    }

    // EN SEED SKAL IKKE OPPFINNE EN RAD KONTRAKTEN ALT KJENNER.
    //
    // `seed_ekstra` skriver forutsetningsrader for hånd. Peker en slik
    // linje på en tabell som SELV står klassifisert, finnes det plutselig
    // to håndholdte beskrivelser av samme gyldige rad — og den ene får
    // aldri korrektur.
    //
    // `malekort_scope` seedet sitt eget målekort med (id, retailer_id,
    // navn). `malekort.metrikk` er not-null, så CI stoppet på linje 243
    // etter to minutter, med en 23502 som ikke sier noe om noen policy.
    // Samme form, stillere: seeden for `tildelte_merker` lot
    // `ansatte.ansatt_nr` stå null — en FORRETNINGSNØKKEL. Den var grønn
    // bare fordi kolonnen tåler null i dag.
    //
    // Regelen: dekk proberaden til tabellen du seeder. Skal en kolonne
    // utelates, må ressursen selv slutte å kreve den.
    for (const linje of r.seed_ekstra ?? []) {
      const m = /insert\s+into\s+public\.([a-z0-9_]+)\s*\(([^)]*)\)/i.exec(linje)
      if (!m) continue
      const mal = k.ressurser.find((x) => x.tabell === m[1])
      if (!mal) continue
      const satt = new Set(m[2].split(',').map((c) => c.trim()))
      const mangler = Object.keys(mal.proberad)
        .filter((kol) => !kol.startsWith('$') && !satt.has(kol))
      if (mangler.length > 0) {
        feil.push(`${r.tabell}: seed_ekstra mot «${m[1]}» setter ikke `
          + `${mangler.map((x) => `«${x}»`).join(', ')}, som ${m[1]}s egen proberad krever. `
          + 'To håndholdte beskrivelser av samme rad, og bare én av dem blir rettet.')
      }
    }

    // `null_stasjon` sier hva null BETYR. Uten et null-tilfelle i
    // scopet er feltet en påstand om noe som ikke finnes.
    if (r.null_stasjon && r.tenant_scope !== 'retailer_or_station') {
      feil.push(`${r.tabell}: null_stasjon krever tenant_scope retailer_or_station`)
    }

    // Proberaden er den eneste håndholdte biten per tabell. Mangler den,
    // kan ingen positiv kontroll genereres — og en suite uten positive
    // kontroller kan være grønn fordi alt er ødelagt.
    // En ressurs uten operasjoner er en som ingen rolle når — den har
    // ingen positiv kontroll å ha, og skal ikke kreve en proberad.
    const relevante = Object.keys(r.proberad).filter((k) => !k.startsWith('$'))
    if (r.operasjoner.length > 0 && relevante.length === 0) {
      feil.push(`${r.tabell}: tom proberad — ingen positiv kontroll mulig`)
    }
    if (r.operasjoner.length === 0) {
      for (const rolle of ['tablet', 'manager', 'owner'] as const) {
        if (r[rolle] !== 'none') {
          feil.push(`${r.tabell}: ingen operasjoner, men ${rolle} er «${String(r[rolle])}»`)
        }
      }
    }

    // FORRETNINGSNØKKELEN MÅ VARIERE PER FORSØK.
    //
    // Gjør den ikke det, kolliderer forsøk nummer to med 23505 — og en
    // 23505 er ikke et bevis på noe som helst om tenantgrensen. Den
    // strenge SQLSTATE-regelen gjør en slik fixture rød, ikke grønn,
    // men den skal helst ikke oppstå i det hele tatt.
    for (const kol of r.business_unik ?? []) {
      if (kol === 'stasjon_id' || kol === 'retailer_id') continue // varierer med målet
      const unntak = r.business_unik_unntak?.[kol]
      if (unntak) {
        if (unntak.trim().length < 10) {
          feil.push(`${r.tabell}: unntaket for «${kol}» mangler en reell begrunnelse`)
        }
        continue
      }
      const verdi = r.proberad[kol]
      if (verdi === undefined) {
        feil.push(`${r.tabell}: business_unik nevner «${kol}», men proberaden setter den ikke`)
        continue
      }
      const varierer = /\{\{seed:|\{\{unik/.test(verdi) || /clock_timestamp\(\)/.test(verdi)
      if (!varierer) {
        feil.push(`${r.tabell}: business_unik-kolonnen «${kol}» er konstant (${verdi}). `
          + 'To forsøk ville kollidert med 23505, som ikke er en sikkerhetsavvisning. '
          + 'Bruk {{seed:...}} for en fersk forutsetning, {{unik}}/{{unik_dato}}, eller clock_timestamp().')
      }
    }

    if (r.avvik_fra_intensjon !== undefined && r.avvik_fra_intensjon.trim().length < 30) {
      feil.push(`${r.tabell}: avvik_fra_intensjon mangler en reell beskrivelse`)
    }

    // Gjeld uten beskrivelse er ikke gjeld, det er en TODO.
    if (r.capability_gjeld !== undefined && r.capability_gjeld.trim().length < 30) {
      feil.push(`${r.tabell}: capability_gjeld mangler en reell beskrivelse`)
    }

    for (const t of k.uklassifisert_tillatt.tabeller) {
      if (t === r.tabell) feil.push(`${r.tabell}: står både som klassifisert og uklassifisert`)
    }
  }
  return feil
}
