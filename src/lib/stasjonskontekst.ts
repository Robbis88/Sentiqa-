import 'server-only'
import { cookies } from 'next/headers'
import {
  fraLagring, sidenTaalerAggregat, stasjonFraUrl, velgStasjon, type Stasjon,
} from './stasjonsvalg'

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
  const husket = fraLagring((await cookies()).get(STASJONSKAPSEL)?.value)
  return velgStasjon(alle, { fraUrl, fraHukommelse: husket, tillatAlle })
}

/**
 * Rå verdi i informasjonskapselen, uten tolkning.
 *
 * Brukes til ÉN ting: å se om det huskede valget er noe annet enn det
 * URL-en nettopp ga oss. Er det det, skal hukommelsen oppdateres - og
 * uten dette ville appskallet ikke visst at det var noe å oppdatere.
 */
export async function raaHukommelse(): Promise<string | null> {
  return fraLagring((await cookies()).get(STASJONSKAPSEL)?.value)
}

/**
 * Hele stasjonskonteksten i ett kall.
 *
 * TO TING ENDRET SEG I TRINN 09, og begge var den samme feilen:
 *
 * 1) FUNKSJONEN TAR NÅ RUTA, IKKE ROLLEN. `tillatAlle` var definert som
 *    `rolle === 'retailer_admin'`, og det svarte på feil spørsmål.
 *    «Kan disse tallene summeres?» er en egenskap ved SIDA -
 *    produksjonsplanen for alle stasjoner er ikke en plan noen kan bake
 *    etter - mens «har jeg mer enn én stasjon å summere?» er en egenskap
 *    ved brukeren. Begge må være sanne. Den gamle regelen tok fra
 *    butikksjefen med to stasjoner et aggregat hun allerede hadde.
 *
 * 2) FUNKSJONEN TAR NÅ URL-EN. Før gjorde den det ikke, og kunne derfor
 *    ikke vite om siden under viste noe annet. Det var hele feilen:
 *    appskallet sa «5102 Grenseby» mens /produksjonsplan sto på 4177,
 *    fordi de to leste hver sin kilde. Nå leser de den samme, i den
 *    samme rekkefølgen, gjennom den samme funksjonen - og da KAN de ikke
 *    svare forskjellig.
 *
 * Ingen ny tilgang: `stasjoner` kommer fra en RLS-vaktet spørring, og en
 * butikksjef ser bare sine egne (`har_stasjonstilgang`, 0001).
 */
export async function stasjonskontekst(
  supabase: SupabaseKlient,
  sti: string,
  sok?: URLSearchParams,
): Promise<Stasjonskontekst> {
  const { data } = await supabase
    .from('stasjoner').select('id, navn, butikknummer')
    .is('slettet_tid', null).order('butikknummer')
  const stasjoner = (data ?? []) as Stasjon[]

  const tillatAlle = sidenTaalerAggregat(sti) && stasjoner.length > 1
  const fraUrl = sok ? stasjonFraUrl(sok, stasjoner) : undefined

  return {
    stasjoner,
    valgt: await husketStasjon(stasjoner, fraUrl, tillatAlle),
    tillatAlle,
    /** Sant når URL-en - ikke hukommelsen - avgjorde. */
    fraUrl: fraUrl !== undefined,
  }
}

export type Stasjonskontekst = {
  stasjoner: Stasjon[]
  /** null = alle stasjoner samlet. Bare mulig når `tillatAlle`. */
  valgt: string | null
  tillatAlle: boolean
  fraUrl: boolean
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
