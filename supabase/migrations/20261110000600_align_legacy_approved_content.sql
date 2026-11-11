-- =============================================================================
-- Alineación de contenido legado aprobado por moderación previa
-- =============================================================================
-- PEMTREE usaba moderation_status = 1 como "visible bajo revisión". El nuevo
-- contrato legal usa 1 = oculto/en revisión y 0 = visible. Para no vaciar el
-- feed, se aprueban (0) SOLO las entidades cuya última auditoría es
-- 'appropriate' y que no están bajo retención legal. El resto permanece oculto.
-- =============================================================================

-- 1. Auditoría de la alineación (posts)
WITH latest AS (
    SELECT entity_table, entity_id, moderation_label,
           row_number() OVER (PARTITION BY entity_table, entity_id ORDER BY created_at DESC) AS rn
    FROM public.moderation_audit_log
    WHERE entity_table IN ('posts', 'comments', 'student_groups')
      AND moderation_label <> 'LEGACY_APPROVAL_ALIGNMENT'
), approved AS (
    SELECT entity_table, entity_id FROM latest WHERE rn = 1 AND moderation_label = 'appropriate'
)
INSERT INTO public.moderation_audit_log (
    moderator_id, entity_table, entity_id, justification, is_automated,
    moderation_label, confidence, created_at
)
SELECT NULL, 'posts', p.id,
       'Alineación de contenido legado: aprobado previamente por moderación (status 1 -> 0)',
       true, 'LEGACY_APPROVAL_ALIGNMENT', 1.0, now()
FROM approved a
JOIN public.posts p ON p.id = a.entity_id
WHERE a.entity_table = 'posts'
  AND p.moderation_status = 1
  AND p.is_legal_hold = false
  AND NOT EXISTS (
      SELECT 1 FROM public.moderation_audit_log x
      WHERE x.entity_table = 'posts' AND x.entity_id = p.id
        AND x.moderation_label = 'LEGACY_APPROVAL_ALIGNMENT'
  );

-- 2. Auditoría de la alineación (comments)
WITH latest AS (
    SELECT entity_table, entity_id, moderation_label,
           row_number() OVER (PARTITION BY entity_table, entity_id ORDER BY created_at DESC) AS rn
    FROM public.moderation_audit_log
    WHERE entity_table IN ('posts', 'comments', 'student_groups')
      AND moderation_label <> 'LEGACY_APPROVAL_ALIGNMENT'
), approved AS (
    SELECT entity_table, entity_id FROM latest WHERE rn = 1 AND moderation_label = 'appropriate'
)
INSERT INTO public.moderation_audit_log (
    moderator_id, entity_table, entity_id, justification, is_automated,
    moderation_label, confidence, created_at
)
SELECT NULL, 'comments', c.id,
       'Alineación de contenido legado: aprobado previamente por moderación (status 1 -> 0)',
       true, 'LEGACY_APPROVAL_ALIGNMENT', 1.0, now()
FROM approved a
JOIN public.comments c ON c.id = a.entity_id
WHERE a.entity_table = 'comments'
  AND c.moderation_status = 1
  AND c.is_legal_hold = false
  AND NOT EXISTS (
      SELECT 1 FROM public.moderation_audit_log x
      WHERE x.entity_table = 'comments' AND x.entity_id = c.id
        AND x.moderation_label = 'LEGACY_APPROVAL_ALIGNMENT'
  );

-- 3. Auditoría de la alineación (student_groups)
WITH latest AS (
    SELECT entity_table, entity_id, moderation_label,
           row_number() OVER (PARTITION BY entity_table, entity_id ORDER BY created_at DESC) AS rn
    FROM public.moderation_audit_log
    WHERE entity_table IN ('posts', 'comments', 'student_groups')
      AND moderation_label <> 'LEGACY_APPROVAL_ALIGNMENT'
), approved AS (
    SELECT entity_table, entity_id FROM latest WHERE rn = 1 AND moderation_label = 'appropriate'
)
INSERT INTO public.moderation_audit_log (
    moderator_id, entity_table, entity_id, justification, is_automated,
    moderation_label, confidence, created_at
)
SELECT NULL, 'student_groups', g.id,
       'Alineación de contenido legado: aprobado previamente por moderación (status 1 -> 0)',
       true, 'LEGACY_APPROVAL_ALIGNMENT', 1.0, now()
