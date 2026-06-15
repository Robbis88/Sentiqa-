// Delt payload-type for browser-parsing: klienten parser fila lokalt og sender
// PARSER-RESULTATET hit. Egen fil (ingen server-avhengigheter) så både klient-
// opplasteren og server-kjernen kan importere den uten å dra inn hverandre.
import type { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import type { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import type { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import type { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import type { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import type { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'

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
    }
