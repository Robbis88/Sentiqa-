'use client'
import { useState } from 'react'
import { gjenkjennRapporttype } from '@/lib/parsere/gjenkjenn'
import type { Rapporttype } from '@/lib/parsere/typer'
import { tilServeren, FOR_STOR } from '@/lib/import/rute'
import { parseSalgsstatistikk } from '@/lib/parsere/salgsstatistikk'
import { parseSalesPerHourInneUte } from '@/lib/parsere/salesperhourinneute'
import { parseKassererstatistikk } from '@/lib/parsere/kassererstatistikk'
import { parseVaretransaksjon } from '@/lib/parsere/varetransaksjon'
import { parseRegnskap, parseRegnskapStasjoner } from '@/lib/parsere/regnskap'
import { parseUsynligSvinn } from '@/lib/parsere/usynligsvinn'
import type { ForhandsPayload } from '@/lib/import/typer'
import { importerForhandsparset, registrerRaaFil } from './handlinger'
import { behandleJobb } from '@/lib/import/behandle'
import { lagSupabaseNettleserKlient } from '@/lib/supabase/client'
import { trygtFilnavn } from '@/lib/storage-noekkel'
import { BehandleKnapp } from './behandle-knapp'

// Nettleseren laster hele arbeidsboka i minnet for å parse den. St1s
// forretningsplan er ~27 MB med et ark på 289 000 rader og koster over 2 GB —
// fanen ryker før den er ferdig. Slike filer skal gjennom drop-zonen, der
// serveren strømmer dem. Grensen ligger godt over alt vi ellers mottar
// (regnskapsrapporten er ~1,2 MB, timesalg noen hundre kB).
//
// Selve regelen for hvem som går hvor bor i `@/lib/import/rute` — den er
// ikke bare en størrelsesgrense, og den skal ha en test.

type Tilstand = 'venter' | 'parser' | 'lagrer' | 'ferdig' | 'iko' | 'hoppet' | 'feilet'
// `jobbId` settes når fila alt er lastet opp. Da kan handlingen tilbys
// her, i stedet for å sende brukeren til en statusliste som bare viser
// de 50 siste jobbene — en BP fra i fjor står ikke der.
type FilRad = { navn: string; tilstand: Tilstand; melding?: string; jobbId?: string }

// 'iko' er BLA, ikke gronn: fila er lagret, men ingen data er importert
// enda. Gronn skal vaere reservert for tall som faktisk ligger i basen -
// ellers leser man den gronne prikken og lar forretningsplanen ligge.
const PIP: Record<Tilstand, string> = { venter: '', parser: 'gul', lagrer: 'gul', ferdig: 'gronn', iko: 'bla', hoppet: 'bla', feilet: 'rod' }
const ETIKETT: Record<Tilstand, string> = { venter: 'Venter', parser: 'Leser fila …', lagrer: 'Lagrer …', ferdig: 'Importert', iko: 'Ikke importert ennå', hoppet: 'Hoppet over', feilet: 'Feilet' }

