import type { Metadata } from 'next'
import Link from 'next/link'
import { DPA_VERSJON } from '@/lib/juss'

export const metadata: Metadata = {
  title: 'Databehandleravtale – Sentiqa',
  description:
    'Databehandleravtale (DPA) mellom R-G Invest AS (databehandler) og kunden (behandlingsansvarlig) for bruk av Sentiqa.',
}

export default function DatabehandleravtaleSide() {
  return (
    <main className="dok">
      <p className="dok-tilbake">
        <Link href="/">← Tilbake til Sentiqa</Link>
      </p>

      <h1>Databehandleravtale</h1>
      <p className="dok-meta">Versjon {DPA_VERSJON} · utkast til juridisk gjennomgang</p>

      <div className="dok-merknad" role="note">
        <strong>Utkast.</strong> Avtalen beskriver hvordan Sentiqa faktisk er bygget og driftes, men er
        ikke ferdig juridisk gjennomgått. Den er et solid utgangspunkt — ikke en erstatning for juridisk
        rådgivning. Endelig, bindende versjon godkjennes før kommersiell lansering.
      </div>

      <h2>1. Parter og bakgrunn</h2>
      <p>
        Denne databehandleravtalen («Avtalen») inngås mellom <strong>R-G Invest AS</strong>, org.nr{' '}
        <strong>937 861 621</strong> («Databehandleren»), og kunden som tar i bruk Sentiqa
        («Behandlingsansvarlig»). Avtalen regulerer Databehandlerens behandling av personopplysninger på
        vegne av Behandlingsansvarlig i forbindelse med leveransen av tjenesten Sentiqa, og utfyller
        partenes øvrige avtale om bruk av tjenesten.
      </p>
      <p>
        Ved motstrid om behandling av personopplysninger går Avtalen foran øvrige avtaler mellom partene.
        Avtalen oppfyller kravene i personvernforordningen (GDPR) artikkel 28.
      </p>

      <h2>2. Formål og omfang</h2>
      <p>
        Databehandleren behandler personopplysninger utelukkende for å levere Sentiqa: innlogging og
        tilgangsstyring, innlesing og analyse av Behandlingsansvarliges egne drifts- og salgsrapporter,
        AI-genererte innsikter, samt drift, support og fakturering. Behandlingens art, formål, varighet,
        kategorier av registrerte og personopplysninger er nærmere beskrevet i Vedlegg A.
      </p>

      <h2>3. Behandlingsansvarliges instrukser</h2>
      <p>
        Databehandleren skal kun behandle personopplysninger etter dokumenterte instrukser fra
        Behandlingsansvarlig, slik de fremgår av Avtalen og bruken av tjenesten. Databehandleren varsler
        Behandlingsansvarlig dersom en instruks etter Databehandlerens syn er i strid med
        personvernregelverket. Behandlingsansvarlig er ansvarlig for at det foreligger gyldig
        behandlingsgrunnlag for opplysningene som legges inn i tjenesten.
      </p>

      <h2>4. Databehandlerens plikter</h2>
      <ul>
        <li>Behandle personopplysninger kun for de formål som er angitt, og ikke til egne formål.</li>
        <li>Sikre at personer med tilgang er underlagt taushetsplikt (punkt 8).</li>
        <li>Gjennomføre egnede tekniske og organisatoriske sikkerhetstiltak (punkt 7).</li>
        <li>Bistå Behandlingsansvarlig som angitt i punkt 9.</li>
        <li>Stille til rådighet informasjon som er nødvendig for å vise at pliktene oppfylles (punkt 11).</li>
      </ul>

      <h2>5. Kategorier av registrerte og personopplysninger (Vedlegg A)</h2>
      <ul>
        <li><strong>Registrerte:</strong> Behandlingsansvarliges ansatte og brukere (eiere, butikksjefer, kasserere m.fl.).</li>
        <li><strong>Personopplysninger:</strong> navn, e-postadresse, rolle og firmatilknytning; identifikatorer og navn knyttet til kasserer-/driftsdata i opplastede rapporter; PIN-innlogging der dette er aktivert; innloggings- og tilgangslogger.</li>
        <li><strong>Særlige kategorier:</strong> tjenesten er ikke ment for behandling av særlige kategorier personopplysninger (GDPR art. 9).</li>
      </ul>

      <h2>6. Underdatabehandlere (Vedlegg B)</h2>
      <p>
        Behandlingsansvarlig gir Databehandleren generell godkjenning til å benytte underdatabehandlere.
        Databehandleren inngår avtale med hver underdatabehandler som pålegger tilsvarende
        personvernforpliktelser, og er ansvarlig for deres utførelse. All lagring og behandling skjer i{' '}
        <strong>EU/EØS</strong>. Gjeldende underdatabehandlere:
      </p>
      <table className="dok-tabell">
        <thead>
          <tr><th>Leverandør</th><th>Funksjon</th><th>Region</th></tr>
        </thead>
        <tbody>
          <tr><td>Supabase</td><td>Database, autentisering og fillagring</td><td>EU/EØS</td></tr>
          <tr><td>Vercel</td><td>Drift og hosting av applikasjonen</td><td>EU/EØS</td></tr>
          <tr><td>Anthropic</td><td>AI-modell for analyse og assistent</td><td>Se personvernerklæringen pkt. 5</td></tr>
          <tr><td>E-post-/SMS-leverandør</td><td>Varsler og innlesing av rapporter på e-post</td><td>EU/EØS</td></tr>
        </tbody>
      </table>
      <p>
        Ved planlagte endringer i bruk av underdatabehandlere varsles Behandlingsansvarlig i rimelig tid,
        slik at det er mulig å motsette seg endringen. Se også{' '}
        <Link href="/personvern">personvernerklæringen</Link>.
      </p>

      <h2>7. Sikkerhet (art. 32)</h2>
      <ul>
        <li><strong>Tenant-isolasjon:</strong> hver kundes data er adskilt fra alle andres på databasenivå (row-level security).</li>
        <li><strong>Kryptering</strong> av personopplysninger i transport og i ro.</li>
        <li><strong>Tilgangsstyring</strong> basert på roller, og logg over hvem som har sett hva.</li>
        <li><strong>PII-redaksjon</strong> i AI-loggføring; AI-en ser kun den enkelte kundens egne data.</li>
        <li>Rutiner for testing og evaluering av tiltakenes effektivitet.</li>
      </ul>

      <h2>8. Konfidensialitet</h2>
      <p>
        Databehandleren sikrer at enhver som behandler personopplysninger under Avtalen, er underlagt
        taushetsplikt om opplysningene. Taushetsplikten består også etter at Avtalen er opphørt.
      </p>

      <h2>9. Bistand til Behandlingsansvarlig</h2>
      <p>
        Databehandleren bistår, hensyntatt behandlingens art og tilgjengelig informasjon,
        Behandlingsansvarlig med å oppfylle plikter knyttet til registrertes rettigheter (innsyn, retting,
        sletting, dataportabilitet m.m.), sikkerhet, melding om brudd, og eventuelle
        personvernkonsekvensvurderinger (GDPR art. 32–36).
      </p>

      <h2>10. Brudd på personopplysningssikkerheten</h2>
      <p>
        Ved brudd på personopplysningssikkerheten varsler Databehandleren Behandlingsansvarlig uten ugrunnet
        opphold etter å ha blitt kjent med bruddet, og gir informasjon som gjør Behandlingsansvarlig i stand
        til å oppfylle egne varslingsplikter overfor Datatilsynet og berørte.
      </p>

      <h2>11. Revisjon og dokumentasjon</h2>
      <p>
        Databehandleren gjør tilgjengelig informasjon som er nødvendig for å vise at pliktene etter Avtalen
        oppfylles, og muliggjør og bidrar til revisjoner, herunder inspeksjoner, gjennomført av
        Behandlingsansvarlig eller en revisor utpekt av denne, på rimelige vilkår.
      </p>

      <h2>12. Varighet, opphør og sletting</h2>
      <p>
        Avtalen gjelder så lenge Databehandleren behandler personopplysninger på vegne av
        Behandlingsansvarlig. Ved opphør skal Databehandleren, etter Behandlingsansvarliges valg, tilbakeføre
        og/eller slette personopplysningene, med mindre lovpålagte oppbevaringskrav er til hinder for dette.
        Kunder kan be om eksport av egne data og om reell sletting ved avslutning.
      </p>

      <h2>13. Overføring til tredjeland</h2>
      <p>
        Personopplysninger overføres ikke til land utenfor EU/EØS uten at det foreligger et gyldig
        overføringsgrunnlag etter GDPR kapittel V.
      </p>

      <h2>14. Ansvar</h2>
      <p>
        Partenes ansvar for behandling av personopplysninger følger av GDPR og av den øvrige avtalen mellom
        partene om bruk av Sentiqa.
      </p>

      <h2>15. Lovvalg og verneting</h2>
      <p>
        Avtalen er underlagt norsk rett. Tvister søkes løst i minnelighet; om nødvendig avgjøres de av norske
        domstoler.
      </p>

      <h2>16. Kontakt</h2>
      <p>
        Henvendelser om Avtalen rettes til R-G Invest AS på{' '}
        <a href="mailto:post@sentiqa.ai">post@sentiqa.ai</a>.
      </p>

      <footer className="auth-bunn" style={{ marginTop: '3rem' }}>R-G Invest AS · Org.nr 937 861 621</footer>
    </main>
  )
}
