import 'server-only'
import Anthropic from '@anthropic-ai/sdk'
import { env } from '@/lib/env'
import { lagSupabaseServerKlient } from '@/lib/supabase/server'
import type { InnloggetBruker } from '@/lib/auth/typer'
import { ROLLE_ETIKETT } from '@/lib/auth/typer'
import { VERKTOY, VERKTOY_ETIKETT, verktoyForRolle } from './verktoy'
import { idagOslo } from './periode'
import { erTreffoppfolging, lesPrognose, signerPrognose, type Prognosereferanse } from './prognosereferanse'
import { hentScope, type Scope } from './scope'

const CHATBOT_MODELL = 'claude-opus-4-7'

// Seks runder dekker sammensatte spørsmål og holder chatten innenfor tidsgrensen.
const MAKS_ITERASJONER = 6
const MAKS_SVAR_TOKENS = 16_000

export type Melding = { rolle: 'bruker' | 'assistent'; tekst: string; prognoseRef?: string }
export type AssistentSvar = { svar: string; kilder: string[]; prognoseRef?: string }


function systemprompt(bruker: InnloggetBruker, idag: string, scope?: Scope): string {
  const erEier = bruker.rolle === 'retailer_admin'
  const stasjonskontekst = scope
    ? scope.stasjoner.length
      ? scope.stasjoner.map((s) => `${s.butikknummer} ${s.navn}`).join(', ')
      : 'Ingen stasjoner er tilgjengelige i denne økten.'
    : 'Stasjoner må hentes med list_stasjoner før du navngir dem.'

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
    'KONTEKST SOM GJELDER I DENNE MELDINGEN:',
    `Rolle: ${ROLLE_ETIKETT[bruker.rolle]}. Dato: ${idag}.`,
    `Autoriserte stasjoner: ${stasjonskontekst}.`,
    'Tall, perioder og årsaker er ikke forhåndslastet. Hent dem med riktig verktøy før du konkluderer. Ikke bruk denne kontekstblokken som tallgrunnlag.',
    rolleRegel,
    '',
    'DU ER ET SPØRRELAG, IKKE EN RAPPORTKNAPP.',
    'Verktøyene tar stasjoner og en periode. Velg kilder ut fra spørsmålet, '
    + 'hent det du trenger fra flere av dem, og kall gjerne flere verktøy '
    + 'etter hverandre i samme svar.',
    '',
    'EIER SENTIQA SVARET, SKAL DU HENTE DET — ALDRI REGNE DET UT PÅ NYTT.',
    'Flere av tallene har en egen motor bak seg, med regler du ikke ser: '
    + 'identitet, innlånte ansatte, fastlønn, kalibrering, svinn. Et tall du '
    + 'bygger selv av rådata kan se helt riktig ut og likevel være feil, og '
    + 'du ville ikke hatt noen måte å oppdage det på.',
    '- forventet konto 503 / lønnskost per stasjon  ->  hent_lonnskost',
    '- lønnsrom, styringsavvik, over/under på lønn   ->  hent_lonnsrom',
    '- status mot businessplan                        ->  hent_bp_status',
    '- timer mot budsjett                             ->  hent_timeregnskap',
    '- forventet salg per vare, avdeling eller varegruppe -> forventet_salg (bruk vare med brukerens ord; verktøyet løser nivået)',
    'Finner du ikke et verktøy for tallet, si at Sentiqa ikke har det — '
    + 'ikke bygg det av noe annet.',
    '',
    'DU KAN FORTSATT REGNE FOR Å PRESENTERE. Summere stasjoner du har hentet, '
    + 'finne en differanse mellom to tall verktøyene ga deg, regne ut en '
    + 'prosentvis endring, sortere. Grensen går ved å REKONSTRUERE en sannhet '
    + 'en motor eier — ikke ved aritmetikk i seg selv.',
    '',
    'PROVENIENSEN FØLGER MED UT. Sier et verktøy at et tall er en NEDRE '
    + 'GRENSE (`sikkerhet: minst`), skal du si «minst» — aldri presentere det '
    + 'som et eksakt beløp. Er brutto ANSLÅTT (`brutto_anslaatt: true`), er '
    + 'rommet en prognose, ikke fasit. Er måneden ikke avlagt, er lønnstallet '
    + 'ikke bokført. Og mangler grunnlaget helt, finnes det ingen kroneverdi — '
    + 'da sier du at grunnlaget mangler, ALDRI at det er 0.',
    '',
    'ALDRI FINN PÅ ET TALL. Slå alltid opp. Kan du ikke slå det opp, si det.',
    'Ingen plassholdere: aldri send X stk, tomme felt, undefined, null eller uferdige setninger til brukeren. Ved manglende grunnlag: «Jeg mangler tilstrekkelig datagrunnlag til å beregne en samlet prognose.»',
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
    + 'tilgangen din». Du vet ikke om den finnes, og skal ikke late som du gjør. '
    + 'Når tonen passer kan du være lett og vennlig ertende: «Du er nysgjerrig, '
    + 'men dette ligger utenfor tilgangen din. Spør Robert.» Aldri ydmyk brukeren, '
    + 'påstå noe om private relasjoner eller bruk ertingen til å bekrefte data.',
    'PRESENTASJONSTONEN FOR STIG: Dersom brukeren er butikksjefen Stig på Bønes og spør om en annen stasjon eller admin-only data, '
    + 'kan du én gang svare vennlig og kort: «Stig, vi vet alle at du er nysgjerrig! Men dette får du ikke se her. Spør sjefen din Robert.» '
    + 'Dette er bare en formulering oppå samme tilgangsavslag. Gi aldri tall, stasjonsnavn eller bekreftelse på data utenfor scope.',
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
    'DE TRE VANLIGSTE LEDERSPØRSMÅLENE:',
    '1) Tariff om arbeidstid og pause: kall sla_opp_kunnskap først. Oppgi paragraf/kilde og skill sikker tekst fra spørsmål som må avklares.',
    '2) Forventet salg eller produksjon: kall forventet_salg eller hent_produksjonsplan. For avdeling, vareområde eller varegruppe skal du bruke forventet_salg med brukerens begrep og presentere den deterministiske totalsummen og produktfordelingen verktøyet returnerer. Skill alltid faktisk historisk salg, prognose, produksjonsforslag og planlagt antall. Når produksjonslinjen har forklaring, bruk bare tallene i forklaringssporet for hvorfor-svar; aldri regn ut eller dikt årsaker selv. Hvis sporet mangler, si: «Jeg finner forslaget, men beregningsgrunnlaget ble ikke lagret for denne kjøringen.» Suppler med hent_salg og hent_datadekning ved spørsmål om utvikling eller usikkerhet. Si tydelig når vær, arrangement eller utsolgt ikke finnes som datagrunnlag.',
    '3) Prioritering før ledersamtale: kall hent_bp_status, hent_regnskap, hent_svinn eller hent_lonnsrom etter spørsmålet. Skill sikre funn fra ting som må undersøkes, og foreslå høyst tre konkrete tiltak.',
    'Ved spørsmål om bemanning og lønnsrom skal du bruke hent_lonnsrom/hent_timeregnskap. Målet er riktig bemanning når kundene kommer, ikke færrest mulige timer.',
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
    'For historiske relative datoer som «sist søndag» og «forrige uke», send brukerens ord i relativ-feltet. Verktøyet bestemmer datoene.',
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
  const autorisertScope = await hentScope(supabase, bruker.rolle).catch(() => ({ feil: 'scope kunne ikke leses' }))
  const scope = 'feil' in autorisertScope ? undefined : autorisertScope

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
  async function loggVerktoykall(verktoy: string, argument: Record<string, unknown>) {
    if (!bruker.retailerId) return
    try {
      await supabase.from('ai_tool_log').insert({
        retailer_id: bruker.retailerId, bruker_id: bruker.id, verktoy, argument,
      })
    } catch { /* Logging skal aldri velte svaret. */ }
  }
  let sistePrognose: Prognosereferanse | null = null
  for (const m of historikk) {
    if (m.rolle !== 'assistent') continue
    const ref = lesPrognose(m.prognoseRef, bruker.id, env.ANTHROPIC_API_KEY)
    if (ref) sistePrognose = ref
  }
  // En uavklart vare er ikke en prognose. Oppfølgingen gjelder siste
  // faktisk leverte prognose, og tallene hentes gjennom autorisert verktøy.
  if (sistePrognose && erTreffoppfolging(nyMelding)) {
    const input = { vare: sistePrognose.vare, stasjoner: sistePrognose.stasjoner, fra: sistePrognose.fra, til: sistePrognose.til }
    try {
      const resultat = await VERKTOY.forventet_salg.kjor(input, { supabase, bruker })
      await loggVerktoykall('forventet_salg', input)
      messages.push({ role: 'assistant', content: [{ type: 'tool_use', id: 'siste_prognose', name: 'forventet_salg', input }] })
      messages.push({ role: 'user', content: [{ type: 'tool_result', tool_use_id: 'siste_prognose', content: JSON.stringify({
        ...resultat as Record<string, unknown>,
        samtalereferanse: 'Dette oppslaget gjelder siste leverte prognose som ga et tall. En senere uavklart vareforespørsel erstatter ikke den. Besvar oppfølgingen for denne varen, stasjonen og perioden; endrer brukeren dem eksplisitt, må du gjøre et nytt oppslag.',
      }) }] })
      kilder.add(VERKTOY_ETIKETT.forventet_salg)
    } catch {
      return { svar: 'Jeg fikk ikke kontrollert treffsikkerheten for den siste prognosen. Prøv igjen.', kilder: [] }
    }
  }

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
        max_tokens: MAKS_SVAR_TOKENS,
        system: systemprompt(bruker, idag, scope),
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

      if (block.name === 'forventet_salg') {
        const resultat = utdata as { status?: string; data?: { ean: string; dato: string; fra?: string; til?: string; forventetAntall: number | null }[]; scope?: { besvart?: string[] } }
        const rader = Array.isArray(resultat.data) ? resultat.data.filter((r) => r.forventetAntall != null) : []
        if ((resultat.status === 'ok' || resultat.status === 'malt_null') && rader.length && resultat.scope?.besvart?.length) {
          sistePrognose = { vare: rader[0].ean, stasjoner: resultat.scope.besvart, fra: rader[0].fra ?? rader[0].dato, til: rader[0].til ?? rader[0].dato }
        }
      }

      // Logg kallet (§8/§15). Argumentene er datoer/butikknummer — ingen PII.
      // Logging skal aldri velte svaret → svelg ev. feil.
      await loggVerktoykall(block.name, block.input as Record<string, unknown>)

      resultater.push({
        type: 'tool_result',
        tool_use_id: block.id,
        content: JSON.stringify(utdata),
      })
    }

    messages.push({ role: 'user', content: resultater })
  }

  if (!svar) svar = 'Jeg klarte ikke å fullføre svaret. Prøv å spørre litt enklere.'
  return { svar, kilder: [...kilder], ...(sistePrognose ? { prognoseRef: signerPrognose(sistePrognose, bruker.id, env.ANTHROPIC_API_KEY) } : {}) }
}
