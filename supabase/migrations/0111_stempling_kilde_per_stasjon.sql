-- =====================================================================
-- 0111 - overgangen fra easy@work, en stasjon om gangen
--
-- 0110 ga `stempling` en `kilde`-kolonne (import/tablet). Denne
-- migrasjonen gjor den til noe som faktisk styrer hva som telles.
--
-- PROBLEMET: under parallellkjoring skriver BEGGE kilder til `stempling`
-- for samme stasjon og samme maaned. Den unike noekkelen er
-- (stasjon_id, ansatt_nr, dato, fra_tid), og de to kildene gir ikke
-- samme fra_tid - nettbrettet har det faktiske minuttet, easy@work et
-- avrundet. Altsaa kolliderer de ikke; de LEGGER SEG VED SIDEN AV
-- hverandre. Uten et filter dobles timene i lonnsfila, i
-- bemanningsplanen og i stillingsanslaget.
--
-- Det er den farligste formen for feil dette systemet kan gjore: den ser
-- ut som vekst.
--
-- LOSNINGEN er den samme som for drivstoff i daglig_salg: et flagg per
-- stasjon, og en VIEW som filtrerer. Alt som summerer timer leser viewet
-- og merker ingenting. Ingen kallesteder maa huske paa noe.
--
-- Trygt aa kjore om igjen.
-- =====================================================================

-- --- Flagget -------------------------------------------------------

alter table public.stasjoner
  add column if not exists stempling_kilde text not null default 'import';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'stasjoner_stempling_kilde_gyldig'
  ) then
    alter table public.stasjoner
      add constraint stasjoner_stempling_kilde_gyldig
      check (stempling_kilde in ('import', 'tablet'));
  end if;
end $$;

comment on column public.stasjoner.stempling_kilde is
  'Hvilken kilde som TELLER for denne stasjonen: import (easy@work) eller '
  'tablet (stempling i Sentiqa). Snus per stasjon, en om gangen, etter at '
  'en hel maaned er avstemt mot begge kilder. Default import - en ny '
  'stasjon skal ikke bytte kilde ved et uhell.';

-- Standard er `import` for alle. Ingen update her: en uvaktet
-- `update ... set stempling_kilde = 'import'` ville satt en stasjon som
-- alt ER gaatt over tilbake til easy@work neste gang settet kjores fra
-- bunn, og da forsvinner timene deres uten at noen ser det.

-- --- Viewet som gjor flagget virksomt --------------------------------

create or replace view public.v_stempling_aktiv
with (security_invoker = true) as
select s.*
from public.stempling s
join public.stasjoner st on st.id = s.stasjon_id
where s.kilde = st.stempling_kilde;

comment on view public.v_stempling_aktiv is
  'Stemplinger fra kilden som teller for stasjonen. LES DENNE, ikke '
  'stempling, i alt som summerer timer. Under parallellkjoring finnes '
  'samme vakt to ganger - en fra easy@work-importen og en avledet fra '
  'nettbrettet - og de kolliderer ikke, fordi minuttene er ulike. Leser '
  'du tabellen direkte, dobles timene i lonnsfila og i stillingsanslaget.';

-- --- De som alt summerer timer ---------------------------------------

-- Stillingsanslaget og kontraktseksponeringen. Denne var den mest
-- utsatte: den summerer over hele historikken, saa en dobling ville
-- vist seg som at alle plutselig jobbet mer enn kontrakten sin - og det
-- er en advarsel systemet gir fra for, saa den ville sett ekte ut.
create or replace view public.v_stempling_ansatt_mnd
with (security_invoker = true) as
select stasjon_id,
       ansatt_nr,
       -- Nyeste navn vinner. Folk gifter seg, og stemplingsnummeret er
       -- den stabile noekkelen.
       (array_agg(ansatt_navn order by dato desc))[1] as ansatt_navn,
       date_trunc('month', dato)::date                as maaned,
       sum(minutter) / 60.0                           as timer
from public.v_stempling_aktiv
where betalt
group by stasjon_id, ansatt_nr, date_trunc('month', dato);

comment on view public.v_stempling_ansatt_mnd is
  'Arbeidede timer per ansatt per maaned, fra kilden som teller for '
  'stasjonen. Mater stillingsanslaget og kontraktseksponeringen.';

-- --- Rettigheter -----------------------------------------------------

-- Views arver ikke rettigheter, like lite som partisjoner gjor (se 0105).
revoke all on public.v_stempling_aktiv from anon, authenticated;
grant select on public.v_stempling_aktiv to authenticated;
revoke all on public.v_stempling_ansatt_mnd from anon;
grant select on public.v_stempling_ansatt_mnd to authenticated;
