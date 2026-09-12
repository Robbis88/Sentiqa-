// Delt payload-type for browser-parsing: klienten parser fila lokalt og sender
// PARSER-RESULTATET hit. Egen fil (ingen server-avhengigheter) så både klient-
// opplasteren og server-kjernen kan importere den uten å dra inn hverandre.
import type { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import type { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import type { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import type { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import type { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import type { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'
import type { Leverandorsum } from '@/lib/parsere/bilagsbuffer'

export type ForhandsPayload =
  | { type: 'st1_salgsstatistikk'; salg: Awaited<ReturnType<typeof parseSalgsstatistikk>> }
  | { type: 'st1_salesperhour_inneute'; timesalg: Awaited<ReturnType<typeof parseSalesPerHourInneUte>> }
  | { type: 'st1_cashierstats'; kasserer: Awaited<ReturnType<typeof parseKassererstatistikk>> }
  | { type: 'salgsgrid_varetrans'; svinn: Awaited<ReturnType<typeof parseVaretransaksjon>> }
  | {
      type: 'regnskap_resultat'
      regnskap: Awaited<ReturnType<typeof parseRegnskap>>
      stasjoner: Awaited<ReturnType<typeof parseRegnskapStasjoner>>
      usynlig: Awaited<ReturnType<typeof parseUsynligSvinn>> | null
      /**
       * Bilagsbufferen, SUMMERT I NETTLESEREN.
       *
       * Raa bilagslinjer er titusener per fil og ville sprengt
       * kroppsgrensen paa en serverhandling (1 MB). Summeringen er den
       * samme som lagringen gjoer uansett - én rad per (butikk, periode,
       * konto, tekst) - saa nettleseren sender det som faktisk skal
       * lagres, ikke raamaterialet.
       *
       * `null` naar fila ikke har pivotbuffer. Noen maanedsfiler mangler
       * den, og det er ikke en feil ved fila.
       */
      bilag: { antall: number; perioder: string[]; summer: Leverandorsum[] } | null
    }
