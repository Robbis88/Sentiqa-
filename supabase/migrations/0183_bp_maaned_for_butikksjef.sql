-- ---------------------------------------------------------------------
-- 0183: butikksjefen skal se SITT eget budsjett
-- ---------------------------------------------------------------------
-- `bp_aar` og `bp_linje` staar med `manager: "none"` i tenantkontrakten,
-- og det er riktig: BP-en er kjedens dokument. Gir vi butikksjefen
-- lesetilgang, ser hun hver eneste stasjons budsjett, ikke bare sitt.
--
-- Konsekvensen var likevel ikke tenkt igjennom. Uten BP:
--
--   * maaneder som bare finnes i BP-en forsvinner fra /lonnskost - en
--     butikksjef saa siste avlagte maaned og ingenting framover
--   * LOENNSROMMET kan aldri regnes, for det ER en andel av BP-en:
--     loennsandel = BP-loenn / BP-brutto
--
-- Altsaa: funksjonen som er bygget for butikksjefen kunne ikke virke for
-- butikksjefen.
--
-- SMALHET, IKKE RANG. Samme form som 0165/0167/0168: en security
-- definer-funksjon som baerer tenantpredikatet SELV og rører noeyaktig de
-- kolonnene som trengs. Ingen ny grant paa tabellene, ingen policy som
-- maa vurderes paa nytt, og ingen vei til en annen stasjons tall.
--
-- ET VIEW VILLE IKKE HOLDT. Med `security_invoker = true` leser viewet
-- som kalleren, og da er butikksjefen fortsatt stengt ute. Uten
-- klausulen leser det som eieren - forbi RLS, for alle rader, i alle
-- kjeder. Funksjonen er den eneste formen som kan baere predikatet selv.
create or replace function public.bp_maaned_for_mine_stasjoner(
  fra_maaned text default '0000-01'
)
returns table (
  stasjon_id   uuid,
  maaned       text,
  omsetning_kr numeric,
  brutto_kr    numeric,
  lonn_kr      numeric
)
language sql
stable
security definer
-- Tom search_path: en security definer-funksjon skal ikke kunne loses
-- opp mot et skjema kalleren kontrollerer.
set search_path = ''
as $$
  select
    a.stasjon_id,
    to_char(make_date(a.ar, l.maned, 1), 'YYYY-MM')                        as maaned,
    sum(l.belop_kr) filter (where l.seksjon = 'omsetning')                 as omsetning_kr,
    coalesce(sum(l.belop_kr) filter (where l.seksjon = 'omsetning'), 0)
      - coalesce(sum(l.belop_kr) filter (where l.seksjon = 'varekost'), 0) as brutto_kr,
    -- LOENNSKODENE, IKKE HELE KOSTNADSSEKSJONEN. `bp_kostnad` har over
    -- femti konti; bare 5xxx-personalkodene er loenn. Speiler
    -- BP_LONNSKODER i src/lib/lonnskost/bp.ts.
    sum(l.belop_kr) filter (
      where l.seksjon = 'kostnad'
        and l.kode in ('5010', '5012', '5090', '5400', '5401')
    )                                                                      as lonn_kr
  from public.bp_linje l
  join public.bp_aar a on a.id = l.bp_aar_id
  -- TENANTPREDIKATET STAAR HER, i funksjonen, ikke i en policy noen kan
  -- glemme aa skrive. `mine_stasjoner()` gir eieren hele kjeden og
  -- butikksjefen sine egne - samme funksjon, to svar.
  where a.stasjon_id in (select public.mine_stasjoner())
    and to_char(make_date(a.ar, l.maned, 1), 'YYYY-MM') >= fra_maaned
  group by a.stasjon_id, a.ar, l.maned;
$$;

comment on function public.bp_maaned_for_mine_stasjoner(text) is
  'BP-ens omsetning, brutto og loenn per maaned, for stasjonene kalleren har '
  'tilgang til. Finnes fordi butikksjefen ikke leser bp_linje direkte - BP-en '
  'er kjedens dokument, men maanedstallet for EGEN stasjon er hennes.';

revoke all on function public.bp_maaned_for_mine_stasjoner(text) from public, anon;
grant execute on function public.bp_maaned_for_mine_stasjoner(text) to authenticated;

-- Kvittering.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'bp_maaned_for_mine_stasjoner'
      and p.prosecdef)                                                as definer,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'bp_maaned_for_mine_stasjoner'
      and p.proconfig::text like '%search_path=%')                    as search_path_satt,
  (select count(*) from information_schema.role_routine_grants
    where routine_schema = 'public'
      and routine_name = 'bp_maaned_for_mine_stasjoner'
      and grantee = 'anon')                                           as anon;
