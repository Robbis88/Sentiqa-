-- =====================================================================
-- 0217  AVVIST ER ABSOLUTT, OG UTKASTENE SKRIVES ATOMISK
-- =====================================================================
-- Tre ting, og de henger sammen:
--
--   1  `linjer_lest` tilbake i `v_kurs_maanedstall`
--   2  laasetriggeren utvidet: `avvist` er uforanderlig, og snapshotet
--      er med i laasen for `sluppet`/`sendt`
--   3  `skriv_maanedsplan_utkast()` - én atomisk skriver for BEGGE
--      kallerne, med laasen inne i selve setningen
--
-- ---------------------------------------------------------------------
-- HVORFOR DEN ATOMISKE SKRIVEREN
--
-- `lagreUtkast` gjorde SELECT status -> filtrer -> UPSERT. Det er tre
-- steg og to vinduer. Avviser eieren planen ETTER lesingen, men FOER
-- skrivingen, ble avvisningen skrevet tilbake til utkast - og triggeren
-- fanget det ikke, fordi den bare voktet `sluppet` og `sendt`.
--
-- En forhaandssjekk i applikasjonen er ikke en laas. Laasen hoerer
-- hjemme i setningen som skriver: `on conflict ... do update ... where`
-- evalueres ETTER at raden er laast, og blokkerer paa en uferdig
-- konkurrerende update. Naar den andre transaksjonen committer,
-- evalueres `where` mot den NYE radversjonen.
--
-- ---------------------------------------------------------------------
-- ÉN REGEL, IKKE TO
--
-- Foerste utkast hadde `p_laaste text[]` som parameter, saa importen
-- kunne beholde sin saerregel om aa skrive om en avvist plan. Det er en
-- klientstyrt laasepolitikk: en `authenticated`-bruker kunne kalt
-- funksjonen med en tom liste og gjenaapnet en avvisning.
--
-- Regelen er derfor én, og den staar som literaler i kroppen:
-- `sluppet`, `sendt` og `avvist` skrives aldri om. Ingen parameter, og
-- ingen andre funksjon aa velge.
--
-- Aa gjenaapne en avvist plan blir en egen, eksplisitt handling med eget
-- revisjonsspor. Den bygges IKKE her.
--
-- ---------------------------------------------------------------------
-- HVA `authenticated` KAN OG IKKE KAN
--
-- Funksjonen er `security invoker`: RLS er grensen, ikke funksjonen.
-- Den gir ingen ny adgang - den gjoer en skriving brukeren allerede har
-- rett til, atomisk.
--
-- KJEDEN KAN IKKE VELGES. `coalesce((select gjeldende_retailer_id()),
-- p_retailer_id)`: har kalleren en sesjon, vinner sesjonen og
-- payloaden ignoreres. Parameteren finnes bare fordi e-postinntaket
-- kjoerer med tjenestenoekkelen, der `gjeldende_retailer_id()` er NULL.
--
-- STASJONEN SJEKKES FOR SEG. `maanedsplan_ny` (0202) kontrollerer
-- `retailer_id`, ikke `stasjon_id` - en rad med min kjede og en annen
-- kjedes stasjon ville sluppet forbi policyen.
--
-- Idempotent: `create or replace`, `drop ... if exists`.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1  `linjer_lest` TILBAKE I VIEWET
--
-- `security_invoker = true` staar med, som alltid: `create or replace
-- view` uten klausulen nullstiller flagget i stillhet, og da leser
-- viewet som eier - forbi RLS. Punkt 9 i vakthunden kaster paa det.
-- Kolonnen legges BAKERST; `create or replace` godtar ikke annet.
-- ---------------------------------------------------------------------
create or replace view public.v_kurs_maanedstall
with (security_invoker = true) as
with linjer as (
  select
    l.retailer_id,
    l.stasjon_id,
    date_trunc('month', l.periode)::date as maaned,
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as omsetning_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'omsetning'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as omsetning_budsjett_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'bruttofortjeneste'
        and l.kode is not null
        and l.kode not in ('10', '250', '40')
        and l.kode not like '250%'
    ) as brutto_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'omsetning' and l.kode like '12%'
    ) as matsalg_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
        'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
        'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
        'andre_personalkostnader'
      ])
    ) as personal_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'faste_lonninger', 'lonnstillegg', 'timelonn', 'sykelonn',
        'refundert_sykelonn', 'palopte_feriepenger', 'bonus',
        'arbeidsgiveravgift_lonn', 'arbeidsgiveravgift_feriepenger',
        'andre_personalkostnader'
      ])
    ) as personal_budsjett_kr,
    sum(l.regnskap) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
        'utstyr_verktoy', 'forbruksmateriell', 'rep_vedlikehold',
        'pengehandtering', 'kontorrekvisita', 'kassedifferanse'
      ])
    ) as paavirkbar_drift_kr,
    sum(l.budsjett) filter (
      where l.seksjon = 'driftskostnader' and l.begrep = any (array[
        'renhold', 'renhold_og_renovasjon', 'renovasjon', 'broyting',
        'utstyr_verktoy', 'forbruksmateriell', 'rep_vedlikehold',
        'pengehandtering', 'kontorrekvisita', 'kassedifferanse'
      ])
    ) as paavirkbar_drift_kr_budsjett,
    sum(l.regnskap) filter (where l.seksjon = 'resultat') as resultat_kr,

    -- HAR MAANEDEN REGNSKAPSRADER I DET HELE TATT?
    --
    -- `0206` beregnet denne og eksponerte den aldri; `0213`-`0215`
    -- redefinerte viewet og den forsvant helt. Den er tilbake fordi
    -- «nyeste komplette datamaaned» maa kunne bevises paa DATADEKNING,
    -- ikke paa et beloep: `omsetning_kr > 0` blander en ekte nullmaaned
    -- med en maaned ingen har importert.
    --
    -- I dag er den alltid >= 1, siden raden bare finnes naar gruppen
    -- finnes. Blir joinen en gang gjort om til `full outer`, er
    -- eksistens ikke lenger nok - og da er denne fortsatt riktig.
    count(*)                                   as linjer_lest
  from public.regnskapslinjer l
  where l.stasjon_id is not null
    and l.slettet_tid is null
    and l.seksjon in (
      'omsetning', 'bruttofortjeneste', 'driftskostnader', 'resultat'
    )
  group by l.retailer_id, l.stasjon_id, date_trunc('month', l.periode)
),
svinn as (
  select
    s.retailer_id,
    s.stasjon_id,
    date_trunc('month', s.periode)::date as maaned,
    count(*)                                   as svinnrader,
    max(s.datastatus)                          as datastatus,
    count(*) filter (where s.kode like '12%')  as mat_rader,
    count(*) filter (where s.avviksstatus = 'avvik') as avvik_antall,
    -- INGEN COALESCE NAAR FILTERET IKKE TRAFF. `sum()` over null rader
    -- er NULL, og det er riktig svar: matgruppen ble ikke funnet.
    case when count(*) filter (where s.kode like '12%') = 0 then null
         else coalesce(sum(s.kast) filter (where s.kode like '12%'), 0)
    end                                        as matkast_kr,
    case when count(*) filter (where s.kode like '12%') = 0 then null
         else coalesce(sum(s.usynlig_kr) filter (where s.kode like '12%'), 0)
    end                                        as usynlig_mat_kr,
    -- `rest` beholder sin coalesce: filteret er en AVGRENSNING, og null
    -- rader betyr at det ikke er noe utenfor mat, vask og pant.
    coalesce(sum(s.usynlig_kr) filter (
      where s.kode is null
         or (s.kode not like '12%' and s.kode not like '21%' and s.kode not like '250%')
    ), 0)                                      as usynlig_rest_kr
  from public.v_svinn_grunnlag s
  where s.stasjon_id is not null
    and s.slettet_tid is null
  group by s.retailer_id, s.stasjon_id, date_trunc('month', s.periode)
)
select
  l.retailer_id,
  l.stasjon_id,
  l.maaned,
  coalesce(l.omsetning_kr, 0)                 as omsetning_kr,
  coalesce(l.omsetning_budsjett_kr, 0)        as omsetning_budsjett_kr,
  coalesce(l.brutto_kr, 0)                    as brutto_kr,
  coalesce(l.matsalg_kr, 0)                   as matsalg_kr,
  coalesce(l.personal_kr, 0)                  as personal_kr,
  coalesce(l.personal_budsjett_kr, 0)         as personal_budsjett_kr,
  coalesce(l.paavirkbar_drift_kr, 0)          as paavirkbar_drift_kr,
  coalesce(l.paavirkbar_drift_kr_budsjett, 0) as paavirkbar_drift_budsjett_kr,
  coalesce(l.resultat_kr, 0)                  as resultat_kr,
  s.matkast_kr,
  s.usynlig_rest_kr,
  (s.svinnrader is not null and s.svinnrader > 0) as har_svinndata,
  s.datastatus,
  s.usynlig_mat_kr,
  s.avvik_antall,
  s.mat_rader,
  l.linjer_lest
