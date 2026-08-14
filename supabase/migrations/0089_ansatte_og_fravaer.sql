-- ---------------------------------------------------------------------
-- 0089: stillingsprosent og fravaer
-- ---------------------------------------------------------------------
-- «Alle skal faa timene sine» krever at systemet vet hva folk har krav
-- paa. Det tallet finnes ikke i noen fil vi faar inn, og aa be
-- butikksjefen taste inn stillingsprosent for femten personer er aa be
-- om noe hun ikke kommer til aa gjore - hun planlegger paa hukommelse
-- nettopp fordi det aa hente tall er arbeid.
--
-- Derfor: systemet anslaar fra 19 maaneder med stemplinger, og hun
-- retter det som er feil. stillingsprosent er null saa lenge ingen har
-- tatt stilling, og da brukes anslaget. Et lagret tall betyr «et
-- menneske har sagt at dette er riktig», og det skal aldri overskrives
-- av en ny beregning.
create table if not exists public.ansatt_avtale (
  id               uuid primary key default gen_random_uuid(),
  stasjon_id       uuid not null references public.stasjoner(id) on delete cascade,
  -- Stemplingsnummeret fra easy@work. Stabil noekkel; navnet endrer seg.
  ansatt_nr        text not null,
  navn             text not null,
  stillingsprosent int,
  oppdatert_tid    timestamptz not null default now(),
  unique (stasjon_id, ansatt_nr),
  check (stillingsprosent is null or stillingsprosent between 1 and 150)
);

create index if not exists ansatt_avtale_stasjon_idx
  on public.ansatt_avtale (stasjon_id);

comment on table public.ansatt_avtale is
  'Kontraktsfestet stilling per ansatt. null = ikke bekreftet, bruk anslaget.';
comment on column public.ansatt_avtale.stillingsprosent is
  '100 = 37,5 t/uke. Satt av et menneske - overskriv aldri med et anslag.';

-- ---------------------------------------------------------------------
-- fravaer
-- ---------------------------------------------------------------------
-- Butikksjefens fem uker er den enkeltposten som flytter mest. Er han
-- borte, dekker ikke den faste vakten gulvet lenger, og timene maa
-- kjopes av rammen. Ferie SPARER ikke timer, den flytter dem fra
-- fastlonn til timelonn - og de maanedene trenger FLERE timer, ikke
-- like mange.
--
-- navn matcher bemanning_fast_vakt.navn: det er den koblingen motoren
-- bruker for aa vite hvem som ikke staar der.
create table if not exists public.bemanning_fravaer (
  id            uuid primary key default gen_random_uuid(),
  stasjon_id    uuid not null references public.stasjoner(id) on delete cascade,
  navn          text not null,
  fra_dato      date not null,
  til_dato      date not null,
  arsak         text,
  oppdatert_tid timestamptz not null default now(),
  check (til_dato >= fra_dato)
);

create index if not exists bemanning_fravaer_stasjon_idx
  on public.bemanning_fravaer (stasjon_id, fra_dato);

comment on table public.bemanning_fravaer is
  'Ferie og annet fravaer for faste vakter. navn matcher bemanning_fast_vakt.navn.';

-- ---------------------------------------------------------------------
-- RLS - samme monster som 0081/0087/0088
-- ---------------------------------------------------------------------
alter table public.ansatt_avtale      enable row level security;
alter table public.bemanning_fravaer  enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['ansatt_avtale', 'bemanning_fravaer']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_les', t);
    execute format('drop policy if exists %I on public.%I', t || '_ins', t);
    execute format('drop policy if exists %I on public.%I', t || '_upd', t);
    execute format('drop policy if exists %I on public.%I', t || '_del', t);

    -- Aldri "for all": USING i en for all-policy gjelder ogsaa SELECT,
    -- og permissive policyer OR-es sammen.
    execute format($f$
      create policy %I on public.%I for select to authenticated
        using (stasjon_id in (select public.mine_stasjoner()))
    $f$, t || '_les', t);

    execute format($f$
      create policy %I on public.%I for insert to authenticated
        with check (stasjon_id in (select public.mine_stasjoner())
                    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    $f$, t || '_ins', t);

    execute format($f$
      create policy %I on public.%I for update to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
        with check (stasjon_id in (select public.mine_stasjoner())
                    and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    $f$, t || '_upd', t);

    execute format($f$
      create policy %I on public.%I for delete to authenticated
        using (stasjon_id in (select public.mine_stasjoner())
               and (select public.gjeldende_rolle()) in ('retailer_admin', 'butikksjef'))
    $f$, t || '_del', t);

    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end $$;
