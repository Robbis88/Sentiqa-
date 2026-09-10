# E-post fra Sentiqa: hva som er satt opp, og hvor

Alt her bor i Supabase-dashboardet (prosjekt `ahsetswpwzvcizkurymg`), ikke
i en migrasjon. Det er derfor denne fila finnes: en innstilling som bare
lever i et dashboard har ingen historikk, ingen diff og ingen som ser at
den ble endret.

## Hva som avhenger av at dette virker

Fire flater, ikke én. Uten e-post er alle fire døde:

| flate | hva som sendes |
|---|---|
| `/registrer` | invitasjon — **hele beviset** for at adressen er din |
| `/plattform` → ny kjede | invitasjon til kjedens første eier |
| `/plattform` → send på nytt | gjenopprettingslenke |
| `/logg-inn/glemt` | gjenopprettingslenke |

`/registrer` er den strengeste: passordfeltet ble fjernet fra skjemaet
med vilje, fordi *det å motta brevet* er beviset. Kommer brevet aldri
fram, kan ingen registrere seg i det hele tatt.

## 1. SMTP

Standardoppsettet til Supabase sender **noen få e-poster i timen, og bare
til prosjektets teammedlemmer**. Det er ikke en feil man ser: alt svarer
grønt, og ingenting kommer fram til en butikksjef.

Resend ligger allerede i prosjektet — ukebriefen sender gjennom den, og
domenet `sentiqa.ai` er verifisert der. Samme nøkkel brukes som SMTP-passord.

Authentication → Emails → SMTP Settings:

| felt | verdi |
|---|---|
| Enable Custom SMTP | på |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | Resend-API-nøkkelen (`re_…`) — samme som `RESEND_API_KEY` |
| Sender email | `konto@sentiqa.ai` |
| Sender name | `Sentiqa` |

Avsenderadressen må ligge på et domene som er verifisert hos Resend.
`sentiqa.ai` er det, siden ukebriefen sender fra `ukebrief@sentiqa.ai`.

**Rate limit:** Authentication → Rate Limits → «Emails» står på 2 per
time så lenge SMTP er standardoppsettet. Med egen SMTP kan den settes
opp; 30 i timen holder for fem stasjoner.

## 2. URL-oppsett

Authentication → URL Configuration:

| felt | verdi |
|---|---|
| Site URL | `https://sentiqa.ai` |
| Redirect URLs | `https://sentiqa.ai/auth/bekreft` |

Site URL er den malene bygger lenken fra. Se neste seksjon for hvorfor
det ikke er preview-adressen.

## 3. Malene

Filene her er **kopien i repoet av det som står i dashboardet** —
Authentication → Emails → Templates. De kjøres ikke av noe; Supabase leser
sin egen kopi. Grunnen til at de likevel ligger her er at en innstilling
som bare finnes i et dashboard ikke har noen historikk, ingen diff og
ingen som ser at den ble endret.

## Den ene linja som betyr noe

Standardmalene fra Supabase bruker `{{ .ConfirmationURL }}`. Den peker på
`<prosjekt>.supabase.co/auth/v1/verify?…`, som verifiserer og deretter
sender brukeren videre med tokenet i **URL-fragmentet** (`#access_token=…`).

Et fragment sendes aldri til serveren. `/auth/bekreft` er en
serverrute — den ser ingenting, og lander på
`/logg-inn?feil=ingen-token`. Lenken ser riktig ut, e-posten kom fram, og
ingenting virker.

Derfor bruker alle malene her formen Supabase selv anbefaler for
server-side rammeverk:

```
{{ .SiteURL }}/auth/bekreft?token_hash={{ .TokenHash }}&type=<ærend>
```

`token_hash` står i spørrestrengen, serveren leser den, `verifyOtp`
løser den inn, og brukeren er innlogget når hun lander på
`/sett-passord`.

**`type` må stemme med malen:** `invite`, `recovery`, `signup`. Feil
`type` gir «Token has expired or is invalid» på et helt ferskt token.

## Kanarifuglen

Går noen tilbake til standardmalen, blir symptomet nøyaktig
`/logg-inn?feil=ingen-token` — teksten «Lenken manglet nøkkelen sin».
Ser du den, er det denne fila som ikke lenger stemmer med dashboardet.
Den vanlige varianten, «utløpt eller allerede brukt», er noe annet og
helt normalt.

## Hvorfor `{{ .SiteURL }}` og ikke `{{ .RedirectTo }}`

`.RedirectTo` er adressen koden ba om, og koden bygger den fra
`Host`-headeren. Kjøres handlingen fra en preview-deploy, sender vi en
lenke inn i previewen — til en base som kan være borte i morgen.
`.SiteURL` er prosjektets ene faste adresse, satt ett sted.

Site URL skal være `https://sentiqa.ai`, og `https://sentiqa.ai/auth/bekreft`
skal stå i Redirect URLs.

## Filene

| fil | Supabase-mal | `type` |
|---|---|---|
| `invitasjon.html` | Invite user | `invite` |
| `gjenoppretting.html` | Reset password | `recovery` |
| `bekreft-registrering.html` | Confirm signup | `signup` |

Fargene er de samme som i `src/lib/ukebrief/epost.ts`, av samme grunn som
står forklart der: e-postklienter har ingen CSS-variabler, så alt må stå
inline, og da er paletten en literal. Endres `--primaer` i `globals.css`,
endres den begge steder.
