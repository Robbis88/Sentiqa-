-- =====================================================================
-- KONTROLLEN KAN SETTES UTEN AT EN BRUKER STAAR BAK
--
-- `0152` la inn skranken
--
--   check ((kontrollert_av is null) = (kontrollert_tid is null))
--
-- med begrunnelsen "halv kontroll finnes ikke". Den var feil, og fixturene
-- avslorte det foerste gang de forsoekte aa erklaere "ingen drivstoff".
--
-- ---------------------------------------------------------------------
-- HVORFOR
--
-- Samme migrasjon slaar fast at INGEN approlle kan sette
-- `kontrollert_tid`: `with check`-klausulene krever at den er null,
-- nettopp fordi paastanden "vi har ikke drivstoff" aapner hver eneste
-- rad. Kontrollen settes derfor av oss, manuelt, i SQL Editor.
--
-- Og da finnes det ingen bruker aa peke paa. Det finnes ingen
-- Sentiqa-rolle i basen. `plattform_redaktor` staar riktignok utenfor
-- tenant - `profiler.retailer_id` er nullable for nettopp den - men det
-- er ikke gitt at en slik profil eksisterer, og aa kreve en for aa kunne
-- bekrefte er aa kreve en bruker vi ikke har.
--
-- Skranken tvang altsaa fram enten en oppdiktet profil eller at
-- kontrollen ikke kunne settes i det hele tatt. Begge deler er verre enn
-- en kolonne som staar tom.
--
-- ---------------------------------------------------------------------
-- HVA SOM GJELDER ETTER DETTE
--
-- `kontrollert_tid` er den som teller - viewet leser bare den.
-- `kontrollert_av` er valgfri dokumentasjon av HVEM, og fylles den dagen
-- en Sentiqa-flate finnes. Null betyr "satt manuelt av Sentiqa", ikke
-- "ukjent tilstand".
--
-- Ingen atferdsendring: viewet, policyene og statusviewet er uroert.
-- Idempotent: `drop constraint if exists`.
-- =====================================================================

alter table public.retailer_kodeerklaering
  drop constraint if exists retailer_kodeerklaering_check1;

-- Skranken fikk et generert navn i 0152. Postgres nummererer anonyme
-- check-skranker i rekkefoelge, og `_check` er tatt av `rolle in (...)`.
-- Vi finner den paa DEFINISJONEN i stedet, saa fjerningen ikke hviler paa
-- en gjetning om navnet.
do $$
declare n text;
begin
  for n in
    select con.conname
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public'
      and c.relname = 'retailer_kodeerklaering'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like '%kontrollert_av%'
      and pg_get_constraintdef(con.oid) like '%kontrollert_tid%'
  loop
    execute format('alter table public.retailer_kodeerklaering drop constraint %I', n);
    raise notice 'droppet skranke %', n;
  end loop;
end $$;

comment on column public.retailer_kodeerklaering.kontrollert_av is
  'Valgfri: hvem hos Sentiqa som bekreftet. Null betyr satt manuelt i '
  'SQL Editor - det finnes ingen Sentiqa-rolle i basen enda. Det er '
  'kontrollert_tid viewet leser.';

-- Kvittering: skranken skal vaere borte, og ingen rad skal ha mistet noe.
select count(*) filter (where pg_get_constraintdef(con.oid) like '%kontrollert_av%')
         as gjenstaaende_skranker,
       (select count(*) from public.retailer_kodeerklaering) as erklaeringer
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace ns on ns.oid = c.relnamespace
where ns.nspname = 'public' and c.relname = 'retailer_kodeerklaering'
  and con.contype = 'c';