async function sha256Hex(buf: ArrayBuffer): Promise<string> {
  const d = await crypto.subtle.digest('SHA-256', buf)
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function byggPayload(
  buf: ArrayBuffer, type: Rapporttype,
): Promise<ForhandsPayload | null> {
  switch (type) {
    case 'st1_salgsstatistikk': return { type, salg: await parseSalgsstatistikk(buf) }
    case 'st1_salesperhour_inneute': return { type, timesalg: await parseSalesPerHourInneUte(buf) }
    case 'st1_cashierstats': return { type, kasserer: await parseKassererstatistikk(buf) }
    case 'salgsgrid_varetrans': return { type, svinn: await parseVaretransaksjon(buf) }
    case 'regnskap_resultat': {
      let usynlig: Awaited<ReturnType<typeof parseUsynligSvinn>> | null = null
      try { usynlig = await parseUsynligSvinn(buf) } catch { usynlig = null }
      return { type, regnskap: await parseRegnskap(buf), stasjoner: await parseRegnskapStasjoner(buf), usynlig }
    }
    default: return null
  }
}

// Laster fila rett til Storage fra nettleseren og ber serveren registrere den.
// Stien må ligge under {retailer_id}/ — det er både storage-policyen (0080) og
// serverens egen sjekk. Retailer-id-en hentes fra profilen, ikke fra klienten.
async function tilStorage(
  fil: File,
): Promise<{ ok: boolean; hoppet?: boolean; melding?: string; feil?: string; jobbId?: string }> {
  const supabase = lagSupabaseNettleserKlient()
  const { data: bruker } = await supabase.auth.getUser()
  if (!bruker.user) return { ok: false, feil: 'Ikke innlogget.' }

  const { data: profil } = await supabase
    .from('profiler').select('retailer_id').eq('id', bruker.user.id).single()
  const retailerId = (profil as { retailer_id: string } | null)?.retailer_id
  if (!retailerId) return { ok: false, feil: 'Fant ingen kjede på brukeren.' }

  const buf = await fil.arrayBuffer()
  const sha = await sha256Hex(buf)
  const sti = `${retailerId}/${crypto.randomUUID()}-${trygtFilnavn(fil.name)}`

  const { error } = await supabase.storage
    .from('raa-filer')
    .upload(sti, fil, { contentType: fil.type || 'application/octet-stream' })
  if (error) return { ok: false, feil: `Opplasting feilet: ${error.message}` }

  return await registrerRaaFil({ filnavn: fil.name, sha256: sha, storrelse: fil.size, sti })
}

export function KlientOpplaster() {
  const [filer, setFiler] = useState<FilRad[]>([])
  const [kjorer, setKjorer] = useState(false)

  async function kjor(valgte: File[]) {
    if (valgte.length === 0) return
    setKjorer(true)
    setFiler(valgte.map((f) => ({ navn: f.name, tilstand: 'venter' as Tilstand })))
    const sett = (i: number, tilstand: Tilstand, melding?: string, jobbId?: string) =>
      setFiler((prev) => prev.map((x, j) => (j === i ? { ...x, tilstand, melding, jobbId } : x)))

    for (let i = 0; i < valgte.length; i++) {
      try {
        // Store filer parses ikke her — de lastes rett til Storage og legges i
        // kø for serveren. Nettleseren ville brukt over 2 GB på å åpne dem.
        //
        // PDF og CSV går samme vei. Nettleserparseren her kan bare xlsx —
        // slipper man en CSV inn i den, kveles zip-leseren og fila «feiler»
        // uten at noen skjønner hvorfor. Serveren kan begge deler.
        const tilServer = async () => {
          sett(i, 'lagrer')
          const res = await tilStorage(valgte[i])
          if (res.hoppet) {
            sett(
              i, 'hoppet',
              res.jobbId
                ? 'Allerede lastet opp — behandle den på nytt her:'
                : (res.melding ?? 'Allerede lastet opp'),
              res.jobbId,
            )
          } else if (res.ok) sett(i, 'iko', 'Ligger i kø — behandles i natt, eller trykk «Behandle» under')
          else sett(i, 'feilet', res.feil)
        }
        const fil = { navn: valgte[i].name, storrelse: valgte[i].size }
        // Første runde: det vi kan se uten å åpne fila.
        if (tilServeren(fil)) {
          await tilServer()
          continue
        }
        sett(i, 'parser')
        const buf = await valgte[i].arrayBuffer()
        const type = await gjenkjennRapporttype(buf)
        // Andre runde, nå med typen. Forretningsplanen har ingen
        // nettleserparser og skal hit uansett hvor liten den er — se
        // `rute.ts` for hvorfor det ikke kan stå som en størrelsesgrense.
        if (tilServeren({ ...fil, type })) {
          await tilServer()
          continue
        }

        const payload = await byggPayload(buf, type)
        if (!payload) { sett(i, 'feilet', 'Ukjent/ustøttet filtype'); continue }
        const sha = await sha256Hex(buf)
        sett(i, 'lagrer')
        const res = await importerForhandsparset({ filnavn: valgte[i].name, sha256: sha, storrelse: valgte[i].size, payload })
        if (res.hoppet) sett(i, 'hoppet', res.melding ?? 'Allerede importert')
        else if (res.ok) sett(i, 'ferdig', `${res.antallRader ?? 0} linjer`)
        else sett(i, 'feilet', res.feil)
      } catch (e) {
        sett(i, 'feilet', e instanceof Error ? e.message : String(e))
      }
    }
    setKjorer(false)
  }

  const ferdige = filer.filter((f) => f.tilstand === 'ferdig').length
  const feilede = filer.filter((f) => f.tilstand === 'feilet').length
  const hoppede = filer.filter((f) => f.tilstand === 'hoppet').length

  return (
    <div className="klient-opplaster">
      <label className="felt">
        <span><strong>Velg filer</strong> — salgsstatistikk, timesalg, regnskap, forretningsplan</span>
        <input
          type="file"
          multiple
          accept=".csv,.txt,.xlsx,.xlsm,.xls,.pdf"
          disabled={kjorer}
          onChange={(e) => kjor([...(e.target.files ?? [])])}
        />
      </label>
      <p className="undertittel">
        Starter med én gang — ingen knapp å trykke. Velg gjerne mange på én gang; de tas én og én, og
        én rar fil stopper ikke resten.
      </p>
      <p className="undertittel">
        <strong>Forretningsplanen</strong> — uansett størrelse — og andre filer over{' '}
        {Math.round(FOR_STOR / 1024 / 1024)} MB lastes rett til lagring og legges i kø.
        Den behandles automatisk i natt — vil du ha tallene inn med én gang, trykk{' '}
        <strong>«Behandle»</strong> på raden i statuslista lenger ned. Er fila lastet opp
        fra før, får du knappen her.
      </p>

      {filer.length > 0 && (
        <>
          <p className="undertittel">
            {kjorer ? 'Behandler …' : 'Ferdig.'} {ferdige} importert{hoppede ? ` · ${hoppede} hoppet over` : ''}{feilede ? ` · ${feilede} feilet` : ''} av {filer.length}.
          </p>
          <ul className="arr-liste">
            {filer.map((f, i) => (
              <li key={i}>
                <span>
                  {f.navn} {f.melding ? <span className="undertittel">· {f.melding}</span> : null}
                  {/* Handlingen der brukeren er. En «Hoppet over» uten vei
                      videre er en blindvei, og statuslista under viser bare
                      de 50 siste jobbene. */}
                  {f.jobbId ? (
                    <form action={behandleJobb}>
                      <input type="hidden" name="jobbId" value={f.jobbId} />
                      <BehandleKnapp tekst="Behandle på nytt" />
                    </form>
                  ) : null}
                </span>
                <span className={`status-pip ${PIP[f.tilstand]}`}>{ETIKETT[f.tilstand]}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  )
}
