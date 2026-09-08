-- =====================================================================
-- Sentiqa - HVA VILLE EN STRAMMET REGNSKAPSPOLICY FAKTISK TATT?
--
-- `regnskap-tilgang.ts` sier at butikksjefen ser kostnadene hen selv kan
-- paavirke, og at royalty, husleie, finans, avskrivninger og selve
-- RESULTAT-linja er eierens. Den regelen haandheves tre steder i appen -
-- /regnskap, AI-konteksten og auto-fokus - men **ikke i RLS**.
--
-- `regnskapslinjer_les` (0067) gir butikksjefen HVER rad for stasjonene
-- sine. Filteret er en visningsregel, og en visningsregel er ikke en
-- grense: den samme brukeren kan lese royaltylinja rett over PostgREST
-- med sin egen sesjon. Det er samme form som `malekort.vis_tablet` foer
-- `0134` - et flagg som bare bodde i spoerringen.
--
-- ---------------------------------------------------------------------
-- HVORFOR EN SONDE FOER MIGRASJONEN
--
-- Fordi jeg ikke skal gjette hva som forsvinner. `hentLonnskost` leser
-- HELE `driftskostnader` for stasjonen og filtrerer i TypeScript; blir
-- policyen for stram, faller loennskosten ut - og den er det ene stedet
-- den ikke faar lov til aa svikte.
--
-- Denne fila endrer ingenting. Den leser katalogen og tallene, og svarer
-- paa tre ting:
--
--   1. Hvilke kontoer ville forsvunnet for en butikksjef, med navn og
--      kroner, saa vi ser om lista stemmer med intensjonen.
--   2. Om alle de ni loennskontoene overlever. Gjoer de ikke det, skal
--      migrasjonen ikke kjores.
--   3. Hvilke `seksjon`-verdier som finnes i basen - forslaget roerer
--      bare `driftskostnader` og `resultat`, og da maa vi vite at det
--      ikke har dukket opp en tredje seksjon med kostnader i.
--
-- Kjores i SQL Editor som eier. Ingen `begin`/`rollback` trengs - her
-- finnes ingen skriving.
-- =====================================================================

-- FOERSTE KJOERING (2026-09-08) GA 3743 -> 3334, og 265 loennsrader
-- beholdt. Tallene stemte - men lista var feil: `506 Refundert
-- sykeloenn` stod i `LONNSKONTI` og IKKE i `BUTIKKSJEF_PERSONAL_KODER`,
-- saa forslaget ville kuttet refusjonen av sykeloennen for
-- butikksjefen. 506 er negativ, saa loennskosten hadde blitt for HOEY.
-- Det er rettet i begge listene; denne fila speiler dem.
--
-- Kodene butikksjefen SKAL se, ordrett fra `src/lib/regnskap-tilgang.ts`.
-- Star de to listene fra hverandre, er svaret under feil - derfor har
-- migrasjonen en vitest som binder dem sammen.
create temp table if not exists lov_kode(kode text primary key) on commit drop;
truncate lov_kode;
insert into lov_kode(kode) values
  ('501'), ('502'), ('503'), ('505'), ('506'), ('508'), ('509'), ('540'), ('541'), ('590'),
  ('627'), ('628'), ('629'), ('632'), ('633'), ('634'), ('636'), ('638'), ('746');

-- ---------------------------------------------------------------------
-- 1) HVA FORSVINNER
-- ---------------------------------------------------------------------
-- Bare rader med `stasjon_id` - klyngelinjene ser butikksjefen ikke i
-- dag heller, saa de er ikke en endring.
select
  'kutt' as hva,
  r.seksjon,
  coalesce(r.kode, '(ingen kode)')            as kode,
  min(r.post)                                 as eksempelpost,
  count(*)                                    as rader,
  count(distinct r.stasjon_id)                as stasjoner,
  round(sum(coalesce(r.regnskap, 0)))         as sum_regnskap
from public.regnskapslinjer r
where r.slettet_tid is null
  and r.stasjon_id is not null
  and (
    r.seksjon = 'resultat'
    or (r.seksjon = 'driftskostnader'
        and (r.kode is null or r.kode not in (select kode from lov_kode)))
  )
group by r.seksjon, coalesce(r.kode, '(ingen kode)')
order by r.seksjon, kode;

-- ---------------------------------------------------------------------
-- 2) OVERLEVER LOENNSKOSTEN?
-- ---------------------------------------------------------------------
-- De ni kontiene loennskosten bygger paa. Star det 0 rader paa noen av
-- dem, betyr det enten at kontoen ikke finnes i data (greit) eller at
-- den ligger i en annen seksjon enn `driftskostnader` (ikke greit - da
-- treffer forslaget feil).
select
  'lonnskost' as hva,
  k.kode,
  count(r.id) filter (where r.seksjon = 'driftskostnader') as i_driftskostnader,
  count(r.id) filter (where r.seksjon <> 'driftskostnader') as i_annen_seksjon,
  coalesce(string_agg(distinct r.seksjon, ', '), '(ingen rader)') as seksjoner
from (values ('501'),('502'),('503'),('505'),('506'),('508'),('509'),('540'),('541')) as k(kode)
left join public.regnskapslinjer r
  on r.kode = k.kode and r.slettet_tid is null and r.stasjon_id is not null
group by k.kode
order by k.kode;

-- ---------------------------------------------------------------------
-- 3) HVILKE SEKSJONER FINNES
-- ---------------------------------------------------------------------
-- Forslaget lar hver seksjon UNNTATT `driftskostnader` og `resultat`
-- vaere i fred. Det er med vilje: en hvitliste over seksjoner ville
-- gjort at en ny seksjon forsvant i stillhet for butikksjefen, og en
-- side som blir tom uten feilmelding er den dyreste formen. Men da maa
-- vi vite hva som finnes - dukker det opp en seksjon med kostnader i
-- som ikke heter `driftskostnader`, treffer forslaget forbi.
select
  'seksjoner' as hva,
  r.seksjon,
  count(*)                                     as rader,
  count(*) filter (where r.stasjon_id is null) as klyngerader,
  count(distinct r.kode)                       as ulike_koder,
  min(r.periode)                               as fra,
  max(r.periode)                               as til
from public.regnskapslinjer r
where r.slettet_tid is null
group by r.seksjon
order by rader desc;

-- ---------------------------------------------------------------------
-- 4) KVITTERING
-- ---------------------------------------------------------------------
-- SQL Editor viser ikke `raise notice`, saa svaret maa komme som en rad.
select
  'kvittering'                                                       as hva,
  (select count(*) from public.regnskapslinjer
    where slettet_tid is null and stasjon_id is not null)            as rader_butikksjef_ser_i_dag,
  (select count(*) from public.regnskapslinjer r
    where r.slettet_tid is null and r.stasjon_id is not null
      and not (
        r.seksjon = 'resultat'
        or (r.seksjon = 'driftskostnader'
            and (r.kode is null or r.kode not in (select kode from lov_kode)))
      ))                                                             as rader_etter_stramming,
  (select count(*) from public.regnskapslinjer r
    where r.slettet_tid is null and r.stasjon_id is not null
      and r.seksjon = 'driftskostnader'
      and r.kode in ('501','502','503','505','506','508','509','540','541'))
                                                                     as lonnskostrader_beholdt;
