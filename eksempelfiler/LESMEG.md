# Eksempelfiler for parser-utvikling

Legg **ekte (gjerne anonymiserte)** eksempelrapporter her, så bygges parserne
mot virkeligheten — ikke gjetning (PROSJEKT.md §6/§8: «gjett aldri»).

## Prioritert (bygges først, §16)

| Rapport | Filnavn-hint | Format |
|---|---|---|
| St1 Salgsstatistikk (produktnivå, daglig) | f.eks. `salgsstatistikk-*.csv` | CSV/Excel? |
| Visma Resultatrapport (månedlig) | f.eks. `visma-resultat-*.pdf` | PDF/Excel? |

## Senere

- St1 0758 SalesPerHour
- St1 0018 CashierStatistics
- Salesgrid Varetransaksjonsliste

## Tips for anonymisering

- Behold kolonneoverskrifter, datoformat, tallformat (komma/punktum), koder og
  struktur **nøyaktig** — det er det parseren trenger.
- Bytt gjerne ut stasjonsnavn/butikknummer og skaler tallene.

> Denne mappen er kun for utvikling. Ekte produksjonsfiler havner i Supabase
> Storage via drop-zone/e-post, aldri i git.
