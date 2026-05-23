-- Levla — Supabase schema
-- Run in the Supabase SQL editor against a fresh project, top to bottom.
-- All tables are owner-scoped via RLS (row-level security).

-- ============================================================================
-- 1. PROFILES
-- ============================================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  streak_days int not null default 0,
  fridge_score int not null default 8,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- Auto-create a profile row when a user signs up
create or replace function public.handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
    values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
    on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- 2. FOOD ITEMS (the fridge)
-- ============================================================================
create table if not exists public.food_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  food_key text not null,
  category text not null check (category in ('Dairy','Vegetables','Meat','Pantry','Drinks','Freezer')),
  qty text not null default '1',
  days_left int not null default 7,
  confidence text not null default 'high' check (confidence in ('high','med')),
  added_at timestamptz not null default now(),
  source text not null default 'manual' check (source in ('scan','receipt','voice','manual')),
  is_low boolean not null default false
);

create index if not exists food_items_user_idx on public.food_items(user_id);
create index if not exists food_items_added_idx on public.food_items(user_id, added_at desc);

alter table public.food_items enable row level security;

drop policy if exists "food_items_select_own" on public.food_items;
create policy "food_items_select_own" on public.food_items for select using (auth.uid() = user_id);

drop policy if exists "food_items_insert_own" on public.food_items;
create policy "food_items_insert_own" on public.food_items for insert with check (auth.uid() = user_id);

drop policy if exists "food_items_update_own" on public.food_items;
create policy "food_items_update_own" on public.food_items for update using (auth.uid() = user_id);

drop policy if exists "food_items_delete_own" on public.food_items;
create policy "food_items_delete_own" on public.food_items for delete using (auth.uid() = user_id);

-- ============================================================================
-- 3. SHOPPING LIST
-- ============================================================================
create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  qty text not null default '1',
  section text not null default 'Other',
  auto boolean not null default false,
  for_recipe text,
  checked boolean not null default false,
  in_fridge boolean not null default false,
  added_by text,
  created_at timestamptz not null default now()
);

create index if not exists shopping_items_user_idx on public.shopping_items(user_id);

alter table public.shopping_items enable row level security;

drop policy if exists "shopping_select_own" on public.shopping_items;
create policy "shopping_select_own" on public.shopping_items for select using (auth.uid() = user_id);

drop policy if exists "shopping_insert_own" on public.shopping_items;
create policy "shopping_insert_own" on public.shopping_items for insert with check (auth.uid() = user_id);

drop policy if exists "shopping_update_own" on public.shopping_items;
create policy "shopping_update_own" on public.shopping_items for update using (auth.uid() = user_id);

drop policy if exists "shopping_delete_own" on public.shopping_items;
create policy "shopping_delete_own" on public.shopping_items for delete using (auth.uid() = user_id);

-- ============================================================================
-- 4. RECIPE FAVOURITES (optional — for Cook deck "save")
-- ============================================================================
create table if not exists public.recipe_favourites (
  user_id uuid not null references auth.users(id) on delete cascade,
  recipe_slug text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, recipe_slug)
);

alter table public.recipe_favourites enable row level security;

drop policy if exists "fav_select_own" on public.recipe_favourites;
create policy "fav_select_own" on public.recipe_favourites for select using (auth.uid() = user_id);

drop policy if exists "fav_insert_own" on public.recipe_favourites;
create policy "fav_insert_own" on public.recipe_favourites for insert with check (auth.uid() = user_id);

drop policy if exists "fav_delete_own" on public.recipe_favourites;
create policy "fav_delete_own" on public.recipe_favourites for delete using (auth.uid() = user_id);
