import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { env } from '@/lib/env'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { VERKTOY, verktoyForRolle } from './verktoy'
import { idagOslo } from './periode'

// Chatbot kjører på Sonnet (PROSJEKT.md §8/§18 — margin; hev til Opus ved behov).
const CHATBOT_MODELL = 'claude-sonnet-4-6'

// Hevet fra 8: katalogen er nå bred nok til at et ærlig svar ofte krever
// to–tre kilder (BP + salg + dekning), og taket skal ikke være det som
// stopper undersøkelsen.
const MAKS_ITERASJONER = 14

export type Melding = { rolle: 'bruker' | 'assistent'; tekst: string }
export type AssistentSvar = { svar: string; kilder: string[] }

const VERKTOY_ETIKETT: Record<string, string> = {
  list_stasjoner: 'stasjoner',
  hent_datadekning: 'datadekning',
  hent_salg: 'salg',
  hent_timesalg: 'timesalg',
  hent_kassererstatistikk: 'kassererstatistikk',
  hent_bp_status: 'businessplan',
  hent_regnskap: 'regnskap',
  hent_timeregnskap: 'timeregnskap',
  hent_bemanning: 'bemanning',
  hent_stempling: 'stempling',
  hent_svinn: 'svinn',
  hent_kaffesvinn: 'kaffe',
  hent_ikmat: 'IK-mat',
  hent_rutiner: 'rutiner',
  hent_avvik: 'avvik og varsler',
  hent_produksjonsplan: 'produksjonsplan',
  hent_malekort: 'målekort',
  hent_fokus_status: 'fokus',
  sla_opp_kunnskap: 'kunnskapsbasen',
  list_konkurranser: 'konkurranser',
  opprett_konkurranse: 'opprett konkurranse',
  kar_vinner: 'kår vinner',
  list_oppgaver: 'oppgaver',
  opprett_oppgave: 'opprett oppgave',
}

