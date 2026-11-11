


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "_triggers";


ALTER SCHEMA "_triggers" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "_triggers"."crear_notificacion_foro"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_actor_alias" "text", "p_post_id" "uuid", "p_comment_id" "uuid", "p_actor_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_id     uuid;
    v_secret text;
    v_url    text := 'https://hfvsstkfqszpjrsrwhql.supabase.co/functions/v1/send-push';
    v_pref   record;
    v_subs   bigint;
begin
    if p_user_id is null or p_user_id = p_actor_id then
        return;
    end if;

    select comment_enabled, reply_enabled, like_enabled, new_post_enabled
      into v_pref
      from public.notification_preferences
     where user_id = p_user_id;

    if v_pref is not null then
        if p_type = 'comment'  and not v_pref.comment_enabled  then return; end if;
        if p_type = 'reply'    and not v_pref.reply_enabled    then return; end if;
        if p_type = 'like'     and not v_pref.like_enabled     then return; end if;
        if p_type = 'new_post' and not v_pref.new_post_enabled then return; end if;
    end if;

    insert into public.user_notifications
        (user_id, type, title, body, actor_alias, post_id, comment_id)
    values
        (p_user_id, p_type, p_title, p_body, p_actor_alias, p_post_id, p_comment_id)
    returning id into v_id;

    delete from public.user_notifications
     where user_id = p_user_id
       and id not in (
           select id
             from public.user_notifications
            where user_id = p_user_id
            order by created_at desc
            limit 20
       );

    select count(*) into v_subs
      from public.notification_subscriptions
     where user_id = p_user_id;

    if v_subs > 0 then
        select decrypted_secret into v_secret
          from vault.decrypted_secrets
         where name = 'push_edge_secret';

        if v_secret is not null then
            perform net.http_post(
                url     := v_url,
                body    := jsonb_build_object('notification_id', v_id),
                headers := jsonb_build_object(
                    'Content-Type',    'application/json',
                    'x-pemtree-secret', v_secret
                ),
                timeout_milliseconds := 5000
            );
        end if;
    end if;
end;
$$;


ALTER FUNCTION "_triggers"."crear_notificacion_foro"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_actor_alias" "text", "p_post_id" "uuid", "p_comment_id" "uuid", "p_actor_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."notify_comment_inserted"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_post  record;
    v_recip uuid;
begin
    select user_id, title
      into v_post
      from public.posts
     where id = NEW.post_id;

    if v_post is null or v_post.user_id is null then
        return null;
    end if;

    if NEW.parent_id is not null then
        select user_id into v_recip
          from public.comments
         where id = NEW.parent_id;
        if v_recip is null then
            return null;
        end if;
        perform _triggers.crear_notificacion_foro(
            p_user_id     := v_recip,
            p_type        := 'reply',
            p_title       := left(coalesce(v_post.title, 'Te respondieron en el foro'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' respondió: ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.post_id,
            p_comment_id  := NEW.id,
            p_actor_id    := NEW.user_id
        );
    else
        perform _triggers.crear_notificacion_foro(
            p_user_id     := v_post.user_id,
            p_type        := 'comment',
            p_title       := left(coalesce(v_post.title, 'Nuevo comentario'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' comentó: ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.post_id,
            p_comment_id  := NEW.id,
            p_actor_id    := NEW.user_id
        );
    end if;

    return null;
end;
$$;


ALTER FUNCTION "_triggers"."notify_comment_inserted"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."notify_new_post"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    r record;
    v_carrera text := coalesce(NEW.carrera, 'todas');
begin
    for r in
        select np.user_id
          from public.notification_preferences np
         where np.new_post_enabled
           and exists (
               select 1
                 from public.notification_preference_carreras npc
                where npc.user_id = np.user_id
                  and npc.carrera_id in (v_carrera, 'todas')
           )
    loop
        perform _triggers.crear_notificacion_foro(
            p_user_id     := r.user_id,
            p_type        := 'new_post',
            p_title       := left(coalesce(NEW.title, 'Nueva publicación'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' · ' || v_carrera || ' · ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.id,
            p_comment_id  := null,
            p_actor_id    := NEW.user_id
        );
    end loop;

    return null;
end;
$$;


ALTER FUNCTION "_triggers"."notify_new_post"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."notify_post_liked"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_post record;
    v_alias text;
begin
    select user_id, title
      into v_post
      from public.posts
     where id = NEW.post_id;

    if v_post is null or v_post.user_id is null then
        return null;
    end if;

    select coalesce(
        (select author_alias from public.posts    where user_id = NEW.user_id order by created_at desc limit 1),
        (select author_alias from public.comments where user_id = NEW.user_id order by created_at desc limit 1),
        'Estudiante'
    ) into v_alias;

    perform _triggers.crear_notificacion_foro(
        p_user_id     := v_post.user_id,
        p_type        := 'like',
        p_title       := left(coalesce(v_post.title, 'Me gusta en tu publicación'), 60),
        p_body        := 'A ' || v_alias || ' le gustó tu publicación',
        p_actor_alias := v_alias,
        p_post_id     := NEW.post_id,
        p_comment_id  := null,
        p_actor_id    := NEW.user_id
    );

    return null;
end;
$$;


ALTER FUNCTION "_triggers"."notify_post_liked"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."set_created_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
    new.created_at := now();
    return new;
end $$;


ALTER FUNCTION "_triggers"."set_created_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "_triggers"."set_created_at"() IS 'Trigger BEFORE INSERT: fuerza NEW.created_at = now() (evita backdating por parte de clientes).';



CREATE OR REPLACE FUNCTION "_triggers"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
    new.updated_at := now();
    return new;
end $$;


ALTER FUNCTION "_triggers"."set_updated_at"() OWNER TO "postgres";


COMMENT ON FUNCTION "_triggers"."set_updated_at"() IS 'Trigger BEFORE UPDATE: setea NEW.updated_at = now().';



CREATE OR REPLACE FUNCTION "_triggers"."sync_entity_report_counters"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
    if tg_op = 'INSERT' then
        if new.entity_type = 'group' then
            update public.student_groups g
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'group' and er.entity_id = new.entity_id)
             where g.id = new.entity_id;
        elsif new.entity_type = 'marketplace_item' then
            update public.marketplace_items m
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'marketplace_item' and er.entity_id = new.entity_id)
             where m.id = new.entity_id;
        end if;
    elsif tg_op = 'DELETE' then
        if old.entity_type = 'group' then
            update public.student_groups g
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'group' and er.entity_id = old.entity_id)
             where g.id = old.entity_id;
        elsif old.entity_type = 'marketplace_item' then
            update public.marketplace_items m
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'marketplace_item' and er.entity_id = old.entity_id)
             where m.id = old.entity_id;
        end if;
    else
        if new.entity_type is distinct from old.entity_type
           or new.entity_id is distinct from old.entity_id then
            if old.entity_type = 'group' then
                update public.student_groups g
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'group' and er.entity_id = old.entity_id)
                 where g.id = old.entity_id;
            elsif old.entity_type = 'marketplace_item' then
                update public.marketplace_items m
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'marketplace_item' and er.entity_id = old.entity_id)
                 where m.id = old.entity_id;
            end if;
            if new.entity_type = 'group' then
                update public.student_groups g
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'group' and er.entity_id = new.entity_id)
                 where g.id = new.entity_id;
            elsif new.entity_type = 'marketplace_item' then
                update public.marketplace_items m
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'marketplace_item' and er.entity_id = new.entity_id)
                 where m.id = new.entity_id;
            end if;
        end if;
    end if;
    return null;
end $$;


ALTER FUNCTION "_triggers"."sync_entity_report_counters"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_group_reported_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.student_groups
        SET reported_count = (SELECT COUNT(*) FROM public.student_group_reports WHERE group_id = NEW.group_id)
        WHERE id = NEW.group_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.student_groups
        SET reported_count = (SELECT COUNT(*) FROM public.student_group_reports WHERE group_id = OLD.group_id)
        WHERE id = OLD.group_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.group_id <> OLD.group_id THEN
            UPDATE public.student_groups
            SET reported_count = (SELECT COUNT(*) FROM public.student_group_reports WHERE group_id = OLD.group_id)
            WHERE id = OLD.group_id;
            UPDATE public.student_groups
            SET reported_count = (SELECT COUNT(*) FROM public.student_group_reports WHERE group_id = NEW.group_id)
            WHERE id = NEW.group_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_group_reported_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_group_upvotes_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.student_groups
        SET upvotes = (SELECT COUNT(*) FROM public.student_group_upvotes WHERE group_id = NEW.group_id)
        WHERE id = NEW.group_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.student_groups
        SET upvotes = (SELECT COUNT(*) FROM public.student_group_upvotes WHERE group_id = OLD.group_id)
        WHERE id = OLD.group_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.group_id <> OLD.group_id THEN
            UPDATE public.student_groups
            SET upvotes = (SELECT COUNT(*) FROM public.student_group_upvotes WHERE group_id = OLD.group_id)
            WHERE id = OLD.group_id;
            UPDATE public.student_groups
            SET upvotes = (SELECT COUNT(*) FROM public.student_group_upvotes WHERE group_id = NEW.group_id)
            WHERE id = NEW.group_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_group_upvotes_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_marketplace_reported_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.marketplace_items
        SET reported_count = (SELECT COUNT(*) FROM public.marketplace_reports WHERE item_id = NEW.item_id)
        WHERE id = NEW.item_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.marketplace_items
        SET reported_count = (SELECT COUNT(*) FROM public.marketplace_reports WHERE item_id = OLD.item_id)
        WHERE id = OLD.item_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.item_id <> OLD.item_id THEN
            UPDATE public.marketplace_items
            SET reported_count = (SELECT COUNT(*) FROM public.marketplace_reports WHERE item_id = OLD.item_id)
            WHERE id = OLD.item_id;
            UPDATE public.marketplace_items
            SET reported_count = (SELECT COUNT(*) FROM public.marketplace_reports WHERE item_id = NEW.item_id)
            WHERE id = NEW.item_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_marketplace_reported_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_marketplace_upvotes_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.marketplace_items
        SET upvotes = (SELECT COUNT(*) FROM public.marketplace_upvotes WHERE item_id = NEW.item_id)
        WHERE id = NEW.item_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.marketplace_items
        SET upvotes = (SELECT COUNT(*) FROM public.marketplace_upvotes WHERE item_id = OLD.item_id)
        WHERE id = OLD.item_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.item_id <> OLD.item_id THEN
            UPDATE public.marketplace_items
            SET upvotes = (SELECT COUNT(*) FROM public.marketplace_upvotes WHERE item_id = OLD.item_id)
            WHERE id = OLD.item_id;
            UPDATE public.marketplace_items
            SET upvotes = (SELECT COUNT(*) FROM public.marketplace_upvotes WHERE item_id = NEW.item_id)
            WHERE id = NEW.item_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_marketplace_upvotes_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_poll_votes_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.post_poll_options
        SET votes_count = (SELECT COUNT(*) FROM public.post_poll_votes WHERE option_id = NEW.option_id)
        WHERE id = NEW.option_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.post_poll_options
        SET votes_count = (SELECT COUNT(*) FROM public.post_poll_votes WHERE option_id = OLD.option_id)
        WHERE id = OLD.option_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.option_id <> OLD.option_id THEN
            UPDATE public.post_poll_options
            SET votes_count = (SELECT COUNT(*) FROM public.post_poll_votes WHERE option_id = OLD.option_id)
            WHERE id = OLD.option_id;
            UPDATE public.post_poll_options
            SET votes_count = (SELECT COUNT(*) FROM public.post_poll_votes WHERE option_id = NEW.option_id)
            WHERE id = NEW.option_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_poll_votes_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_post_likes_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts
        SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id)
        WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts
        SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id)
        WHERE id = OLD.post_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.post_id <> OLD.post_id THEN
            UPDATE public.posts
            SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id)
            WHERE id = OLD.post_id;
            UPDATE public.posts
            SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id)
            WHERE id = NEW.post_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_post_likes_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "_triggers"."sync_reposts_counter"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.quoted_post_id IS NOT NULL THEN
        UPDATE public.posts
        SET reposts_count = (SELECT COUNT(*) FROM public.posts WHERE quoted_post_id = NEW.quoted_post_id)
        WHERE id = NEW.quoted_post_id;
    ELSIF TG_OP = 'DELETE' AND OLD.quoted_post_id IS NOT NULL THEN
        UPDATE public.posts
        SET reposts_count = (SELECT COUNT(*) FROM public.posts WHERE quoted_post_id = OLD.quoted_post_id)
        WHERE id = OLD.quoted_post_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.quoted_post_id IS DISTINCT FROM OLD.quoted_post_id THEN
            IF OLD.quoted_post_id IS NOT NULL THEN
                UPDATE public.posts
                SET reposts_count = (SELECT COUNT(*) FROM public.posts WHERE quoted_post_id = OLD.quoted_post_id)
                WHERE id = OLD.quoted_post_id;
            END IF;
            IF NEW.quoted_post_id IS NOT NULL THEN
                UPDATE public.posts
                SET reposts_count = (SELECT COUNT(*) FROM public.posts WHERE quoted_post_id = NEW.quoted_post_id)
                WHERE id = NEW.quoted_post_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION "_triggers"."sync_reposts_counter"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_cancelar_jobs_panel"("p_tabla" "text", "p_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_n integer;
begin
  update public.moderation_jobs
     set status     = 'done',
         locked_by  = null,
         updated_at = now(),
         last_error = coalesce(last_error, 'Cancelado por decisión manual del panel')
   where entity_table = p_tabla
     and entity_id = p_id
     and status in ('pending', 'processing');
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;


