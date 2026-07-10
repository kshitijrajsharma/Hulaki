-- FieldChat backend schema. Run once in the Supabase SQL editor.
-- The relay only ever stores ciphertext; content is unreadable without the
-- group key, which is shared out of band through the invite link.

create table if not exists public.envelopes (
  seq         bigint generated always as identity primary key,
  group_id    text        not null,
  message_id  text        not null,
  sender_id   text        not null,
  ciphertext  text        not null,
  created_at  timestamptz not null default now(),
  unique (group_id, message_id)
);

create index if not exists envelopes_group_seq_idx
  on public.envelopes (group_id, seq);

alter table public.envelopes enable row level security;

-- MVP posture: any signed-in device (anonymous auth) may read and append.
-- Access is not scoped per group at the database layer; confidentiality comes
-- from end-to-end encryption. Harden later with a membership check.
create policy envelopes_select on public.envelopes
  for select to authenticated using (true);

create policy envelopes_insert on public.envelopes
  for insert to authenticated with check (true);

-- Same open MVP posture: any signed-in device may delete, so an admin's
-- "Delete group" can purge the group's envelopes. Harden later alongside the
-- select and insert policies with a per-group membership check.
create policy envelopes_delete on public.envelopes
  for delete to authenticated using (true);

-- Realtime fan-out for subscribe().
alter publication supabase_realtime add table public.envelopes;

-- Encrypted media blobs, keyed by id.
insert into storage.buckets (id, name, public)
  values ('media', 'media', false)
  on conflict (id) do nothing;

create policy media_read on storage.objects
  for select to authenticated using (bucket_id = 'media');

create policy media_write on storage.objects
  for insert to authenticated with check (bucket_id = 'media');

-- Delete lets a client drop a blob when its message is deleted or its group is
-- purged, so removed media does not linger. Same open MVP posture as the other
-- policies: any signed-in device may delete, and confidentiality still rests on
-- end-to-end encryption, not on the store.
create policy media_delete on storage.objects
  for delete to authenticated using (bucket_id = 'media');

-- The public directory: groups their admins chose to make discoverable. This
-- holds plaintext metadata plus the group key, so anyone nearby can find and
-- join. Private groups never appear here. The geo index keeps proximity search
-- instant.
create table if not exists public.public_groups (
  group_id     text primary key,
  name         text not null,
  description  text,
  center_lat   double precision not null,
  center_lng   double precision not null,
  enc_key      text not null,
  photo        text,
  tags         jsonb not null default '[]'::jsonb,
  mapper_count integer not null default 0,
  aoi          text,
  updated_at   timestamptz not null default now()
);

-- Preview columns, applied idempotently so an existing directory gains them
-- without a rebuild. photo is a base64 JPEG icon; tags is the quick-tag list;
-- aoi is the drawn area as GeoJSON, shown as a minimap before joining.
alter table public.public_groups add column if not exists photo text;
alter table public.public_groups
  add column if not exists tags jsonb not null default '[]'::jsonb;
alter table public.public_groups
  add column if not exists mapper_count integer not null default 0;
alter table public.public_groups add column if not exists aoi text;
alter table public.public_groups
  add column if not exists join_approval boolean not null default false;

create index if not exists public_groups_geo_idx
  on public.public_groups (center_lat, center_lng);

-- Set mapper_count from the group's envelopes whenever a listing is written,
-- so the directory preview is correct on every publish and refresh instead of
-- trusting a client tally. sender_id is server-side plaintext, so counting
-- needs no decryption.
create or replace function public.set_mapper_count()
  returns trigger
  language plpgsql
as $$
begin
  new.mapper_count := (
    select count(distinct sender_id)
      from public.envelopes
     where group_id = new.group_id
  );
  return new;
end;
$$;

drop trigger if exists public_groups_mapper_count on public.public_groups;
create trigger public_groups_mapper_count
  before insert or update on public.public_groups
  for each row
  execute function public.set_mapper_count();

-- Backfill existing listings once, so current rows correct immediately.
update public.public_groups pg
   set mapper_count = counts.c
  from (
    select group_id, count(distinct sender_id) as c
      from public.envelopes
     group by group_id
  ) counts
 where counts.group_id = pg.group_id;

alter table public.public_groups enable row level security;

create policy public_groups_select on public.public_groups
  for select to authenticated using (true);

create policy public_groups_write on public.public_groups
  for all to authenticated using (true) with check (true);

-- Requests to join an approval-gated public group. The requester posts their
-- public keys; an admin approves by writing back the group key sealed to the
-- requester's X25519 key, so the key is never exposed to the server in the
-- clear. MVP posture matches the rest: any signed-in device may read and write.
create table if not exists public.join_requests (
  id             text primary key,
  group_id       text not null,
  requester_id   text not null,
  requester_name text,
  signing_key    text not null,
  agreement_key  text not null,
  sealed_key     text,
  created_at     timestamptz not null default now(),
  unique (group_id, requester_id)
);

create index if not exists join_requests_group_idx
  on public.join_requests (group_id);

alter table public.join_requests enable row level security;

create policy join_requests_select on public.join_requests
  for select to authenticated using (true);

create policy join_requests_write on public.join_requests
  for all to authenticated using (true) with check (true);
