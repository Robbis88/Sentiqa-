-- =====================================================================
-- Anvisninger: PDF-ark ved siden av fritekst
--
-- `anvisninger` (0035) er prosedyrer skrevet inn som tekst. Arkene fra
-- leverandoeren er PDF - «slik smoerer vi horn med ost og skinke» - og
-- personalet slaar dem opp paa nettbrettet mens de staar og jobber.
--
-- ÉN TABELL, IKKE TO. Et eget PDF-arkiv ved siden av ville gitt to
-- flater som begge heter «anvisninger», og den som leter maatte vite
-- hvilken av dem arket ligger i. Robert om lederdekningen: «hva om vi
-- bare bruker denne? Slipper den aa ligge 2 steder.» Samme svar her.
-- `innhold` blir valgfri; en rad har enten tekst eller fil.
--
-- PER RETAILER, IKKE GLOBALT. Spesifikasjonen beskriver et felles arkiv
-- for hele kjeden. Det passer ikke her: appen er flerkunde, og et
-- globalt arkiv ville delt St1s oppskrifter med neste kjede som kommer
-- inn. `retailer_id` staar allerede paa tabellen, og storage-stien
-- foelger den.
--
-- STIKKORD ER GRUNNEN TIL AT SOEKET FOELES BRA. Personalet soeker paa
-- ingrediensen de har i haanda («ost»), ikke paa produktnavnet. Tittelen
-- alene rekker ikke. Normalisert til smaa bokstaver ved opplasting.
--
-- `dato` og `erstatter_dato` speiler feltene som staar TRYKT paa arkene.
-- Personalet kjenner dem igjen, og de avgjoer hvilket ark som gjelder.
-- =====================================================================

alter table public.anvisninger
  add column if not exists stikkord         text[] not null default '{}',
  add column if not exists fil_sti          text,
  add column if not exists original_filnavn text,
  add column if not exists dato             date,
  add column if not exists erstatter_dato   date;

-- En rad har enten tekst eller fil. `innhold` var `not null` fra 0035.
alter table public.anvisninger alter column innhold drop not null;

-- MAA TAALE AA KJOERES OM IGJEN. `if not exists` finnes ikke for
-- constraints; katalogsjekken gjoer det samme.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'anvisninger_tekst_eller_fil'
      and conrelid = 'public.anvisninger'::regclass
  ) then
    alter table public.anvisninger
      add constraint anvisninger_tekst_eller_fil
      check (innhold is not null or fil_sti is not null);
  end if;
end $$;

-- Soeket filtreres i nettleseren, men LISTA hentes per retailer og maa
-- vaere rask. Delvis indeks: bare radene som ikke er slettet.
create index if not exists anvisninger_aktiv_idx
  on public.anvisninger (retailer_id, kategori, sortering)
  where slettet_tid is null;

comment on column public.anvisninger.stikkord is
  'Ord personalet soeker paa - ingrediensen i haanda, ikke produktnavnet. '
  'Normalisert til smaa bokstaver ved opplasting.';
comment on column public.anvisninger.original_filnavn is
  'Kun til duplikatvarselet. Noekkelen i storage er generert, se `fil_sti`.';
comment on column public.anvisninger.erstatter_dato is
  'Datoen arket erstatter, slik den staar trykt paa arket fra leverandoeren.';

-- ---------------------------------------------------------------------
-- Bucket og filtilgang
--
-- PRIVAT BUCKET, signerte URL-er med 24 timers levetid. Aldri offentlige
-- lenker: arkene er kjedens eget materiale.
--
-- LEVETIDEN MAA VAERE LENGER ENN CACHE-VINDUET. Er sida cachet lenger
-- enn URL-en lever, faar brukeren 403 paa en lenke som saa gyldig ut.
-- Sida rendres dynamisk, saa 24 timer er rikelig - men aldri kortere.
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('anvisninger', 'anvisninger', false)
on conflict (id) do nothing;

-- Foerste stisegment er retailer_id. `lagFilsti` i anvisningssok.ts
-- bygger den, og en test der laaser rekkefoelgen: bytter den, faller
-- tenantgjerdet her.
--
-- SPLITTET I LES OG SKRIV, aldri `for all`. `USING` i en `for all`-policy
-- gjelder ogsaa SELECT, og permissive policyer OR-es sammen - da trekkes
-- skrivepolicyen inn i hver leseplan.
drop policy if exists anvisninger_storage on storage.objects;
drop policy if exists anvisninger_storage_les on storage.objects;
create policy anvisninger_storage_les on storage.objects for select to authenticated
  using (
    bucket_id = 'anvisninger'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
  );

-- Bare ledere laster opp. Sletting av selve fila gjoeres ikke - raden
-- soft-slettes, og fila blir liggende.
drop policy if exists anvisninger_storage_skriv on storage.objects;
create policy anvisninger_storage_skriv on storage.objects for insert to authenticated
  with check (
    bucket_id = 'anvisninger'
    and (storage.foldername(name))[1] = (select public.gjeldende_retailer_id())::text
    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef')
  );
