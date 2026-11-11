-- Auto-agenda — pushmeldingen
-- Draai dit NA schema.sql, en pas NADAT de site op Vercel staat.
-- Vul onderaan je Vercel-URL en NOTIFY_SECRET in.

create extension if not exists pg_net;

-- Abonnementen per telefoon (alleen bereikbaar via de functies hieronder)
create table if not exists public.push_subscriptions (
  endpoint      text primary key,
  name          text not null check (name in ('Boris','Job','Mama')),
  subscription  jsonb not null,
  updated_at    timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;

create or replace function public.save_push_subscription(p_endpoint text, p_name text, p_sub jsonb)
returns void language sql security definer set search_path = public as $$
  insert into public.push_subscriptions (endpoint, name, subscription, updated_at)
  values (p_endpoint, p_name, p_sub, now())
  on conflict (endpoint) do update set name = excluded.name, subscription = excluded.subscription, updated_at = now();
$$;

create or replace function public.delete_push_subscription(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_subscriptions where endpoint = p_endpoint;
$$;

revoke all on function public.save_push_subscription(text,text,jsonb) from public;
revoke all on function public.delete_push_subscription(text) from public;
grant execute on function public.save_push_subscription(text,text,jsonb) to anon;
grant execute on function public.delete_push_subscription(text) to anon;

-- Instellingen (niet leesbaar voor de site)
create table if not exists public.app_config (
  id             int primary key default 1 check (id = 1),
  notify_url     text,
  notify_secret  text
);
alter table public.app_config enable row level security;

-- Trigger: stuur bij elke aanvraag / stem / intrekking een seintje naar Vercel
create or replace function public.notify_push() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  cfg public.app_config;
  payload jsonb;
begin
  select * into cfg from public.app_config where id = 1;
  if cfg.notify_url is null then return new; end if;

  if tg_table_name = 'requests' then
    if tg_op = 'INSERT' then
      payload := jsonb_build_object('kind','request','request_id',new.id);
    elsif new.cancelled and not old.cancelled then
      payload := jsonb_build_object('kind','cancel','request_id',new.id);
    else
      return new;
    end if;
  else
    if tg_op = 'UPDATE' and new.vote = old.vote then return new; end if;
    payload := jsonb_build_object('kind','vote','request_id',new.request_id,'voter',new.voter,'vote',new.vote);
  end if;

  perform net.http_post(
    url     := cfg.notify_url,
    body    := payload,
    headers := jsonb_build_object('Content-Type','application/json','x-notify-secret',cfg.notify_secret)
  );
  return new;
end $$;

drop trigger if exists trg_push_requests on public.requests;
create trigger trg_push_requests after insert or update of cancelled on public.requests
  for each row execute function public.notify_push();

drop trigger if exists trg_push_votes on public.votes;
create trigger trg_push_votes after insert or update on public.votes
  for each row execute function public.notify_push();

-- ▼▼ VUL IN ▼▼
insert into public.app_config (id, notify_url, notify_secret)
values (1, 'https://JOUW-SITE.vercel.app/api/notify', 'JOUW-NOTIFY-SECRET')
on conflict (id) do update set notify_url = excluded.notify_url, notify_secret = excluded.notify_secret;