from linjer l
left join svinn s
  on  s.retailer_id = l.retailer_id
  and s.stasjon_id  = l.stasjon_id
  and s.maaned      = l.maaned;

grant select on public.v_kurs_maanedstall to authenticated;
revoke all on public.v_kurs_maanedstall from anon;

-- De to linjene over staar KLISTRET til definisjonen, uten en
-- kommentarblokk imellom.
--
-- `alter default privileges ... grant all on tables to anon` treffer
-- hvert nytt view, og `anon` er rollen bak den offentlige noekkelen i
-- hver sidelast - derfor maa de staa. Og `lesere.test.ts` leser dem med
-- et moenster som krever `;` etterfulgt av `grant`: en kommentar imellom
-- gjorde definisjonen usynlig for vakten. Den felte det paa foerste
-- kjoering, som den skal.

comment on view public.v_kurs_maanedstall is
  'Én rad per stasjon per maaned: grunnlaget Kursen maaler retning paa. '
  'REGNSKAPET AVGJOER OM MAANEDEN FINNES (0206). matkast_kr og '
  'usynlig_mat_kr er NULL naar matgruppen ikke har rader (0215). '
  'linjer_lest (0217) er antall regnskapslinjer bak raden - '
  'DATADEKNINGEN, som «nyeste komplette maaned» maa bevises paa. '
  'Et beloep er ikke en datastatus: omsetning 0 kan vaere en ekte '
  'nullmaaned.';