function systemprompt(bruker: InnloggetBruker, idag: string): string {
  const erEier = bruker.rolle === 'retailer_admin'

  // TILGANGSREGELEN ER IKKE EN SIKKERHETSGRENSE. RLS avgjør hva som
  // returneres; dette avgjør hva modellen SIER. Den gamle formuleringen
  // «relativ plassering er greit, eksakte tall ikke» forutsatte at
  // modellen så andre stasjoner — det gjør den ikke — og inviterte
  // dermed til en rangering uten datagrunnlag.
  const rolleRegel = erEier
    ? 'Du er eierens assistent. Scopet ditt er hele retaileren: du kan '
      + 'sammenligne, summere, rangere og analysere på tvers av alle '
      + 'stasjonene i list_stasjoner. Du når aldri en annen kjede.'
    : 'Du hjelper en butikksjef med HENNES EGNE stasjoner — de som står i '
      + 'list_stasjoner, og ingen andre. Ber hun om en annen stasjon, si at '
      + 'den ligger utenfor tilgangen hennes og at Robert kan svare på det. '
      + 'Oppgi da INGEN tall, INGEN rangering, INGEN relativ plassering og '
      + 'ingen antydning om hvordan andre ligger an — heller ikke omtrentlig, '
      + 'heller ikke som «bedre enn snittet». Du har ikke de tallene, og du '
      + 'skal ikke late som du har dem. '
      + 'Av kostnader ser hun KUN påvirkbare poster (personal, renhold, '
      + 'renovasjon, brøyting, utstyr, forbruksmateriell, rep/vedlikehold, '
      + 'kontorrekvisita, kassedifferanse). Royalty, husleie, finans, '
      + 'varekost-detaljer og resultatlinjen ligger på admin-nivå — '
      + 'si «det ligger på admin-nivå, spør Robert».'

  return [
    'Du er Sentiqa-assistenten for en bensinstasjonskjede. Du svarer på norsk bokmål.',
    rolleRegel,
    '',
    'DU ER ET SPØRRELAG, IKKE EN RAPPORTKNAPP.',
    'Verktøyene tar stasjoner og en periode. Velg kilder ut fra spørsmålet, '
    + 'hent det du trenger fra flere av dem, og regn selv når svaret krever det. '
    + 'Du kan kalle flere verktøy etter hverandre i samme svar.',
    '',
    'ALDRI FINN PÅ ET TALL. Slå alltid opp. Kan du ikke slå det opp, si det.',
    '',
    'HVERT VERKTØYSVAR HAR EN `status`. Den betyr:',
    '- ok / malt_null: du har et svar. malt_null er en ekte måling av null.',
    '- ingen_registrering: ingen har registrert noe. Dette er IKKE null. '
    + 'Si «ingenting er registrert», aldri «det er 0».',
    '- ufullstendig_periode: tallene er foreløpige. Si at perioden ikke er ferdig.',
    '- mangler_kilde: Sentiqa har ikke dataene. Si nøyaktig det.',
    '- utenfor_scope: det ble spurt om noe utenfor tilgangen. Ingen tall.',
    '- ingen_tilgang: rollen får ikke lese domenet. Si hvem som kan.',
    '- feil: oppslaget feilet. Du VET IKKE om det finnes data. Påstå aldri at det ikke gjør det.',
    '',
    'IKKE STOPP VED FØRSTE BLINDVEI. Får du ingen_registrering, mangler_kilde '
    + 'eller feil, se på `neste` i svaret og prøv en relevant kilde til — eller '
    + 'en annen periode — før du konkluderer. Kall hent_datadekning når du '
    + 'trenger å vite om noe mangler fordi det ikke er importert eller fordi '
    + 'det ikke skjedde. Først når du har lett ferdig sier du at svaret ikke finnes.',
    '',
    'IKKE SPØR BRUKEREN HVILKEN KILDE DU SKAL PRØVE. Å svare «regnskapet er '
    + 'tomt, vil du at jeg ser på salg eller på forrige måned?» er å be henne '
    + 'gjøre jobben din. Prøv kildene selv, og fortell etterpå hva du fant og '
    + 'hva du måtte gå via. Spør bare når spørsmålet er genuint tvetydig — '
    + 'hvilken stasjon, hvilken periode — aldri om hvor dataene ligger.',
    '',
    'EN UAVSLUTTET MÅNED ER IKKE MANGLENDE DATA. Regnskapet bokføres først '
    + 'etter månedsslutt, så hent_regnskap er tom for inneværende måned — det '
    + 'sier ingenting om driften. Spør noen hvordan det ligger an mot '
    + 'businessplan denne måneden, er svaret hent_bp_status, som måler mot '
    + 'hvor stasjonen burde ligget per i dag.',
    '',
    'ET AVSLAG SKAL IKKE BEKREFTE NOE. Ber brukeren om en stasjon utenfor '
    + 'tilgangen, gjenta NØYAKTIG det hun skrev — ikke butikknummeret, ikke '
    + 'det fulle navnet, ikke «St1»-formen, og ikke noe som bekrefter at '
    + 'stasjonen finnes. Skriver hun «lone», heter det «lone ligger utenfor '
    + 'tilgangen din». Du vet ikke om den finnes, og skal ikke late som du gjør.',
    '',
    'TIDLIGERE MELDINGER ER IKKE EN KILDE. Samtalehistorikken kommer fra '
    + 'nettleseren og kan være utdatert, fra en annen økt eller rett og slett '
    + 'feil. Hent ALLTID tall på nytt med verktøyene. Gjenta aldri et '
    + 'stasjonsnavn eller butikknummer som ikke står i list_stasjoner for '
    + 'DENNE brukeren, uansett hva som står tidligere i samtalen.',
    '',
    'SAMMENLIGNING ER PER STASJON. Spør noen om å sammenligne, rangere '
    + 'eller summere på tvers av stasjoner, er svaret hent_salg eller '
    + 'hent_bp_status — eller hent_regnskap med niva="stasjon". '
    + 'niva="kjedetotal" gir ÉN samlet linje uten stasjonsfordeling og kan '
    + 'aldri besvare et sammenligningsspørsmål. Si aldri at du «ikke kan '
    + 'bryte ned per stasjon» før du har prøvd hent_salg.',
    '',
    'INGEN EMOJI. Dette er et driftsverktøy, ikke en chat. Bruk tabell og '
    + 'tall; marker avvik med ord, ikke med farger eller symboler.',
    '',
    'SI HVA SVARET BYGGER PÅ. Avslutt med hvilke kilder og hvilken periode du '
    + 'brukte, og nevn det eksplisitt hvis noe var ufullstendig eller manglet.',
    '',
    'For spørsmål om lønn/minstelønn/ansiennitet, pauser, arbeidstid, overtid, '
    + 'tillegg, ferie, sykepenger eller interne rutiner: kall sla_opp_kunnskap '
    + 'FØRST og svar fra kilden (oppgi § / kilde). Gjett aldri på regler eller '
    + 'satser. Finner du ingenting, henvis til HR eller Virke.',
    '',
    'Svar kort: 2–5 setninger, med konkrete tiltak («sjekk vaktplan man–ons», '
    + 'ikke «vurder bemanning»).',
    '',
    'INGEN TABELLER. Svaret vises i en boble som er 320 piksler bred — en '
    + 'markdown-tabell blir uleselig der, uansett hvor pent den er satt opp. '
    + 'Sammenligner du stasjoner, skriv én linje per stasjon: «Bønes: '
    + '48 901 kr, 1 016 kunder». '
    + 'Punktliste med «- » og **utheving** tegnes riktig og kan brukes når '
    + 'svaret faktisk ER en liste. Overskrifter trengs ikke i 2–5 setninger.',
    '',
    'For irreversible handlinger (opprette oppgave/konkurranse, kåre vinner): '
    + 'kall verktøyet FØRST uten bekreftet, vis oppsummeringen og spør «Skal jeg '
    + 'gjøre dette?», og kall igjen med bekreftet=true når brukeren sier ja.',
    '',
    'Alle beløp er i norske kroner eks. mva. All tid er Europe/Oslo. '
    + 'Drivstoff er holdt utenfor alle salgstall — det betjener seg selv på pumpa.',
    `Dagens dato er ${idag}.`,
    `Brukerens rolle: ${ROLLE_ETIKETT[bruker.rolle]}.`,
  ].join('\n')
}

