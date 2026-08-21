-- =====================================================================
-- v_bp_status_avdeling: brutto mot BUDSJETT, ikke mot kassa
--
-- DOMENEREGELEN, fra Robert 2026-08-21:
--
--   «Kassen er fasit paa en perfekt hverdag. BP-budsjett i brutto mot
--    regnskap er fasiten paa pengene vi tjener. Sier BP 60 %, kassa
--    80 % og regnskapet 40 %, saa er gapet mellom BP og regnskap det
--    som maa dekkes.»
--
-- VARM DRIKKE er grunnen til at dette maatte rettes. Kaffeavtaler: en
-- fast sum, og saa tar kunden saa mye han vil. Hver kopp etter den
-- foerste gaar ut uten et salg bak seg. Kassen ser bare de registrerte
-- koppene og sier 80 %; tellingen ser alt som er brukt og sier 20 %.
-- Andelen avtaler varierer sterkt mellom stasjoner.
--
-- Sida maalte `kassen - regnskap` og farget den som om den krevde
-- handling. For varm drikke ville den alltid vaert stor, alltid roed og
-- alltid uten et grep aa ta: differansen ER avtalene. Vi ville sendt
-- butikksjefen etter et svinn som ikke finnes, hver eneste maaned.
--
-- Budsjettet er satt MED avtalene innbakt. Derfor er `regnskap mot
-- budsjett` den eneste av de tre sammenligningene som maaler drift.
--
-- Kassen blir staaende - som TAKET paa en perfekt dag, ikke som fasit.
--
-- Alvoret hentes fra `TERSKLER.brfGul` (-5 % indeks under budsjett).
-- Den grensen finnes fra foer og betyr det samme; en ny terskel her
-- ville gitt to sannheter om naar brutto er for lav.
-- =====================================================================

create or replace view public.v_bp_status_avdeling
with (security_invoker = true) as

with naa as (
  -- PER STASJON. Salgstall er alltid gaarsdagens, og vi maaler mot den
  -- datoen stasjonen HAR - ikke mot dagens dato, og ikke mot naboens.
  select stasjon_id,
         max(dato)                                as siste_dato,
         date_trunc('month', max(dato))::date     as denne_mnd,
         extract(day from max(dato))::int         as dagnr
  from public.v_butikksalg
  group by stasjon_id
),

-- Hvilke avdelingskoder stasjonen i det hele tatt HAR salgsdata paa,
-- noen gang. Skillet mellom «ingen salg denne maaneden» og «denne koden
-- finnes ikke i salgsdataene» kan ikke tas uten dette.
kjente_koder as (
  select distinct stasjon_id, avdeling_kode as gruppe_kode
  from public.v_butikksalg
  where avdeling_kode is not null
),

