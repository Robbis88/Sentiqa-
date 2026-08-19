import 'server-only'
import { cookies } from 'next/headers'
import { velgStasjon, type Stasjon } from './stasjonsvalg'

/**
 * Navnet på informasjonskapselen.
 *
 * Bor her, ikke i 'use server'-fila: den kan bare eksportere async
 * funksjoner, og en konstant der brekker bygget.
 */
export const STASJONSKAPSEL = 'sentiqa_stasjon'

/**
 * Hvilken stasjon siden skal vise.
 *
 * Erstatter `alle.find((s) => s.id === sok.stasjon) ?? alle[0]`, som sto
 * i hver side og ignorerte at brukeren hadde valgt noe i toppstripen.
 *
 * URL-en vinner fortsatt — en delt lenke skal vise det den lovet.
 */
export async function husketStasjon(
  alle: Stasjon[],
  fraUrl?: string | null,
  tillatAlle = false,
): Promise<string | null> {
  const husket = (await cookies()).get(STASJONSKAPSEL)?.value ?? null
  return velgStasjon(alle, { fraUrl, fraHukommelse: husket, tillatAlle })
}

/**
 * Hele stasjonskonteksten i ett kall.
 *
 * Logikken lå i to halvdeler: `husketStasjon()` her, og oppslaget av
 * hvilke stasjoner brukeren har tilgang til gjentatt i hver side som
 * trengte det. Seks sider gjorde det samme fire linjene, og hver av dem
 * kunne glemme `tillatAlle` — som er forskjellen på at eieren ser
 * porteføljen samlet og at han ser den første stasjonen sin.
 *
 * ENDRER INGEN OPPFØRSEL. Samme spørring, samme prioritering:
 * URL vinner over informasjonskapsel, som vinner over første stasjon.
 * En delt lenke skal fortsatt vise det den lovet.
 *
 * `tillatAlle` følger rollen, ikke sida: bare eieren har flere stasjoner
 * å se samlet. En butikksjef med én stasjon får ingen velger i det hele
 * tatt — se `visVelger`.
 */
export async function stasjonskontekst(
  supabase: SupabaseKlient,
  rolle: string,
  fraUrl?: string | null,
): Promise<Stasjonskontekst> {
  const { data } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const stasjoner = (data ?? []) as Stasjon[]
  const tillatAlle = rolle === 'retailer_admin'
  return {
    stasjoner,
    valgt: await husketStasjon(stasjoner, fraUrl, tillatAlle),
    tillatAlle,
  }
}

export type Stasjonskontekst = {
  stasjoner: Stasjon[]
  /** null = alle stasjoner samlet. Bare mulig når `tillatAlle`. */
  valgt: string | null
  tillatAlle: boolean
}

type SupabaseKlient = {
  from: (tabell: string) => {
    select: (kolonner: string) => {
      is: (kolonne: string, verdi: null) => {
        order: (kolonne: string) => PromiseLike<{ data: unknown }>
      }
    }
  }
}