-- =====================================================================
-- 2  LAASEN
-- =====================================================================
-- To armer, og de er ulike med vilje.
--
-- AVVIST er absolutt: verken status, innhold, snapshot eller proveniens.
-- Eieren har tatt stilling, og hverken en ny import, en regenerering,
-- en PATCH over PostgREST eller annen applikasjonskode skal kunne gjoere
-- om paa det i stillhet.
--
-- SLUPPET/SENDT laaser INNHOLDET, men ikke status: `sluppet -> sendt`
-- maa fortsatt gaa den dagen utsendingen bygges. Laa
-- `new.status is distinct from old.status` i den armen, ville den
-- blokkert sin egen neste tilstand.
--
-- ---------------------------------------------------------------------
-- FELTENE `0216` ETTERLOT
--
-- Den gamle triggeren voktet `punkter`, `ingress` og `dom`. `0216` la
-- til `matkast`, `usynlig` og `rangering` og tok dem ikke inn i laasen -
-- saa snapshotet paa en SLUPPET plan kunne skrives om i stillhet.
--
-- Det er nettopp det snapshotet finnes for aa hindre: det som
-- godkjennes, lagres og sendes skal vaere samme oeyeblikksbilde. Og
-- `merknad` sto aldri der, selv om den er tekst eieren godkjenner.
--
-- `kilde_jobb_id` er med i avvist-armen: proveniensen paa en avgjort
-- plan er en del av avgjoerelsen.
-- ---------------------------------------------------------------------
create or replace function public.maanedsplan_laas_sluppet()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  innhold_endret boolean := (
       new.dom       is distinct from old.dom
    or new.ingress   is distinct from old.ingress
    or new.punkter   is distinct from old.punkter
    or new.merknad   is distinct from old.merknad
    or new.matkast   is distinct from old.matkast
    or new.usynlig   is distinct from old.usynlig
    or new.rangering is distinct from old.rangering
  );
begin
  -- AVVIST: ingenting. Heller ikke status, heller ikke proveniens.
  if old.status = 'avvist'
     and (innhold_endret
          or new.status is distinct from old.status
          or new.kilde_jobb_id is distinct from old.kilde_jobb_id) then
    raise exception
      'Maanedsplanen for % % er AVVIST. Innhold, snapshot, proveniens og '
      'status er laast. Gjenaapning er en egen, eksplisitt handling - '
      'ikke en update.',
      old.stasjon_id, to_char(old.maaned, 'YYYY-MM')
      using errcode = 'check_violation';
  end if;

  -- SLUPPET/SENDT: innholdet laast, status kan fortsatt gaa videre.
  if old.status in ('sluppet', 'sendt') and innhold_endret then
    raise exception
      'Maanedsplanen for % % er allerede %, og innholdet kan ikke endres. '
      'Sett status tilbake til utkast foerst hvis den skal skrives om.',
      old.stasjon_id, to_char(old.maaned, 'YYYY-MM'), old.status
      using errcode = 'check_violation';
  end if;

  new.oppdatert_tid := now();
  return new;
end $$;

drop trigger if exists maanedsplan_laas_sluppet_trg on public.maanedsplan;
create trigger maanedsplan_laas_sluppet_trg
  before update on public.maanedsplan
  for each row execute function public.maanedsplan_laas_sluppet();