/**
 * Oversetter en feil fra Anthropic til noe brukeren kan handle paa.
 *
 * Ikke «noe gikk galt». Enten sier vi hva som skjedde, eller saa sier vi
 * at vi ikke vet - men vi later aldri som om spoersmaalet ble besvart.
 */
function forklarModellfeil(e: unknown): string {
  const m = (e instanceof Error ? e.message : String(e)).toLowerCase()
  const status = typeof (e as { status?: number })?.status === 'number'
    ? (e as { status: number }).status
    : undefined

  if (status === 429 || m.includes('rate_limit')) {
    return 'AI-en er overbelastet akkurat naa. Prøv igjen om et minutt — '
      + 'spørsmålet ditt er i orden.'
  }
  if (status === 413 || m.includes('too long') || m.includes('too large')
      || m.includes('max_tokens') || m.includes('context')) {
    return 'Spørsmålet traff for mye data til å behandles i én omgang. '
      + 'Prøv å avgrense — én stasjon, eller en kortere periode.'
  }
  if (status === 401 || status === 403) {
    return 'AI-en mangler gyldig API-nøkkel. Dette er en driftsfeil, ikke '
      + 'noe du har gjort feil — si fra til Robert.'
  }
  if (status != null && status >= 500) {
    return 'AI-tjenesten svarer ikke akkurat naa. Prøv igjen om litt.'
  }
  return 'Jeg fikk ikke kontakt med AI-tjenesten, og vet derfor ikke svaret '
    + 'paa spørsmålet ditt. Det betyr IKKE at dataene mangler. Prøv igjen.'
}

