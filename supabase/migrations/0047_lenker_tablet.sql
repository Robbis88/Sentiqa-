-- =====================================================================
-- Sentiqa - Lenker som tablet-funksjon (hurtiglenker for aa hjelpe kunder).
-- Alle i tenanten (ogsaa tablet) kan styre lenkene. Seeder to kundehjelp-
-- lenker (ikon = standard, kan endres paa tableten).
-- =====================================================================
drop policy if exists lenker_skriv on public.lenker;
create policy lenker_skriv on public.lenker for all to authenticated
  using (retailer_id = public.gjeldende_retailer_id())
  with check (retailer_id = public.gjeldende_retailer_id());

insert into public.lenker (retailer_id, tittel, url, sortering)
select r.id, x.tittel, x.url, x.sortering
from public.retailers r
cross join (values
  ('Oljeguide (Champion)', 'https://widik.com/champion/?flag=NO#oilfinder', 1),
  ('Vindusviskere (Bosch)', 'https://www.boschwiperblades.com/xc/en-gb/basic-page.html/-/en-gb/profile', 2)
) as x(tittel, url, sortering)
where r.slettet_tid is null
  and not exists (select 1 from public.lenker l where l.retailer_id = r.id and l.url = x.url);
