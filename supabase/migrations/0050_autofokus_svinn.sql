-- =====================================================================
-- Sentiqa - Butikksjef auto-fokus: kast (synlig svinn) pr produkt +
-- kategori/tittel/bot-flagg paa fokuspunkter (3 forbedre + 3 ros).
-- =====================================================================
alter table public.regnskap_usynlig_svinn add column if not exists kast numeric;

alter table public.fokuspunkter add column if not exists kategori text;
alter table public.fokuspunkter add column if not exists tittel text;
alter table public.fokuspunkter add column if not exists opprettet_av_bot boolean not null default false;
