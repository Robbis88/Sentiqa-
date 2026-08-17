-- ---------------------------------------------------------------------
-- 0104: puls - koblingen beholdes, men ingen kan lese den
-- ---------------------------------------------------------------------
-- Nettbrettet sa «Kommentar (valgfri, anonym)», mens ansatt_id ble lagret
-- paa hvert svar - og lese-policyen fra 0026 lot enhver butikksjef hente
-- den kolonnen direkte via API-et. Skjermbildet viste den ikke.
-- Skjermbildet er ikke sikkerheten.
--
-- Systemet er ikke i drift enda, saa ingen har faatt noe lofte og det
-- finnes ingen svar. Da er dette en beslutning, ikke en opprydding.
--
-- VALGET: ikke lov anonymitet. Paa en stasjon med ti ansatte er en
-- fritekstkommentar ofte gjenkjennelig paa innholdet alene, uansett hva
-- basen gjor. Et lofte som ikke kan holdes teknisk, holdes ikke.
--
-- Men koblingen beholdes - uten den kan samme person svare mange ganger,
-- og tallene blir verdilose. Losningen er at ingen kan LESE den.

-- ---------------------------------------------------------------------
-- 1) Kolonnenivaa-lesetilgang: alt unntatt ansatt_id
-- ---------------------------------------------------------------------
-- Bygget fra katalogen framfor en fast liste: puls_svar har endret
-- kolonner flere ganger (dato droppet i 0044, runde-modellen i 0038), og
-- en hardkodet liste ville blitt feil ved neste endring.
do $$
declare
  kolonner text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
    into kolonner
    from information_schema.columns
   where table_schema = 'public'
     and table_name = 'puls_svar'
     and column_name <> 'ansatt_id';

  if kolonner is null then
    raise exception 'Fant ingen kolonner paa puls_svar.';
  end if;

  revoke select on public.puls_svar from authenticated;
  execute format('grant select (%s) on public.puls_svar to authenticated', kolonner);
end $$;

comment on column public.puls_svar.ansatt_id is
  'Hindrer dobbeltsvar. Ingen med authenticated-rolle kan LESE den (0104) '
  '- skriving gaar gjennom lagre_puls_svar().';

-- ---------------------------------------------------------------------
-- 2) Skriving gjennom funksjon
-- ---------------------------------------------------------------------
-- Appen upsertet med «on conflict (runde_id, ansatt_id)». Det er ikke
-- opplagt om konfliktmaalet krever leserett paa kolonnen naar den er
-- sperret, og et sporsmaal uten sikkert svar hoerer ikke hjemme i en
-- innsendingsvei som brukes fra nettbrettet.
--
-- security definer fjerner spoersmaalet: funksjonen eier skrivingen, og
-- appen trenger aldri aa se ansatt_id.
create or replace function public.lagre_puls_svar(
  p_runde     uuid,
  p_stasjon   uuid,
  p_ansatt    uuid,
  p_skala     int,
  p_kommentar text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_retailer uuid;
begin
  if p_skala is null or p_skala < 1 or p_skala > 5 then
    raise exception 'Skala maa vaere mellom 1 og 5.';
  end if;
  -- Samme kontroll som lese-policyen ville gjort: du kan bare svare for
  -- en stasjon du har tilgang til.
  if not exists (select 1 from public.mine_stasjoner() m where m = p_stasjon) then
    raise exception 'Ingen tilgang til stasjonen.';
  end if;

  select retailer_id into v_retailer from public.stasjoner where id = p_stasjon;

  if p_ansatt is null then
    -- Uten PIN finnes ingen aa avduplisere paa. Da blir det en ny rad.
    insert into public.puls_svar (runde_id, retailer_id, stasjon_id, ansatt_id, skala, kommentar)
    values (p_runde, v_retailer, p_stasjon, null, p_skala, p_kommentar);
  else
    insert into public.puls_svar (runde_id, retailer_id, stasjon_id, ansatt_id, skala, kommentar)
    values (p_runde, v_retailer, p_stasjon, p_ansatt, p_skala, p_kommentar)
    on conflict (runde_id, ansatt_id)
    do update set skala = excluded.skala, kommentar = excluded.kommentar;
  end if;
end;
$$;

comment on function public.lagre_puls_svar(uuid, uuid, uuid, int, text) is
  'Eneste vei inn for puls-svar. Finnes fordi ansatt_id ikke er lesbar '
  '(0104), og en upsert fra appen da ikke kan avduplisere selv.';

revoke all on function public.lagre_puls_svar(uuid, uuid, uuid, int, text) from public;
grant execute on function public.lagre_puls_svar(uuid, uuid, uuid, int, text) to authenticated;

-- ---------------------------------------------------------------------
-- 3) Insert/update direkte paa tabellen er ikke lenger noedvendig
-- ---------------------------------------------------------------------
-- Alt gaar gjennom funksjonen. Da skal ikke veien utenom staa aapen -
-- den ville latt noen skrive et svar med en annens ansatt_id.
revoke insert, update on public.puls_svar from authenticated;

drop policy if exists puls_insert on public.puls_svar;
drop policy if exists puls_update on public.puls_svar;
