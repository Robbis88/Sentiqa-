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
   * Skjemaet håndhever én rad per stasjon — typisk fordi `stasjon_id`
   * *er* primærnøkkelen (`bemanning_stasjon`).
   *
   * Styrer bare hvordan generatoren lager gyldige fixtures: den kan
   * ikke lage en fersk rad før hver update/delete-test, for den andre
   * ville kollidert med primærnøkkelen. Sier ingenting om
   * autorisasjon.
   */
  en_rad_per_stasjon?: boolean
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
