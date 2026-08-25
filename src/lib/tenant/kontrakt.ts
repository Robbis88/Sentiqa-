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

export type TenantScope = 'retailer' | 'station' | 'retailer_and_station' | 'global'
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

    if (r.operasjoner.length === 0) feil.push(`${r.tabell}: ingen operasjoner`)

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
    if (Object.keys(r.proberad).length === 0) {
      feil.push(`${r.tabell}: tom proberad — ingen positiv kontroll mulig`)
    }

    for (const t of k.uklassifisert_tillatt.tabeller) {
      if (t === r.tabell) feil.push(`${r.tabell}: står både som klassifisert og uklassifisert`)
    }
  }
  return feil
}
