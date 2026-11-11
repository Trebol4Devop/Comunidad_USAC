-- =============================================================================
-- Fix de regresión B-04: check_whatsapp_groups_limit debe ser SECURITY DEFINER
-- =============================================================================
-- La revocación de SELECT (user_id) en public.student_groups impide que el
-- trigger, ejecutado como SECURITY INVOKER, cuente los grupos del usuario.
-- Se redefine como SECURITY DEFINER y se excluyen los soft-deleted.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.check_whatsapp_groups_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_count integer;
    v_target_user uuid;
BEGIN
    v_target_user := COALESCE(auth.uid(), NEW.user_id);

    -- Moderadores y administradores no tienen límite.
    IF public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()) THEN
        RETURN NEW;
    END IF;

    SELECT COUNT(*)
      INTO v_count
      FROM public.student_groups
     WHERE user_id = v_target_user
       AND deleted_at IS NULL;

    IF v_count >= 5 THEN
        RAISE EXCEPTION 'Límite de 5 grupos alcanzado: Un usuario normal no puede publicar más de 5 grupos en la comunidad. Si necesitas publicar más, comunícate con un administrador o moderador.';
    END IF;

    RETURN NEW;
END;
$fn$;