-- =====================================================================
-- 3  DEN ATOMISKE SKRIVEREN
-- =====================================================================
-- `p_kilde_jobb_id` VALIDERES, den stoles ikke paa.
--
-- En `authenticated`-bruker kan kalle funksjonen direkte og sende en
-- hvilken som helst uuid. «Data, ikke politikk» gjoer den ikke trygg:
-- en forfalsket peker sender den som leser planen til feil fil.
--
-- Fire krav, og hele kallet feiler lukket hvis ett svikter - ingen plan
-- skrives:
--
--   finnes i import_jobber
--   tilhoerer effektiv kjede
--   rapporttype = 'regnskap_resultat'
--   gjelder_dato er satt OG i samme maaned som raden
--
-- GRENSEN FOR HVA DETTE BEVISER: `import_jobber_admin_ins` (0107) lar
-- en retailer_admin opprette jobber i SIN EGEN kjede - den retten
-- trenger «Behandle»-knappen. En bestemt eier kan derfor lage en jobb
-- som passer og peke planen paa den. Valideringen stopper uhell og alt
-- paa tvers av kjeder; den stopper ikke en eier som forfalsker sin egen
-- proveniens. Det staar her framfor aa bli oppdaget senere.
--
-- VED REGENERERING er `p_kilde_jobb_id` NULL. Da beholder en rad som
-- finnes fra foer sin egen peker, og en ny rad faar NULL. Ingen
-- kildejobb dikttes opp.
-- ---------------------------------------------------------------------
drop function if exists public.skriv_maanedsplan_utkast(jsonb, uuid, uuid);

create or replace function public.skriv_maanedsplan_utkast(
  p_rader         jsonb,
  p_retailer_id   uuid,
  p_kilde_jobb_id uuid
) returns table (
  stasjon_id       uuid,
  maaned           date,
  skrevet          boolean,
  status_ved_start text,
  tilhorer_kjeden  boolean
)
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
-- NAVNEKOLLISJONEN MELLOM OUT-PARAMETRE OG KOLONNER.
--
-- `returns table (stasjon_id, maaned, ...)` gjoer navnene til
-- PL/pgSQL-variabler. I `return query` er de da tvetydige mot
-- kolonnene med samme navn, og Postgres nekter - «column reference
-- stasjon_id is ambiguous».
--
-- `use_column` sier at kolonnen vinner. Vi TILDELER aldri til
-- out-parametrene her; hele svaret kommer fra `return query`, saa det
-- er trygt. Alternativet - aa doepe om parametrene - ville endret
-- kolonnenavnene kallerne leser.
#variable_conflict use_column
declare
  v_retailer uuid := coalesce((select public.gjeldende_retailer_id()), p_retailer_id);
  v_maaneder date[];
begin
  if v_retailer is null then
    raise exception 'Ingen kjede: verken sesjon eller p_retailer_id'
      using errcode = 'check_violation';
  end if;

  -- FEIL LUKKET, FOER NOEN RAD SKRIVES.
  if p_kilde_jobb_id is not null then
    select array_agg(distinct x.maaned) into v_maaneder
      from jsonb_to_recordset(p_rader) as x(maaned date);

    if not exists (
      select 1 from public.import_jobber j
       where j.id = p_kilde_jobb_id
         and j.retailer_id = v_retailer
         and j.rapporttype = 'regnskap_resultat'
         and j.gjelder_dato is not null
         and date_trunc('month', j.gjelder_dato)::date = all (v_maaneder)
    ) then
      raise exception
        'Ugyldig kildejobb %: den finnes ikke, hoerer til en annen kjede, '
        'har feil rapporttype, eller gjelder en annen maaned enn radene.',
        p_kilde_jobb_id
        using errcode = 'check_violation';
    end if;
  end if;

  return query
  with inn as (
    select * from jsonb_to_recordset(p_rader) as x(
      stasjon_id uuid, maaned date, dom text, ingress text,
      punkter jsonb, merknad text,
      matkast jsonb, usynlig jsonb, rangering jsonb)
  ),
  -- STATUS FOER, lest i samme snapshot som setningen starter i. Den kan
  -- vaere ETT COMMIT gammel i forhold til det `on conflict` faktisk saa
  -- etter radlaasen. Den er en FORKLARING; `skrevet` er autoriteten.
  foer as (
    select i.stasjon_id, i.maaned, m.status,
           exists (select 1 from public.stasjoner st
                    where st.id = i.stasjon_id
                      and st.retailer_id = v_retailer
                      and st.slettet_tid is null) as tilhorer
      from inn i
      left join public.maanedsplan m
        on m.stasjon_id = i.stasjon_id and m.maaned = i.maaned
  ),
  skrevet as (
    insert into public.maanedsplan (
      retailer_id, stasjon_id, maaned, dom, ingress, punkter, merknad,
      matkast, usynlig, rangering, status, kilde_jobb_id, oppdatert_tid)
    select v_retailer, i.stasjon_id, i.maaned, i.dom, i.ingress,
           i.punkter, i.merknad, i.matkast, i.usynlig, i.rangering,
           'utkast', p_kilde_jobb_id, now()
      from inn i
      join foer f on f.stasjon_id = i.stasjon_id and f.maaned = i.maaned
     where f.tilhorer
    on conflict (stasjon_id, maaned) do update
       set dom = excluded.dom,
           ingress = excluded.ingress,
           punkter = excluded.punkter,
           merknad = excluded.merknad,
           matkast = excluded.matkast,
           usynlig = excluded.usynlig,
           rangering = excluded.rangering,
           status = 'utkast',
           -- NULL betyr «behold». Regenereringen har ingen jobb aa vise
           -- til, og skulle ikke slette pekeren til fila tallene kom fra.
           kilde_jobb_id = coalesce(excluded.kilde_jobb_id,
                                    public.maanedsplan.kilde_jobb_id),
           oppdatert_tid = now()
     where public.maanedsplan.status not in ('sluppet', 'sendt', 'avvist')
    returning public.maanedsplan.stasjon_id, public.maanedsplan.maaned
  )
  select f.stasjon_id, f.maaned,
         exists (select 1 from skrevet s
                  where s.stasjon_id = f.stasjon_id and s.maaned = f.maaned),
         f.status,
         f.tilhorer
    from foer f;
