-- =====================================================================
-- Sentiqa - Kunnskapsbasen blir GLOBAL og redaktør-styrt. Kun plattform_redaktor
-- vedlikeholder den; alle kjeder leser den samme kuraterte basen (chatboten
-- svarer ut fra den). Hindrer at hver tenant fyller den med eget rot.
-- Eksisterende per-tenant-artikler gjøres globale (etter eier-valg).
-- =====================================================================

update public.kunnskap set retailer_id = null where retailer_id is not null;

-- Les: alle innloggede leser hele (global) basen.
drop policy if exists kunnskap_les on public.kunnskap;
create policy kunnskap_les on public.kunnskap for select to authenticated
  using (slettet_tid is null);

-- Skriv: KUN plattform-redaktør, og bare globale artikler (retailer_id null).
drop policy if exists kunnskap_skriv on public.kunnskap;
create policy kunnskap_skriv on public.kunnskap for all to authenticated
  using (public.gjeldende_rolle() = 'plattform_redaktor')
  with check (public.gjeldende_rolle() = 'plattform_redaktor' and retailer_id is null);
