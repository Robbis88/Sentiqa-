-- =====================================================================
-- MYK SLETTING SKAL FAKTISK KUNNE GJENNOMFOERES
--
-- En SELECT-policy som krever `slettet_tid IS NULL` blokkerer sin egen
-- soft delete. Setter en UPDATE `slettet_tid`, faller den nye raden ut av
-- policyen - og Postgres nekter en oppdatering som gjoer raden usynlig
-- for den som skriver.
--
-- Symptomet:
--
--   Kunne ikke slette malekort [42501]:
--   new row violates row-level security policy for table "malekort"
--
-- Feilen sier "tilgang". Rollen var riktig hele tiden.
--
-- ---------------------------------------------------------------------
-- BEVIST, IKKE RESONNERT
--
-- Samme UPDATE gikk gjennom straks en midlertidig policy lot eieren se
-- slettede rader. `set navn = navn` og `set anonymiser` gaar fint - det
-- er `slettet_tid` alene som utloeser det.
--
-- 19 tabeller. Ingen har kunnet slette et malekort siden `0073`, i mai.
--
-- ---------------------------------------------------------------------
-- REGELEN
--
-- **`slettet_tid` er ikke et sikkerhetsvilkaar.** En slettet rad i din
-- egen kjede er din egen rad i en annen tilstand, ikke andres data.
--
-- RLS haandhever TENANT. Spoerringene haandhever LIVSSYKLUS. Det er ikke
-- en ny regel - 62 av 80 lesninger gjorde det allerede. Den var bare ikke
-- haandhevet, og de 18 som manglet rettes i samme endring.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ROERES
--
-- **Salgstabellene.** `daglig_salg`, `timesalg`, `synlig_svinn`,
-- `kassererstatistikk`, `regnskapslinjer` myk-slettes bare av importen,
-- som kjoerer som service_role og omgaar RLS. Der virker slettingen alt,
-- og aa eksponere slettede salgsrader er en tallrisiko, ikke en
-- forbedring.
--
-- **Alt annet i policyene.** Tre av dem bruker
-- `har_stasjonstilgang(stasjon_id)`, som husreglene sier aldri kan bli
-- initplan, og flere kaller `gjeldende_retailer_id()` upakket. Det er
-- ekte gjeld - men en ytelsesendring gjemt inne i en feilretting gjoer
-- diffen ugranskelig. Hvert uttrykk under er kopiert fra katalogen med
-- `slettet_tid IS NULL` fjernet, og INGENTING annet endret.
--
-- ---------------------------------------------------------------------
-- RISIKO, MAALT
--
-- Fem slettede rader i hele basen, fordelt paa tre tabeller: `rutiner`
-- (3), `plattform_innlegg` (1), `tablet_meldinger` (1). Alle tre er blant
-- dem der HVER spoerring alt filtrerer selv. Lesesiden har null risiko i
-- dag.
--
-- `personlig_punkt` staar ikke her: SELECT-policyen der filtrerer ikke
-- `slettet_tid`, saa slettingen virker allerede.
--
-- Idempotent: `drop policy if exists` foer hver `create policy`.
-- =====================================================================

-- --- retailer_id = gjeldende_retailer_id() -------------------------

drop policy if exists anvisninger_les on public.anvisninger;
create policy anvisninger_les on public.anvisninger for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists arrangementer_les on public.arrangementer;
create policy arrangementer_les on public.arrangementer for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists kalender_kilder_les on public.kalender_kilder;
create policy kalender_kilder_les on public.kalender_kilder for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists konkurranser_les on public.konkurranser;
create policy konkurranser_les on public.konkurranser for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists lenker_les on public.lenker;
create policy lenker_les on public.lenker for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists merker_les on public.merker;
create policy merker_les on public.merker for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists opp2_oppgave_les on public.opplaering_oppgave;
create policy opp2_oppgave_les on public.opplaering_oppgave for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists puls_runde_les on public.puls_runde;
create policy puls_runde_les on public.puls_runde for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

drop policy if exists puls_sporsmal_les on public.puls_sporsmal;
create policy puls_sporsmal_les on public.puls_sporsmal for select to authenticated
  using (retailer_id = gjeldende_retailer_id());

-- --- stasjon_id in (select mine_stasjoner()) -----------------------

drop policy if exists ansatte_les on public.ansatte;
create policy ansatte_les on public.ansatte for select to authenticated
  using (stasjon_id in (select mine_stasjoner()));