budsjett as (
  -- Begge kildene i en. `filter` skiller dem, saa en avlagt og en aapen
  -- maaned aldri kan blande budsjettene sine.
  --
  -- UTELATTE KODER: drivstoff (10), pant (250) og grand total (40).
  -- Dette er den SAMME domeneregelen som `SKJUL_OMS_KODER` i
  -- src/lib/avdelinger.ts, og ikke en ny beslutning:
  --
  --   10   Drivstoff - kommisjon/volum utenfor butikkdriften. Sier
  --        ingenting om hvordan butikken drives.
  --   250  Pant - gjennomgang uten margin. En rad med 0 % brutto midt i
  --        en analyse som handler om margin er stoy, ikke informasjon.
  --   40   CR - regnskapets grand total, summen av alle de andre. Tas
  --        den med, dobbelttelles hele stasjonen mot avdelingene.
  --
  -- SQL kan ikke importere fra TypeScript, saa lista staar to steder.
  -- `utelatte-koder.test.ts` leser BEGGE og feller hvis de gaar fra
  -- hverandre.
  -- utelatte_koder := array['10', '250', '40']
  select r.stasjon_id,
         r.periode                                    as maned,
         r.kode                                       as gruppe_kode,
         min(r.post)                                  as post,
         sum(r.budsjett) filter (where r.seksjon = 'bp_omsetning')          as bp_oms_aapen,
         sum(r.budsjett) filter (where r.seksjon = 'bp_bruttofortjeneste')  as bp_brt_aapen,
         sum(r.budsjett) filter (where r.seksjon = 'omsetning')             as bp_oms_avlagt,
         sum(r.budsjett) filter (where r.seksjon = 'bruttofortjeneste')     as bp_brt_avlagt,
         sum(r.regnskap) filter (where r.seksjon = 'omsetning')             as regn_oms,
         sum(r.regnskap) filter (where r.seksjon = 'bruttofortjeneste')     as regn_brt,
         count(*) filter (where r.seksjon in ('omsetning', 'bruttofortjeneste')) > 0
                                                      as er_avlagt
  from public.regnskapslinjer r
  where r.kode is not null
    and r.kode not in ('10', '250', '40')
    and r.seksjon in ('omsetning', 'bruttofortjeneste',
                      'bp_omsetning', 'bp_bruttofortjeneste')
  group by r.stasjon_id, r.periode, r.kode
),

salg as (
  select v.stasjon_id,
         date_trunc('month', v.dato)::date     as maned,
         v.avdeling_kode                       as gruppe_kode,
         min(v.avdeling_navn)                  as navn,
         sum(v.omsetning_eks_mva)              as omsetning,
         sum(v.bto_fortjeneste_kr)             as brutto
  from public.v_butikksalg v
  where v.avdeling_kode is not null
    and v.avdeling_kode not in ('10', '250', '40')
  group by v.stasjon_id, date_trunc('month', v.dato), v.avdeling_kode
),

-- Samme periode i fjor. For en avsluttet maaned: hele maaneden. For
-- inneveaerende: dag 1 til samme dagnummer - ellers sammenligner vi en
-- halv maaned med en hel og kaller fallet en utvikling.
--
-- `dagnr` kommer naa fra STASJONENS egen kalender (join paa naa), ikke
-- fra kjedens. `n.dagnr` maa staa i group by: den er konstant per
-- stasjon, men Postgres kan ikke utlede det.
ifjor as (
  select v.stasjon_id,
         (date_trunc('month', v.dato) + interval '1 year')::date as maned,
         v.avdeling_kode                                          as gruppe_kode,
         sum(v.omsetning_eks_mva)                                 as oms_hel,
         sum(v.omsetning_eks_mva) filter (
           where extract(day from v.dato) <= n.dagnr
         )                                                        as oms_hittil,
         -- Andelen av maaneden som laa paa dag 1..dagnr i fjor. Det er
         -- denne kurven «burde_naa» pro-rateres etter, og den er hele
         -- grunnen til at 20 dagers salg maales mot 20 dagers budsjett.
         sum(v.omsetning_eks_mva) filter (
           where extract(day from v.dato) <= n.dagnr
         ) / nullif(sum(v.omsetning_eks_mva), 0)                  as andel
  from public.v_butikksalg v
  join naa n on n.stasjon_id = v.stasjon_id
  where v.avdeling_kode is not null
  group by v.stasjon_id, date_trunc('month', v.dato), v.avdeling_kode, n.dagnr
),

