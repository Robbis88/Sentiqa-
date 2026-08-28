-- =====================================================================
-- BUGFIX: VAERPROFILEN LAERTE PAA DRIVSTOFF
--
-- `beregn_vaerprofil` (0068) sier i sin egen kommentar at den regner paa
-- "butikkomsetning (eks drivstoff/pant)". Den filtrerer paa
--
--     avdeling_kode not in ('10', '250')
--
-- og baselinekjoeringen 2026-08-28 viste at drivstoff har avdelingskode
-- **1000**, ikke 10. Koden '250' (pant) og '40' (CR) finnes heller ikke.
-- Alle avdelinger i data er tresifrede - 120..999 - pluss 1000.
--
-- Filteret traff altsaa ingenting. Funksjonen summerer omsetning per
-- stasjon per dag over ALLE avdelinger og korrelerer den mot vaer. Med
-- drivstoff paa 43-84 % av omsetningen per stasjon maalte den
-- drivstoffets vaerfoelsomhet, ikke butikkens - og skrev resultatet til
-- `stasjoner.vaerfolsomhet_laert`, som produksjonsplanen,
-- salgsprognosen og backtesten leser.
--
-- ---------------------------------------------------------------------
-- HVORFOR `v_butikksalg` OG IKKE ET NYTT FILTER
--
-- Den aapenbare minsteendringen er aa kopiere navnesjekken fra
-- `v_butikksalg`:  `upper(avdeling_navn) <> 'ENERGI'`. Det ville virket,
-- og det ville gitt en TREDJE kopi av drivstoffdefinisjonen som maa
-- holdes i takt med de to andre.
--
-- `v_butikksalg` ER den eksisterende representasjonen av butikksalg, og
-- husreglene sier at alt som summerer kroner eller antall skal lese den.
-- Naar drivstoffdefinisjonen en gang blir retailer-konfigurasjon, endres
-- viewet - og disse to funksjonene foelger med uten aa roeres.
--
-- **Dette er ikke semantisk mapping.** Ingen ny tabell, ingen ny
-- abstraksjon. Bare: les den kilden som allerede er riktig.
--
-- ---------------------------------------------------------------------
-- HVA SOM FAKTISK ENDRER SEG
--
--   beregn_vaerprofil         ENDRER TALL. Den summerer over alle
--                             avdelinger til ett tall per stasjon per
--                             dag, saa drivstoff dominerte korrelasjonen.
--
--   beregn_kategori_vaerprofil ENDRER INGEN KOEFFISIENT. Den grupperer
--                             per (stasjon, niva, kode) og korrelerer per
--                             kode - bakerienes verdier var allerede
--                             regnet fra sine egne rader. Effekten er at
--                             ENERGI-raden forsvinner fra
--                             `kategori_vaerprofil`. Ingen leser den.
--                             Rettes likevel: samme feil, samme regel, og
--                             en halvveis rettet regel er verre enn en
--                             urettet.
--
-- ---------------------------------------------------------------------
-- HVA SOM IKKE ROERES
--
--   * `v_butikksalg` - uendret.
--   * `PRODUKSJON_KODER` - uendret.
--   * Alle andre salgsfiltre - uendret.
--   * RLS og policyer - uendret. Begge funksjoner er fortsatt
--     `security definer`; viewet er `security_invoker`, saa det leses som
--     funksjonens eier, akkurat som `daglig_salg` ble i dag. Ingen tabell
--     har `force row level security`, saa eieren ser alle rader - samme
--     rekkevidde som foer.
--   * Grants paa `v_butikksalg` - se eget notat, ikke denne PR-en.
--
-- Idempotent: kun `create or replace`. Trygg aa kjoere om igjen.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. LAERT VAERPROFIL PER STASJON
-- ---------------------------------------------------------------------
-- Identisk med 0068 bortsett fra kilden. `slettet_tid` filtreres ikke
-- lenger her: `v_butikksalg` gjoer det selv, og en dublert sjekk ville
-- antydet at viewet ikke kan stoles paa.
create or replace function public.beregn_vaerprofil()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare antall integer;
begin
  with dag as (
    select v.stasjon_id, v.dato,
           extract(dow from v.dato)::int as ukedag,
           sum(v.omsetning_eks_mva)      as oms
    from public.v_butikksalg v
    -- Pant beholdes som uttrykt hensikt fra 0068. Baselinen 2026-08-28
    -- viste at koden ikke finnes i data, saa armen er i praksis doed -
    -- men aa fjerne den ville vaert en beslutning om pant, ikke om
    -- drivstoff, og hoerer ikke hjemme i denne bugfixen.
    where (v.avdeling_kode is null or v.avdeling_kode not in ('250'))
      and v.dato >= (current_date - interval '400 days')
    group by v.stasjon_id, v.dato
  ),
  wd as (
    select stasjon_id, ukedag, avg(oms) as wd_mean from dag group by stasjon_id, ukedag
  ),
  res as (
    select d.stasjon_id, d.dato, d.oms - w.wd_mean as resid
    from dag d join wd w on w.stasjon_id = d.stasjon_id and w.ukedag = d.ukedag
  ),
  korr as (
    select r.stasjon_id,
           corr(r.resid, v.temp_maks)  as temp_korr,
           corr(r.resid, v.nedbor_mm)  as nedbor_korr,
           count(*)                    as n
    from res r
    join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato and v.temp_maks is not null
    group by r.stasjon_id
  ), oppdatert as (
    update public.stasjoner s set
      vaer_temp_korr      = k.temp_korr,
      vaer_nedbor_korr    = k.nedbor_korr,
      vaerfolsomhet_laert = least(1.0, greatest(0.1, greatest(abs(coalesce(k.temp_korr, 0)), abs(coalesce(k.nedbor_korr, 0))) * 2.0)),
      vaer_profil_tid     = now()
    from korr k
    where s.id = k.stasjon_id and k.n >= 30 -- krev nok historikk
    returning 1
  )
  select count(*) into antall from oppdatert;
  return antall;