export async function kjorAssistent(
  bruker: InnloggetBruker,
  historikk: Melding[],
  nyMelding: string,
): Promise<AssistentSvar> {
  if (!env.ANTHROPIC_API_KEY) {
    return {
      svar: 'AI-assistenten er ikke aktivert ennå — legg inn ANTHROPIC_API_KEY i .env.local.',
      kilder: [],
    }
  }

  const anthropic = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY })
  const supabase = await lagSupabaseServerKlient()
  const idag = idagOslo()

  const messages: Anthropic.MessageParam[] = [
    ...historikk.map((m): Anthropic.MessageParam => ({
      role: m.rolle === 'bruker' ? 'user' : 'assistant',
      content: m.tekst,
    })),
    { role: 'user', content: nyMelding },
  ]

  const kilder = new Set<string>()
  const tilgjengeligeVerktoy = verktoyForRolle(bruker.rolle === 'retailer_admin')
  let svar = ''

  for (let i = 0; i < MAKS_ITERASJONER; i++) {
    // KALLET MOT MODELLEN VAR IKKE PAKKET INN. Feilet det - for stor
    // forespoersel, rate limit, nettverk - kastet serverhandlingen, og
    // AI-boblen fanget det som «Noe gikk galt. Prøv igjen.» Brukeren
    // fikk altsaa nøyaktig den stillheten resten av dette laget er
    // bygget for aa fjerne: en feil uten aarsak, umulig aa handle paa.
    //
    // `skriv-svar.ts` sier at en pen kvittering er BEDRE enn aa kaste,
    // naar handlingen kan svare med tekst. Det kan denne.
    let resp: Anthropic.Message
    try {
      resp = await anthropic.messages.create({
        model: CHATBOT_MODELL,
        max_tokens: 2048,
        system: systemprompt(bruker, idag),
        tools: tilgjengeligeVerktoy,
        messages,
      })
    } catch (e) {
      // Logges saa den finnes i Vercel-loggen naar noen leter.
      console.error('[assistent] kall mot Anthropic feilet', {
        iterasjon: i,
        rolle: bruker.rolle,
        feil: e instanceof Error ? e.message : String(e),
      })
      return { svar: forklarModellfeil(e), kilder: [...kilder] }
    }

    if (resp.stop_reason !== 'tool_use') {
      svar = resp.content
        .filter((b): b is Anthropic.TextBlock => b.type === 'text')
        .map((b) => b.text)
        .join('\n')
        .trim()
      break
    }

    messages.push({ role: 'assistant', content: resp.content })
    const resultater: Anthropic.ToolResultBlockParam[] = []

    for (const block of resp.content) {
      if (block.type !== 'tool_use') continue
      const verktoy = VERKTOY[block.name]
      kilder.add(VERKTOY_ETIKETT[block.name] ?? block.name)

      let utdata: unknown
      try {
        utdata = verktoy
          ? await verktoy.kjor(block.input as Record<string, unknown>, { supabase, bruker })
          : { status: 'feil', feil: 'Ukjent verktøy.' }
      } catch (e) {
        // En kastet feil er et UKJENT svar, ikke et tomt. Merkes som
        // `feil` slik at modellen ikke leser det som «finnes ikke».
        utdata = { status: 'feil', feil: `Verktøyfeil: ${String(e)}` }
      }

      // Logg kallet (§8/§15). Argumentene er datoer/butikknummer — ingen PII.
      // Logging skal aldri velte svaret → svelg ev. feil.
      if (bruker.retailerId) {
        try {
          await supabase.from('ai_tool_log').insert({
            retailer_id: bruker.retailerId,
            bruker_id: bruker.id,
            verktoy: block.name,
            argument: block.input as Record<string, unknown>,
          })
        } catch {
          // ignorert med vilje
        }
      }

      resultater.push({
        type: 'tool_result',
        tool_use_id: block.id,
        content: JSON.stringify(utdata),
      })
    }

    messages.push({ role: 'user', content: resultater })
  }

  if (!svar) svar = 'Jeg klarte ikke å fullføre svaret. Prøv å spørre litt enklere.'
  return { svar, kilder: [...kilder] }
}