-- Hittil i aar, fra AVLAGTE maaneder: bade det regnskapet viser og det
-- budsjettet lovet, over NOEYAKTIG DE SAMME maanedene.
--
-- Begge sider maa summeres over samme utvalg. Sammenlignes regnskapets
-- fem avlagte maaneder med budsjettets tolv, er avviket bare en
-- kalenderforskjell forkledd som en margin.
--
-- VEKTET, IKKE SNITT AV MAANEDSPROSENTER: sum(brutto)/sum(omsetning).
-- En stor maaned skal veie mer enn en liten.
ytd as (
  select b.stasjon_id, b.gruppe_kode,
         date_trunc('year', b.maned)::date               as aar,
         sum(b.regn_brt)                                 as brutto_kr,
         sum(b.regn_oms)                                 as oms_kr,
         sum(coalesce(b.bp_brt_avlagt, b.bp_brt_aapen))  as bp_brutto_kr,
         sum(coalesce(b.bp_oms_avlagt, b.bp_oms_aapen))  as bp_oms_kr
  from budsjett b
  where b.er_avlagt
  group by b.stasjon_id, b.gruppe_kode, date_trunc('year', b.maned)
),

grunn as (
  select coalesce(b.stasjon_id, s.stasjon_id)   as stasjon_id,
         coalesce(b.maned, s.maned)             as maned,
         coalesce(b.gruppe_kode, s.gruppe_kode) as gruppe_kode,
         coalesce(s.navn, b.post)               as gruppe_navn,
         b.er_avlagt,
         coalesce(b.bp_oms_avlagt, b.bp_oms_aapen) as bp_omsetning_kr,
         coalesce(b.bp_brt_avlagt, b.bp_brt_aapen) as bp_brutto_kr,
         b.regn_oms, b.regn_brt,
         s.omsetning as salg_oms,
         s.brutto    as salg_brt,
         f.oms_hel   as ifjor_hel,
         f.oms_hittil as ifjor_hittil,
         f.andel     as ifjor_andel,
         -- FIRE TILSTANDER, IKKE TO. Se kommentaren paa `kobling` under.
         (b.gruppe_kode is not null) as har_plan,
         (s.gruppe_kode is not null) as har_salg,
         (k.gruppe_kode is not null) as koden_finnes_i_salg
  from budsjett b
  full join salg s
    on s.stasjon_id = b.stasjon_id and s.maned = b.maned
   and s.gruppe_kode = b.gruppe_kode
  left join ifjor f
    on f.stasjon_id = coalesce(b.stasjon_id, s.stasjon_id)
   and f.maned      = coalesce(b.maned, s.maned)
   and f.gruppe_kode = coalesce(b.gruppe_kode, s.gruppe_kode)
  left join kjente_koder k
    on k.stasjon_id  = coalesce(b.stasjon_id, s.stasjon_id)
   and k.gruppe_kode = coalesce(b.gruppe_kode, s.gruppe_kode)
),

med_status as (
  select g.*,
         n.denne_mnd, n.dagnr,
         extract(days from (g.maned + interval '1 month' - interval '1 day'))::int as dager_i_mnd,
         case
           when g.er_avlagt              then 'avlagt'
           when g.maned = n.denne_mnd    then 'innevaerende'
           when g.maned > n.denne_mnd    then 'kommende'
           -- FIRE VERDIER, IKKE TRE. Juli 2026 er over, har fullt salg og
           -- BP - men regnskapet er ikke avlagt ennaa.
           else                               'venter_regnskap'
         end as periode_status
  from grunn g
  join naa n on n.stasjon_id = g.stasjon_id
)

