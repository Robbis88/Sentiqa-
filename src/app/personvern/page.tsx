import type { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Personvernerklæring – Sentiqa',
  description:
    'Hvordan Sentiqa (R-G Invest AS) behandler personopplysninger: formål, behandlingsgrunnlag, underdatabehandlere, lagringstid, sikkerhet og dine rettigheter.',
}

// Sist oppdatert settes manuelt ved endring (ingen Date.now i render — statisk side).
const SIST_OPPDATERT = '26. juni 2026'

export default function PersonvernSide() {
  return (
    <main className="dok">
      <p className="dok-tilbake">
        <Link href="/">← Tilbake til Sentiqa</Link>
      </p>

      <h1>Personvernerklæring</h1>
      <p className="dok-meta">Sist oppdatert: {SIST_OPPDATERT} · Versjon: utkast til juridisk gjennomgang</p>

      <div className="dok-merknad" role="note">
        <strong>Utkast.</strong> Denne erklæringen beskriver hvordan Sentiqa faktisk er bygget og driftes,
        men er ikke ferdig juridisk gjennomgått. Den er et solid utgangspunkt — ikke en erstatning for
        juridisk rådgivning. Endelig, bindende versjon godkjennes før kommersiell lansering.
      </div>

      <h2>1. Hvem er ansvarlig</h2>
      <p>
        Sentiqa eies og driftes av <strong>R-G Invest AS</strong>, org.nr <strong>937 861 621</strong>
        («vi», «oss»). For personopplysninger som behandles i tjenesten på vegne av den enkelte kjede/butikk
        («kunden»), er vi <strong>databehandler</strong> og kunden er <strong>behandlingsansvarlig</strong>.
        Behandlingen reguleres av en <Link href="/databehandleravtale">databehandleravtale (DPA)</Link> mellom oss og hver kunde.
      </p>
      <p>
        For opplysninger vi behandler om våre egne kontakt- og fakturaforhold (f.eks. ved registrering og
        EHF-fakturering) er vi selv behandlingsansvarlig.
      </p>
      <p>
        Kontakt for personvern: <a href="mailto:post@sentiqa.ai">post@sentiqa.ai</a>.
      </p>

      <h2>2. Hvilke opplysninger vi behandler</h2>
      <ul>
        <li><strong>Kontoopplysninger:</strong> navn, e-postadresse, rolle og firmatilknytning for brukere som logger inn.</li>
        <li><strong>Kunde-/fakturaopplysninger:</strong> firmanavn, organisasjonsnummer og fakturakontakt.</li>
        <li><strong>Driftsdata fra butikk:</strong> salgs-, kasserer-, time- og regnskapsrapporter du laster opp eller sender inn. Disse kan inneholde personopplysninger om ansatte (f.eks. kasserer-id og navn).</li>
        <li><strong>Ansatt-/driftsfunksjoner:</strong> opplæring, rutiner, PIN-innlogging på nettbrett, oppgaver og lignende der det er aktivert.</li>
        <li><strong>Teknisk:</strong> innloggings- og tilgangslogger (hvem så hva), samt nødvendige informasjonskapsler for å holde deg innlogget.</li>
      </ul>

      <h2>3. Formål og behandlingsgrunnlag</h2>
      <p>
        Vi behandler opplysningene for å levere tjenesten kunden har bestilt: innlogging og tilgangsstyring,
        innlesing og analyse av butikkens egne rapporter, AI-genererte innsikter, samt fakturering og support.
        Behandlingsgrunnlaget er oppfyllelse av avtale (GDPR art. 6 nr. 1 b) og berettiget interesse i sikker,
        effektiv drift (art. 6 nr. 1 f). For driftsdata som kunden legger inn, skjer behandlingen etter kundens
        instruks som behandlingsansvarlig.
      </p>

      <h2>4. Underdatabehandlere</h2>
      <p>
        All lagring og behandling skjer i <strong>EU/EØS</strong>. Vi bruker følgende underdatabehandlere, alle
        underlagt databehandleravtale:
      </p>
      <table className="dok-tabell">
        <thead>
          <tr><th>Leverandør</th><th>Funksjon</th><th>Region</th></tr>
        </thead>
        <tbody>
          <tr><td>Supabase</td><td>Database, autentisering og fillagring</td><td>EU/EØS</td></tr>
          <tr><td>Vercel</td><td>Drift og hosting av applikasjonen</td><td>EU/EØS</td></tr>
          <tr><td>Anthropic</td><td>AI-modell for analyse og assistent</td><td>Se punkt 5</td></tr>
          <tr><td>E-post-/SMS-leverandør</td><td>Varsler og innlesing av rapporter på e-post</td><td>EU/EØS</td></tr>
        </tbody>
      </table>
      <p>
        En oppdatert liste over underdatabehandlere gjøres tilgjengelig for kunder på forespørsel, og endringer
        varsles i tråd med databehandleravtalen.
      </p>

      <h2>5. AI-behandling</h2>
      <p>
        AI-funksjonene bruker Anthropics modeller via deres kommersielle/API-vilkår. Per september 2025 gjelder
        at inn- og utdata <strong>som standard ikke brukes til trening</strong> av modellene, og at API-logger
        oppbevares kort tid og aldri brukes til trening. Vilkår fra leverandører kan endre seg — gjeldende vilkår
        hos Anthropic er til enhver tid styrende. AI-en ser kun den enkelte kundens egne data (tenant-isolasjon),
        og følsomme felter redigeres bort før logging på vår side.
      </p>

      <h2>6. Lagringstid</h2>
      <p>
        Vi lagrer opplysningene så lenge kundeforholdet består og tjenesten er i bruk. Når en kunde avslutter,
        kan data eksporteres, og opplysningene slettes deretter. Lovpålagte oppbevaringskrav (f.eks. bokførings-
        og fakturadokumentasjon) kan medføre at enkelte opplysninger oppbevares lenger.
      </p>

      <h2>7. Sikkerhet</h2>
      <ul>
        <li><strong>Tenant-isolasjon:</strong> hver kundes data er adskilt fra alle andres på databasenivå (row-level security).</li>
        <li><strong>Kryptering:</strong> opplysninger er kryptert i transport og i ro.</li>
        <li><strong>Tilgangskontroll og logg:</strong> rollebasert tilgang, og logg over hvem som har sett hva.</li>
        <li><strong>PII-redaksjon</strong> i AI-loggføringen.</li>
      </ul>

      <h2>8. Dine rettigheter</h2>
      <p>
        Du har rett til innsyn, retting, sletting, begrensning og dataportabilitet, og rett til å protestere mot
        behandling. For driftsdata som behandles på vegne av en kunde, retter du henvendelsen til kunden
        (behandlingsansvarlig), og vi bistår som databehandler. Du kan også klage til{' '}
        <a href="https://www.datatilsynet.no" target="_blank" rel="noopener noreferrer">Datatilsynet</a>.
      </p>

      <h2>9. Eksport og sletting</h2>
      <p>
        Kunder kan be om eksport av egne data og om reell sletting ved avslutning. Sletting gjennomføres
        permanent etter eventuell eksport og utløp av lovpålagte oppbevaringskrav.
      </p>

      <h2>10. Informasjonskapsler</h2>
      <p>
        Vi bruker kun de informasjonskapslene som er nødvendige for at innlogging og tjenesten skal fungere.
        Vi bruker ikke informasjonskapsler til markedsføring eller sporing på tvers av nettsteder.
      </p>

      <h2>11. Endringer</h2>
      <p>
        Vi kan oppdatere denne erklæringen. Ved vesentlige endringer varsler vi kundene. Dato for siste
        oppdatering står øverst.
      </p>

      <h2>12. Kontakt</h2>
      <p>
        Spørsmål om personvern rettes til R-G Invest AS på{' '}
        <a href="mailto:post@sentiqa.ai">post@sentiqa.ai</a>.
      </p>

      <footer className="auth-bunn" style={{ marginTop: '3rem' }}>R-G Invest AS · Org.nr 937 861 621</footer>
    </main>
  )
}
