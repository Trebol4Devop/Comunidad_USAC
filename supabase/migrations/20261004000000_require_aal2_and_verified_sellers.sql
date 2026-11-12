-- Require MFA assurance level 2 for authenticated writes and keep seller
-- verification server-authoritative. A user-provided carnet is never proof.

alter table public.profiles
  add column if not exists seller_verification_status text not null default 'unverified',
  add column if not exists seller_verified_at timestamptz,
  add column if not exists seller_verified_by uuid references auth.users(id) on delete set null;

alter table public.marketplace_items
  add column if not exists sponsor_brand_name text;

alter table public.profiles
  drop constraint if exists profiles_seller_verification_status_check;
alter table public.profiles
  add constraint profiles_seller_verification_status_check
  check (seller_verification_status in ('unverified', 'pending', 'verified', 'rejected'));

create or replace function public.guard_seller_verification_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.seller_verification_status is distinct from old.seller_verification_status
      or new.seller_verified_at is distinct from old.seller_verified_at
      or new.seller_verified_by is distinct from old.seller_verified_by)
     and auth.role() is distinct from 'service_role'
     and current_user not in ('postgres', 'supabase_admin')
     and not (
       public.is_pemtree_admin(auth.uid())
       or public.is_pemtree_moderator(auth.uid())
     ) then
    raise exception 'Seller verification can only be changed by authorized staff.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_seller_verification_fields on public.profiles;
create trigger guard_seller_verification_fields
before update on public.profiles
for each row execute function public.guard_seller_verification_fields();

create policy "Staff can review seller verification"
  on public.profiles
  for update to authenticated
  using (public.is_pemtree_admin(auth.uid()) or public.is_pemtree_moderator(auth.uid()))
  with check (public.is_pemtree_admin(auth.uid()) or public.is_pemtree_moderator(auth.uid()));

-- A user may create a listing only after an authorized staff verification.
drop policy if exists "Authenticated users can insert own marketplace items"
  on public.marketplace_items;
create policy "Verified sellers can insert own marketplace items"
  on public.marketplace_items
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.seller_verification_status = 'verified'
    )
  );

create or replace function public.guard_marketplace_privileged_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_staff boolean := public.is_pemtree_admin(auth.uid())
      or public.is_pemtree_moderator(auth.uid());
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and not v_staff then
      new.user_id := auth.uid();
      new.is_sponsored := false;
      new.sponsor_badge_text := null;
      new.sponsor_brand_name := null;
      new.moderation_status := 0;
      new.moderated_at := null;
      new.moderated_by := null;
    end if;
    return new;
  end if;

  if auth.uid() is not null
     and not v_staff
     and current_user not in ('postgres', 'supabase_admin')
     and (
    new.user_id is distinct from old.user_id
    or new.is_sponsored is distinct from old.is_sponsored
    or new.sponsor_badge_text is distinct from old.sponsor_badge_text
    or new.sponsor_brand_name is distinct from old.sponsor_brand_name
    or new.moderation_status is distinct from old.moderation_status
    or new.moderation_label is distinct from old.moderation_label
    or new.moderation_confidence is distinct from old.moderation_confidence
    or new.moderation_reason is distinct from old.moderation_reason
    or new.moderated_at is distinct from old.moderated_at
    or new.moderated_by is distinct from old.moderated_by
  ) then
    raise exception 'Only authorized staff may change sponsorship or moderation fields.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_marketplace_privileged_fields on public.marketplace_items;
create trigger guard_marketplace_privileged_fields
before insert or update on public.marketplace_items
for each row execute function public.guard_marketplace_privileged_fields();

-- Sponsor requests are private to their requester and staff; only staff can
-- approve, reject, or edit workflow state.
drop policy if exists "Anyone can insert sponsor requests"
  on public.sponsor_requests;
create policy "Authenticated users can submit pending sponsor requests"
  on public.sponsor_requests
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');
create policy "Requesters and admins can read sponsor requests"
  on public.sponsor_requests
  for select to authenticated
  using (user_id = auth.uid() or public.is_pemtree_admin(auth.uid()));
create policy "Only admins can review sponsor requests"
  on public.sponsor_requests
  for update to authenticated
  using (public.is_pemtree_admin(auth.uid()))
  with check (public.is_pemtree_admin(auth.uid()));

create or replace function public.guard_sponsor_request_workflow()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null and auth.role() <> 'service_role' then
      new.user_id := auth.uid();
      new.status := 'pending';
    end if;
    return new;
  end if;

  if auth.uid() is not null
     and auth.role() is distinct from 'service_role'
     and not public.is_pemtree_admin(auth.uid())
     and (new.status is distinct from old.status or new.user_id is distinct from old.user_id) then
    raise exception 'Only admins may review sponsor requests.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists guard_sponsor_request_workflow on public.sponsor_requests;
create trigger guard_sponsor_request_workflow
before insert or update on public.sponsor_requests
for each row execute function public.guard_sponsor_request_workflow();

-- RLS is the server-side boundary; the Flutter TOTP guard alone is insufficient.
do $$
declare
  v_table record;
  v_name text;
  v_aal_check text := '(auth.jwt() ->> ''aal'' = ''aal2'' and coalesce(auth.jwt() ->> ''is_anonymous'', ''false'') <> ''true'')';