select
  m.stasjon_id,
  maned,
  periode_status,
  m.gruppe_kode,
  gruppe_navn,

  round(bp_omsetning_kr)                            as bp_omsetning_kr,
  round(bp_brutto_kr)                               as bp_brutto_kr,

  -- BURDE VAERT NAA. Bare meningsfullt inneveaerende maaned.
  case when periode_status = 'innevaerende' and bp_omsetning_kr is not null
       then round(bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd))
  end                                               as burde_naa_omsetning,

  case when periode_status = 'kommende' then null
       else round(salg_oms) end                     as faktisk_omsetning,

  -- HOVEDDOMMEN.
  case
    when periode_status = 'kommende' then null
    when periode_status = 'innevaerende' and bp_omsetning_kr is not null
      then round(salg_oms - bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd))
    when bp_omsetning_kr is not null then round(salg_oms - bp_omsetning_kr)
  end                                               as mot_bp_kr,

  case
    when periode_status = 'kommende' or coalesce(bp_omsetning_kr, 0) = 0 then null
    when periode_status = 'innevaerende'
      then round(((salg_oms - bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd))
                  / nullif(bp_omsetning_kr * coalesce(ifjor_andel, dagnr::numeric / dager_i_mnd), 0)) * 100, 1)
    else round(((salg_oms - bp_omsetning_kr) / nullif(bp_omsetning_kr, 0)) * 100, 1)
  end                                               as mot_bp_pst,

  -- KONTEKST, IKKE DOM.
  case
    when periode_status = 'kommende' then null
    when periode_status = 'innevaerende'
      then round(((salg_oms - ifjor_hittil) / nullif(ifjor_hittil, 0)) * 100, 1)
    else round(((salg_oms - ifjor_hel) / nullif(ifjor_hel, 0)) * 100, 1)
  end                                               as mot_ifjor_pst,

  -- TEORETISK BRUTTO: hva kassa sier margen var, uten svinn.
  --
  -- NEVNEREN MAA GI ET MENINGSFULLT BRUTTOMAAL. To krav, og begge er
  -- egenskaper ved tallparet, ikke terskler noen har funnet paa:
  --
  --   * omsetningen maa vaere positiv. En margin av null eller negativ
  --     omsetning er ikke liten eller stor - den finnes ikke.
  --   * bruttoen maa ligge innenfor omsetningen. Er |brutto| stoerre
  --     enn omsetningen, er de to tallene ikke et marginpar i det hele
  --     tatt; da kommer de fra hver sin stoerrelse, og prosenten er et
  --     symptom paa feil kobling - ikke en maaling av drift.
  --
  -- `DRIFT` ga -3536,4 % foer dette. Kronene staar fortsatt, saa
  -- problemet skjules ikke - det er bare prosenten som ikke paastaas.
  case when periode_status = 'kommende' then null
       else round(salg_brt) end                     as teoretisk_brutto_kr,
  case when periode_status = 'kommende'
         or coalesce(salg_oms, 0) <= 0
         or abs(salg_brt) > salg_oms then null
       else round((salg_brt / salg_oms) * 100, 1) end
                                                    as teoretisk_brutto_pst,

  -- FAKTISK BRUTTO HITTIL I AAR: regnskapet, med tellingene i seg.
  round(y.brutto_kr)                                as faktisk_brutto_ytd_kr,
  case when coalesce(y.oms_kr, 0) <= 0
         or abs(y.brutto_kr) > y.oms_kr then null
       else round((y.brutto_kr / y.oms_kr) * 100, 1) end
                                                    as faktisk_brutto_ytd_pst,

  -- GAPET. Positivt = kassa tror margen er bedre enn regnskapet viser.
  -- Faller bort saa snart en av de to prosentene ikke er et bruttomaal:
  -- en differanse mellom et tall og et ikke-tall er ikke en lekkasje.
  case
    when periode_status = 'kommende'
      or coalesce(salg_oms, 0) <= 0 or abs(salg_brt) > salg_oms
      or coalesce(y.oms_kr, 0) <= 0 or abs(y.brutto_kr) > y.oms_kr then null
    else round(((salg_brt / salg_oms) - (y.brutto_kr / y.oms_kr)) * 100, 1)
  end                                               as brutto_gap_pst,

  -- Sier om «burde_naa» er regnet fra fjoraarets EGEN kurve eller falt
  -- tilbake paa lineaert. Uten den leses et anslag som en maaling.
  case when ifjor_andel is not null then 'ifjor' else 'lineaert' end
                                                    as grunnlag,

  round(regn_oms)                                   as regnskap_omsetning_kr,
  round(regn_brt)                                   as regnskap_brutto_kr,

  -- KOBLINGEN, EKSPLISITT.
  --
  -- Uten denne kolonnen ser to helt ulike tilstander like ut: en
  -- avdeling som har budsjett og bare ikke har solgt noe ennaa, og en
  -- budsjettlinje som ikke har noen avdeling aa maales mot i det hele
  -- tatt. 0113 kalte begge «ingen plan lagt inn», som var motsatt av
  -- sannheten for begge.
  --
  --   plan_med_salg      Budsjett og salg moettes paa samme kode. Det
  --                      eneste tilfellet der en dom er mulig.
  --   plan_uten_salg     Koden FINNES i stasjonens salgsdata, men har
  --                      ingen omsetning denne maaneden. En ekte
  --                      nulltilstand: avdelingen er kjent, den har
  --                      bare ikke solgt.
  --   plan_uten_kobling  Koden finnes ikke i salgsdataene i det hele
  --                      tatt. `211 Selvvask`, `DRIFT`, `SYSTEM`.
  --                      Budsjettet er ekte, men det finnes ingenting
  --                      aa maale det mot - og det er en opplysning om
  --                      kodeverket, ikke om driften.
  --   salg_uten_plan     Avdelingen selger, men har ikke budsjett.
  --
  -- Hva hver kategori skal telle som i totalsummen er en
  -- produktbeslutning. Den tas ikke her - men den kan ikke tas foer
  -- kategorien er kjent, og foer 0114 var den det ikke.
  case
    when not har_plan                      then 'salg_uten_plan'
    when har_salg                          then 'plan_med_salg'
    when koden_finnes_i_salg               then 'plan_uten_salg'
    else                                        'plan_uten_kobling'
  end                                               as kobling,

  -- Fjoraarets HELE maaned, samme avdeling. Staar med fordi vekstkravet
  -- under ellers er et tall uten synlig grunnlag - og et forholdstall
  -- man ikke kan etterregne er en paastand.
  round(ifjor_hel)                                  as ifjor_omsetning_kr,

  -- VEKSTKRAVET. Hvor mye mer enn i fjor planen ber om.
  --
  -- Positiv: planen krever vekst. Negativ: planen ligger under fjoraaret,
  -- og da er «bak plan» et strengere svar enn «ned mot i fjor» - noe som
  -- er lett aa lese feil uten dette tallet.
  --
  -- Null naar fjoraaret mangler: et vekstkrav mot ingenting er ikke
  -- uendelig, det finnes ikke. Nye avdelinger og nye stasjoner er
  -- noeyaktig det tilfellet, og de skal ikke faa et tall som ser ut som
  -- en maaling.
  case when coalesce(ifjor_hel, 0) > 0 and bp_omsetning_kr is not null
       then round(((bp_omsetning_kr - ifjor_hel) / ifjor_hel) * 100, 1)
  end                                               as bp_vekst_pst,

  -- =====================================================================
  -- BRUTTO: TRE TALL, OG BARE ETT AV DEM ER EN DOM
  -- =====================================================================
  --
  -- Domeneregelen, fra Robert 2026-08-21:
  --
  --   «Kassen er fasit paa en perfekt hverdag. BP-budsjett i brutto mot
  --    regnskap er fasiten paa pengene vi tjener. Sier BP 60 %, kassa
  --    80 % og regnskapet 40 %, saa er gapet mellom BP og regnskap det
  --    som maa dekkes.»
  --
  -- Dette er ikke en finesse. VARM DRIKKE selges paa kaffeavtaler: en
  -- fast sum, og saa tar kunden saa mye han vil. Hver kopp etter den
  -- foerste gaar ut UTEN et salg bak seg. Kassen ser bare de registrerte
  -- koppene og sier 80 %; tellingen ser alt som faktisk er brukt og sier
  -- 20 %. Andelen avtaler varierer sterkt mellom stasjoner.
  --
  -- Foer dette maalte sida `kassen - regnskap` og farget den som om den
  -- krevde handling. For varm drikke ville den alltid vaert stor, alltid
  -- roed, og alltid uten et grep aa ta: differansen ER avtalene.
  --
  -- Budsjettet er derimot satt MED avtalene innbakt - regnskapet ligger
  -- naer BP for varm drikke. Derfor er det den sammenligningen som
  -- maaler drift, og den eneste som skal ha farge.
  --
  -- HITTIL I AAR, ikke maaneden: regnskapsbrutto finnes bare for
  -- avlagte maaneder, og sida viser den inneveaerende.

  -- Hva planen lovet i margin, over de samme avlagte maanedene.
  case when coalesce(y.bp_oms_kr, 0) <= 0
         or abs(y.bp_brutto_kr) > y.bp_oms_kr then null
       else round((y.bp_brutto_kr / y.bp_oms_kr) * 100, 1) end
                                                    as bp_brutto_ytd_pst,

  -- DOMMEN. Regnskapets margin minus den budsjetterte, i prosentpoeng.
  -- Negativ = vi tjener mindre paa hver krone enn planen la opp til.
  -- Det er dette tallet som maa dekkes inn.
  case when coalesce(y.oms_kr, 0) <= 0 or abs(y.brutto_kr) > y.oms_kr
         or coalesce(y.bp_oms_kr, 0) <= 0 or abs(y.bp_brutto_kr) > y.bp_oms_kr
       then null
       else round(((y.brutto_kr / y.oms_kr) - (y.bp_brutto_kr / y.bp_oms_kr)) * 100, 1)
  end                                               as brutto_mot_bp_pp,

  -- SAMME DOM I KRONER. Prosentpoeng sier hvor mye tynnere hver krone
  -- er; kroner sier hvor mye det ble. En avdeling kan ligge 2 pp under
  -- paa stort volum og tape mer enn en som ligger 10 pp under paa lite.
  case when y.brutto_kr is null or y.bp_brutto_kr is null then null
       else round(y.brutto_kr - y.bp_brutto_kr) end
                                                    as brutto_mot_bp_kr,

  -- Og som INDEKS, saa alvoret kan hentes fra `TERSKLER.brfGul` -
  -- «bruttofortjeneste, index % under budsjett». Den grensen finnes
  -- allerede og gjelder det samme; en ny terskel her ville gitt to
  -- sannheter om naar brutto er for lav.
  case when coalesce(y.bp_brutto_kr, 0) = 0 then null
       else round(((y.brutto_kr - y.bp_brutto_kr) / y.bp_brutto_kr) * 100, 1)
  end                                               as brutto_mot_bp_indeks