drop policy if exists oppgaver_les on public.oppgaver;
create policy oppgaver_les on public.oppgaver for select to authenticated
  using (stasjon_id in (select mine_stasjoner()));

drop policy if exists rutiner_les on public.rutiner;
create policy rutiner_les on public.rutiner for select to authenticated
  using (stasjon_id in (select mine_stasjoner()));

-- --- har_stasjonstilgang(stasjon_id) -------------------------------
-- BEHOLDT SOM DEN ER. Husreglene sier at denne aldri kan bli initplan,
-- fordi den tar en kolonne som argument. Det er gjeld - men den hoerer
-- til en egen endring, ikke til denne.

drop policy if exists ik_punkter_les on public.ik_kontrollpunkter;
create policy ik_punkter_les on public.ik_kontrollpunkter for select to authenticated
  using (har_stasjonstilgang(stasjon_id));

drop policy if exists rutineskjemaer_les on public.rutineskjemaer;
create policy rutineskjemaer_les on public.rutineskjemaer for select to authenticated
  using (har_stasjonstilgang(stasjon_id));

drop policy if exists sjekkpunkter_les on public.sjekkpunkter;
create policy sjekkpunkter_les on public.sjekkpunkter for select to authenticated
  using (har_stasjonstilgang(stasjon_id));

-- --- Egne former ---------------------------------------------------

-- Malekortet leser sitt eget visningsflagg (0134). Flagget er en GRENSE,
-- ikke bare et visningsvilkaar - nettbrettet leste ellers kort merket
-- `vis_tablet = false` rett over PostgREST. Uroert her.
drop policy if exists malekort_les on public.malekort;
create policy malekort_les on public.malekort for select to authenticated
  using (retailer_id = (select gjeldende_retailer_id())
         and case (select gjeldende_rolle())
               when 'butikkbruker_tablet' then vis_tablet
               when 'butikksjef'          then vis_butikksjef
               else true
             end);

-- Plattforminnlegg: upublisert er redaktoerens alene. Uroert.
drop policy if exists plattform_les on public.plattform_innlegg;
create policy plattform_les on public.plattform_innlegg for select to authenticated
  using (publisert or gjeldende_rolle() = 'plattform_redaktor');

-- Nettbrettmeldinger: kjeden, og enten hele kjeden eller mine stasjoner.
drop policy if exists tablet_meldinger_les on public.tablet_meldinger;
create policy tablet_meldinger_les on public.tablet_meldinger for select to authenticated
  using (retailer_id = (select gjeldende_retailer_id())
         and (stasjon_id is null or stasjon_id in (select mine_stasjoner())));

-- KUNNSKAP ER GLOBAL MED VILJE, og kontrakten sier det: tariff, loenn,
-- arbeidsrett og HMS er likt for alle kjeder. Policyen hadde derfor
-- ingen tenantgrense i utgangspunktet - `slettet_tid IS NULL` var hele
-- uttrykket.
--
-- Uten den staar `true` igjen, og det SER dramatisk ut. Det er likevel
-- den aerlige formen: tabellen har ingen tenantgrense aa haandheve, og
-- livssyklusen hoerer hjemme i spoerringen. De to lesningene som ikke
-- filtrerte er rettet i samme endring - her er de det eneste vernet mot
-- aa vise et slettet oppslag.
drop policy if exists kunnskap_les on public.kunnskap;
create policy kunnskap_les on public.kunnskap for select to authenticated
  using (true);

-- ---------------------------------------------------------------------
-- KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`. `gjenstaaende` skal vaere 0.

select count(*) as gjenstaaende,
       coalesce(string_agg(c.relname, ', ' order by c.relname), '(ingen)') as tabeller
from pg_policy pol
join pg_class c on c.oid = pol.polrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and pol.polcmd::text in ('r', '*')
  and pg_get_expr(pol.polqual, pol.polrelid) like '%slettet_tid IS NULL%'
  and c.relname = any (array[
    'malekort','ansatte','rutiner','rutineskjemaer','oppgaver',
    'sjekkpunkter','konkurranser','merker','lenker','kunnskap',
    'anvisninger','arrangementer','kalender_kilder','ik_kontrollpunkter',
    'puls_runde','puls_sporsmal','opplaering_oppgave','plattform_innlegg',
    'tablet_meldinger','personlig_punkt']);