begin
  for v_table in
    select n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and c.relrowsecurity
  loop
    v_name := 'require_aal2_insert';
    execute format('drop policy if exists %I on %I.%I', v_name, v_table.nspname, v_table.relname);
    execute format(
      'create policy %I on %I.%I as restrictive for insert to authenticated with check (%s)',
      v_name, v_table.nspname, v_table.relname, v_aal_check
    );

    v_name := 'require_aal2_update';
    execute format('drop policy if exists %I on %I.%I', v_name, v_table.nspname, v_table.relname);
    execute format(
      'create policy %I on %I.%I as restrictive for update to authenticated using (%s) with check (%s)',
      v_name, v_table.nspname, v_table.relname, v_aal_check, v_aal_check
    );

    v_name := 'require_aal2_delete';
    execute format('drop policy if exists %I on %I.%I', v_name, v_table.nspname, v_table.relname);
    execute format(
      'create policy %I on %I.%I as restrictive for delete to authenticated using (%s)',
      v_name, v_table.nspname, v_table.relname, v_aal_check
    );
  end loop;
end;
$$;

-- Also guard writes performed by SECURITY DEFINER routines, which bypass RLS.
create or replace function public.require_aal2_for_authenticated_write()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is not null
     and auth.role() is distinct from 'service_role'
     and (
       coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
       or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2'
     ) then
    raise exception 'AAL2 authentication is required to write.'
      using errcode = '42501';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

do $$
declare
  v_table record;
begin
  for v_table in
    select n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and c.relrowsecurity
  loop
    execute format(
      'drop trigger if exists trg_require_aal2_writes on %I.%I',
      v_table.nspname, v_table.relname
    );
    execute format(
      'create trigger trg_require_aal2_writes before insert or update or delete on %I.%I for each row execute function public.require_aal2_for_authenticated_write()',
      v_table.nspname, v_table.relname
    );
  end loop;
end;
$$;

-- SECURITY DEFINER RPCs also check AAL2 explicitly for clear errors.
create or replace function public.moderate_marketplace_item (
  target_item_id uuid,
  new_status integer,
  p_label text default null,
  p_confidence double precision default null,
  p_reason text default null
) returns boolean
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_user_role text;
begin
  if v_user_id is null
     or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'AAL2 authentication is required to moderate content.'
      using errcode = '42501';
  end if;

  select role into v_user_role
  from public.user_roles
  where user_id = v_user_id;
  if coalesce(v_user_role, '') not in ('admin', 'moderator') then
    return false;
  end if;

  update public.marketplace_items
  set moderation_status = new_status,
      moderation_label = coalesce(p_label, moderation_label),
      moderation_confidence = coalesce(p_confidence, moderation_confidence),
      moderation_reason = coalesce(nullif(trim(p_reason), ''), moderation_reason),
      moderated_at = now(),
      moderated_by = v_user_id
  where id = target_item_id;
  if not found then return false; end if;

  insert into public.moderation_audit_log (
    moderator_id, entity_table, entity_id, justification,
    is_automated, moderation_label, confidence
  ) values (
    v_user_id, 'marketplace_items', target_item_id,
    coalesce(nullif(trim(p_reason), ''), 'Moderación manual de publicación de marketplace'),
    false, p_label, p_confidence
  );
  return true;
end;
$$;

create or replace function public.report_forum_comment(
  p_comment_id uuid,
  p_reason text,
  p_details text default null
) returns boolean
language plpgsql security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null
     or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'AAL2 authentication is required to report content.'
      using errcode = '42501';
  end if;
  insert into public.entity_reports (reporter_id, entity_type, entity_id, reason, details)
  values (auth.uid(), 'comment', p_comment_id, p_reason, p_details)
  on conflict (reporter_id, entity_type, entity_id) do nothing;
  return true;
end;
$$;

create or replace function public.report_forum_post(
  p_post_id uuid,
  p_reason text,
  p_details text default null
) returns boolean
language plpgsql security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null
     or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'AAL2 authentication is required to report content.'
      using errcode = '42501';
  end if;
  insert into public.entity_reports (reporter_id, entity_type, entity_id, reason, details)
  values (auth.uid(), 'post', p_post_id, p_reason, p_details)
  on conflict (reporter_id, entity_type, entity_id) do nothing;
  return true;
end;
$$;

create or replace function public.report_marketplace_item(
  target_item_id uuid,
  report_reason text,
  target_seller_id uuid default null,
  target_seller_alias text default null
) returns boolean
language plpgsql security definer
set search_path to 'public'
as $$
declare
  v_count int;
begin
  if auth.uid() is null
     or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    raise exception 'AAL2 authentication is required to report content.'
      using errcode = '42501';
  end if;

  insert into public.entity_reports (
    reporter_id, entity_type, entity_id, entity_owner_id, reason, metadata
  ) values (
    auth.uid(), 'marketplace_item', target_item_id,
    case when target_seller_id is not null and public.user_exists(target_seller_id)
      then target_seller_id else null end,
    report_reason,
    jsonb_strip_nulls(jsonb_build_object('seller_alias', target_seller_alias))
  )
  on conflict (reporter_id, entity_type, entity_id) do nothing;

  select reported_count into v_count
  from public.marketplace_items
  where id = target_item_id;
  if v_count >= 3 then
    update public.marketplace_items
    set moderation_status = 2
    where id = target_item_id;
  end if;
  return true;
exception when others then
  if sqlstate = '42501' then raise; end if;
  return false;
end;
$$;