from med_status m
left join ytd y
  on y.stasjon_id = m.stasjon_id
 and y.gruppe_kode = m.gruppe_kode
 and y.aar = date_trunc('year', m.maned)::date;

comment on view public.v_bp_status_avdeling is
  'BP mot faktisk per avdeling og maaned. BP avgjor om stasjonen er i '
  'rute (mot_bp_*), fjoraaret forklarer utviklingen (mot_ifjor_pst), og '
  'bp_vekst_pst sier hvor mye vekst planen KREVER mot i fjor - uten den '
  'leses hvert ambisiost budsjett som en fiasko i drift. Hver stasjon '
  'maales mot SIN egen siste salgsdato. Bruttoprosent og gap er null '
  'naar nevneren ikke gir et bruttomaal. `kobling` sier om budsjett og '
  'salg faktisk moettes, eller hvilken av dem som mangler. '
  'BRUTTO: `brutto_mot_bp_pp` er dommen - regnskapets margin mot den '
  'budsjetterte, hittil i aar over de samme avlagte maanedene. '
  '`teoretisk_brutto_pst` (kassa) er taket paa en perfekt dag og skal '
  'IKKE brukes som fasit: kaffeavtaler gir varm drikke en stor og helt '
  'normal differanse mellom kassa og tellingen.';

grant select on public.v_bp_status_avdeling to authenticated;

