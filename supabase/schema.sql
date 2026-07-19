-- Reel Agent — Supabase schema for cloud sync
-- Run this once in your Supabase project's SQL editor (Dashboard → SQL Editor → New query).

-- ============================================================
-- 1. Draft metadata table (script, context, voice refinement,
--    segments — text/JSON only, one row per user, upserted on
--    every autosave)
-- ============================================================
create table if not exists reel_drafts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  script text,
  context text,
  voice jsonb,
  segments jsonb,
  updated_at timestamptz not null default now()
);

alter table reel_drafts enable row level security;

create policy "Users manage their own draft"
  on reel_drafts for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- 2. Exported videos table (one row per exported reel; the
--    actual file lives in Storage, this just indexes it)
-- ============================================================
create table if not exists reel_videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  size_bytes bigint,
  duration_sec numeric,
  created_at timestamptz not null default now()
);

alter table reel_videos enable row level security;

create policy "Users manage their own videos"
  on reel_videos for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- 3. Storage bucket for exported video files
--    Public bucket: anyone with the exact file URL can view it
--    (not listed/discoverable publicly), which keeps playback
--    simple. Uploads/deletes are still restricted to the owner
--    via the policies below.
-- ============================================================
insert into storage.buckets (id, name, public)
values ('reel-agent-files', 'reel-agent-files', true)
on conflict (id) do nothing;

create policy "Users upload to their own folder"
  on storage.objects for insert
  with check (
    bucket_id = 'reel-agent-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users read their own folder"
  on storage.objects for select
  using (
    bucket_id = 'reel-agent-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users delete their own folder"
  on storage.objects for delete
  using (
    bucket_id = 'reel-agent-files'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Note: because the bucket itself is marked public, anyone with a direct
-- file URL can fetch that specific file regardless of the SELECT policy
-- above (that policy only governs listing/reading via the API). This is
-- intentional and matches how the app generates shareable download links.
-- If you'd rather every reel be strictly private (no link-sharing), set
-- `public` to false above and switch the app to use signed URLs instead
-- of getPublicUrl() — ask if you want that variant.