ALTER FUNCTION "public"."_cancelar_jobs_panel"("p_tabla" "text", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."after_comment_insert_author"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    INSERT INTO public.comment_authors (comment_id, user_id)
    VALUES (NEW.id, NEW.user_id)
    ON CONFLICT (comment_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."after_comment_insert_author"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."after_post_insert_author"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    INSERT INTO public.post_authors (post_id, user_id)
    VALUES (NEW.id, NEW.user_id)
    ON CONFLICT (post_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."after_post_insert_author"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_item jsonb;
  v_table text;
  v_id uuid;
  v_key uuid;
  v_label text;
  v_status integer;
  v_confidence double precision;
  v_reason text;
  v_job_id uuid;
  v_locked timestamptz;
  v_updated integer := 0;
begin
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_table      := v_item->>'table';
    v_id         := (v_item->>'id')::uuid;
    v_key        := nullif(v_item->>'key', '')::uuid;
    v_job_id     := nullif(v_item->>'job_id', '')::uuid;
    v_status     := coalesce(
                      nullif(v_item->>'status', '')::integer,
                      case v_item->>'label'
                        when 'appropriate' then 1
                        when 'inappropriate' then 2
                        else 3
                      end
                    );
    v_label      := coalesce(
                      nullif(v_item->>'label', ''),
                      case v_status when 1 then 'appropriate' when 2 then 'inappropriate' else 'error' end
                    );
    v_confidence := coalesce((v_item->>'confidence')::double precision, 0.0);
    v_reason     := coalesce(v_item->>'reason', '');

    v_locked := null;
    if v_job_id is not null then
      select j.locked_at into v_locked from public.moderation_jobs j where j.id = v_job_id;
    end if;

    if v_table = 'posts' then
      update public.posts set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where id = v_id
         and not exists (
           select 1 from public.moderation_audit_log a
            where a.entity_table = 'posts' and a.entity_id = v_id
              and a.is_automated = false and a.created_at > v_locked
         );

    elsif v_table = 'comments' then
      update public.comments set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where id = v_id
         and not exists (
           select 1 from public.moderation_audit_log a
            where a.entity_table = 'comments' and a.entity_id = v_id
              and a.is_automated = false and a.created_at > v_locked
         );

    elsif v_table = 'student_groups' then
      update public.student_groups set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where id = v_id
         and not exists (
           select 1 from public.moderation_audit_log a
            where a.entity_table = 'student_groups' and a.entity_id = v_id
              and a.is_automated = false and a.created_at > v_locked
         );

    elsif v_table = 'marketplace_items' then
      update public.marketplace_items set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where id = v_id
         and not exists (
           select 1 from public.moderation_audit_log a
            where a.entity_table = 'marketplace_items' and a.entity_id = v_id
              and a.is_automated = false and a.created_at > v_locked
         );

    elsif v_table = 'whatsapp_groups' then
      update public.whatsapp_groups set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where id = v_id;

    elsif v_table = 'user_reports' then
      update public.user_reports set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where id = v_id;

    elsif v_table = 'whatsapp_group_reports' then
      update public.whatsapp_group_reports set
        moderation_status = v_status,
        moderation_label = v_label,
        moderation_confidence = v_confidence,
        moderation_reason = v_reason,
        moderated_at = now(),
        moderated_by = null
       where group_id = v_id and user_id = v_key;

    else
      if v_job_id is not null then
        perform public.fail_moderation_job(v_job_id, 'Tabla desconocida: ' || coalesce(v_table, '(null)'));
      end if;
      continue;
    end if;

    if found then
      insert into public.moderation_audit_log(
        moderator_id, entity_table, entity_id, justification,
        is_automated, moderation_label, confidence
      ) values (
        null, v_table, v_id, v_reason, true, v_label, v_confidence
      );
      v_updated := v_updated + 1;
    end if;

    if v_job_id is not null then
      perform public.complete_moderation_job(v_job_id);
    end if;
  end loop;

  return v_updated;
end;
$$;


ALTER FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_content_moderation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog'
    AS $_$
            DECLARE
                new_row JSONB := to_jsonb(NEW);
                clean_text TEXT := '';
                compact_text TEXT;
                word TEXT;
                key TEXT;
                val TEXT;

                -- 1. Lista exhaustiva de groserías e insultos (Guatemaltequismos, Español e Inglés)
                forbidden_words TEXT[] := ARRAY[
                    -- Guatemaltequismos / Centroamérica
                    'cerote', 'cerota', 'cerotes', 'cerotas', 'mula', 'mulas', 'mulada', 'muladas',
                    'pisado', 'pisada', 'pisados', 'pisadas', 'shumo', 'shuma', 'marote', 'taliche',
                    'huevon', 'huevona', 'huevones', 'culero', 'culera', 'culeros', 'culo', 'culito',
                    'pija', 'pijas', 'pijazo', 'verga', 'vergas', 'vergazo', 'verguiza', 'cagada',
                    'cagadas', 'cagon', 'cagona', 'mierda', 'mierdas', 'mierdero', 'caca', 'cacas',
                    'malparido', 'malparida', 'hijueputa', 'hijueputas', 'hijo de puta', 'hp', 'hdp',
                    'ptm', 'alv', 'vtl',
                    -- General Español
                    'pendejo', 'pendeja', 'pendejos', 'pendejas', 'idiota', 'idiotas', 'estupido',
                    'estupida', 'estupidos', 'estupidas', 'imbecil', 'imbeciles', 'puta', 'putas',
                    'puto', 'putos', 'putazo', 'putazos', 'putero', 'cabron', 'cabrona', 'cabrones',
                    'chingar', 'chinga', 'chingada', 'chingadazo', 'pinche', 'pinches', 'gonorrea',
                    'mamahuevos', 'mamada', 'mamadas', 'tarado', 'tarada', 'tarados', 'zorete',
                    'zorra', 'zorras', 'perra', 'perras', 'asqueroso', 'asquerosa', 'puerco', 'puerca',
                    'mongol', 'mongoles', 'mongolito', 'mongolita', 'bastardo', 'bastarda', 'maricon',
                    'maricones', 'marica', 'maricas', 'joder', 'jodido', 'jodida', 'subnormal',
                    'subnormales', 'lacra', 'lacras', 'baboso', 'babosa', 'babosos', 'mamon', 'mamona',
                    -- Inglés
                    'fuck', 'fucker', 'fuckers', 'fucking', 'motherfucker', 'motherfuckers', 'fucktard',
                    'shit', 'shits', 'shitty', 'bullshit', 'dipshit', 'shithead', 'bitch', 'bitches',
                    'asshole', 'assholes', 'dumbass', 'jackass', 'bastard', 'bastards', 'scumbag',
                    'dick', 'dickhead', 'cock', 'cocksucker', 'pussy', 'pussies', 'cunt', 'cunts',
                    'twat', 'wanker', 'prick', 'whore', 'slut', 'sluts', 'douchebag', 'skank',
                    'retard', 'retarded', 'nigger', 'niggers', 'nigga', 'niggas', 'faggot', 'fags'
                ];

                -- 2. Lista exhaustiva de dominios, páginas de adultos, apuestas y malware
                forbidden_links TEXT[] := ARRAY[
                    -- Adultos / Pornografía
                    'porn', 'xxx', 'xvideos', 'pornhub', 'onlyfans', 'xhamster', 'redtube',
                    'brazzers', 'chaturbate', 'xnxx', 'eporner', 'youporn', 'spankbang', 'hentai',
                    'sex', 'nude', 'pack de', 'packs de', 'camgirls',
                    -- Apuestas / Casinos
                    'casino', 'bet365', '1xbet', 'poker', 'slots', 'apuestas', 'rushbet',
                    'codere', 'sportingbet', 'roulette', 'jackpot',
                    -- Acortadores peligrosos y redes de spam
                    'bit.ly', 'tinyurl.com', 't.co/', 'is.gd', 'cutt.ly', 'shorte.st', 'adf.ly',
                    'shrinkme', 'ow.ly', 'buff.ly', 'bl.ink',
                    -- Archivos sospechosos
                    '.exe', '.apk', '.bat', '.scr', '.vbs', '.msi', '.xyz', '.top', '.ru', '.tk', '.biz',
                    'trojan', 'keygen', 'phishing'
                ];
            BEGIN
                -- Extraer dinámicamente TODOS los campos de texto del registro,
                -- excluyendo campos internos/técnicos para evitar falsos positivos:
                --   - *_id        (UUIDs / identificadores)
                --   - id
                --   - image_url   (cadenas Base64 largas)
                --   - moderation_* (etiquetas/razones de moderación re-evaluadas)
                --   - *_at        (timestamps)
                FOR key, val IN SELECT k, v FROM jsonb_each_text(new_row) AS e(k, v)
                LOOP
                    IF key = 'id'
                       OR key LIKE '%\_id'
                       OR key = 'image_url'
                       OR key LIKE 'moderation\_%'
                       OR key = 'moderated_by'
                       OR key LIKE '%\_at'
                    THEN
                        CONTINUE;
                    END IF;
                    clean_text := clean_text || ' ' || COALESCE(val, '');
                END LOOP;

                clean_text := LOWER(clean_text);

                -- Traducción anti-evasión (Leetspeak y acentos)
                clean_text := TRANSLATE(clean_text, '013457@$!v', 'oieastasiu');
                clean_text := TRANSLATE(clean_text, 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN');

                -- Versión ultra-compacta para detectar palabras separadas por puntos, guiones o espacios (ej. c.e.r.o.t.e)
                compact_text := REGEXP_REPLACE(clean_text, '[\s\-\_\.\*\+\?\!|/()\[\]{}:,;~#%&^=]', '', 'g');

                -- Anti-Flooding: repeticiones consecutivas (>12 en campos de texto)
                IF compact_text ~* '(.)\1{12,}' THEN
                    RAISE EXCEPTION 'El mensaje contiene caracteres repetidos excesivamente. (Rechazado por moderación de Base de Datos)';
                END IF;

                -- Verificar groserías (únicamente con límite de palabra exacto \y para evitar que subcadenas como "computadora", "fórmula")
                FOREACH word IN ARRAY forbidden_words
                LOOP
                    IF clean_text ~* ('\y' || word || '\y') THEN
                        RAISE EXCEPTION 'El contenido contiene lenguaje inapropiado u ofensivo ("%"). (Rechazado por moderación de Base de Datos)', word;
                    END IF;
                END LOOP;

                -- Verificar enlaces o contenido prohibido (verificando extensión exacta para no alterar palabras normales)
                FOREACH word IN ARRAY forbidden_links
                LOOP
                    IF LEFT(word, 1) = '.' THEN
                        -- Es una extensión de dominio o archivo (ej. .ru, .exe, .apk), verificar que actúe como extensión al final de palabra
                        IF clean_text ~* ('\' || word || '(\/|\?|\y|$)') THEN
                            RAISE EXCEPTION 'El contenido incluye enlaces inapropiados o no autorizados ("%"). (Rechazado por moderación de Base de Datos)', word;
                        END IF;
                    ELSE
                        IF clean_text ~* ('\y' || word || '\y') OR clean_text ~* ('\.' || word || '\.') OR clean_text ~* ('\/' || word || '(\/|\?|\y|$)') THEN
                            RAISE EXCEPTION 'El contenido incluye enlaces inapropiados o no autorizados ("%"). (Rechazado por moderación de Base de Datos)', word;
                        END IF;
                    END IF;
                END LOOP;

                RETURN NEW;
            END;
            $_$;


ALTER FUNCTION "public"."check_content_moderation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_whatsapp_groups_limit"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_count integer;
    v_target_user uuid := COALESCE(auth.uid(), NEW.user_id);
BEGIN
    IF public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()) THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.student_groups
    WHERE user_id = v_target_user;

    IF v_count >= 5 THEN
        RAISE EXCEPTION 'Límite de 5 grupos alcanzado: Un usuario normal no puede publicar más de 5 grupos en la comunidad. Si necesitas publicar más, comunícate con un administrador o moderador.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."check_whatsapp_groups_limit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_moderation_job"("p_worker" "text") RETURNS TABLE("job_id" "uuid", "entity_table" "text", "entity_id" "uuid", "attempts" integer, "has_image" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare v_id uuid;
begin
  update public.moderation_jobs as mj
     set status     = case when mj.attempts >= mj.max_attempts then 'failed' else 'pending' end,
         last_error = coalesce(mj.last_error, 'Worker sin respuesta (job colgado)'),
         locked_by  = null,
         locked_at  = null,
         updated_at = now()
   where mj.status = 'processing'
     and mj.locked_at < now() - interval '10 minutes';

  select j.id into v_id
    from public.moderation_jobs j
   where j.status = 'pending' and j.run_after <= now()
   order by j.priority, j.created_at
   for update skip locked
   limit 1;

  if v_id is null then return; end if;

  update public.moderation_jobs as mj
     set status     = 'processing',
         locked_by  = p_worker,
         locked_at  = now(),
         attempts   = mj.attempts + 1,
         updated_at = now()
   where mj.id = v_id;

  return query
    select m.id, m.entity_table, m.entity_id, m.attempts, m.has_image
      from public.moderation_jobs m where m.id = v_id;
end;
$$;


ALTER FUNCTION "public"."claim_moderation_job"("p_worker" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_moderation_job"("p_job_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update public.moderation_jobs
     set status     = 'done',
         updated_at = now(),
         locked_by  = null,
         locked_at  = null
   where id = p_job_id;
end;
$$;


ALTER FUNCTION "public"."complete_moderation_job"("p_job_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_inappropriate_posts"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts
    WHERE moderation_status = 2;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN 'Se eliminaron ' || v_deleted || ' publicaciones no apropiadas.';
END;
$$;


ALTER FUNCTION "public"."delete_inappropriate_posts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_old_posts"("months_old" integer DEFAULT 3) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts
    WHERE created_at < NOW() - (months_old || ' months')::interval;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN 'Se eliminaron ' || v_deleted || ' publicaciones con más de ' || months_old || ' meses de antigüedad.';
END;
$$;


ALTER FUNCTION "public"."delete_old_posts"("months_old" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_owner_id uuid;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No estás autenticado en el sistema.';
    END IF;

    IF p_tabla = 'whatsapp_groups' THEN
        SELECT user_id INTO v_owner_id FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        SELECT user_id INTO v_owner_id FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        SELECT user_id INTO v_owner_id FROM public.comments WHERE id = p_item_id;
    ELSIF p_tabla = 'marketplace_items' THEN
        SELECT user_id INTO v_owner_id FROM public.marketplace_items WHERE id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El registro ya no existe o fue eliminado previamente en la base de datos.';
    END IF;

    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: Solo el administrador de PEMTREE puede eliminar contenido de forma definitiva. Si eres moderador o el autor, usa la acción de ocultar.';
    END IF;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, p_tabla, p_item_id,
            COALESCE(NULLIF(TRIM(p_justificacion), ''), 'Eliminación definitiva por administrador'),
            false, 'deleted');

    IF p_tabla = 'whatsapp_groups' THEN
        DELETE FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        DELETE FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        DELETE FROM public.comments WHERE id = p_item_id;
    ELSIF p_tabla = 'marketplace_items' THEN
        DELETE FROM public.marketplace_items WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enqueue_from_report"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_table text;
begin
  v_table := case new.entity_type
    when 'post' then 'posts'
    when 'comment' then 'comments'
    when 'group' then 'student_groups'
    when 'student_group' then 'student_groups'
    when 'marketplace_item' then 'marketplace_items'
    else null end;

  if v_table is null then return new; end if;

  if not exists (
    select 1 from public.moderation_jobs j
     where j.entity_table = v_table
       and j.entity_id = new.entity_id
       and j.status in ('pending','processing')
  ) then
    insert into public.moderation_jobs(entity_table, entity_id, content_hash, priority)
    values (v_table, new.entity_id, 'report:' || new.id::text, 10)
    on conflict (entity_table, entity_id, content_hash) do nothing;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."enqueue_from_report"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enqueue_moderation"("p_table" "text", "p_id" "uuid", "p_hash" "text", "p_priority" integer DEFAULT 100, "p_has_image" boolean DEFAULT false) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.moderation_jobs as j
    (entity_table, entity_id, content_hash, priority, has_image)
  values (p_table, p_id, p_hash, p_priority, p_has_image)
  on conflict (entity_table, entity_id, content_hash) do update
     set status    = 'pending',
         attempts  = 0,
         last_error = null,
         priority  = least(j.priority, excluded.priority),
         run_after = now(),
         updated_at = now()
   where j.status in ('done', 'failed');
end;
$$;


ALTER FUNCTION "public"."enqueue_moderation"("p_table" "text", "p_id" "uuid", "p_hash" "text", "p_priority" integer, "p_has_image" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fail_moderation_job"("p_job_id" "uuid", "p_error" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_attempts int;
  v_max int;
begin
  select attempts, max_attempts into v_attempts, v_max
    from public.moderation_jobs where id = p_job_id;

  if v_attempts is null then return; end if;

  if v_attempts >= v_max then
    update public.moderation_jobs
       set status     = 'failed',
           last_error = p_error,
           updated_at = now(),
           locked_by  = null,
           locked_at  = null
     where id = p_job_id;
  else
    update public.moderation_jobs
       set status     = 'pending',
           run_after  = now() + (interval '1 minute' * power(2, v_attempts)),
           last_error = p_error,
           updated_at = now(),
           locked_by  = null,
           locked_at  = null
     where id = p_job_id;
  end if;
end;
$$;


ALTER FUNCTION "public"."fail_moderation_job"("p_job_id" "uuid", "p_error" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."force_marketplace_item_owner"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  NEW.user_id := auth.uid();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."force_marketplace_item_owner"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_author_hash"("p_user_id" "uuid") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$                                                                                                                                
      SELECT public.generate_author_hash(p_user_id, 'USAC_COMMUNITY_ANON_SECRET_SALT_2026_KEY'::text);                                   
    $$;


ALTER FUNCTION "public"."generate_author_hash"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_author_hash"("p_user_id" "uuid", "p_salt" "text" DEFAULT 'USAC_COMMUNITY_ANON_SECRET_SALT_2026_KEY'::"text") RETURNS "text"
    LANGUAGE "plpgsql" IMMUTABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN encode(extensions.digest(p_user_id::text || ':' || p_salt, 'sha256'), 'hex');
END;
$$;


ALTER FUNCTION "public"."generate_author_hash"("p_user_id" "uuid", "p_salt" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_push_secrets"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_secret      text;
    v_public      text;
    v_private     text;
    v_subject     text;
begin
    select decrypted_secret into v_secret  from vault.decrypted_secrets where name = 'push_edge_secret';
    select decrypted_secret into v_public  from vault.decrypted_secrets where name = 'vapid_public_key';
    select decrypted_secret into v_private from vault.decrypted_secrets where name = 'vapid_private_key';
    select decrypted_secret into v_subject from vault.decrypted_secrets where name = 'vapid_subject';

    if v_secret is null or v_public is null or v_private is null or v_subject is null then
        raise exception 'Faltan secretos de push en el vault';
    end if;

    return jsonb_build_object(
        'edge_secret',   v_secret,
        'vapid_public',  v_public,
        'vapid_private', v_private,
        'vapid_subject', v_subject
    );
end;
$$;


ALTER FUNCTION "public"."get_push_secrets"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) RETURNS TABLE("user_id" "uuid", "email" "text", "full_name" "text", "avatar_url" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if not public.is_pemtree_admin() then
        raise exception 'Acceso denegado';
    end if;

    return query
        select u.id,
               u.email::text,
               u.raw_user_meta_data->>'full_name' as full_name,
               u.raw_user_meta_data->>'avatar_url' as avatar_url
        from auth.users u
        where u.id = any(p_user_ids);
end;
$$;


ALTER FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_comment_author_hash"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_uid uuid := coalesce(auth.uid(), NEW.user_id);
BEGIN
  IF v_uid IS NOT NULL THEN
    NEW.author_hash := public.generate_author_hash(v_uid);
    NEW.user_id := v_uid;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_comment_author_hash"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_post_author_hash"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_uid uuid := coalesce(auth.uid(), NEW.user_id);
BEGIN
  IF v_uid IS NOT NULL THEN
    NEW.author_hash := public.generate_author_hash(v_uid);
    NEW.user_id := v_uid;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_post_author_hash"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF p_user_id::text = '10884922-e583-409e-b3e8-8a875ddaa5d9' THEN
        RETURN true;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'admin') THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$;


ALTER FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF public.is_pemtree_admin(p_user_id) THEN
        RETURN true;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'moderator') THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$;


ALTER FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."legacy_marketplace_reports_iud"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
    if tg_op = 'INSERT' then
        insert into public.entity_reports
          (id, reporter_id, entity_type, entity_id, entity_owner_id, reason, created_at,
           moderation_status, metadata)
        values
          (coalesce(new.id, gen_random_uuid()),
           new.user_id,
           'marketplace_item',
           new.item_id,
           case when new.seller_user_id is not null and public.user_exists(new.seller_user_id)
                then new.seller_user_id else null end,
           new.reason,
           coalesce(new.created_at, now()),
           case lower(coalesce(new.status, 'pending'))
             when 'reviewed'  then 1
             when 'resolved'  then 1
             when 'in_review' then 1
             when 'dismissed' then 2
             when 'rejected'  then 2
             else 0
           end,
           jsonb_strip_nulls(jsonb_build_object(
             'seller_alias', new.seller_alias,
             'legacy_status', new.status)));
        return new;

    elsif tg_op = 'UPDATE' then
        update public.entity_reports set
          reporter_id = new.user_id,
          entity_id = new.item_id,
          entity_owner_id = case when new.seller_user_id is not null and public.user_exists(new.seller_user_id)
                                 then new.seller_user_id else null end,
          reason = new.reason,
          created_at = coalesce(new.created_at, created_at),
          moderation_status = case lower(coalesce(new.status, 'pending'))
             when 'reviewed'  then 1
             when 'resolved'  then 1
             when 'in_review' then 1
             when 'dismissed' then 2
             when 'rejected'  then 2
             else 0
           end,
          metadata = coalesce(metadata, '{}'::jsonb)
                     || jsonb_strip_nulls(jsonb_build_object(
                          'seller_alias', new.seller_alias,
                          'legacy_status', new.status))
        where id = old.id and entity_type = 'marketplace_item';
        return new;

    else
        delete from public.entity_reports where id = old.id and entity_type = 'marketplace_item';
        return old;
    end if;
end $$;


ALTER FUNCTION "public"."legacy_marketplace_reports_iud"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."legacy_student_group_reports_iud"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
    if tg_op = 'INSERT' then
        insert into public.entity_reports
          (reporter_id, entity_type, entity_id, reason, created_at,
           moderation_status, moderation_label, moderation_confidence, moderation_reason,
           moderated_at, moderated_by, metadata)
        values
          (new.user_id,
           'group',
           new.group_id,
           coalesce(new.reason, ''),
           coalesce(new.created_at, now()),
           coalesce(new.moderation_status, 0),
           new.moderation_label,
           new.moderation_confidence,
           new.moderation_reason,
           new.moderated_at,
           new.moderated_by,
           '{}'::jsonb);
        return new;

    elsif tg_op = 'UPDATE' then
        update public.entity_reports set
          reporter_id = new.user_id,
          entity_id = new.group_id,
          reason = new.reason,
          created_at = coalesce(new.created_at, created_at),
          moderation_status = new.moderation_status,
          moderation_label = new.moderation_label,
          moderation_confidence = new.moderation_confidence,
          moderation_reason = new.moderation_reason,
          moderated_at = new.moderated_at,
          moderated_by = new.moderated_by
        where entity_type = 'group'
          and entity_id = old.group_id
          and reporter_id = old.user_id;
        return new;

    else
        delete from public.entity_reports
         where entity_type = 'group'
           and entity_id = old.group_id
           and reporter_id = old.user_id;
        return old;
    end if;
end $$;


ALTER FUNCTION "public"."legacy_student_group_reports_iud"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."legacy_user_reports_iud"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
    if tg_op = 'INSERT' then
        insert into public.entity_reports
          (id, reporter_id, entity_type, entity_id, reported_user_id, reason, created_at,
           moderation_status, moderation_label, moderation_confidence, moderation_reason,
           moderated_at, moderated_by, metadata)
        values
          (coalesce(new.id, gen_random_uuid()),
           new.reporter_id,
           'user',
           new.reported_user_id,
           case when public.user_exists(new.reported_user_id) then new.reported_user_id else null end,
           new.reason,
           coalesce(new.created_at, now()),
           coalesce(new.moderation_status, 0),
           new.moderation_label,
           new.moderation_confidence,
           new.moderation_reason,
           new.moderated_at,
           new.moderated_by,
           jsonb_strip_nulls(jsonb_build_object('reported_user_alias', new.reported_user_alias)));
        return new;

    elsif tg_op = 'UPDATE' then
        update public.entity_reports set
          reporter_id = new.reporter_id,
          entity_id = new.reported_user_id,
          reported_user_id = case when public.user_exists(new.reported_user_id) then new.reported_user_id else null end,
          reason = new.reason,
          created_at = coalesce(new.created_at, created_at),
          moderation_status = new.moderation_status,
          moderation_label = new.moderation_label,
          moderation_confidence = new.moderation_confidence,
          moderation_reason = new.moderation_reason,
          moderated_at = new.moderated_at,
          moderated_by = new.moderated_by,
          metadata = coalesce(metadata, '{}'::jsonb)
                     || jsonb_strip_nulls(jsonb_build_object('reported_user_alias', new.reported_user_alias))
        where id = old.id and entity_type = 'user';
        return new;

    else
        delete from public.entity_reports where id = old.id and entity_type = 'user';
        return old;
    end if;
end $$;


ALTER FUNCTION "public"."legacy_user_reports_iud"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpieza_semestral_pemtree"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    DECLARE
        v_hoy_md text := TO_CHAR(CURRENT_DATE, 'MM-DD');
        v_es_fecha_grupos boolean := v_hoy_md IN ('01-01', '05-15', '07-01', '11-15');
    BEGIN
        RAISE NOTICE 'Iniciando limpieza automática de PEMTREE (fecha clave grupos: %)...', v_hoy_md;

        DELETE FROM public.posts
        WHERE created_at < NOW() - INTERVAL '3 months';

        DELETE FROM public.user_reports
        WHERE created_at < NOW() - INTERVAL '3 months';

        DELETE FROM public.comments
        WHERE created_at < NOW() - INTERVAL '3 months';

        DELETE FROM public.user_notifications
        WHERE created_at < NOW() - INTERVAL '3 months';

        IF v_es_fecha_grupos THEN
            DELETE FROM public.whatsapp_groups;
            RAISE NOTICE 'Fecha clave (%): se eliminaron todos los grupos de WhatsApp.', v_hoy_md;
        ELSE
            RAISE NOTICE 'No es fecha clave de grupos (%), se mantienen los grupos de WhatsApp.', v_hoy_md;
        END IF;

        RAISE NOTICE 'Limpieza automática de PEMTREE completada exitosamente.';
    END;
    $$;


ALTER FUNCTION "public"."limpieza_semestral_pemtree"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."marcar_pendientes_error"("p_horas" integer DEFAULT 1) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_limite timestamptz := now() - make_interval(hours => p_horas);
  v_total integer := 0;
  v_cont integer;
begin
  with marcados as (
    update public.posts
       set moderation_status = 3, moderation_label = 'error', moderation_confidence = 0,
           moderation_reason = 'Servicio de moderación no disponible',
           moderated_at = now(), moderated_by = null
     where moderation_status = 0 and created_at < v_limite
    returning id
  )
  insert into public.moderation_audit_log
    (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
  select null, 'posts', id, 'Servicio de moderación no disponible', true, 'error', 0 from marcados;
  get diagnostics v_cont = row_count;
  v_total := v_total + v_cont;

  with marcados as (
    update public.comments
       set moderation_status = 3, moderation_label = 'error', moderation_confidence = 0,
           moderation_reason = 'Servicio de moderación no disponible',
           moderated_at = now(), moderated_by = null
     where moderation_status = 0 and created_at < v_limite
    returning id
  )
  insert into public.moderation_audit_log
    (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
  select null, 'comments', id, 'Servicio de moderación no disponible', true, 'error', 0 from marcados;
  get diagnostics v_cont = row_count;
  v_total := v_total + v_cont;

  with marcados as (
    update public.student_groups
       set moderation_status = 3, moderation_label = 'error', moderation_confidence = 0,
           moderation_reason = 'Servicio de moderación no disponible',
           moderated_at = now(), moderated_by = null
     where moderation_status = 0 and created_at < v_limite
    returning id
  )
  insert into public.moderation_audit_log
    (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
  select null, 'student_groups', id, 'Servicio de moderación no disponible', true, 'error', 0 from marcados;
  get diagnostics v_cont = row_count;
  v_total := v_total + v_cont;

  with marcados as (
    update public.marketplace_items
       set moderation_status = 3, moderation_label = 'error', moderation_confidence = 0,
           moderation_reason = 'Servicio de moderación no disponible',
           moderated_at = now(), moderated_by = null
     where moderation_status = 0 and created_at < v_limite
    returning id
  )
  insert into public.moderation_audit_log
    (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
  select null, 'marketplace_items', id, 'Servicio de moderación no disponible', true, 'error', 0 from marcados;
  get diagnostics v_cont = row_count;
  v_total := v_total + v_cont;

  return v_total;
end;
$$;


ALTER FUNCTION "public"."marcar_pendientes_error"("p_horas" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."moderate_marketplace_item"("target_item_id" "uuid", "new_status" integer, "p_label" "text" DEFAULT NULL::"text", "p_confidence" double precision DEFAULT NULL::double precision, "p_reason" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
    user_role_val text;
    v_user_id uuid := auth.uid();
begin
    select role into user_role_val
    from public.user_roles
    where user_id = v_user_id;

    if user_role_val = 'admin' or user_role_val = 'moderator' then
        update public.marketplace_items
           set moderation_status = new_status,
               moderation_label = coalesce(p_label, moderation_label),
               moderation_confidence = coalesce(p_confidence, moderation_confidence),
               moderation_reason = coalesce(nullif(trim(p_reason), ''), moderation_reason),
               moderated_at = now(),
               moderated_by = v_user_id
         where id = target_item_id;

        if not found then
            return false;
        end if;

        insert into public.moderation_audit_log
            (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
        values
            (v_user_id, 'marketplace_items', target_item_id,
             coalesce(nullif(trim(p_reason), ''), 'Moderación manual de publicación de marketplace'),
             false, p_label, p_confidence);

        return true;
    else
        return false;
    end if;
end $$;


ALTER FUNCTION "public"."moderate_marketplace_item"("target_item_id" "uuid", "new_status" integer, "p_label" "text", "p_confidence" double precision, "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_owner_id uuid;
    v_is_admin boolean := public.is_pemtree_admin(v_user_id);
    v_is_mod boolean := public.is_pemtree_moderator(v_user_id);
    v_justificacion text;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No estás autenticado en el sistema.';
    END IF;

    IF p_tabla = 'whatsapp_groups' THEN
        SELECT user_id INTO v_owner_id FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        SELECT user_id INTO v_owner_id FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        SELECT user_id INTO v_owner_id FROM public.comments WHERE id = p_item_id;
    ELSIF p_tabla = 'marketplace_items' THEN
        SELECT user_id INTO v_owner_id FROM public.marketplace_items WHERE id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El registro ya no existe o fue eliminado previamente en la base de datos.';
    END IF;

    IF v_owner_id <> v_user_id AND NOT v_is_admin AND NOT v_is_mod THEN
        RAISE EXCEPTION 'Permiso denegado: No tienes autorización para ocultar este contenido.';
    END IF;

    IF v_owner_id <> v_user_id AND NOT v_is_admin THEN
        IF p_justificacion IS NULL OR TRIM(p_justificacion) = '' THEN
            RAISE EXCEPTION 'Justificación obligatoria: Como moderador, debes ingresar la razón por la cual ocultas este contenido.';
        END IF;
        v_justificacion := TRIM(p_justificacion);
    ELSE
        v_justificacion := COALESCE(NULLIF(TRIM(p_justificacion), ''), 'Ocultado por el autor o administrador');
    END IF;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, p_tabla, p_item_id, v_justificacion, false, 'inappropriate');

    IF p_tabla = 'whatsapp_groups' THEN
        UPDATE public.whatsapp_groups
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        UPDATE public.posts
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        UPDATE public.comments
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    ELSIF p_tabla = 'marketplace_items' THEN
        UPDATE public.marketplace_items
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    END IF;

    PERFORM public._cancelar_jobs_panel(p_tabla, p_item_id);

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."panel_aprobar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text" DEFAULT 'Aprobado por moderador'::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := auth.uid();
  v_reason text := coalesce(nullif(trim(p_reason), ''), 'Aprobado por moderador');
begin
  if v_uid is null then
    raise exception 'No estás autenticado en el sistema.';
  end if;
  if not (public.is_pemtree_admin(v_uid) or public.is_pemtree_moderator(v_uid)) then
    raise exception 'Permiso denegado: solo administradores o moderadores pueden aprobar contenido manualmente.';
  end if;

  if p_tabla = 'posts' then
    update public.posts
       set moderation_status = 1, moderation_label = 'appropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  elsif p_tabla = 'comments' then
    update public.comments
       set moderation_status = 1, moderation_label = 'appropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  elsif p_tabla = 'student_groups' then
    update public.student_groups
       set moderation_status = 1, moderation_label = 'appropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  elsif p_tabla = 'marketplace_items' then
    update public.marketplace_items
       set moderation_status = 1, moderation_label = 'appropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  else
    raise exception 'Tabla (%) no válida para moderación manual.', p_tabla;
  end if;

  if not found then
    raise exception 'El registro ya no existe en la base de datos.';
  end if;

  perform public._cancelar_jobs_panel(p_tabla, p_id);

  insert into public.moderation_audit_log
      (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
  values (v_uid, p_tabla, p_id, v_reason, false, 'appropriate');

  return true;
end;
$$;


ALTER FUNCTION "public"."panel_aprobar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."panel_cola_revision"("p_umbral" double precision DEFAULT 0.75) RETURNS TABLE("tabla" "text", "item_id" "uuid", "titulo" "text", "moderation_status" integer, "moderation_label" "text", "moderation_confidence" double precision, "moderation_reason" "text", "created_at" timestamp with time zone, "motivo_cola" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not (public.is_pemtree_admin(auth.uid()) or public.is_pemtree_moderator(auth.uid())) then
    raise exception 'Permiso denegado: solo administradores o moderadores pueden ver la cola de revisión.';
  end if;

  return query
  select q.tabla, q.item_id, q.titulo, q.moderation_status, q.moderation_label,
         q.moderation_confidence, q.moderation_reason, q.created_at, q.motivo_cola
  from (
    select 'posts'::text as tabla, p.id as item_id, p.title as titulo,
           p.moderation_status, p.moderation_label, p.moderation_confidence,
           p.moderation_reason, p.created_at, 'error'::text as motivo_cola, 0 as orden
      from public.posts p
     where p.moderation_status = 3
    union all
    select 'comments', c.id, left(c.content, 80),
           c.moderation_status, c.moderation_label, c.moderation_confidence,
           c.moderation_reason, c.created_at, 'error', 0
      from public.comments c
     where c.moderation_status = 3
    union all
    select 'student_groups', g.id, g.title,
           g.moderation_status, g.moderation_label, g.moderation_confidence,
           g.moderation_reason, g.created_at, 'error', 0
      from public.student_groups g
     where g.moderation_status = 3
    union all
    select 'marketplace_items', m.id, m.title,
           m.moderation_status, m.moderation_label, m.moderation_confidence,
           m.moderation_reason, m.created_at, 'error', 0
      from public.marketplace_items m
     where m.moderation_status = 3
    union all
    select 'posts', p.id, p.title,
           p.moderation_status, p.moderation_label, p.moderation_confidence,
           p.moderation_reason, p.created_at, 'baja_confianza', 1
      from public.posts p
     where p.moderation_status = 2 and coalesce(p.moderation_confidence, 0) < p_umbral
    union all
    select 'comments', c.id, left(c.content, 80),
           c.moderation_status, c.moderation_label, c.moderation_confidence,
           c.moderation_reason, c.created_at, 'baja_confianza', 1
      from public.comments c
     where c.moderation_status = 2 and coalesce(c.moderation_confidence, 0) < p_umbral
    union all
    select 'student_groups', g.id, g.title,
           g.moderation_status, g.moderation_label, g.moderation_confidence,
           g.moderation_reason, g.created_at, 'baja_confianza', 1
      from public.student_groups g
     where g.moderation_status = 2 and coalesce(g.moderation_confidence, 0) < p_umbral
    union all
    select 'marketplace_items', m.id, m.title,
           m.moderation_status, m.moderation_label, m.moderation_confidence,
           m.moderation_reason, m.created_at, 'baja_confianza', 1
      from public.marketplace_items m
     where m.moderation_status = 2 and coalesce(m.moderation_confidence, 0) < p_umbral
  ) q
  order by q.orden, q.created_at desc;
end;
$$;


ALTER FUNCTION "public"."panel_cola_revision"("p_umbral" double precision) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."panel_rechazar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := auth.uid();
  v_reason text := nullif(trim(p_reason), '');
begin
  if v_uid is null then
    raise exception 'No estás autenticado en el sistema.';
  end if;
  if not (public.is_pemtree_admin(v_uid) or public.is_pemtree_moderator(v_uid)) then
    raise exception 'Permiso denegado: solo administradores o moderadores pueden rechazar contenido manualmente.';
  end if;
  if v_reason is null then
    raise exception 'Justificación obligatoria: debes indicar la razón del rechazo.';
  end if;

  if p_tabla = 'posts' then
    update public.posts
       set moderation_status = 2, moderation_label = 'inappropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  elsif p_tabla = 'comments' then
    update public.comments
       set moderation_status = 2, moderation_label = 'inappropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  elsif p_tabla = 'student_groups' then
    update public.student_groups
       set moderation_status = 2, moderation_label = 'inappropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  elsif p_tabla = 'marketplace_items' then
    update public.marketplace_items
       set moderation_status = 2, moderation_label = 'inappropriate',
           moderation_reason = v_reason, moderated_by = v_uid, moderated_at = now()
     where id = p_id;
  else
    raise exception 'Tabla (%) no válida para moderación manual.', p_tabla;
  end if;

  if not found then
    raise exception 'El registro ya no existe en la base de datos.';
  end if;

  perform public._cancelar_jobs_panel(p_tabla, p_id);

  insert into public.moderation_audit_log
      (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
  values (v_uid, p_tabla, p_id, v_reason, false, 'inappropriate');

  return true;
end;
$$;


ALTER FUNCTION "public"."panel_rechazar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."panel_remoderar"("p_tabla" "text", "p_id" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := auth.uid();
  v_has_image boolean;
  v_job_id uuid;
begin
  if v_uid is null then
    raise exception 'No estás autenticado en el sistema.';
  end if;
  if not (public.is_pemtree_admin(v_uid) or public.is_pemtree_moderator(v_uid)) then
    raise exception 'Permiso denegado: solo administradores o moderadores pueden re-moderar contenido.';
  end if;

  if p_tabla = 'posts' then
    select (p.image_url is not null or p.gif_url is not null)
      into v_has_image
      from public.posts p where p.id = p_id;
  elsif p_tabla = 'comments' then
    select (c.gif_url is not null)
      into v_has_image
      from public.comments c where c.id = p_id;
  elsif p_tabla = 'student_groups' then
    select (g.image_url is not null)
      into v_has_image
      from public.student_groups g where g.id = p_id;
  elsif p_tabla = 'marketplace_items' then
    select (coalesce(array_length(m.image_urls, 1), 0) >= 1)
      into v_has_image
      from public.marketplace_items m where m.id = p_id;
  else
    raise exception 'Tabla (%) no válida para re-moderación.', p_tabla;
  end if;

  if not found then
    raise exception 'El registro ya no existe en la base de datos.';
  end if;

  perform public._cancelar_jobs_panel(p_tabla, p_id);

  insert into public.moderation_jobs(entity_table, entity_id, content_hash, priority, has_image)
  values (p_tabla, p_id, 'manual:' || gen_random_uuid()::text, 5, coalesce(v_has_image, false))
  returning id into v_job_id;

  insert into public.moderation_audit_log
      (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
  values (v_uid, p_tabla, p_id, 'Re-moderación manual solicitada desde el panel', false, null);

  return v_job_id;
end;
$$;


ALTER FUNCTION "public"."panel_remoderar"("p_tabla" "text", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_nonmoderator_restore"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN NEW;
    END IF;

    IF public.is_pemtree_admin(v_uid) OR public.is_pemtree_moderator(v_uid) THEN
        RETURN NEW;
    END IF;

    IF NEW.moderation_status IS DISTINCT FROM OLD.moderation_status
       AND NEW.moderation_status IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION 'Permiso denegado: Una vez ocultado, solo un administrador o moderador puede restaurar este contenido.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_nonmoderator_restore"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_inappropriate_content"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_posts integer := 0;
    v_comments integer := 0;
    v_groups integer := 0;
    v_ureports integer := 0;
    v_greports integer := 0;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts WHERE moderation_status = 2;
    GET DIAGNOSTICS v_posts = ROW_COUNT;

    DELETE FROM public.comments WHERE moderation_status = 2;
    GET DIAGNOSTICS v_comments = ROW_COUNT;

    DELETE FROM public.whatsapp_groups WHERE moderation_status = 2;
    GET DIAGNOSTICS v_groups = ROW_COUNT;

    DELETE FROM public.user_reports WHERE moderation_status = 2;
    GET DIAGNOSTICS v_ureports = ROW_COUNT;

    DELETE FROM public.whatsapp_group_reports WHERE moderation_status = 2;
    GET DIAGNOSTICS v_greports = ROW_COUNT;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, 'cleanup', '00000000-0000-0000-0000-000000000000',
            'Limpieza administrador: todo el contenido inapropiado/bloqueado', false, 'cleanup');

    RETURN 'Limpieza completada — posts=' || v_posts || ', comentarios=' || v_comments ||
           ', grupos=' || v_groups || ', reportes de usuario=' || v_ureports || ', reportes de grupo=' || v_greports;
END;
$$;


ALTER FUNCTION "public"."purge_inappropriate_content"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_old_content"("p_months" integer DEFAULT 3) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
    v_cutoff timestamptz := now() - make_interval(months => p_months);
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts WHERE created_at < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, 'cleanup', '00000000-0000-0000-0000-000000000000',
            'Limpieza administrador: posts con más de ' || p_months || ' meses de antigüedad', false, 'cleanup');

    RETURN 'Se eliminaron ' || v_deleted || ' publicaciones (y sus respuestas/likes) con más de ' || p_months || ' meses de antigüedad.';
END;
$$;


ALTER FUNCTION "public"."purge_old_content"("p_months" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_reported_groups"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.whatsapp_groups
    WHERE reported_count > 0
       OR id IN (SELECT group_id FROM public.whatsapp_group_reports);
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, 'cleanup', '00000000-0000-0000-0000-000000000000',
            'Limpieza administrador: grupos reportados', false, 'cleanup');

    RETURN 'Se eliminaron ' || v_deleted || ' grupos reportados (y sus reportes/votos asociados).';
END;
$$;


ALTER FUNCTION "public"."purge_reported_groups"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalcular_contadores"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_reparados jsonb := '{}'::jsonb;
  v_n integer;
begin
  -- Admins por JWT; service_role; o conexión directa/cron (sin claims).
  if v_uid is not null and not public.is_pemtree_admin(v_uid) then
    raise exception 'Permiso denegado: solo administradores pueden recalcular contadores.';
  end if;
  if v_uid is null and v_role not in ('', 'service_role') then
    raise exception 'Permiso denegado: se requiere sesión de administrador.';
  end if;

  -- posts.likes
  update public.posts p
     set likes = (select count(*) from public.post_likes l where l.post_id = p.id)
   where p.likes is distinct from (select count(*) from public.post_likes l where l.post_id = p.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('posts.likes', v_n);

  -- posts.reposts_count
  update public.posts p
     set reposts_count = (select count(*) from public.posts r where r.quoted_post_id = p.id)
   where p.reposts_count is distinct from (select count(*) from public.posts r where r.quoted_post_id = p.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('posts.reposts_count', v_n);

  -- student_groups.upvotes
  update public.student_groups g
     set upvotes = (select count(*) from public.student_group_upvotes u where u.group_id = g.id)
   where g.upvotes is distinct from (select count(*) from public.student_group_upvotes u where u.group_id = g.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('student_groups.upvotes', v_n);

  -- student_groups.reported_count
  update public.student_groups g
     set reported_count = (
       select count(*) from public.entity_reports er
       where er.entity_type = 'group' and er.entity_id = g.id)
   where g.reported_count is distinct from (
       select count(*) from public.entity_reports er
       where er.entity_type = 'group' and er.entity_id = g.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('student_groups.reported_count', v_n);

  -- marketplace_items.upvotes
  update public.marketplace_items m
     set upvotes = (select count(*) from public.marketplace_upvotes u where u.item_id = m.id)
   where m.upvotes is distinct from (select count(*) from public.marketplace_upvotes u where u.item_id = m.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('marketplace_items.upvotes', v_n);

  -- marketplace_items.reported_count
  update public.marketplace_items m
     set reported_count = (
       select count(*) from public.entity_reports er
       where er.entity_type = 'marketplace_item' and er.entity_id = m.id)
   where m.reported_count is distinct from (
       select count(*) from public.entity_reports er
       where er.entity_type = 'marketplace_item' and er.entity_id = m.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('marketplace_items.reported_count', v_n);

  -- post_poll_options.votes_count
  update public.post_poll_options o
     set votes_count = (select count(*) from public.post_poll_votes v where v.option_id = o.id)
   where o.votes_count is distinct from (select count(*) from public.post_poll_votes v where v.option_id = o.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('post_poll_options.votes_count', v_n);

  return v_reparados;
end $$;


ALTER FUNCTION "public"."recalcular_contadores"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."recalcular_contadores"() IS 'Recalcula los contadores denormalizados desde sus tablas fuente y devuelve cuántas filas corrigió por contador.';



CREATE OR REPLACE FUNCTION "public"."report_forum_comment"("p_comment_id" "uuid", "p_reason" "text", "p_details" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para reportar.';
  END IF;

  INSERT INTO public.entity_reports (reporter_id, entity_type, entity_id, reason, details)
  VALUES (auth.uid(), 'comment', p_comment_id, p_reason, p_details)
  ON CONFLICT (reporter_id, entity_type, entity_id) DO NOTHING;

  RETURN true;
END;
$$;


ALTER FUNCTION "public"."report_forum_comment"("p_comment_id" "uuid", "p_reason" "text", "p_details" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_forum_post"("p_post_id" "uuid", "p_reason" "text", "p_details" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión para reportar.';
  END IF;

  INSERT INTO public.entity_reports (reporter_id, entity_type, entity_id, reason, details)
  VALUES (auth.uid(), 'post', p_post_id, p_reason, p_details)
  ON CONFLICT (reporter_id, entity_type, entity_id) DO NOTHING;

  RETURN true;
END;
$$;


ALTER FUNCTION "public"."report_forum_post"("p_post_id" "uuid", "p_reason" "text", "p_details" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_marketplace_item"("target_item_id" "uuid", "report_reason" "text", "target_seller_id" "uuid" DEFAULT NULL::"uuid", "target_seller_alias" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
    v_count int;
begin
    insert into public.entity_reports (
        reporter_id,
        entity_type,
        entity_id,
        entity_owner_id,
        reason,
        metadata
    ) values (
        auth.uid(),
        'marketplace_item',
        target_item_id,
        case when target_seller_id is not null and public.user_exists(target_seller_id)
             then target_seller_id else null end,
        report_reason,
        jsonb_strip_nulls(jsonb_build_object('seller_alias', target_seller_alias))
    )
    on conflict (reporter_id, entity_type, entity_id) do nothing;

    -- El trigger AFTER INSERT ya recalculó reported_count.
    select reported_count into v_count
    from public.marketplace_items
    where id = target_item_id;

    if v_count >= 3 then
        update public.marketplace_items
           set moderation_status = 2
         where id = target_item_id;
    end if;

    return true;
exception
    when others then
        return false;
end $$;


ALTER FUNCTION "public"."report_marketplace_item"("target_item_id" "uuid", "report_reason" "text", "target_seller_id" "uuid", "target_seller_alias" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_moderation_on_edit"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
    if tg_table_name = 'posts' then
        if new.title is distinct from old.title
           or new.content is distinct from old.content
           or new.category is distinct from old.category
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'comments' then
        if new.content is distinct from old.content then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name in ('student_groups', 'whatsapp_groups') then
        if new.title is distinct from old.title
           or new.carrera is distinct from old.carrera
           or new.curso is distinct from old.curso
           or new.section is distinct from old.section
           or new.link is distinct from old.link
           or new.description is distinct from old.description
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'marketplace_items' then
        if new.title is distinct from old.title
           or new.description is distinct from old.description
           or new.category is distinct from old.category
           or new.price is distinct from old.price
           or new.image_urls is distinct from old.image_urls
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'user_reports' then
        if new.reason is distinct from old.reason then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name in ('student_group_reports', 'whatsapp_group_reports') then
        if new.reason is distinct from old.reason then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'entity_reports' then
        if new.reason is distinct from old.reason
           or new.details is distinct from old.details
           or new.metadata is distinct from old.metadata
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    return new;
end $$;


ALTER FUNCTION "public"."reset_moderation_on_edit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_is_admin boolean := public.is_pemtree_admin(v_user_id);
    v_is_mod boolean := public.is_pemtree_moderator(v_user_id);
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No estás autenticado en el sistema.';
    END IF;

    IF p_tabla = 'whatsapp_groups' THEN
        PERFORM 1 FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        PERFORM 1 FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        PERFORM 1 FROM public.comments WHERE id = p_item_id;
    ELSIF p_tabla = 'marketplace_items' THEN
        PERFORM 1 FROM public.marketplace_items WHERE id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El registro ya no existe o fue eliminado previamente en la base de datos.';
    END IF;

    IF NOT v_is_admin AND NOT v_is_mod THEN
        RAISE EXCEPTION 'Permiso denegado: Solo un administrador o moderador puede restaurar contenido oculto. El autor ya no puede restaurar sus publicaciones una vez ocultadas.';
    END IF;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, p_tabla, p_item_id, 'Contenido restaurado/aprobado', false, 'appropriate');

    IF p_tabla = 'whatsapp_groups' THEN
        UPDATE public.whatsapp_groups
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        UPDATE public.posts
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        UPDATE public.comments
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    ELSIF p_tabla = 'marketplace_items' THEN
        UPDATE public.marketplace_items
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    END IF;

    PERFORM public._cancelar_jobs_panel(p_tabla, p_item_id);

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_enqueue_comments"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new text;
  v_old text;
begin
  v_new := md5(coalesce(new.content,'')||coalesce(new.gif_url,''));
  if tg_op = 'UPDATE' then
    v_old := md5(coalesce(old.content,'')||coalesce(old.gif_url,''));
    if v_new = v_old then return new; end if;
  end if;
  perform public.enqueue_moderation(
    'comments', new.id, v_new, 100,
    (new.gif_url is not null)
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_enqueue_comments"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_enqueue_marketplace"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_first_img text;
  v_new text;
  v_old text;
  v_first_img_old text;
begin
  v_first_img := case
    when new.image_urls is null or array_length(new.image_urls,1) is null then null
    else new.image_urls[1] end;

  v_new := md5(coalesce(new.title,'')||coalesce(new.description,'')||coalesce(v_first_img,'')||coalesce(new.video_url,''));

  if tg_op = 'UPDATE' then
    v_first_img_old := case
      when old.image_urls is null or array_length(old.image_urls,1) is null then null
      else old.image_urls[1] end;
    v_old := md5(coalesce(old.title,'')||coalesce(old.description,'')||coalesce(v_first_img_old,'')||coalesce(old.video_url,''));
    if v_new = v_old then return new; end if;
  end if;

  perform public.enqueue_moderation(
    'marketplace_items', new.id, v_new, 100,
    (v_first_img is not null)
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_enqueue_marketplace"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_enqueue_posts"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new text;
  v_old text;
begin
  v_new := md5(coalesce(new.title,'')||coalesce(new.content,'')||coalesce(new.image_url,'')||coalesce(new.gif_url,''));
  if tg_op = 'UPDATE' then
    v_old := md5(coalesce(old.title,'')||coalesce(old.content,'')||coalesce(old.image_url,'')||coalesce(old.gif_url,''));
    if v_new = v_old then return new; end if;
  end if;
  perform public.enqueue_moderation(
    'posts', new.id, v_new, 100,
    (new.image_url is not null or new.gif_url is not null)
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_enqueue_posts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_enqueue_student_groups"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new text;
  v_old text;
begin
  v_new := md5(coalesce(new.title,'')||coalesce(new.description,'')||coalesce(new.link,'')||coalesce(new.image_url,''));
  if tg_op = 'UPDATE' then
    v_old := md5(coalesce(old.title,'')||coalesce(old.description,'')||coalesce(old.link,'')||coalesce(old.image_url,''));
    if v_new = v_old then return new; end if;
  end if;
  perform public.enqueue_moderation(
    'student_groups', new.id, v_new, 100,
    (new.image_url is not null)
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_enqueue_student_groups"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."user_exists"("p_user_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$ select exists (select 1 from auth.users u where u.id = p_user_id) $$;


ALTER FUNCTION "public"."user_exists"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."v_moderation_queue"() RETURNS TABLE("entity_table" "text", "entity_id" "uuid", "entity_key" "uuid", "content" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
    SELECT 'posts'::text, id, NULL::uuid,
           COALESCE(title, '') || ' ' || COALESCE(content, ''),
           created_at
    FROM public.posts
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'comments', id, NULL::uuid,
           COALESCE(content, ''),
           created_at
    FROM public.comments
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'whatsapp_groups', id, NULL::uuid,
           COALESCE(title, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(link, ''),
           created_at
    FROM public.whatsapp_groups
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'marketplace_items', id, NULL::uuid,
           COALESCE(title, '') || ' ' || COALESCE(description, ''),
           created_at
    FROM public.marketplace_items
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'user_reports', id, NULL::uuid,
           COALESCE(reason, '') || ' ' || COALESCE(reported_user_alias, ''),
           created_at
    FROM public.user_reports
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'whatsapp_group_reports', group_id, user_id,
           COALESCE(reason, ''),
           created_at
    FROM public.whatsapp_group_reports
    WHERE moderation_status = 0
    ORDER BY created_at;
$$;


ALTER FUNCTION "public"."v_moderation_queue"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verificar_contadores"() RETURNS TABLE("contador" "text", "desincronizados" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
begin
  if v_uid is not null and not public.is_pemtree_admin(v_uid) then
    raise exception 'Permiso denegado: solo administradores pueden verificar contadores.';
  end if;
  if v_uid is null and v_role not in ('', 'service_role') then
    raise exception 'Permiso denegado: se requiere sesión de administrador.';
  end if;

  return query
    select 'posts.likes'::text, count(*)::bigint
    from public.posts p
    left join (select post_id, count(*) c from public.post_likes group by 1) x on x.post_id = p.id
    where p.likes is distinct from coalesce(x.c, 0)
    union all
    select 'posts.reposts_count', count(*)::bigint
    from public.posts p
    left join (select quoted_post_id, count(*) c from public.posts where quoted_post_id is not null group by 1) x
      on x.quoted_post_id = p.id
    where p.reposts_count is distinct from coalesce(x.c, 0)
    union all
    select 'student_groups.upvotes', count(*)::bigint
    from public.student_groups g
    left join (select group_id, count(*) c from public.student_group_upvotes group by 1) x on x.group_id = g.id
    where g.upvotes is distinct from coalesce(x.c, 0)
    union all
    select 'student_groups.reported_count', count(*)::bigint
    from public.student_groups g
    left join (select entity_id, count(*) c from public.entity_reports where entity_type='group' group by 1) x
      on x.entity_id = g.id
    where g.reported_count is distinct from coalesce(x.c, 0)
    union all
    select 'marketplace_items.upvotes', count(*)::bigint
    from public.marketplace_items m
    left join (select item_id, count(*) c from public.marketplace_upvotes group by 1) x on x.item_id = m.id
    where m.upvotes is distinct from coalesce(x.c, 0)
    union all
    select 'marketplace_items.reported_count', count(*)::bigint
    from public.marketplace_items m
    left join (select entity_id, count(*) c from public.entity_reports where entity_type='marketplace_item' group by 1) x
      on x.entity_id = m.id
    where m.reported_count is distinct from coalesce(x.c, 0)
    union all
    select 'post_poll_options.votes_count', count(*)::bigint
    from public.post_poll_options o
    left join (select option_id, count(*) c from public.post_poll_votes group by 1) x on x.option_id = o.id
    where o.votes_count is distinct from coalesce(x.c, 0);
end $$;


ALTER FUNCTION "public"."verificar_contadores"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."verificar_contadores"() IS 'Devuelve, por contador denormalizado, cuántas filas están desincronizadas respecto de su tabla fuente.';


SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."carreras" (
    "id" "text" NOT NULL,
    "facultad_id" "text" NOT NULL,
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."carreras" OWNER TO "postgres";


COMMENT ON TABLE "public"."carreras" IS 'Catálogo de carreras USAC. Solo lectura; se actualiza por migración desde categories.dart.';



CREATE TABLE IF NOT EXISTS "public"."categorias_foro" (
    "id" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."categorias_foro" OWNER TO "postgres";


COMMENT ON TABLE "public"."categorias_foro" IS 'Catálogo de categorías del foro. Solo lectura.';



CREATE TABLE IF NOT EXISTS "public"."categorias_marketplace" (
    "id" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."categorias_marketplace" OWNER TO "postgres";


COMMENT ON TABLE "public"."categorias_marketplace" IS 'Catálogo de categorías del marketplace. Solo lectura.';



CREATE TABLE IF NOT EXISTS "public"."comment_authors" (
    "comment_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."comment_authors" OWNER TO "postgres";


COMMENT ON TABLE "public"."comment_authors" IS 'Mapa privado comentario -> autor real (user_id). Se puebla por trigger en el INSERT del comentario; RLS solo permite al autor leer su propia fila. La autoría pública se expone anonimizada vía comments.author_hash (v_public_comments), no por esta tabla.';



COMMENT ON COLUMN "public"."comment_authors"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid",
    "author_alias" "text" NOT NULL,
    "content" "text" NOT NULL,
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_id" "uuid",
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid",
    "gif_url" "text",
    "author_hash" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "comments_moderation_status_check" CHECK ((("moderation_status" >= 0) AND ("moderation_status" <= 3)))
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02', "fillfactor"='90');


ALTER TABLE "public"."comments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."comments"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



COMMENT ON COLUMN "public"."comments"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



CREATE TABLE IF NOT EXISTS "public"."entity_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "details" "text",
    "moderation_status" integer DEFAULT 0 NOT NULL,
    "moderated_by" "uuid",
    "moderated_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "reported_user_id" "uuid",
    "entity_owner_id" "uuid",
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "entity_reports_entity_type_check" CHECK (("entity_type" = ANY (ARRAY['post'::"text", 'comment'::"text", 'group'::"text", 'marketplace_item'::"text", 'user'::"text"]))),
    CONSTRAINT "entity_reports_moderation_status_check" CHECK ((("moderation_status" >= 0) AND ("moderation_status" <= 3)))
);


ALTER TABLE "public"."entity_reports" OWNER TO "postgres";


COMMENT ON COLUMN "public"."entity_reports"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



COMMENT ON COLUMN "public"."entity_reports"."metadata" IS 'Campos específicos del tipo de entidad: reported_user_alias, seller_alias, legacy_status.';



COMMENT ON COLUMN "public"."entity_reports"."reported_user_id" IS 'Usuario reportado (solo entity_type = user). FK a auth.users.';



COMMENT ON COLUMN "public"."entity_reports"."entity_owner_id" IS 'Dueño del contenido reportado, p.ej. vendedor (solo marketplace_item). FK a auth.users.';



COMMENT ON COLUMN "public"."entity_reports"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



CREATE TABLE IF NOT EXISTS "public"."facultades" (
    "id" "text" NOT NULL,
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."facultades" OWNER TO "postgres";


COMMENT ON TABLE "public"."facultades" IS 'Catálogo de facultades USAC. Solo lectura; se actualiza por migración desde categories.dart.';



CREATE TABLE IF NOT EXISTS "public"."marketplace_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "price" numeric(10,2) DEFAULT 0.00 NOT NULL,
    "is_free" boolean DEFAULT false NOT NULL,
    "category" "text" DEFAULT 'otros_articulos'::"text" NOT NULL,
    "facultad" "text" DEFAULT 'todas'::"text" NOT NULL,
    "sede" "text" DEFAULT 'central'::"text" NOT NULL,
    "building_code" "text" DEFAULT ''::"text",
    "location_detail" "text" DEFAULT ''::"text",
    "contact_whatsapp" "text",
    "contact_telegram" "text",
    "image_urls" "text"[] DEFAULT '{}'::"text"[],
    "video_url" "text",
    "is_sponsored" boolean DEFAULT false NOT NULL,
    "sponsor_badge_text" "text",
    "author_alias" "text" DEFAULT 'Estudiante Emprendedor'::"text" NOT NULL,
    "user_id" "uuid",
    "upvotes" integer DEFAULT 0 NOT NULL,
    "moderation_status" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_instagram" "text",
    "contact_messenger" "text",
    "social_links" "text"[] DEFAULT '{}'::"text"[],
    "reported_count" integer DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'available'::"text" NOT NULL,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "marketplace_items_moderation_status_check" CHECK ((("moderation_status" >= 0) AND ("moderation_status" <= 3))),
    CONSTRAINT "marketplace_items_status_check" CHECK (("status" = ANY (ARRAY['available'::"text", 'reserved'::"text", 'sold'::"text", 'paused'::"text", 'archived'::"text"])))
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02', "fillfactor"='90');


ALTER TABLE "public"."marketplace_items" OWNER TO "postgres";


COMMENT ON COLUMN "public"."marketplace_items"."upvotes" IS 'Denormalizado: count(public.marketplace_upvotes). Mantenido por trg_sync_marketplace_upvotes. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."marketplace_items"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



COMMENT ON COLUMN "public"."marketplace_items"."reported_count" IS 'Denormalizado: count(entity_reports con entity_type=marketplace_item). Mantenido por trg_sync_entity_report_counters. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."marketplace_items"."status" IS 'Estado de la publicación: available | reserved | sold | paused | archived.';



COMMENT ON COLUMN "public"."marketplace_items"."moderation_label" IS 'Etiqueta de moderación: appropriate | inappropriate | error | ...';



COMMENT ON COLUMN "public"."marketplace_items"."moderation_confidence" IS 'Confianza del clasificador de moderación (0.0 - 1.0).';



COMMENT ON COLUMN "public"."marketplace_items"."moderation_reason" IS 'Justificación o motivo de la decisión de moderación.';



COMMENT ON COLUMN "public"."marketplace_items"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



CREATE OR REPLACE VIEW "public"."marketplace_reports" WITH ("security_invoker"='true') AS
 SELECT "id",
    "entity_id" AS "item_id",
    "reporter_id" AS "user_id",
    "reason",
    "created_at",
    "entity_owner_id" AS "seller_user_id",
    ("metadata" ->> 'seller_alias'::"text") AS "seller_alias",
    COALESCE(("metadata" ->> 'legacy_status'::"text"), 'pending'::"text") AS "status",
    "moderation_status",
    "moderation_label",
    "moderation_confidence",
    "moderation_reason",
    "moderated_at",
    "moderated_by"
   FROM "public"."entity_reports" "er"
  WHERE ("entity_type" = 'marketplace_item'::"text");


ALTER VIEW "public"."marketplace_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."marketplace_upvotes" (
    "item_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02');


ALTER TABLE "public"."marketplace_upvotes" OWNER TO "postgres";


COMMENT ON TABLE "public"."marketplace_upvotes" IS 'Upvotes de marketplace. PK compuesta (item_id, user_id) e igual esquema que post_likes y student_group_upvotes.';



COMMENT ON COLUMN "public"."marketplace_upvotes"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."moderation_audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "moderator_id" "uuid",
    "entity_table" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "justification" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_automated" boolean DEFAULT false,
    "moderation_label" "text",
    "confidence" double precision
);


ALTER TABLE "public"."moderation_audit_log" OWNER TO "postgres";


COMMENT ON COLUMN "public"."moderation_audit_log"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."moderation_jobs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entity_table" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "content_hash" "text" NOT NULL,
    "has_image" boolean DEFAULT false NOT NULL,
    "priority" integer DEFAULT 100 NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "attempts" integer DEFAULT 0 NOT NULL,
    "max_attempts" integer DEFAULT 5 NOT NULL,
    "run_after" timestamp with time zone DEFAULT "now"() NOT NULL,
    "locked_by" "text",
    "locked_at" timestamp with time zone,
    "last_error" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "moderation_jobs_entity_table_check" CHECK (("entity_table" = ANY (ARRAY['posts'::"text", 'comments'::"text", 'student_groups'::"text", 'marketplace_items'::"text"]))),
    CONSTRAINT "moderation_jobs_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'done'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."moderation_jobs" OWNER TO "postgres";


COMMENT ON TABLE "public"."moderation_jobs" IS 'Cola (outbox) de contenido por moderar. La consume el worker vía claim_moderation_job(). Prioridad baja = primero.';



CREATE TABLE IF NOT EXISTS "public"."notification_preference_carreras" (
    "user_id" "uuid" NOT NULL,
    "carrera_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_preference_carreras" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_preference_carreras" IS 'Carreras suscritas por usuario para notificaciones (reemplaza notification_preferences.carreras text[]). Integridad garantizada por FK a carreras.';



CREATE TABLE IF NOT EXISTS "public"."notification_preferences" (
    "user_id" "uuid" NOT NULL,
    "comment_enabled" boolean DEFAULT true NOT NULL,
    "reply_enabled" boolean DEFAULT true NOT NULL,
    "like_enabled" boolean DEFAULT true NOT NULL,
    "new_post_enabled" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_preferences" OWNER TO "postgres";


COMMENT ON COLUMN "public"."notification_preferences"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."notification_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "endpoint" "text" NOT NULL,
    "p256dh" "text" NOT NULL,
    "auth" "text" NOT NULL,
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_subscriptions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."notification_subscriptions"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."post_authors" (
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."post_authors" OWNER TO "postgres";


COMMENT ON TABLE "public"."post_authors" IS 'Mapa privado post -> autor real (user_id). Se puebla por trigger en el INSERT del post; RLS solo permite al autor leer su propia fila. La autoría pública se expone anonimizada vía posts.author_hash (v_public_posts), no por esta tabla.';



COMMENT ON COLUMN "public"."post_authors"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."post_bookmarks" (
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02');


ALTER TABLE "public"."post_bookmarks" OWNER TO "postgres";


COMMENT ON COLUMN "public"."post_bookmarks"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."post_likes" (
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02');


ALTER TABLE "public"."post_likes" OWNER TO "postgres";


COMMENT ON COLUMN "public"."post_likes"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."post_poll_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "poll_id" "uuid" NOT NULL,
    "option_text" "text" NOT NULL,
    "votes_count" integer DEFAULT 0 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02', "fillfactor"='90');


ALTER TABLE "public"."post_poll_options" OWNER TO "postgres";


COMMENT ON COLUMN "public"."post_poll_options"."votes_count" IS 'Denormalizado: count(public.post_poll_votes). Mantenido por trg_sync_poll_votes_counter. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."post_poll_options"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



COMMENT ON COLUMN "public"."post_poll_options"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."post_poll_votes" (
    "poll_id" "uuid" NOT NULL,
    "option_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."post_poll_votes" OWNER TO "postgres";


COMMENT ON COLUMN "public"."post_poll_votes"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."post_polls" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid" NOT NULL,
    "question" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."post_polls" OWNER TO "postgres";


COMMENT ON COLUMN "public"."post_polls"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



COMMENT ON COLUMN "public"."post_polls"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



CREATE TABLE IF NOT EXISTS "public"."posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "category" "text" NOT NULL,
    "content" "text" NOT NULL,
    "author_alias" "text" NOT NULL,
    "likes" integer DEFAULT 0,
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "carrera" "text" DEFAULT 'sistemas'::"text",
    "image_url" "text",
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid",
    "quoted_post_id" "uuid",
    "gif_url" "text",
    "is_pinned" boolean DEFAULT false NOT NULL,
    "reposts_count" integer DEFAULT 0 NOT NULL,
    "author_hash" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "posts_moderation_status_check" CHECK ((("moderation_status" >= 0) AND ("moderation_status" <= 3)))
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02', "fillfactor"='90');


ALTER TABLE "public"."posts" OWNER TO "postgres";


COMMENT ON COLUMN "public"."posts"."likes" IS 'Denormalizado: count(public.post_likes). Mantenido por trg_sync_post_likes. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."posts"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



COMMENT ON COLUMN "public"."posts"."reposts_count" IS 'Denormalizado: count(public.posts donde quoted_post_id = id). Mantenido por trg_sync_reposts_counter. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."posts"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "cui" "text",
    "carne" "text",
    "full_name" "text",
    "carrera" "text",
    "is_verified" boolean DEFAULT false NOT NULL,
    "verified_at" timestamp with time zone,
    "reputation_score" numeric DEFAULT 5.0,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."seccion_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "curso_codigo" "text" NOT NULL,
    "seccion" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "recomienda" boolean NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."seccion_reviews" OWNER TO "postgres";


COMMENT ON COLUMN "public"."seccion_reviews"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE OR REPLACE VIEW "public"."seccion_reputation" WITH ("security_invoker"='true') AS
 SELECT "curso_codigo",
    "seccion",
    "count"("id") AS "total",
    "count"("id") FILTER (WHERE "recomienda") AS "recomendados",
        CASE
            WHEN ("count"("id") = 0) THEN NULL::numeric
            ELSE "round"(((("count"("id") FILTER (WHERE "recomienda"))::numeric / ("count"("id"))::numeric) * (100)::numeric))
        END AS "pct_recomienda"
   FROM "public"."seccion_reviews"
  GROUP BY "curso_codigo", "seccion";


ALTER VIEW "public"."seccion_reputation" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sponsor_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "brand_name" "text" NOT NULL,
    "contact_name" "text" NOT NULL,
    "contact_phone" "text" NOT NULL,
    "email" "text",
    "proposal_details" "text" NOT NULL,
    "expected_placement" "text" DEFAULT 'Primera Plana - Marketplace'::"text",
    "user_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sponsor_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'in_review'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."sponsor_requests" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sponsor_requests"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE OR REPLACE VIEW "public"."student_group_reports" WITH ("security_invoker"='true') AS
 SELECT "entity_id" AS "group_id",
    "reporter_id" AS "user_id",
    "reason",
    "created_at",
    "moderation_status",
    "moderation_label",
    "moderation_confidence",
    "moderation_reason",
    "moderated_at",
    "moderated_by"
   FROM "public"."entity_reports" "er"
  WHERE ("entity_type" = 'group'::"text");


ALTER VIEW "public"."student_group_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."student_group_upvotes" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02');


ALTER TABLE "public"."student_group_upvotes" OWNER TO "postgres";


COMMENT ON COLUMN "public"."student_group_upvotes"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE TABLE IF NOT EXISTS "public"."student_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "carrera" "text" DEFAULT 'todas'::"text" NOT NULL,
    "curso" "text" NOT NULL,
    "section" "text",
    "link" "text" NOT NULL,
    "description" "text",
    "user_id" "uuid",
    "author_alias" "text" DEFAULT 'Estudiante Anónimo'::"text" NOT NULL,
    "upvotes" integer DEFAULT 0,
    "reported_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "image_url" "text",
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid",
    "platform" "text" DEFAULT 'whatsapp'::"text" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "student_groups_moderation_status_check" CHECK ((("moderation_status" >= 0) AND ("moderation_status" <= 3))),
    CONSTRAINT "student_groups_platform_check" CHECK (("platform" = ANY (ARRAY['whatsapp'::"text", 'telegram'::"text", 'discord'::"text", 'drive'::"text", 'otro'::"text"])))
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02', "fillfactor"='90');


ALTER TABLE "public"."student_groups" OWNER TO "postgres";


COMMENT ON COLUMN "public"."student_groups"."upvotes" IS 'Denormalizado: count(public.student_group_upvotes). Mantenido por trg_sync_group_upvotes. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."student_groups"."reported_count" IS 'Denormalizado: count(entity_reports con entity_type=group). Mantenido por trg_sync_entity_report_counters. Reconciliar con public.recalcular_contadores().';



COMMENT ON COLUMN "public"."student_groups"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



COMMENT ON COLUMN "public"."student_groups"."updated_at" IS 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.';



CREATE TABLE IF NOT EXISTS "public"."user_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "actor_alias" "text",
    "post_id" "uuid",
    "comment_id" "uuid",
    "read_at" timestamp with time zone,
    "push_sent_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_notifications_type_check" CHECK (("type" = ANY (ARRAY['comment'::"text", 'reply'::"text", 'like'::"text", 'new_post'::"text"])))
)
WITH ("autovacuum_vacuum_threshold"='20', "autovacuum_vacuum_scale_factor"='0.05', "autovacuum_analyze_threshold"='20', "autovacuum_analyze_scale_factor"='0.02', "fillfactor"='90');


ALTER TABLE "public"."user_notifications" OWNER TO "postgres";


COMMENT ON COLUMN "public"."user_notifications"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE OR REPLACE VIEW "public"."user_reports" WITH ("security_invoker"='true') AS
 SELECT "id",
    "reporter_id",
    "reported_user_id",
    ("metadata" ->> 'reported_user_alias'::"text") AS "reported_user_alias",
    "reason",
    "created_at",
    "moderation_status",
    "moderation_label",
    "moderation_confidence",
    "moderation_reason",
    "moderated_at",
    "moderated_by"
   FROM "public"."entity_reports" "er"
  WHERE ("entity_type" = 'user'::"text");


ALTER VIEW "public"."user_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_roles_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'moderator'::"text"])))
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."user_roles"."created_at" IS 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.';



CREATE OR REPLACE VIEW "public"."v_public_comments" WITH ("security_invoker"='true') AS
 SELECT "c"."id",
    "c"."post_id",
    "c"."parent_id",
    "c"."content",
    "c"."author_alias",
    "c"."author_hash",
    "c"."gif_url",
    "c"."created_at",
    "c"."moderation_status",
    (("c"."author_hash" IS NOT NULL) AND ("c"."author_hash" = "p"."author_hash")) AS "is_post_author",
        CASE
            WHEN ("auth"."uid"() IS NOT NULL) THEN ("c"."author_hash" = "encode"("extensions"."digest"(((("auth"."uid"())::"text" || ':'::"text") || 'USAC_COMMUNITY_ANON_SECRET_SALT_2026_KEY'::"text"), 'sha256'::"text"), 'hex'::"text"))
            ELSE false
        END AS "is_my_comment"
   FROM ("public"."comments" "c"
     LEFT JOIN "public"."posts" "p" ON (("p"."id" = "c"."post_id")))
  WHERE ("c"."moderation_status" IS DISTINCT FROM 2);


ALTER VIEW "public"."v_public_comments" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_public_posts" WITH ("security_invoker"='true') AS
 SELECT "id",
    "title",
    "category",
    "content",
    "author_alias",
    "author_hash",
    "likes",
    "reposts_count",
    "carrera",
    "image_url",
    "gif_url",
    "is_pinned",
    "quoted_post_id",
    "created_at",
    "moderation_status",
    ( SELECT ("count"(*))::integer AS "count"
           FROM "public"."comments" "c"
          WHERE (("c"."post_id" = "p"."id") AND ("c"."moderation_status" IS DISTINCT FROM 2))) AS "comment_count",
        CASE
            WHEN ("auth"."uid"() IS NOT NULL) THEN ("author_hash" = "encode"("extensions"."digest"(((("auth"."uid"())::"text" || ':'::"text") || 'USAC_COMMUNITY_ANON_SECRET_SALT_2026_KEY'::"text"), 'sha256'::"text"), 'hex'::"text"))
            ELSE false
        END AS "is_my_post"
   FROM "public"."posts" "p"
  WHERE ("moderation_status" IS DISTINCT FROM 2);


ALTER VIEW "public"."v_public_posts" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."whatsapp_group_reports" WITH ("security_invoker"='true') AS
 SELECT "group_id",
    "user_id",
    "reason",
    "created_at",
    "moderation_status",
    "moderation_label",
    "moderation_confidence",
    "moderation_reason",
    "moderated_at",
    "moderated_by"
   FROM "public"."student_group_reports";


ALTER VIEW "public"."whatsapp_group_reports" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."whatsapp_group_upvotes" WITH ("security_invoker"='true') AS
 SELECT "group_id",
    "user_id",
    "created_at"
   FROM "public"."student_group_upvotes";


ALTER VIEW "public"."whatsapp_group_upvotes" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."whatsapp_groups" WITH ("security_invoker"='true') AS
 SELECT "id",
    "title",
    "carrera",
    "curso",
    "section",
    "link",
    "description",
    "user_id",
    "author_alias",
    "upvotes",
    "reported_count",
    "created_at",
    "image_url",
    "moderation_status",
    "moderation_label",
    "moderation_confidence",
    "moderation_reason",
    "moderated_at",
    "moderated_by",
    "platform"
   FROM "public"."student_groups";


ALTER VIEW "public"."whatsapp_groups" OWNER TO "postgres";


ALTER TABLE ONLY "public"."carreras"
    ADD CONSTRAINT "carreras_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categorias_foro"
    ADD CONSTRAINT "categorias_foro_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categorias_marketplace"
    ADD CONSTRAINT "categorias_marketplace_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comment_authors"
    ADD CONSTRAINT "comment_authors_pkey" PRIMARY KEY ("comment_id");



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entity_reports"
    ADD CONSTRAINT "entity_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facultades"
    ADD CONSTRAINT "facultades_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."marketplace_items"
    ADD CONSTRAINT "marketplace_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."marketplace_upvotes"
    ADD CONSTRAINT "marketplace_upvotes_pkey" PRIMARY KEY ("item_id", "user_id");



ALTER TABLE ONLY "public"."moderation_audit_log"
    ADD CONSTRAINT "moderation_audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_jobs"
    ADD CONSTRAINT "moderation_jobs_entity_table_entity_id_content_hash_key" UNIQUE ("entity_table", "entity_id", "content_hash");



ALTER TABLE ONLY "public"."moderation_jobs"
    ADD CONSTRAINT "moderation_jobs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preference_carreras"
    ADD CONSTRAINT "notification_preference_carreras_pkey" PRIMARY KEY ("user_id", "carrera_id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."notification_subscriptions"
    ADD CONSTRAINT "notification_subscriptions_endpoint_key" UNIQUE ("endpoint");



ALTER TABLE ONLY "public"."notification_subscriptions"
    ADD CONSTRAINT "notification_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_authors"
    ADD CONSTRAINT "post_authors_pkey" PRIMARY KEY ("post_id");



ALTER TABLE ONLY "public"."post_bookmarks"
    ADD CONSTRAINT "post_bookmarks_pkey" PRIMARY KEY ("post_id", "user_id");



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_pkey" PRIMARY KEY ("post_id", "user_id");



ALTER TABLE ONLY "public"."post_poll_options"
    ADD CONSTRAINT "post_poll_options_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_poll_options"
    ADD CONSTRAINT "post_poll_options_poll_id_id_key" UNIQUE ("poll_id", "id");



ALTER TABLE ONLY "public"."post_poll_votes"
    ADD CONSTRAINT "post_poll_votes_pkey" PRIMARY KEY ("poll_id", "user_id");



ALTER TABLE ONLY "public"."post_polls"
    ADD CONSTRAINT "post_polls_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_polls"
    ADD CONSTRAINT "post_polls_post_id_key" UNIQUE ("post_id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_carne_key" UNIQUE ("carne");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_cui_key" UNIQUE ("cui");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seccion_reviews"
    ADD CONSTRAINT "seccion_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sponsor_requests"
    ADD CONSTRAINT "sponsor_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seccion_reviews"
    ADD CONSTRAINT "unique_user_seccion_review" UNIQUE ("curso_codigo", "seccion", "user_id");



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."student_group_upvotes"
    ADD CONSTRAINT "whatsapp_group_upvotes_pkey" PRIMARY KEY ("group_id", "user_id");



ALTER TABLE ONLY "public"."student_groups"
    ADD CONSTRAINT "whatsapp_groups_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_carreras_facultad_id" ON "public"."carreras" USING "btree" ("facultad_id");



CREATE INDEX "idx_comment_authors_user_id" ON "public"."comment_authors" USING "btree" ("user_id");



CREATE INDEX "idx_comments_created_at" ON "public"."comments" USING "btree" ("created_at");



CREATE INDEX "idx_comments_moderated_by" ON "public"."comments" USING "btree" ("moderated_by");



CREATE INDEX "idx_comments_moderation_status" ON "public"."comments" USING "btree" ("moderation_status");



CREATE INDEX "idx_comments_parent_id" ON "public"."comments" USING "btree" ("parent_id");



CREATE INDEX "idx_comments_post_created" ON "public"."comments" USING "btree" ("post_id", "created_at");



CREATE INDEX "idx_comments_post_id" ON "public"."comments" USING "btree" ("post_id");



CREATE INDEX "idx_comments_post_parent" ON "public"."comments" USING "btree" ("post_id", "parent_id", "created_at");



CREATE INDEX "idx_comments_user_id" ON "public"."comments" USING "btree" ("user_id");



CREATE INDEX "idx_entity_reports_entity_owner_id" ON "public"."entity_reports" USING "btree" ("entity_owner_id");



CREATE INDEX "idx_entity_reports_moderated_by" ON "public"."entity_reports" USING "btree" ("moderated_by");



CREATE INDEX "idx_entity_reports_moderation" ON "public"."entity_reports" USING "btree" ("moderation_status", "created_at" DESC);



CREATE INDEX "idx_entity_reports_reported_user_id" ON "public"."entity_reports" USING "btree" ("reported_user_id");



CREATE INDEX "idx_entity_reports_type_entity" ON "public"."entity_reports" USING "btree" ("entity_type", "entity_id");



CREATE INDEX "idx_marketplace_building_code_trgm" ON "public"."marketplace_items" USING "gin" ("building_code" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_marketplace_category_feed" ON "public"."marketplace_items" USING "btree" ("category", "is_sponsored" DESC, "created_at" DESC) WHERE ("moderation_status" < 2);



CREATE INDEX "idx_marketplace_description_trgm" ON "public"."marketplace_items" USING "gin" ("description" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_marketplace_items_category" ON "public"."marketplace_items" USING "btree" ("category");



CREATE INDEX "idx_marketplace_items_created_at_desc" ON "public"."marketplace_items" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_marketplace_items_facultad" ON "public"."marketplace_items" USING "btree" ("facultad");



CREATE INDEX "idx_marketplace_items_moderated_by" ON "public"."marketplace_items" USING "btree" ("moderated_by");



CREATE INDEX "idx_marketplace_items_moderation" ON "public"."marketplace_items" USING "btree" ("moderation_status", "created_at" DESC);



CREATE INDEX "idx_marketplace_items_user_id" ON "public"."marketplace_items" USING "btree" ("user_id");



CREATE INDEX "idx_marketplace_status_created" ON "public"."marketplace_items" USING "btree" ("status", "created_at" DESC);



CREATE INDEX "idx_marketplace_title_trgm" ON "public"."marketplace_items" USING "gin" ("title" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_marketplace_upvotes_user_id" ON "public"."marketplace_upvotes" USING "btree" ("user_id");



CREATE INDEX "idx_moderation_audit_log_created_brin" ON "public"."moderation_audit_log" USING "brin" ("created_at");



CREATE INDEX "idx_moderation_audit_log_entity" ON "public"."moderation_audit_log" USING "btree" ("entity_table", "entity_id");



CREATE INDEX "idx_moderation_audit_log_moderator_id" ON "public"."moderation_audit_log" USING "btree" ("moderator_id");



CREATE INDEX "idx_notification_preference_carreras_carrera" ON "public"."notification_preference_carreras" USING "btree" ("carrera_id");



CREATE INDEX "idx_notifications_pending_push" ON "public"."user_notifications" USING "btree" ("created_at") WHERE ("push_sent_at" IS NULL);



CREATE INDEX "idx_notifications_user_created" ON "public"."user_notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_post_authors_user_id" ON "public"."post_authors" USING "btree" ("user_id");



CREATE INDEX "idx_post_bookmarks_user" ON "public"."post_bookmarks" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_post_likes_user_id" ON "public"."post_likes" USING "btree" ("user_id");



CREATE INDEX "idx_post_poll_options_poll" ON "public"."post_poll_options" USING "btree" ("poll_id");



CREATE INDEX "idx_post_poll_votes_option" ON "public"."post_poll_votes" USING "btree" ("option_id");



CREATE INDEX "idx_post_poll_votes_poll_option" ON "public"."post_poll_votes" USING "btree" ("poll_id", "option_id");



CREATE INDEX "idx_post_poll_votes_poll_user" ON "public"."post_poll_votes" USING "btree" ("poll_id", "user_id");



CREATE INDEX "idx_post_poll_votes_user_id" ON "public"."post_poll_votes" USING "btree" ("user_id");



CREATE INDEX "idx_post_polls_post" ON "public"."post_polls" USING "btree" ("post_id");



CREATE INDEX "idx_posts_carrera_created" ON "public"."posts" USING "btree" ("carrera", "is_pinned" DESC, "created_at" DESC) WHERE ("moderation_status" IS DISTINCT FROM 2);



CREATE INDEX "idx_posts_carrera_idx" ON "public"."posts" USING "btree" ("carrera");



CREATE INDEX "idx_posts_category" ON "public"."posts" USING "btree" ("category");



CREATE INDEX "idx_posts_category_created" ON "public"."posts" USING "btree" ("category", "is_pinned" DESC, "created_at" DESC) WHERE ("moderation_status" IS DISTINCT FROM 2);



CREATE INDEX "idx_posts_content_trgm" ON "public"."posts" USING "gin" ("content" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_posts_created_at" ON "public"."posts" USING "btree" ("created_at");



CREATE INDEX "idx_posts_created_at_desc" ON "public"."posts" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_posts_global_created" ON "public"."posts" USING "btree" ("is_pinned" DESC, "created_at" DESC) WHERE ("moderation_status" IS DISTINCT FROM 2);



CREATE INDEX "idx_posts_moderated_by" ON "public"."posts" USING "btree" ("moderated_by");



CREATE INDEX "idx_posts_moderation_status" ON "public"."posts" USING "btree" ("moderation_status");



CREATE INDEX "idx_posts_pinned" ON "public"."posts" USING "btree" ("is_pinned", "created_at" DESC) WHERE ("is_pinned" = true);



CREATE INDEX "idx_posts_quoted_post" ON "public"."posts" USING "btree" ("quoted_post_id");



CREATE INDEX "idx_posts_title_trgm" ON "public"."posts" USING "gin" ("title" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_posts_user_id" ON "public"."posts" USING "btree" ("user_id");



CREATE INDEX "idx_profiles_carrera" ON "public"."profiles" USING "btree" ("carrera");



CREATE INDEX "idx_profiles_unverified" ON "public"."profiles" USING "btree" ("created_at") WHERE (NOT "is_verified");



CREATE INDEX "idx_seccion_reviews_curso_seccion" ON "public"."seccion_reviews" USING "btree" ("curso_codigo", "seccion");



CREATE INDEX "idx_seccion_reviews_user" ON "public"."seccion_reviews" USING "btree" ("user_id");



CREATE INDEX "idx_sponsor_requests_status" ON "public"."sponsor_requests" USING "btree" ("status", "created_at" DESC);



CREATE INDEX "idx_sponsor_requests_user_id" ON "public"."sponsor_requests" USING "btree" ("user_id");



CREATE INDEX "idx_student_groups_carrera_curso" ON "public"."student_groups" USING "btree" ("carrera", "curso");



CREATE INDEX "idx_student_groups_carrera_upvotes" ON "public"."student_groups" USING "btree" ("carrera", "upvotes" DESC, "created_at" DESC) WHERE ("moderation_status" < 2);



CREATE INDEX "idx_student_groups_curso_trgm" ON "public"."student_groups" USING "gin" ("curso" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_student_groups_description_trgm" ON "public"."student_groups" USING "gin" ("description" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_student_groups_title_trgm" ON "public"."student_groups" USING "gin" ("title" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_student_groups_user_id" ON "public"."student_groups" USING "btree" ("user_id");



CREATE INDEX "idx_subscriptions_user" ON "public"."notification_subscriptions" USING "btree" ("user_id");



CREATE UNIQUE INDEX "idx_unique_user_entity_report" ON "public"."entity_reports" USING "btree" ("reporter_id", "entity_type", "entity_id");



CREATE INDEX "idx_user_notifications_comment_id" ON "public"."user_notifications" USING "btree" ("comment_id");



CREATE INDEX "idx_user_notifications_post_id" ON "public"."user_notifications" USING "btree" ("post_id");



CREATE INDEX "idx_user_notifications_unread" ON "public"."user_notifications" USING "btree" ("user_id", "created_at" DESC) WHERE ("read_at" IS NULL);



CREATE INDEX "idx_user_notifications_user_id" ON "public"."user_notifications" USING "btree" ("user_id");



CREATE INDEX "idx_user_roles_role" ON "public"."user_roles" USING "btree" ("role");



CREATE INDEX "idx_whatsapp_group_upvotes_user_id" ON "public"."student_group_upvotes" USING "btree" ("user_id");



CREATE INDEX "idx_whatsapp_groups_carrera" ON "public"."student_groups" USING "btree" ("carrera");



CREATE INDEX "idx_whatsapp_groups_created_at" ON "public"."student_groups" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_whatsapp_groups_curso" ON "public"."student_groups" USING "btree" ("curso");



CREATE INDEX "idx_whatsapp_groups_moderated_by" ON "public"."student_groups" USING "btree" ("moderated_by");



CREATE INDEX "idx_whatsapp_groups_moderation_status" ON "public"."student_groups" USING "btree" ("moderation_status");



CREATE INDEX "moderation_jobs_entity_idx" ON "public"."moderation_jobs" USING "btree" ("entity_table", "entity_id");



CREATE INDEX "moderation_jobs_queue_idx" ON "public"."moderation_jobs" USING "btree" ("status", "run_after", "priority", "created_at");



CREATE OR REPLACE TRIGGER "comments_enqueue" AFTER INSERT OR UPDATE OF "content", "gif_url" ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."trg_enqueue_comments"();



CREATE OR REPLACE TRIGGER "entity_reports_enqueue" AFTER INSERT ON "public"."entity_reports" FOR EACH ROW EXECUTE FUNCTION "public"."enqueue_from_report"();



CREATE OR REPLACE TRIGGER "marketplace_enqueue" AFTER INSERT OR UPDATE OF "title", "description", "image_urls", "video_url" ON "public"."marketplace_items" FOR EACH ROW EXECUTE FUNCTION "public"."trg_enqueue_marketplace"();



CREATE OR REPLACE TRIGGER "marketplace_reports_iud" INSTEAD OF INSERT OR DELETE OR UPDATE ON "public"."marketplace_reports" FOR EACH ROW EXECUTE FUNCTION "public"."legacy_marketplace_reports_iud"();



CREATE OR REPLACE TRIGGER "posts_enqueue" AFTER INSERT OR UPDATE OF "title", "content", "image_url", "gif_url" ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."trg_enqueue_posts"();



CREATE OR REPLACE TRIGGER "student_group_reports_iud" INSTEAD OF INSERT OR DELETE OR UPDATE ON "public"."student_group_reports" FOR EACH ROW EXECUTE FUNCTION "public"."legacy_student_group_reports_iud"();



CREATE OR REPLACE TRIGGER "student_groups_enqueue" AFTER INSERT OR UPDATE OF "title", "description", "link", "image_url" ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "public"."trg_enqueue_student_groups"();



CREATE OR REPLACE TRIGGER "trg_after_comment_insert_author" AFTER INSERT ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."after_comment_insert_author"();



CREATE OR REPLACE TRIGGER "trg_after_post_insert_author" AFTER INSERT ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."after_post_insert_author"();



CREATE OR REPLACE TRIGGER "trg_check_whatsapp_groups_limit" BEFORE INSERT ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "public"."check_whatsapp_groups_limit"();



CREATE OR REPLACE TRIGGER "trg_force_marketplace_item_owner" BEFORE INSERT ON "public"."marketplace_items" FOR EACH ROW EXECUTE FUNCTION "public"."force_marketplace_item_owner"();



CREATE OR REPLACE TRIGGER "trg_moderate_comments" BEFORE INSERT OR UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_entity_reports" BEFORE INSERT OR UPDATE ON "public"."entity_reports" FOR EACH ROW WHEN (("new"."entity_type" = ANY (ARRAY['user'::"text", 'group'::"text"]))) EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_posts" BEFORE INSERT OR UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_whatsapp_groups" BEFORE INSERT OR UPDATE ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_notify_comment_inserted" AFTER INSERT ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "_triggers"."notify_comment_inserted"();



CREATE OR REPLACE TRIGGER "trg_notify_new_post" AFTER INSERT ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "_triggers"."notify_new_post"();



CREATE OR REPLACE TRIGGER "trg_notify_post_liked" AFTER INSERT ON "public"."post_likes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."notify_post_liked"();



CREATE OR REPLACE TRIGGER "trg_prevent_nonmoderator_restore_comments" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_nonmoderator_restore"();



CREATE OR REPLACE TRIGGER "trg_prevent_nonmoderator_restore_groups" BEFORE UPDATE ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_nonmoderator_restore"();



CREATE OR REPLACE TRIGGER "trg_prevent_nonmoderator_restore_posts" BEFORE UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_nonmoderator_restore"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_comments" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_entity_reports" BEFORE UPDATE ON "public"."entity_reports" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_marketplace_items" BEFORE UPDATE ON "public"."marketplace_items" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_posts" BEFORE UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_whatsapp_groups" BEFORE UPDATE ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_set_comment_author_hash" BEFORE INSERT ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."handle_comment_author_hash"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."carreras" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."categorias_foro" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."categorias_marketplace" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."comment_authors" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."entity_reports" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."facultades" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."marketplace_items" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."marketplace_upvotes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."moderation_audit_log" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."notification_preferences" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."notification_subscriptions" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."post_authors" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."post_bookmarks" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."post_likes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."post_poll_options" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."post_poll_votes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."post_polls" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."seccion_reviews" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."sponsor_requests" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."student_group_upvotes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."user_notifications" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_created_at" BEFORE INSERT ON "public"."user_roles" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_created_at"();



CREATE OR REPLACE TRIGGER "trg_set_post_author_hash" BEFORE INSERT ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."handle_post_author_hash"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."carreras" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."categorias_foro" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."categorias_marketplace" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."entity_reports" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."facultades" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."marketplace_items" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."notification_preferences" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."post_poll_options" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."post_polls" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."seccion_reviews" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_set_updated_at" BEFORE UPDATE ON "public"."student_groups" FOR EACH ROW EXECUTE FUNCTION "_triggers"."set_updated_at"();



CREATE OR REPLACE TRIGGER "trg_sync_entity_report_counters" AFTER INSERT OR DELETE OR UPDATE ON "public"."entity_reports" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_entity_report_counters"();



CREATE OR REPLACE TRIGGER "trg_sync_group_upvotes" AFTER INSERT OR DELETE OR UPDATE ON "public"."student_group_upvotes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_group_upvotes_counter"();



CREATE OR REPLACE TRIGGER "trg_sync_marketplace_upvotes" AFTER INSERT OR DELETE OR UPDATE ON "public"."marketplace_upvotes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_marketplace_upvotes_counter"();



CREATE OR REPLACE TRIGGER "trg_sync_poll_votes_counter" AFTER INSERT OR DELETE OR UPDATE ON "public"."post_poll_votes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_poll_votes_counter"();



CREATE OR REPLACE TRIGGER "trg_sync_post_likes" AFTER INSERT OR DELETE OR UPDATE ON "public"."post_likes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_post_likes_counter"();



CREATE OR REPLACE TRIGGER "trg_sync_reposts_counter" AFTER INSERT OR DELETE OR UPDATE OF "quoted_post_id" ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_reposts_counter"();



CREATE OR REPLACE TRIGGER "user_reports_iud" INSTEAD OF INSERT OR DELETE OR UPDATE ON "public"."user_reports" FOR EACH ROW EXECUTE FUNCTION "public"."legacy_user_reports_iud"();



ALTER TABLE ONLY "public"."carreras"
    ADD CONSTRAINT "carreras_facultad_id_fkey" FOREIGN KEY ("facultad_id") REFERENCES "public"."facultades"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."comment_authors"
    ADD CONSTRAINT "comment_authors_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comment_authors"
    ADD CONSTRAINT "comment_authors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."entity_reports"
    ADD CONSTRAINT "entity_reports_entity_owner_id_fkey" FOREIGN KEY ("entity_owner_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."entity_reports"
    ADD CONSTRAINT "entity_reports_moderator_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."entity_reports"
    ADD CONSTRAINT "entity_reports_reported_user_id_fkey" FOREIGN KEY ("reported_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."entity_reports"
    ADD CONSTRAINT "entity_reports_reporter_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "fk_comments_parent_cascade" FOREIGN KEY ("parent_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."marketplace_items"
    ADD CONSTRAINT "marketplace_items_category_catalogo_fkey" FOREIGN KEY ("category") REFERENCES "public"."categorias_marketplace"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."marketplace_items"
    ADD CONSTRAINT "marketplace_items_facultad_catalogo_fkey" FOREIGN KEY ("facultad") REFERENCES "public"."facultades"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."marketplace_items"
    ADD CONSTRAINT "marketplace_items_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."marketplace_items"
    ADD CONSTRAINT "marketplace_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."marketplace_upvotes"
    ADD CONSTRAINT "marketplace_upvotes_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."marketplace_items"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."marketplace_upvotes"
    ADD CONSTRAINT "marketplace_upvotes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moderation_audit_log"
    ADD CONSTRAINT "moderation_audit_log_moderator_id_fkey" FOREIGN KEY ("moderator_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notification_preference_carreras"
    ADD CONSTRAINT "notification_preference_carreras_carrera_id_fkey" FOREIGN KEY ("carrera_id") REFERENCES "public"."carreras"("id") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_preference_carreras"
    ADD CONSTRAINT "notification_preference_carreras_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."notification_preferences"("user_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_subscriptions"
    ADD CONSTRAINT "notification_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_authors"
    ADD CONSTRAINT "post_authors_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_authors"
    ADD CONSTRAINT "post_authors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_bookmarks"
    ADD CONSTRAINT "post_bookmarks_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_bookmarks"
    ADD CONSTRAINT "post_bookmarks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_poll_options"
    ADD CONSTRAINT "post_poll_options_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "public"."post_polls"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_poll_votes"
    ADD CONSTRAINT "post_poll_votes_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "public"."post_polls"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_poll_votes"
    ADD CONSTRAINT "post_poll_votes_poll_option_fkey" FOREIGN KEY ("poll_id", "option_id") REFERENCES "public"."post_poll_options"("poll_id", "id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_poll_votes"
    ADD CONSTRAINT "post_poll_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_polls"
    ADD CONSTRAINT "post_polls_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_carrera_catalogo_fkey" FOREIGN KEY ("carrera") REFERENCES "public"."carreras"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_category_catalogo_fkey" FOREIGN KEY ("category") REFERENCES "public"."categorias_foro"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_quoted_post_id_fkey" FOREIGN KEY ("quoted_post_id") REFERENCES "public"."posts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_carrera_catalogo_fkey" FOREIGN KEY ("carrera") REFERENCES "public"."carreras"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seccion_reviews"
    ADD CONSTRAINT "seccion_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sponsor_requests"
    ADD CONSTRAINT "sponsor_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."student_groups"
    ADD CONSTRAINT "student_groups_carrera_catalogo_fkey" FOREIGN KEY ("carrera") REFERENCES "public"."carreras"("id") ON UPDATE CASCADE;



ALTER TABLE ONLY "public"."student_groups"
    ADD CONSTRAINT "student_groups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."student_group_upvotes"
    ADD CONSTRAINT "whatsapp_group_upvotes_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."student_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."student_group_upvotes"
    ADD CONSTRAINT "whatsapp_group_upvotes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."student_groups"
    ADD CONSTRAINT "whatsapp_groups_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



CREATE POLICY "Actualizar mis notificaciones (leídas)" ON "public"."user_notifications" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar mis preferencias de notificación" ON "public"."notification_preferences" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar propias publicaciones" ON "public"."posts" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar propios comentarios" ON "public"."comments" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Anyone can insert sponsor requests" ON "public"."sponsor_requests" FOR INSERT WITH CHECK (true);



CREATE POLICY "Authenticated users can create entity reports" ON "public"."entity_reports" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "reporter_id"));



CREATE POLICY "Authenticated users can delete own upvotes" ON "public"."marketplace_upvotes" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Authenticated users can insert own marketplace items" ON "public"."marketplace_items" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Authenticated users can insert upvotes" ON "public"."marketplace_upvotes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Authors can view own comment ownership" ON "public"."comment_authors" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Authors can view own post ownership" ON "public"."post_authors" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Borrar grupos dueño, admin o moderador" ON "public"."student_groups" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Borrar mis carreras de notificación" ON "public"."notification_preference_carreras" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Borrar mis notificaciones" ON "public"."user_notifications" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Borrar mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Cambiar o retirar voto" ON "public"."post_poll_votes" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear encuestas autenticados" ON "public"."post_polls" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Crear grupos solo autenticados" ON "public"."student_groups" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear mis carreras de notificación" ON "public"."notification_preference_carreras" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear mis preferencias de notificación" ON "public"."notification_preferences" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear opciones autenticados" ON "public"."post_poll_options" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Editar grupos dueño, admin o moderador" ON "public"."student_groups" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "El autor o admin pueden borrar la reseña de sección" ON "public"."seccion_reviews" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "El autor puede actualizar su reseña de sección" ON "public"."seccion_reviews" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Eliminar post guardado" ON "public"."post_bookmarks" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Eliminar propias publicaciones o admin" ON "public"."posts" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Eliminar propios comentarios o admin" ON "public"."comments" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Guardar post propio" ON "public"."post_bookmarks" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Lectura de comentarios (auth: dueño/admin/moderador ven estado" ON "public"."comments" FOR SELECT TO "authenticated" USING ((("moderation_status" IS DISTINCT FROM 2) OR ("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Lectura de marcadores propios" ON "public"."post_bookmarks" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Lectura de marketplace (auth: dueño/admin/moderador ven estado" ON "public"."marketplace_items" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")) OR (("moderation_status" IS DISTINCT FROM 2) AND ("status" = ANY (ARRAY['available'::"text", 'reserved'::"text"])))));



CREATE POLICY "Lectura de posts (auth: dueño/admin/moderador ven estado 2)" ON "public"."posts" FOR SELECT TO "authenticated" USING ((("moderation_status" IS DISTINCT FROM 2) OR ("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Lectura publica de catalogo" ON "public"."carreras" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de catalogo" ON "public"."categorias_foro" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de catalogo" ON "public"."categorias_marketplace" FOR SELECT USING (true);



CREATE POLICY "Lectura publica de catalogo" ON "public"."facultades" FOR SELECT USING (true);



CREATE POLICY "Lectura pública de comentarios (anon)" ON "public"."comments" FOR SELECT TO "anon" USING (("moderation_status" IS DISTINCT FROM 2));



CREATE POLICY "Lectura pública de encuestas" ON "public"."post_polls" FOR SELECT USING (true);



CREATE POLICY "Lectura pública de grupos (anon)" ON "public"."student_groups" FOR SELECT TO "anon" USING (("moderation_status" IS DISTINCT FROM 2));



CREATE POLICY "Lectura pública de grupos (auth)" ON "public"."student_groups" FOR SELECT TO "authenticated" USING ((("moderation_status" IS DISTINCT FROM 2) OR ("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Lectura pública de marketplace (anon)" ON "public"."marketplace_items" FOR SELECT TO "anon" USING ((("moderation_status" IS DISTINCT FROM 2) AND ("status" = ANY (ARRAY['available'::"text", 'reserved'::"text"]))));



CREATE POLICY "Lectura pública de opciones" ON "public"."post_poll_options" FOR SELECT USING (true);



CREATE POLICY "Lectura pública de posts (anon)" ON "public"."posts" FOR SELECT TO "anon" USING (("moderation_status" IS DISTINCT FROM 2));



CREATE POLICY "Lectura pública de reseñas de secciones" ON "public"."seccion_reviews" FOR SELECT USING (true);



CREATE POLICY "Lectura pública de votos" ON "public"."post_poll_votes" FOR SELECT USING (true);



CREATE POLICY "Lectura pública de votos de grupos" ON "public"."student_group_upvotes" FOR SELECT USING (true);



CREATE POLICY "Leer rol propio" ON "public"."user_roles" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Moderators can update entity reports" ON "public"."entity_reports" FOR UPDATE TO "authenticated" USING (("public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Permitir crear comentarios a usuarios autenticados" ON "public"."comments" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir crear publicaciones a usuarios autenticados" ON "public"."posts" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir dar like a usuarios autenticados" ON "public"."post_likes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir lectura de likes a todos" ON "public"."post_likes" FOR SELECT USING (true);



CREATE POLICY "Permitir quitar el propio like" ON "public"."post_likes" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Retirar voto solo por el usuario que lo emitió" ON "public"."student_group_upvotes" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Solo admins pueden ver auditoría" ON "public"."moderation_audit_log" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Users and moderators can delete entity reports" ON "public"."entity_reports" FOR DELETE TO "authenticated" USING ((("reporter_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) AS "is_pemtree_admin") OR ( SELECT "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")) AS "is_pemtree_moderator")));



CREATE POLICY "Users and moderators can view entity reports" ON "public"."entity_reports" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "reporter_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Users can delete their own marketplace items" ON "public"."marketplace_items" FOR DELETE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can read own profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "id") OR ( SELECT "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) AS "is_pemtree_admin")));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "id"));



CREATE POLICY "Users can update their own marketplace items" ON "public"."marketplace_items" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Users can view upvotes" ON "public"."marketplace_upvotes" FOR SELECT USING (true);



CREATE POLICY "Usuarios autenticados pueden reseñar secciones" ON "public"."seccion_reviews" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis carreras de notificación" ON "public"."notification_preference_carreras" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis notificaciones" ON "public"."user_notifications" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis preferencias de notificación" ON "public"."notification_preferences" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Votar en encuestas autenticados" ON "public"."post_poll_votes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Votar en grupos solo usuarios autenticados" ON "public"."student_group_upvotes" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."carreras" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categorias_foro" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."categorias_marketplace" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comment_authors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."entity_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."facultades" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."marketplace_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."marketplace_upvotes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moderation_audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moderation_jobs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_preference_carreras" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_authors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_bookmarks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_likes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_poll_options" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_poll_votes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_polls" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."seccion_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sponsor_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."student_group_upvotes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."student_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "_triggers" TO "anon";
GRANT USAGE ON SCHEMA "_triggers" TO "authenticated";
GRANT USAGE ON SCHEMA "_triggers" TO "service_role";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";









REVOKE ALL ON FUNCTION "_triggers"."crear_notificacion_foro"("p_user_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_actor_alias" "text", "p_post_id" "uuid", "p_comment_id" "uuid", "p_actor_id" "uuid") FROM PUBLIC;



REVOKE ALL ON FUNCTION "_triggers"."notify_comment_inserted"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "_triggers"."notify_new_post"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "_triggers"."notify_post_liked"() FROM PUBLIC;



GRANT ALL ON FUNCTION "_triggers"."sync_group_reported_counter"() TO "anon";
GRANT ALL ON FUNCTION "_triggers"."sync_group_reported_counter"() TO "authenticated";



GRANT ALL ON FUNCTION "_triggers"."sync_group_upvotes_counter"() TO "anon";
GRANT ALL ON FUNCTION "_triggers"."sync_group_upvotes_counter"() TO "authenticated";



GRANT ALL ON FUNCTION "_triggers"."sync_post_likes_counter"() TO "anon";
GRANT ALL ON FUNCTION "_triggers"."sync_post_likes_counter"() TO "authenticated";


































































































































































































































































REVOKE ALL ON FUNCTION "public"."_cancelar_jobs_panel"("p_tabla" "text", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_cancelar_jobs_panel"("p_tabla" "text", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."after_comment_insert_author"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."after_comment_insert_author"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."after_post_insert_author"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."after_post_insert_author"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_content_moderation"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_content_moderation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_content_moderation"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_whatsapp_groups_limit"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_whatsapp_groups_limit"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."claim_moderation_job"("p_worker" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_moderation_job"("p_worker" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."complete_moderation_job"("p_job_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_moderation_job"("p_job_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_inappropriate_posts"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_inappropriate_posts"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_old_posts"("months_old" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_old_posts"("months_old" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."enqueue_from_report"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enqueue_from_report"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."enqueue_moderation"("p_table" "text", "p_id" "uuid", "p_hash" "text", "p_priority" integer, "p_has_image" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."enqueue_moderation"("p_table" "text", "p_id" "uuid", "p_hash" "text", "p_priority" integer, "p_has_image" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."fail_moderation_job"("p_job_id" "uuid", "p_error" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."fail_moderation_job"("p_job_id" "uuid", "p_error" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."force_marketplace_item_owner"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."force_marketplace_item_owner"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid", "p_salt" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid", "p_salt" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid", "p_salt" "text") TO "service_role";
GRANT ALL ON FUNCTION "public"."generate_author_hash"("p_user_id" "uuid", "p_salt" "text") TO "anon";



REVOKE ALL ON FUNCTION "public"."get_push_secrets"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_push_secrets"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_comment_author_hash"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_comment_author_hash"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_user_profile"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user_profile"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_post_author_hash"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_post_author_hash"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."legacy_marketplace_reports_iud"() TO "anon";
GRANT ALL ON FUNCTION "public"."legacy_marketplace_reports_iud"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."legacy_marketplace_reports_iud"() TO "service_role";



GRANT ALL ON FUNCTION "public"."legacy_student_group_reports_iud"() TO "anon";
GRANT ALL ON FUNCTION "public"."legacy_student_group_reports_iud"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."legacy_student_group_reports_iud"() TO "service_role";



GRANT ALL ON FUNCTION "public"."legacy_user_reports_iud"() TO "anon";
GRANT ALL ON FUNCTION "public"."legacy_user_reports_iud"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."legacy_user_reports_iud"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."limpieza_semestral_pemtree"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."limpieza_semestral_pemtree"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."marcar_pendientes_error"("p_horas" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."marcar_pendientes_error"("p_horas" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."moderate_marketplace_item"("target_item_id" "uuid", "new_status" integer, "p_label" "text", "p_confidence" double precision, "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."moderate_marketplace_item"("target_item_id" "uuid", "new_status" integer, "p_label" "text", "p_confidence" double precision, "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."moderate_marketplace_item"("target_item_id" "uuid", "new_status" integer, "p_label" "text", "p_confidence" double precision, "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."panel_aprobar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."panel_aprobar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."panel_aprobar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."panel_cola_revision"("p_umbral" double precision) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."panel_cola_revision"("p_umbral" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."panel_cola_revision"("p_umbral" double precision) TO "service_role";



REVOKE ALL ON FUNCTION "public"."panel_rechazar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."panel_rechazar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."panel_rechazar"("p_tabla" "text", "p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."panel_remoderar"("p_tabla" "text", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."panel_remoderar"("p_tabla" "text", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."panel_remoderar"("p_tabla" "text", "p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_nonmoderator_restore"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_nonmoderator_restore"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_nonmoderator_restore"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_inappropriate_content"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_inappropriate_content"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_old_content"("p_months" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_old_content"("p_months" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_reported_groups"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_reported_groups"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."recalcular_contadores"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."recalcular_contadores"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_forum_comment"("p_comment_id" "uuid", "p_reason" "text", "p_details" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_forum_comment"("p_comment_id" "uuid", "p_reason" "text", "p_details" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_forum_comment"("p_comment_id" "uuid", "p_reason" "text", "p_details" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_forum_post"("p_post_id" "uuid", "p_reason" "text", "p_details" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_forum_post"("p_post_id" "uuid", "p_reason" "text", "p_details" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_forum_post"("p_post_id" "uuid", "p_reason" "text", "p_details" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_marketplace_item"("target_item_id" "uuid", "report_reason" "text", "target_seller_id" "uuid", "target_seller_alias" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_marketplace_item"("target_item_id" "uuid", "report_reason" "text", "target_seller_id" "uuid", "target_seller_alias" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_marketplace_item"("target_item_id" "uuid", "report_reason" "text", "target_seller_id" "uuid", "target_seller_alias" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."reset_moderation_on_edit"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."reset_moderation_on_edit"() TO "anon";
GRANT ALL ON FUNCTION "public"."reset_moderation_on_edit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_moderation_on_edit"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rls_auto_enable"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_enqueue_comments"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_enqueue_comments"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_enqueue_marketplace"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_enqueue_marketplace"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_enqueue_posts"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_enqueue_posts"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."trg_enqueue_student_groups"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."trg_enqueue_student_groups"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."user_exists"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."user_exists"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."user_exists"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."v_moderation_queue"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."v_moderation_queue"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."verificar_contadores"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."verificar_contadores"() TO "service_role";
























GRANT ALL ON TABLE "public"."carreras" TO "anon";
GRANT ALL ON TABLE "public"."carreras" TO "authenticated";
GRANT ALL ON TABLE "public"."carreras" TO "service_role";



GRANT ALL ON TABLE "public"."categorias_foro" TO "anon";
GRANT ALL ON TABLE "public"."categorias_foro" TO "authenticated";
GRANT ALL ON TABLE "public"."categorias_foro" TO "service_role";



GRANT ALL ON TABLE "public"."categorias_marketplace" TO "anon";
GRANT ALL ON TABLE "public"."categorias_marketplace" TO "authenticated";
GRANT ALL ON TABLE "public"."categorias_marketplace" TO "service_role";



GRANT ALL ON TABLE "public"."comment_authors" TO "anon";
GRANT ALL ON TABLE "public"."comment_authors" TO "authenticated";
GRANT ALL ON TABLE "public"."comment_authors" TO "service_role";



GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE "public"."comments" TO "anon";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";



GRANT SELECT("id") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("id") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("post_id") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("post_id") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("author_alias") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("author_alias") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("content") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("content") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("created_at") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("created_at") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("parent_id") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("parent_id") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("moderation_status") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("moderation_status") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("gif_url") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("gif_url") ON TABLE "public"."comments" TO "authenticated";



GRANT SELECT("author_hash") ON TABLE "public"."comments" TO "anon";
GRANT SELECT("author_hash") ON TABLE "public"."comments" TO "authenticated";



GRANT ALL ON TABLE "public"."entity_reports" TO "anon";
GRANT ALL ON TABLE "public"."entity_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."entity_reports" TO "service_role";



GRANT ALL ON TABLE "public"."facultades" TO "anon";
GRANT ALL ON TABLE "public"."facultades" TO "authenticated";
GRANT ALL ON TABLE "public"."facultades" TO "service_role";



GRANT ALL ON TABLE "public"."marketplace_items" TO "anon";
GRANT ALL ON TABLE "public"."marketplace_items" TO "authenticated";
GRANT ALL ON TABLE "public"."marketplace_items" TO "service_role";



GRANT ALL ON TABLE "public"."marketplace_reports" TO "anon";
GRANT ALL ON TABLE "public"."marketplace_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."marketplace_reports" TO "service_role";



GRANT ALL ON TABLE "public"."marketplace_upvotes" TO "anon";
GRANT ALL ON TABLE "public"."marketplace_upvotes" TO "authenticated";
GRANT ALL ON TABLE "public"."marketplace_upvotes" TO "service_role";



GRANT ALL ON TABLE "public"."moderation_audit_log" TO "anon";
GRANT ALL ON TABLE "public"."moderation_audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."moderation_audit_log" TO "service_role";



GRANT ALL ON TABLE "public"."moderation_jobs" TO "service_role";



GRANT ALL ON TABLE "public"."notification_preference_carreras" TO "anon";
GRANT ALL ON TABLE "public"."notification_preference_carreras" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_preference_carreras" TO "service_role";



GRANT ALL ON TABLE "public"."notification_preferences" TO "anon";
GRANT ALL ON TABLE "public"."notification_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."notification_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."notification_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."post_authors" TO "anon";
GRANT ALL ON TABLE "public"."post_authors" TO "authenticated";
GRANT ALL ON TABLE "public"."post_authors" TO "service_role";



GRANT ALL ON TABLE "public"."post_bookmarks" TO "anon";
GRANT ALL ON TABLE "public"."post_bookmarks" TO "authenticated";
GRANT ALL ON TABLE "public"."post_bookmarks" TO "service_role";



GRANT ALL ON TABLE "public"."post_likes" TO "anon";
GRANT ALL ON TABLE "public"."post_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."post_likes" TO "service_role";



GRANT ALL ON TABLE "public"."post_poll_options" TO "anon";
GRANT ALL ON TABLE "public"."post_poll_options" TO "authenticated";
GRANT ALL ON TABLE "public"."post_poll_options" TO "service_role";



GRANT ALL ON TABLE "public"."post_poll_votes" TO "anon";
GRANT ALL ON TABLE "public"."post_poll_votes" TO "authenticated";
GRANT ALL ON TABLE "public"."post_poll_votes" TO "service_role";



GRANT ALL ON TABLE "public"."post_polls" TO "anon";
GRANT ALL ON TABLE "public"."post_polls" TO "authenticated";
GRANT ALL ON TABLE "public"."post_polls" TO "service_role";



GRANT INSERT,REFERENCES,TRIGGER,MAINTAIN ON TABLE "public"."posts" TO "anon";
GRANT INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."posts" TO "authenticated";
GRANT ALL ON TABLE "public"."posts" TO "service_role";



GRANT SELECT("id") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("id") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("title") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("title") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("category") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("category") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("content") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("content") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("author_alias") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("author_alias") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("likes") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("likes") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("created_at") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("created_at") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("carrera") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("carrera") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("image_url") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("image_url") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("moderation_status") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("moderation_status") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("quoted_post_id") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("quoted_post_id") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("gif_url") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("gif_url") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("is_pinned") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("is_pinned") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("reposts_count") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("reposts_count") ON TABLE "public"."posts" TO "authenticated";



GRANT SELECT("author_hash") ON TABLE "public"."posts" TO "anon";
GRANT SELECT("author_hash") ON TABLE "public"."posts" TO "authenticated";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."seccion_reviews" TO "anon";
GRANT ALL ON TABLE "public"."seccion_reviews" TO "authenticated";
GRANT ALL ON TABLE "public"."seccion_reviews" TO "service_role";



GRANT ALL ON TABLE "public"."seccion_reputation" TO "anon";
GRANT ALL ON TABLE "public"."seccion_reputation" TO "authenticated";
GRANT ALL ON TABLE "public"."seccion_reputation" TO "service_role";



GRANT ALL ON TABLE "public"."sponsor_requests" TO "anon";
GRANT ALL ON TABLE "public"."sponsor_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."sponsor_requests" TO "service_role";



GRANT ALL ON TABLE "public"."student_group_reports" TO "anon";
GRANT ALL ON TABLE "public"."student_group_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."student_group_reports" TO "service_role";



GRANT ALL ON TABLE "public"."student_group_upvotes" TO "anon";
GRANT ALL ON TABLE "public"."student_group_upvotes" TO "authenticated";
GRANT ALL ON TABLE "public"."student_group_upvotes" TO "service_role";



GRANT ALL ON TABLE "public"."student_groups" TO "anon";
GRANT ALL ON TABLE "public"."student_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."student_groups" TO "service_role";



GRANT ALL ON TABLE "public"."user_notifications" TO "anon";
GRANT ALL ON TABLE "public"."user_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."user_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."user_reports" TO "anon";
GRANT ALL ON TABLE "public"."user_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."user_reports" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."v_public_comments" TO "service_role";
GRANT SELECT ON TABLE "public"."v_public_comments" TO "anon";
GRANT SELECT ON TABLE "public"."v_public_comments" TO "authenticated";



GRANT ALL ON TABLE "public"."v_public_posts" TO "service_role";
GRANT SELECT ON TABLE "public"."v_public_posts" TO "anon";
GRANT SELECT ON TABLE "public"."v_public_posts" TO "authenticated";



GRANT ALL ON TABLE "public"."whatsapp_group_reports" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_group_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_group_reports" TO "service_role";



GRANT ALL ON TABLE "public"."whatsapp_group_upvotes" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_group_upvotes" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_group_upvotes" TO "service_role";



GRANT ALL ON TABLE "public"."whatsapp_groups" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_groups" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