end $$;

revoke all on function public.beregn_vaerprofil() from public, anon, authenticated;
grant execute on function public.beregn_vaerprofil() to service_role;

-- ---------------------------------------------------------------------
-- 2. LAERT VAERPROFIL PER KATEGORI
-- ---------------------------------------------------------------------
-- Merk at varegruppe-grenen i 0070 ikke hadde NOE avdelingsfilter. Den
-- fikk derfor en egen rad for drivstoffets varegruppe. Koeffisientene for
-- de andre kodene var upaavirket, siden korrelasjonen regnes per kode.
create or replace function public.beregn_kategori_vaerprofil()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare antall integer;
begin
  delete from public.kategori_vaerprofil;

  with base as (
    -- Avdeling: omsetning
    select v.retailer_id, v.stasjon_id, 'avdeling'::text as niva, v.avdeling_kode as kode,
           v.dato, extract(dow from v.dato)::int as ukedag, sum(v.omsetning_eks_mva) as val
    from public.v_butikksalg v
    where v.avdeling_kode is not null
      and v.avdeling_kode not in ('250', '40')   -- pant/CR, som i 0070
      and v.dato >= (current_date - interval '400 days')
    group by v.retailer_id, v.stasjon_id, v.avdeling_kode, v.dato
    union all
    -- Varegruppe: antall
    select v.retailer_id, v.stasjon_id, 'varegruppe', v.varegruppe_kode,
           v.dato, extract(dow from v.dato)::int, sum(v.antall)
    from public.v_butikksalg v
    where v.varegruppe_kode is not null
      and v.dato >= (current_date - interval '400 days')
    group by v.retailer_id, v.stasjon_id, v.varegruppe_kode, v.dato
  ),
  wd as (
    select stasjon_id, niva, kode, ukedag, avg(val) as wd_mean
    from base group by stasjon_id, niva, kode, ukedag
  ),
  res as (
    select b.retailer_id, b.stasjon_id, b.niva, b.kode, b.dato, b.val - w.wd_mean as resid
    from base b join wd w on w.stasjon_id = b.stasjon_id and w.niva = b.niva and w.kode = b.kode and w.ukedag = b.ukedag
  ),
  korr as (
    select r.retailer_id, r.stasjon_id, r.niva, r.kode,
           corr(r.resid, v.temp_maks) as temp_korr,
           corr(r.resid, v.nedbor_mm) as nedbor_korr,
           count(*) as n
    from res r
    join public.vaer v on v.stasjon_id = r.stasjon_id and v.dato = r.dato and v.temp_maks is not null
    group by r.retailer_id, r.stasjon_id, r.niva, r.kode
  ), innsatt as (
    insert into public.kategori_vaerprofil (retailer_id, stasjon_id, niva, kode, temp_korr, nedbor_korr, n)
    select retailer_id, stasjon_id, niva, kode, temp_korr, nedbor_korr, n
    from korr where n >= 30 -- krev nok historikk for en troverdig korrelasjon
    returning 1
  )
  select count(*) into antall from innsatt;
  return antall;
end $$;

revoke all on function public.beregn_kategori_vaerprofil() from public, anon, authenticated;
grant execute on function public.beregn_kategori_vaerprofil() to service_role;

-- ---------------------------------------------------------------------
-- 3. REGN OM
-- ---------------------------------------------------------------------
-- Uten dette staar de gamle verdiene til nattjobben neste gang kjoerer.
-- Kvitteringen er en rad: SQL Editor viser ikke `raise notice`, og et
-- resultat ingen ser blir ikke kontrollert.
select public.beregn_vaerprofil()          as stasjoner_oppdatert,
       public.beregn_kategori_vaerprofil() as kategorirader;
