-- =====================================================================
-- E0 I PRODUKSJON — HVA KOEEN SKAL VISE, OG AT INGENTING FLYTTET SEG
-- =====================================================================
-- RENT LESENDE. Ingen update, ingen insert, ingen transaksjon aa rulle
-- tilbake - den leser bare.
--
-- EN SETNING. SQL Editor viser bare siste resultatmengde.
--
-- ---------------------------------------------------------------------
-- HVA DENNE BEVISER, OG HVA DEN IKKE KAN BEVISE
-- ---------------------------------------------------------------------
--
-- Den regner ut det samme som `standardmaaned` og `delKoe` i
-- `src/lib/kurs/koe.ts`, DIREKTE I BASEN. Da har skjermbildet en fasit
-- aa sammenlignes mot, i stedet for aa se riktig ut.
--
-- Den kan IKKE bevise at sida faktisk tegner det. Det maa du se. Men
-- naar tallene her og tallene paa skjermen er de samme, er det ikke
-- lenger en vurdering.
--
-- ---------------------------------------------------------------------
-- BASELINE, MAALT 2026-09-14 FOER DEPLOYEN
-- ---------------------------------------------------------------------
--
--   5 sluppet (alle juli) · 30 utkast · 0 avvist
--   Lone juni: utkast, sluppet_tid 2026-09-14 14:55:07.086+00 bevart
--
-- Deployen rorte bare kode - ingen migrasjon kjorte. Statusene KAN
-- derfor ikke ha endret seg. Punkt 3 og 5 maaler at de ikke gjorde det,
-- i stedet for aa anta det.
-- =====================================================================

with koe as (
  select id, stasjon_id, maaned, status, sluppet_tid
    from public.maanedsplan
),
aapner as (
  -- `standardmaaned` etter rettelsen i #284: NYESTE MAANED SOM HAR EN
  -- PLAN, uansett status.
  --
  -- Her sto `coalesce(max(maaned) where status='utkast', max(maaned))`
  -- - den gamle regelen. Sonden ville dermed valgt juni mens sida
  -- valgte juli, og en riktig side ville sett ut som et avvik.
  --
  -- En sonde som koder en annen regel enn koden, maaler ikke koden.
  select max(maaned) as m from koe
),
gammel as (
  -- Hva den FORRIGE regelen ville valgt. Staar her for aa vise at
  -- rettelsen betyr noe i dagens data - ikke som et krav.
  select coalesce(
           (select max(maaned) from koe where status = 'utkast'),
           (select max(maaned) from koe)
         ) as m
)

select * from (

  -- --- 1  HVILKEN MAANED SIDA SKAL AAPNE PAA ---------------------------
  select 1 as sort, 'sida skal aapne paa' as noekkel,
         to_char((select m from aapner), 'YYYY-MM') as a,
         (select count(*)::text from koe
           where status = 'utkast' and maaned = (select m from aapner))
           || ' utkast i koen' as b,
         'nyeste maaned som har en plan - status teller ikke med' as c

  -- --- 2  DET SOM SKAL VAERE SKJULT, MEN TELT -------------------------
  -- Dette er tallet flaten MAA skrive ut. Et filter som bare skjuler,
  -- ville byttet feilslippet mot en usluppet plan ingen visste om.
  union all
  select 2, 'skjult, men telt',
         (select count(*)::text from koe
           where status = 'utkast' and maaned <> (select m from aapner))
           || ' eldre utkast',
         (select count(distinct maaned)::text from koe
           where status = 'utkast' and maaned <> (select m from aapner))
           || ' andre maaneder',
         'skal staa som tekst under «Venter paa deg»'

  -- --- 3  STATUSFORDELINGEN, MOT BASELINEN ---------------------------
  union all
  select 3, 'statusfordeling',
         'sluppet ' || count(*) filter (where status = 'sluppet')::text
           || '  utkast ' || count(*) filter (where status = 'utkast')::text
           || '  avvist ' || count(*) filter (where status = 'avvist')::text,
         count(*)::text || ' planer totalt',
         case when count(*) filter (where status = 'sluppet') = 5
                   and count(*) filter (where status = 'utkast') = 30
                   and count(*) filter (where status = 'avvist') = 0
              then 'ok - uendret fra baselinen foer deployen'
              else 'AVVIK - noe har flyttet seg' end
    from koe

  -- --- 4  MAANEDSVELGERENS INNHOLD -----------------------------------
  -- Hver maaned som skal staa i nedtrekkslista, med hva den inneholder.
  union all
  select 4, to_char(maaned, 'YYYY-MM'),
         count(*) filter (where status = 'utkast')::text || ' utkast',
         count(*) filter (where status = 'sluppet')::text || ' sluppet',
         case when maaned = (select m from aapner)
              then '<- denne vises naar du aapner sida'
              else 'naas via velgeren' end
    from koe
   group by maaned

  -- --- 5  LONE JUNI: STATUS OG REVISJONSSPOR -------------------------
  -- Raden som ble feilsluppet og trukket tilbake 2026-09-14. Id-en er
  -- eksakt, saa ingen navnematching kan bomme.
  union all
  select 5, 'Lone juni (feilsluppet, trukket tilbake)',
         status,
         'sluppet_tid ' || coalesce(sluppet_tid::text, '(null)'),
         case when status = 'utkast'
                   and sluppet_tid = timestamptz '2026-09-14 14:55:07.086+00'
              then 'ok - utkast, sporet staar'
              else 'AVVIK - juni har flyttet seg' end
    from koe
   where id = '2f7a85ef-34cc-4197-8a3b-56703fa5f8c8'

  -- --- 6  BETYR RETTELSEN NOE I DAGENS DATA? --------------------------
  -- Den gamle regelen mot den nye. Er de like, er rettelsen usynlig i
  -- dag - og da beviser ikke denne kjoeringen at den virker. Er de
  -- ulike, er det nettopp forskjellen #284 handlet om.
  --
  -- IKKE ET KRAV, en observasjon. Begge utfall er i orden; de betyr
  -- bare ulike ting for hva maalingen har vist.
  union all
  select 6, 'gammel regel mot ny',
         'gammel: ' || to_char((select m from gammel), 'YYYY-MM'),
         'ny: ' || to_char((select m from aapner), 'YYYY-MM'),
         case when (select m from gammel) = (select m from aapner)
              then 'like - rettelsen er usynlig i disse dataene'
              else 'ULIKE - den gamle ville aapnet paa en eldre maaned' end

) r
 order by sort, noekkel;
