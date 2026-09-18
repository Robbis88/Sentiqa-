-- 1220 er varegruppen Wrap. Legg den bare til hos retailere som faktisk
-- har denne varegruppen i importerte salgsrader. Dette endrer ikke motoren;
-- det åpner den eksisterende produksjonsberegningen for riktig varegruppe.
-- Oppslaget er en eksistenskontroll, ikke en summering av salg.
insert into public.retailer_koderegel (retailer_id, rolle, nivaa, kode, navn)
select distinct d.retailer_id, 'produksjon', 'varegruppe', '1220', 'Wrap'
from public.daglig_salg d
where d.slettet_tid is null
  and d.varegruppe_kode = '1220'
  and not exists (
    select 1 from public.retailer_koderegel x
    where x.retailer_id = d.retailer_id
      and x.rolle = 'produksjon'
      and x.nivaa = 'varegruppe'
      and x.kode = '1220'
  );