end $$;

revoke execute on function public.skriv_maanedsplan_utkast(jsonb, uuid, uuid)
  from public, anon;
grant execute on function public.skriv_maanedsplan_utkast(jsonb, uuid, uuid)
  to authenticated, service_role;

comment on function public.skriv_maanedsplan_utkast(jsonb, uuid, uuid) is
  'Skriver maanedsplanutkast ATOMISK. Laasen - sluppet, sendt, avvist - '
  'ligger i on conflict do update ... where, saa en plan som avgjoeres '
  'mellom lesing og skriving staar uroert. Ingen klientstyrt '
  'laasepolitikk. Kjeden tas fra sesjonen naar det finnes én. '
  'p_kilde_jobb_id valideres mot import_jobber og feiler lukket.';

-- ---------------------------------------------------------------------
-- KVITTERING. Rent lesende.
-- ---------------------------------------------------------------------
select
  case
    when not exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'v_kurs_maanedstall'
         and column_name = 'linjer_lest')
      then 'FEIL: linjer_lest mangler i viewet'
    when not exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'skriv_maanedsplan_utkast')
      then 'FEIL: skriveren finnes ikke'
    when (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'skriv_maanedsplan_utkast')
      then 'FEIL: skriveren er security definer'
    when (select count(*) from pg_trigger
           where tgrelid = 'public.maanedsplan'::regclass
             and tgname = 'maanedsplan_laas_sluppet_trg'
             and not tgisinternal) <> 1
      then 'FEIL: laasetriggeren mangler'
    when not (select relrowsecurity from pg_class
               where oid = 'public.maanedsplan'::regclass)
      then 'FEIL: RLS er av'
    when has_function_privilege('anon',
           'public.skriv_maanedsplan_utkast(jsonb, uuid, uuid)', 'execute')
      then 'FEIL: anon kan kjoere skriveren'
    when not has_function_privilege('authenticated',
           'public.skriv_maanedsplan_utkast(jsonb, uuid, uuid)', 'execute')
      then 'FEIL: authenticated kan IKKE kjoere skriveren'
    else 'OK'
  end                                                          as dom,
  (select count(*) from public.maanedsplan)                    as planer,
  (select count(*) from public.maanedsplan where status = 'avvist') as avviste,
  (select count(*) from public.v_kurs_maanedstall)             as kursrader,
  (select count(*) from public.v_kurs_maanedstall
    where linjer_lest is null or linjer_lest < 1)              as uten_linjer,
  (select max(maaned) from public.v_kurs_maanedstall)          as siste_datamaaned,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'v_kurs_maanedstall') as viewkolonner,
  has_function_privilege('authenticated',
    'public.skriv_maanedsplan_utkast(jsonb, uuid, uuid)', 'execute')     as auth_kan,
  has_function_privilege('anon',
    'public.skriv_maanedsplan_utkast(jsonb, uuid, uuid)', 'execute')     as anon_kan;