FROM approved a
JOIN public.student_groups g ON g.id = a.entity_id
WHERE a.entity_table = 'student_groups'
  AND g.moderation_status = 1
  AND g.is_legal_hold = false
  AND NOT EXISTS (
      SELECT 1 FROM public.moderation_audit_log x
      WHERE x.entity_table = 'student_groups' AND x.entity_id = g.id
        AND x.moderation_label = 'LEGACY_APPROVAL_ALIGNMENT'
  );

-- 4. Aprobar posts
WITH latest AS (
    SELECT entity_table, entity_id, moderation_label,
           row_number() OVER (PARTITION BY entity_table, entity_id ORDER BY created_at DESC) AS rn
    FROM public.moderation_audit_log
    WHERE entity_table IN ('posts', 'comments', 'student_groups')
      AND moderation_label <> 'LEGACY_APPROVAL_ALIGNMENT'
), approved AS (
    SELECT entity_table, entity_id FROM latest WHERE rn = 1 AND moderation_label = 'appropriate'
)
UPDATE public.posts p
SET moderation_status = 0,
    updated_at = now()
FROM approved a
WHERE a.entity_table = 'posts'
  AND a.entity_id = p.id
  AND p.moderation_status = 1
  AND p.is_legal_hold = false;

-- 5. Aprobar comments
WITH latest AS (
    SELECT entity_table, entity_id, moderation_label,
           row_number() OVER (PARTITION BY entity_table, entity_id ORDER BY created_at DESC) AS rn
    FROM public.moderation_audit_log
    WHERE entity_table IN ('posts', 'comments', 'student_groups')
      AND moderation_label <> 'LEGACY_APPROVAL_ALIGNMENT'
), approved AS (
    SELECT entity_table, entity_id FROM latest WHERE rn = 1 AND moderation_label = 'appropriate'
)
UPDATE public.comments c
SET moderation_status = 0,
    updated_at = now()
FROM approved a
WHERE a.entity_table = 'comments'
  AND a.entity_id = c.id
  AND c.moderation_status = 1
  AND c.is_legal_hold = false;

-- 6. Aprobar student_groups
WITH latest AS (
    SELECT entity_table, entity_id, moderation_label,
           row_number() OVER (PARTITION BY entity_table, entity_id ORDER BY created_at DESC) AS rn
    FROM public.moderation_audit_log
    WHERE entity_table IN ('posts', 'comments', 'student_groups')
      AND moderation_label <> 'LEGACY_APPROVAL_ALIGNMENT'
), approved AS (
    SELECT entity_table, entity_id FROM latest WHERE rn = 1 AND moderation_label = 'appropriate'
)
UPDATE public.student_groups g
SET moderation_status = 0,
    updated_at = now()
FROM approved a
WHERE a.entity_table = 'student_groups'
  AND a.entity_id = g.id
  AND g.moderation_status = 1
  AND g.is_legal_hold = false;

-- 7. Alinear las vistas de grupos/marketplace al contrato status = 0
--    (el dueño sigue viendo su propio contenido en revisión).
CREATE OR REPLACE VIEW public.safe_student_groups
WITH (security_invoker = true)
AS
SELECT
    id, title, carrera, curso, section, link, description, author_alias,
    upvotes, reported_count, created_at, image_url, moderation_status,
    moderation_label, moderation_confidence, moderation_reason,
    moderated_at, moderated_by, platform, updated_at, deleted_at,
    is_legal_hold,
    public.is_my_group(id) AS is_mine
FROM public.student_groups
WHERE deleted_at IS NULL
  AND (moderation_status = 0 OR public.is_my_group(id));

CREATE OR REPLACE VIEW public.safe_marketplace_items
WITH (security_invoker = true)
AS
SELECT
    id, title, description, price, is_free, category, facultad, sede,
    building_code, location_detail, contact_whatsapp, contact_telegram,
    image_urls, video_url, is_sponsored, sponsor_badge_text, author_alias,
    upvotes, moderation_status, created_at, contact_instagram,
    contact_messenger, social_links, reported_count, status,
    moderation_label, moderation_confidence, moderation_reason,
    moderated_at, moderated_by, updated_at, deleted_at, is_legal_hold,
    public.is_my_marketplace_item(id) AS is_mine
FROM public.marketplace_items
WHERE deleted_at IS NULL
  AND (moderation_status = 0 OR public.is_my_marketplace_item(id))
  AND (status IN ('available', 'reserved') OR public.is_my_marketplace_item(id));
