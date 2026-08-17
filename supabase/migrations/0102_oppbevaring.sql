-- ---------------------------------------------------------------------
-- 0102: oppbevaringsfrist og sletting av persondata
-- ---------------------------------------------------------------------
-- Systemet har til naa aldri slettet noe. «Vi beholder alt for sikkerhets
-- skyld» er ikke et lovlig standpunkt - GDPR art. 5 (1) e krever at
-- personopplysninger ikke lagres lenger enn nodvendig.
--
-- Standard er 60 maaneder. Det er ikke et tall jeg fant paa: lonnsgrunnlag
-- er primaerdokumentasjon etter bokforingsloven § 13 og skal oppbevares i
-- fem aar. Kortere ville satt regnskapsplikten i konflikt med
-- slettepliktien. Lengre ma begrunnes.
--
-- Fristen regnes fra SISTE AKTIVITET, ikke fra da raden ble skrevet. En
-- kontrakt fra 2019 for en som fortsatt jobber her skal ikke slettes;
-- alt om en som sluttet i 2019 skal.

alter table public.retailers
  add column if not exists oppbevaring_maaneder int not null default 60;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'retailers_oppbevaring_sjekk'
  ) then
    alter table public.retailers
      add constraint retailers_oppbevaring_sjekk
      check (oppbevaring_maaneder between 12 and 240);
  end if;
end $$;

comment on column public.retailers.oppbevaring_maaneder is
  'Hvor lenge persondata beholdes etter siste aktivitet. 60 = fem aar, '
  'som folger bokforingslovens krav til lonnsgrunnlag.';

-- ---------------------------------------------------------------------
-- Hvor gammelt er sporet etter hver person?
-- ---------------------------------------------------------------------
-- Bygget som union, ikke som join fra ansatt_avtale: de fleste som
-- stempler har aldri faatt et ansattkort, og de er nettopp dem man
-- glemmer aa slette.
--
-- security_invoker: visningen skal ikke se mer enn den som spor. Etter
-- 0101 betyr det leder.
create or replace view public.v_persondata_alder
with (security_invoker = true) as
with kilder as (
  select stasjon_id, ansatt_nr, ansatt_navn as navn, max(dato) as sist
    from public.stempling
   group by stasjon_id, ansatt_nr, ansatt_navn
  union all
  select stasjon_id, ansatt_nr, navn, max(oppdatert_tid)::date
    from public.ansatt_avtale
   group by stasjon_id, ansatt_nr, navn
  union all
  select stasjon_id, ansatt_nr, ansatt_navn,
         max(coalesce(gjelder_fra, opprettet_tid::date))
    from public.ansatt_kontrakt
   group by stasjon_id, ansatt_nr, ansatt_navn
)
select stasjon_id,
       ansatt_nr,
       -- Nyeste navn vinner. Folk gifter seg; nummeret staar.
       (array_agg(navn order by sist desc))[1] as navn,
       max(sist)                              as sist_aktivitet
  from kilder
 group by stasjon_id, ansatt_nr;

comment on view public.v_persondata_alder is
  'Siste spor etter hver person per stasjon. Grunnlaget for aa vite hvem '
  'som har passert oppbevaringsfristen.';

grant select on public.v_persondata_alder to authenticated;

-- ---------------------------------------------------------------------
-- Slettingen selv
-- ---------------------------------------------------------------------
-- security definer, fordi den maa kunne slette signerte kontrakter -
-- policyen fra 0098 nekter det med vilje, saa en signatur ikke kan
-- fjernes i stillhet. Sletting etter oppbevaringsfrist er det ene
-- unntaket, og det gaar gjennom denne funksjonen alene.
--
-- Funksjonen kontrollerer selv det policyen ellers ville gjort: rolle,
-- stasjonstilgang, og at fristen faktisk har lopt ut. Er den ikke utlopt,
-- kastes det - ingen «slett likevel»-vei.
create or replace function public.slett_person(p_stasjon uuid, p_ansatt_nr text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_frist   int;
  v_sist    date;
  v_grense  date;
  v_navn    text;
  n_stempl  int;
  n_kontr   int;
  n_avtale  int;
begin
  if (select public.gjeldende_rolle()) <> 'retailer_admin' then
    raise exception 'Bare eier kan slette persondata.';
  end if;
  if not exists (select 1 from public.mine_stasjoner() m where m = p_stasjon) then
    raise exception 'Ingen tilgang til stasjonen.';
  end if;

  select r.oppbevaring_maaneder into v_frist
    from public.stasjoner s
    join public.retailers r on r.id = s.retailer_id
   where s.id = p_stasjon;
  if v_frist is null then
    raise exception 'Fant ingen oppbevaringsfrist for stasjonen.';
  end if;
  v_grense := current_date - make_interval(months => v_frist);

  -- Leses fra basetabellene, ikke fra visningen: visningen er
  -- security_invoker, og inne i en security definer-funksjon ville den
  -- lest med funksjonens rettigheter. Da kontrollerer den ingenting.
  select max(x.sist), (array_agg(x.navn order by x.sist desc))[1]
    into v_sist, v_navn
  from (
    select ansatt_navn as navn, max(dato) as sist from public.stempling
      where stasjon_id = p_stasjon and ansatt_nr = p_ansatt_nr group by ansatt_navn
    union all
    select navn, max(oppdatert_tid)::date from public.ansatt_avtale
      where stasjon_id = p_stasjon and ansatt_nr = p_ansatt_nr group by navn
    union all
    select ansatt_navn, max(coalesce(gjelder_fra, opprettet_tid::date))
      from public.ansatt_kontrakt
      where stasjon_id = p_stasjon and ansatt_nr = p_ansatt_nr group by ansatt_navn
  ) x;

  if v_sist is null then
    raise exception 'Fant ingen data for ansattnummer %.', p_ansatt_nr;
  end if;
  if v_sist > v_grense then
    raise exception
      'Siste aktivitet % er innenfor oppbevaringsfristen paa % maaneder (grense %).',
      v_sist, v_frist, v_grense;
  end if;

  delete from public.ansatt_kontrakt
   where stasjon_id = p_stasjon and ansatt_nr = p_ansatt_nr;
  get diagnostics n_kontr = row_count;

  delete from public.stempling
   where stasjon_id = p_stasjon and ansatt_nr = p_ansatt_nr;
  get diagnostics n_stempl = row_count;

  delete from public.ansatt_avtale
   where stasjon_id = p_stasjon and ansatt_nr = p_ansatt_nr;
  get diagnostics n_avtale = row_count;

  return jsonb_build_object(
    'navn', v_navn,
    'sist_aktivitet', v_sist,
    'kontrakter', n_kontr,
    'stemplinger', n_stempl,
    'ansattkort', n_avtale
  );
end;
$$;

comment on function public.slett_person(uuid, text) is
  'Sletter alt som er noklet paa (stasjon, ansatt_nr) naar '
  'oppbevaringsfristen har lopt ut. Kaster hvis den ikke har det. '
  'Data noklet paa navn eller ansatte.id maa ryddes for seg - se '
  '/personvern.';

revoke all on function public.slett_person(uuid, text) from public;
grant execute on function public.slett_person(uuid, text) to authenticated;
