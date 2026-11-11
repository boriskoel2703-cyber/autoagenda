-- Auto-agenda 2026 — Supabase schema
-- Plak dit in Supabase: SQL Editor → New query → Run

create extension if not exists pgcrypto;

-- Aanvragen: één rij per aanvraag, met de dagdelen als JSON-lijst
-- items = [{"d":"2026-11-12","s":"ochtend","note":"naar werk"}, ...]
create table if not exists public.requests (
  id          uuid primary key default gen_random_uuid(),
  by_name     text not null check (by_name in ('Boris','Job','Mama')),
  items       jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) > 0),
  note        text not null default '' check (char_length(note) <= 300),
  cancelled   boolean not null default false,
  created_at  timestamptz not null default now()
);

-- Stemmen: per aanvraag één stem per persoon
create table if not exists public.votes (
  request_id  uuid not null references public.requests(id) on delete cascade,
  voter       text not null check (voter in ('Boris','Job','Mama')),
  vote        text not null check (vote in ('yes','no')),
  voted_at    timestamptz not null default now(),
  primary key (request_id, voter)
);

-- Je mag niet op je eigen aanvraag stemmen
create or replace function public.check_vote() returns trigger
language plpgsql as $$
begin
  if exists (select 1 from public.requests r where r.id = new.request_id and r.by_name = new.voter) then
    raise exception 'own_request';
  end if;
  new.voted_at := now();
  return new;
end $$;
drop trigger if exists trg_check_vote on public.votes;
create trigger trg_check_vote before insert or update on public.votes
  for each row execute function public.check_vote();

-- Geen dubbele boekingen: een dagdeel dat al aangevraagd/goedgekeurd is, kan niet nog eens
create or replace function public.check_slots() returns trigger
language plpgsql as $$
begin
  if exists (
    select 1
    from public.requests r,
         jsonb_array_elements(r.items) it,
         jsonb_array_elements(new.items) ni
    where r.id <> new.id
      and not r.cancelled
      and not exists (select 1 from public.votes v where v.request_id = r.id and v.vote = 'no')
      and it->>'d' = ni->>'d'
      and it->>'s' = ni->>'s'
  ) then
    raise exception 'slot_taken';
  end if;
  return new;
end $$;
drop trigger if exists trg_check_slots on public.requests;
create trigger trg_check_slots before insert on public.requests
  for each row execute function public.check_slots();

-- Toegang (RLS): de site gebruikt de publieke anon key, zonder echte login.
-- Iedereen met de link kan lezen, aanvragen, stemmen en intrekken. Verwijderen kan niet.
alter table public.requests enable row level security;
alter table public.votes    enable row level security;

drop policy if exists "lezen requests"   on public.requests;
drop policy if exists "aanvragen"        on public.requests;
drop policy if exists "intrekken"        on public.requests;
drop policy if exists "lezen votes"      on public.votes;
drop policy if exists "stemmen"          on public.votes;
drop policy if exists "stem wijzigen"    on public.votes;

create policy "lezen requests" on public.requests for select to anon using (true);
create policy "aanvragen"      on public.requests for insert to anon with check (cancelled = false);
create policy "intrekken"      on public.requests for update to anon using (true) with check (true);
create policy "lezen votes"    on public.votes    for select to anon using (true);
create policy "stemmen"        on public.votes    for insert to anon with check (true);
create policy "stem wijzigen"  on public.votes    for update to anon using (true) with check (true);

-- Alleen de kolom 'cancelled' mag worden aangepast
revoke update on public.requests from anon;
grant  update (cancelled) on public.requests to anon;
grant  select, insert on public.requests to anon;
grant  select, insert, update on public.votes to anon;

-- Live updates
do $$ begin
  alter publication supabase_realtime add table public.requests;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.votes;
exception when duplicate_object then null; end $$;
