# Evidencia real de la base de datos — Supabase `hfvsstkfqszpjrsrwhql`

Capturada por SQL directo contra el proyecto **compartido** por `PEMTREE-admin` y `Comunidad_USAC`.
Esta evidencia es la fuente de verdad: cualquier hallazgo que no encaje aquí debe marcarse como NO VERIFICADO.

## 1. Relaciones: RLS y nº de políticas

| Relación | Tipo | RLS | Políticas |
|---|---|---|---|
| `alias_adjectives` | TABLE | True | 1 |
| `alias_nouns` | TABLE | True | 1 |
| `carreras` | TABLE | True | 1 |
| `categorias_foro` | TABLE | True | 1 |
| `categorias_marketplace` | TABLE | True | 1 |
| `comment_authors` | TABLE | True | 1 |
| `comments` | TABLE | True | 5 |
| `entity_reports` | TABLE | True | 4 |
| `facultades` | TABLE | True | 1 |
| `marketplace_items` | TABLE | True | 5 |
| `marketplace_upvotes` | TABLE | True | 3 |
| `moderation_audit_log` | TABLE | True | 1 |
| `moderation_jobs` | TABLE | True | 0 |
| `notification_preference_carreras` | TABLE | True | 3 |
| `notification_preferences` | TABLE | True | 3 |
| `notification_subscriptions` | TABLE | True | 4 |
| `post_authors` | TABLE | True | 1 |
| `post_bookmarks` | TABLE | True | 3 |
| `post_likes` | TABLE | True | 3 |
| `post_poll_options` | TABLE | True | 2 |
| `post_poll_votes` | TABLE | True | 3 |
| `post_polls` | TABLE | True | 2 |
| `posts` | TABLE | True | 5 |
| `profiles` | TABLE | True | 3 |
| `seccion_review_upvotes` | TABLE | True | 3 |
| `seccion_reviews` | TABLE | True | 4 |
| `sponsor_requests` | TABLE | True | 1 |
| `student_group_upvotes` | TABLE | True | 3 |
| `student_groups` | TABLE | True | 5 |
| `user_notifications` | TABLE | True | 3 |
| `user_roles` | TABLE | True | 2 |
| `marketplace_reports` | VIEW | False | 0 |
| `safe_comments` | VIEW | False | 0 |
| `safe_marketplace_items` | VIEW | False | 0 |
| `safe_posts_feed` | VIEW | False | 0 |
| `safe_seccion_reviews` | VIEW | False | 0 |
| `safe_student_groups` | VIEW | False | 0 |
| `seccion_reputation` | VIEW | False | 0 |
| `student_group_reports` | VIEW | False | 0 |
| `user_reports` | VIEW | False | 0 |
| `v_public_comments` | VIEW | False | 0 |
| `v_public_posts` | VIEW | False | 0 |
| `whatsapp_group_reports` | VIEW | False | 0 |
| `whatsapp_group_upvotes` | VIEW | False | 0 |
| `whatsapp_groups` | VIEW | False | 0 |

## 2. Políticas RLS (texto exacto del catálogo)

### `alias_adjectives` — Permitir lectura publica alias_adjectives
- cmd: `SELECT` · roles: `{anon,authenticated}`
- USING: `true`

### `alias_nouns` — Permitir lectura publica alias_nouns
- cmd: `SELECT` · roles: `{anon,authenticated}`
- USING: `true`

### `carreras` — Lectura publica de catalogo
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `categorias_foro` — Lectura publica de catalogo
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `categorias_marketplace` — Lectura publica de catalogo
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `comment_authors` — Authors can view own comment ownership
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((auth.uid() IS NOT NULL) AND (auth.uid() = user_id))`

### `comments` — deny_all_delete_comments
- cmd: `DELETE` · roles: `{anon,authenticated}`
- USING: `false`

### `comments` — Permitir crear comentarios a usuarios autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `comments` — Lectura de comentarios (auth: dueño/admin/moderador ven estado
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((moderation_status IS DISTINCT FROM 2) OR (user_id = ( SELECT auth.uid() AS uid)) OR is_pemtree_admin(( SELECT auth.uid() AS uid)) OR is_pemtree_moderator(( SELECT auth.uid() AS uid)))`

### `comments` — Lectura pública de comentarios (anon)
- cmd: `SELECT` · roles: `{anon}`
- USING: `(moderation_status IS DISTINCT FROM 2)`

### `comments` — Actualizar propios comentarios o moderador
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `(((auth.uid() IS NOT NULL) AND ((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM comment_authors
  WHERE ((comment_authors.comment_id = comments.id) AND (comment_authors.user_id = auth.uid())))))) OR is_pemtree_moderator(auth.uid()))`

### `entity_reports` — Users and moderators can delete entity reports
- cmd: `DELETE` · roles: `{authenticated}`
- USING: `((reporter_id = ( SELECT auth.uid() AS uid)) OR ( SELECT is_pemtree_admin(( SELECT auth.uid() AS uid)) AS is_pemtree_admin) OR ( SELECT is_pemtree_moderator(( SELECT auth.uid() AS uid)) AS is_pemtree_moderator))`

### `entity_reports` — Authenticated users can create entity reports
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = reporter_id)`

### `entity_reports` — Users and moderators can view entity reports
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((( SELECT auth.uid() AS uid) = reporter_id) OR is_pemtree_admin(( SELECT auth.uid() AS uid)) OR is_pemtree_moderator(( SELECT auth.uid() AS uid)))`

### `entity_reports` — Moderators can update entity reports
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `(is_pemtree_admin(( SELECT auth.uid() AS uid)) OR is_pemtree_moderator(( SELECT auth.uid() AS uid)))`

### `facultades` — Lectura publica de catalogo
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `marketplace_items` — deny_all_delete_marketplace_items
- cmd: `DELETE` · roles: `{anon,authenticated}`
- USING: `false`

### `marketplace_items` — Authenticated users can insert own marketplace items
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `marketplace_items` — Lectura de marketplace (auth: dueño/admin/moderador ven estado
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((user_id = ( SELECT auth.uid() AS uid)) OR is_pemtree_admin(( SELECT auth.uid() AS uid)) OR is_pemtree_moderator(( SELECT auth.uid() AS uid)) OR ((moderation_status IS DISTINCT FROM 2) AND (status = ANY (ARRAY['available'::text, 'reserved'::text]))))`

### `marketplace_items` — Lectura pública de marketplace (anon)
- cmd: `SELECT` · roles: `{anon}`
- USING: `((moderation_status IS DISTINCT FROM 2) AND (status = ANY (ARRAY['available'::text, 'reserved'::text])))`

### `marketplace_items` — Users can update their own marketplace items o moderador
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `(((auth.uid() IS NOT NULL) AND (auth.uid() = user_id)) OR is_pemtree_moderator(auth.uid()))`

### `marketplace_upvotes` — Authenticated users can delete own upvotes
- cmd: `DELETE` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `marketplace_upvotes` — Authenticated users can insert upvotes
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `marketplace_upvotes` — Leer solo mis upvotes de marketplace
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(auth.uid() = user_id)`

### `moderation_audit_log` — Solo admins pueden ver auditoría
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((( SELECT auth.uid() AS uid) IS NOT NULL) AND is_pemtree_admin(( SELECT auth.uid() AS uid)))`

### `notification_preference_carreras` — Borrar mis carreras de notificación
- cmd: `DELETE` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_preference_carreras` — Crear mis carreras de notificación
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_preference_carreras` — Ver mis carreras de notificación
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_preferences` — Crear mis preferencias de notificación
- cmd: `INSERT` · roles: `{public}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_preferences` — Ver mis preferencias de notificación
- cmd: `SELECT` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_preferences` — Actualizar mis preferencias de notificación
- cmd: `UPDATE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_subscriptions` — Borrar mis suscripciones de notificación
- cmd: `DELETE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_subscriptions` — Crear mis suscripciones de notificación
- cmd: `INSERT` · roles: `{public}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_subscriptions` — Ver mis suscripciones de notificación
- cmd: `SELECT` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `notification_subscriptions` — Actualizar mis suscripciones de notificación
- cmd: `UPDATE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_authors` — Authors can view own post ownership
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((auth.uid() IS NOT NULL) AND (auth.uid() = user_id))`

### `post_bookmarks` — Eliminar post guardado
- cmd: `DELETE` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_bookmarks` — Guardar post propio
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_bookmarks` — Lectura de marcadores propios
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_likes` — Permitir quitar el propio like
- cmd: `DELETE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_likes` — Permitir dar like a usuarios autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_likes` — Leer solo mis likes
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(auth.uid() = user_id)`

### `post_poll_options` — Crear opciones autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `true`

### `post_poll_options` — Lectura pública de opciones
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `post_poll_votes` — Cambiar o retirar voto
- cmd: `DELETE` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_poll_votes` — Votar en encuestas autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `post_poll_votes` — Leer solo mis votos de encuesta
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(auth.uid() = user_id)`

### `post_polls` — Crear encuestas autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `true`

### `post_polls` — Lectura pública de encuestas
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `posts` — deny_all_delete_posts
- cmd: `DELETE` · roles: `{anon,authenticated}`
- USING: `false`

### `posts` — Permitir crear publicaciones a usuarios autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `posts` — Lectura de posts (auth: dueño/admin/moderador ven estado 2)
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((moderation_status IS DISTINCT FROM 2) OR (user_id = ( SELECT auth.uid() AS uid)) OR is_pemtree_admin(( SELECT auth.uid() AS uid)) OR is_pemtree_moderator(( SELECT auth.uid() AS uid)))`

### `posts` — Lectura pública de posts (anon)
- cmd: `SELECT` · roles: `{anon}`
- USING: `(moderation_status IS DISTINCT FROM 2)`

### `posts` — Actualizar propias publicaciones o moderador
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `(((auth.uid() IS NOT NULL) AND ((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM post_authors
  WHERE ((post_authors.post_id = posts.id) AND (post_authors.user_id = auth.uid())))))) OR is_pemtree_moderator(auth.uid()))`

### `profiles` — Moderators can read profiles
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `is_pemtree_moderator(( SELECT auth.uid() AS uid))`

### `profiles` — Users can read own profile
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((( SELECT auth.uid() AS uid) = id) OR ( SELECT is_pemtree_admin(( SELECT auth.uid() AS uid)) AS is_pemtree_admin))`

### `profiles` — Users can update own profile
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = id)`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = id)`

### `seccion_review_upvotes` — seccion_review_upvotes_delete_own
- cmd: `DELETE` · roles: `{authenticated}`
- USING: `(auth.uid() = user_id)`

### `seccion_review_upvotes` — seccion_review_upvotes_insert_own
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(auth.uid() = user_id)`

### `seccion_review_upvotes` — seccion_review_upvotes_select_own
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(auth.uid() = user_id)`

### `seccion_reviews` — deny_all_delete_seccion_reviews
- cmd: `DELETE` · roles: `{anon,authenticated}`
- USING: `false`

### `seccion_reviews` — Usuarios autenticados pueden reseñar secciones
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `seccion_reviews` — Lectura pública de reseñas de secciones
- cmd: `SELECT` · roles: `{public}`
- USING: `true`

### `seccion_reviews` — El autor puede actualizar su reseña de sección
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `sponsor_requests` — Anyone can insert sponsor requests
- cmd: `INSERT` · roles: `{public}`
- USING: `None`
- WITH CHECK: `true`

### `student_group_upvotes` — Retirar voto solo por el usuario que lo emitió
- cmd: `DELETE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `student_group_upvotes` — Votar en grupos solo usuarios autenticados
- cmd: `INSERT` · roles: `{public}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `student_group_upvotes` — Leer solo mis upvotes de grupos
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(auth.uid() = user_id)`

### `student_groups` — deny_all_delete_student_groups
- cmd: `DELETE` · roles: `{anon,authenticated}`
- USING: `false`

### `student_groups` — Crear grupos solo autenticados
- cmd: `INSERT` · roles: `{authenticated}`
- USING: `None`
- WITH CHECK: `(( SELECT auth.uid() AS uid) = user_id)`

### `student_groups` — Lectura pública de grupos (anon)
- cmd: `SELECT` · roles: `{anon}`
- USING: `(moderation_status IS DISTINCT FROM 2)`

### `student_groups` — Lectura pública de grupos (auth)
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `((moderation_status IS DISTINCT FROM 2) OR (user_id = ( SELECT auth.uid() AS uid)) OR is_pemtree_admin(( SELECT auth.uid() AS uid)) OR is_pemtree_moderator(( SELECT auth.uid() AS uid)))`

### `student_groups` — Editar grupos dueño, admin o moderador
- cmd: `UPDATE` · roles: `{authenticated}`
- USING: `((( SELECT auth.uid() AS uid) = user_id) OR ((auth.uid() IS NOT NULL) AND is_pemtree_admin(( SELECT auth.uid() AS uid))) OR ((auth.uid() IS NOT NULL) AND is_pemtree_moderator(( SELECT auth.uid() AS uid))))`

### `user_notifications` — Borrar mis notificaciones
- cmd: `DELETE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `user_notifications` — Ver mis notificaciones
- cmd: `SELECT` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `user_notifications` — Actualizar mis notificaciones (leídas)
- cmd: `UPDATE` · roles: `{public}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

### `user_roles` — Admins can manage user_roles
- cmd: `ALL` · roles: `{authenticated}`
- USING: `is_pemtree_admin(( SELECT auth.uid() AS uid))`
- WITH CHECK: `is_pemtree_admin(( SELECT auth.uid() AS uid))`

### `user_roles` — Leer rol propio
- cmd: `SELECT` · roles: `{authenticated}`
- USING: `(( SELECT auth.uid() AS uid) = user_id)`

## 3. Privilegios de columna (grants reales)

| Tabla | Rol | Privilegio | Columnas |
|---|---|---|---|
| `alias_adjectives` | anon | INSERT | term |
| `alias_adjectives` | anon | SELECT | term |
| `alias_adjectives` | anon | UPDATE | term |
| `alias_adjectives` | authenticated | INSERT | term |
| `alias_adjectives` | authenticated | SELECT | term |
| `alias_adjectives` | authenticated | UPDATE | term |
| `alias_nouns` | anon | INSERT | term |
| `alias_nouns` | anon | SELECT | term |
| `alias_nouns` | anon | UPDATE | term |
| `alias_nouns` | authenticated | INSERT | term |
| `alias_nouns` | authenticated | SELECT | term |
| `alias_nouns` | authenticated | UPDATE | term |
| `carreras` | anon | INSERT | codigo,created_at,facultad_id,id,nombre,updated_at |
| `carreras` | anon | SELECT | codigo,created_at,facultad_id,id,nombre,updated_at |
| `carreras` | anon | UPDATE | codigo,created_at,facultad_id,id,nombre,updated_at |
| `carreras` | authenticated | INSERT | codigo,created_at,facultad_id,id,nombre,updated_at |
| `carreras` | authenticated | SELECT | codigo,created_at,facultad_id,id,nombre,updated_at |
| `carreras` | authenticated | UPDATE | codigo,created_at,facultad_id,id,nombre,updated_at |
| `categorias_foro` | anon | INSERT | created_at,id,nombre,updated_at |
| `categorias_foro` | anon | SELECT | created_at,id,nombre,updated_at |
| `categorias_foro` | anon | UPDATE | created_at,id,nombre,updated_at |
| `categorias_foro` | authenticated | INSERT | created_at,id,nombre,updated_at |
| `categorias_foro` | authenticated | SELECT | created_at,id,nombre,updated_at |
| `categorias_foro` | authenticated | UPDATE | created_at,id,nombre,updated_at |
| `categorias_marketplace` | anon | INSERT | created_at,id,nombre,updated_at |
| `categorias_marketplace` | anon | SELECT | created_at,id,nombre,updated_at |
| `categorias_marketplace` | anon | UPDATE | created_at,id,nombre,updated_at |
| `categorias_marketplace` | authenticated | INSERT | created_at,id,nombre,updated_at |
| `categorias_marketplace` | authenticated | SELECT | created_at,id,nombre,updated_at |
| `categorias_marketplace` | authenticated | UPDATE | created_at,id,nombre,updated_at |
| `comment_authors` | authenticated | SELECT | comment_id,created_at,user_id |
| `comments` | anon | SELECT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_op,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `comments` | authenticated | INSERT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_op,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at,user_id |
| `comments` | authenticated | SELECT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_op,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `comments` | authenticated | UPDATE | author_alias,content,deleted_at,gif_url,is_legal_hold,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id |
| `entity_reports` | anon | INSERT | created_at,details,entity_id,entity_owner_id,entity_type,id,metadata,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_id,reporter_id,updated_at |
| `entity_reports` | anon | SELECT | created_at,details,entity_id,entity_owner_id,entity_type,id,metadata,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_id,reporter_id,updated_at |
| `entity_reports` | anon | UPDATE | created_at,details,entity_id,entity_owner_id,entity_type,id,metadata,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_id,reporter_id,updated_at |
| `entity_reports` | authenticated | INSERT | created_at,details,entity_id,entity_owner_id,entity_type,id,metadata,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_id,reporter_id,updated_at |
| `entity_reports` | authenticated | SELECT | created_at,details,entity_id,entity_owner_id,entity_type,id,metadata,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_id,reporter_id,updated_at |
| `entity_reports` | authenticated | UPDATE | created_at,details,entity_id,entity_owner_id,entity_type,id,metadata,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_id,reporter_id,updated_at |
| `facultades` | anon | INSERT | codigo,created_at,id,nombre,updated_at |
| `facultades` | anon | SELECT | codigo,created_at,id,nombre,updated_at |
| `facultades` | anon | UPDATE | codigo,created_at,id,nombre,updated_at |
| `facultades` | authenticated | INSERT | codigo,created_at,id,nombre,updated_at |
| `facultades` | authenticated | SELECT | codigo,created_at,id,nombre,updated_at |
| `facultades` | authenticated | UPDATE | codigo,created_at,id,nombre,updated_at |
| `marketplace_items` | anon | SELECT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `marketplace_items` | authenticated | INSERT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,shares_count,social_links,sponsor_badge_text,status,title,updated_at,upvotes,user_id,video_url |
| `marketplace_items` | authenticated | SELECT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `marketplace_items` | authenticated | UPDATE | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,deleted_at,description,facultad,image_urls,is_free,is_legal_hold,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,sede,social_links,status,title,video_url |
| `marketplace_reports` | anon | INSERT | created_at,id,item_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,seller_alias,seller_user_id,status,user_id |
| `marketplace_reports` | anon | UPDATE | created_at,id,item_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,seller_alias,seller_user_id,status,user_id |
| `marketplace_reports` | authenticated | INSERT | created_at,id,item_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,seller_alias,seller_user_id,status,user_id |
| `marketplace_reports` | authenticated | SELECT | created_at,id,item_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,seller_alias,seller_user_id,status,user_id |
| `marketplace_reports` | authenticated | UPDATE | created_at,id,item_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,seller_alias,seller_user_id,status,user_id |
| `marketplace_upvotes` | anon | INSERT | created_at,item_id,user_id |
| `marketplace_upvotes` | anon | UPDATE | created_at,item_id,user_id |
| `marketplace_upvotes` | authenticated | INSERT | created_at,item_id,user_id |
| `marketplace_upvotes` | authenticated | SELECT | created_at,item_id,user_id |
| `marketplace_upvotes` | authenticated | UPDATE | created_at,item_id,user_id |
| `moderation_audit_log` | anon | INSERT | confidence,created_at,entity_id,entity_table,id,is_automated,justification,moderation_label,moderator_id |
| `moderation_audit_log` | anon | SELECT | confidence,created_at,entity_id,entity_table,id,is_automated,justification,moderation_label,moderator_id |
| `moderation_audit_log` | anon | UPDATE | confidence,created_at,entity_id,entity_table,id,is_automated,justification,moderation_label,moderator_id |
| `moderation_audit_log` | authenticated | INSERT | confidence,created_at,entity_id,entity_table,id,is_automated,justification,moderation_label,moderator_id |
| `moderation_audit_log` | authenticated | SELECT | confidence,created_at,entity_id,entity_table,id,is_automated,justification,moderation_label,moderator_id |
| `moderation_audit_log` | authenticated | UPDATE | confidence,created_at,entity_id,entity_table,id,is_automated,justification,moderation_label,moderator_id |
| `notification_preference_carreras` | anon | INSERT | carrera_id,created_at,user_id |
| `notification_preference_carreras` | anon | SELECT | carrera_id,created_at,user_id |
| `notification_preference_carreras` | anon | UPDATE | carrera_id,created_at,user_id |
| `notification_preference_carreras` | authenticated | INSERT | carrera_id,created_at,user_id |
| `notification_preference_carreras` | authenticated | SELECT | carrera_id,created_at,user_id |
| `notification_preference_carreras` | authenticated | UPDATE | carrera_id,created_at,user_id |
| `notification_preferences` | anon | INSERT | comment_enabled,created_at,like_enabled,new_post_enabled,reply_enabled,updated_at,user_id |
| `notification_preferences` | anon | SELECT | comment_enabled,created_at,like_enabled,new_post_enabled,reply_enabled,updated_at,user_id |
| `notification_preferences` | anon | UPDATE | comment_enabled,created_at,like_enabled,new_post_enabled,reply_enabled,updated_at,user_id |
| `notification_preferences` | authenticated | INSERT | comment_enabled,created_at,like_enabled,new_post_enabled,reply_enabled,updated_at,user_id |
| `notification_preferences` | authenticated | SELECT | comment_enabled,created_at,like_enabled,new_post_enabled,reply_enabled,updated_at,user_id |
| `notification_preferences` | authenticated | UPDATE | comment_enabled,created_at,like_enabled,new_post_enabled,reply_enabled,updated_at,user_id |
| `notification_subscriptions` | anon | INSERT | auth,created_at,endpoint,id,p256dh,user_agent,user_id |
| `notification_subscriptions` | anon | SELECT | auth,created_at,endpoint,id,p256dh,user_agent,user_id |
| `notification_subscriptions` | anon | UPDATE | auth,created_at,endpoint,id,p256dh,user_agent,user_id |
| `notification_subscriptions` | authenticated | INSERT | auth,created_at,endpoint,id,p256dh,user_agent,user_id |
| `notification_subscriptions` | authenticated | SELECT | auth,created_at,endpoint,id,p256dh,user_agent,user_id |
| `notification_subscriptions` | authenticated | UPDATE | auth,created_at,endpoint,id,p256dh,user_agent,user_id |
| `post_authors` | authenticated | SELECT | created_at,post_id,user_id |
| `post_bookmarks` | anon | INSERT | created_at,post_id,user_id |
| `post_bookmarks` | anon | SELECT | created_at,post_id,user_id |
| `post_bookmarks` | anon | UPDATE | created_at,post_id,user_id |
| `post_bookmarks` | authenticated | INSERT | created_at,post_id,user_id |
| `post_bookmarks` | authenticated | SELECT | created_at,post_id,user_id |
| `post_bookmarks` | authenticated | UPDATE | created_at,post_id,user_id |
| `post_likes` | anon | INSERT | created_at,post_id,user_id |
| `post_likes` | anon | UPDATE | created_at,post_id,user_id |
| `post_likes` | authenticated | INSERT | created_at,post_id,user_id |
| `post_likes` | authenticated | SELECT | created_at,post_id,user_id |
| `post_likes` | authenticated | UPDATE | created_at,post_id,user_id |
| `post_poll_options` | anon | INSERT | created_at,id,option_text,poll_id,updated_at,votes_count |
| `post_poll_options` | anon | SELECT | created_at,id,option_text,poll_id,updated_at,votes_count |
| `post_poll_options` | anon | UPDATE | created_at,id,option_text,poll_id,updated_at,votes_count |
| `post_poll_options` | authenticated | INSERT | created_at,id,option_text,poll_id,updated_at,votes_count |
| `post_poll_options` | authenticated | SELECT | created_at,id,option_text,poll_id,updated_at,votes_count |
| `post_poll_options` | authenticated | UPDATE | created_at,id,option_text,poll_id,updated_at,votes_count |
| `post_poll_votes` | anon | INSERT | created_at,option_id,poll_id,user_id |
| `post_poll_votes` | anon | UPDATE | created_at,option_id,poll_id,user_id |
| `post_poll_votes` | authenticated | INSERT | created_at,option_id,poll_id,user_id |
| `post_poll_votes` | authenticated | SELECT | created_at,option_id,poll_id,user_id |
| `post_poll_votes` | authenticated | UPDATE | created_at,option_id,poll_id,user_id |
| `post_polls` | anon | INSERT | created_at,id,post_id,question,updated_at |
| `post_polls` | anon | SELECT | created_at,id,post_id,question,updated_at |
| `post_polls` | anon | UPDATE | created_at,id,post_id,question,updated_at |
| `post_polls` | authenticated | INSERT | created_at,id,post_id,question,updated_at |
| `post_polls` | authenticated | SELECT | created_at,id,post_id,question,updated_at |
| `post_polls` | authenticated | UPDATE | created_at,id,post_id,question,updated_at |
| `posts` | anon | SELECT | author_alias,author_hash,carrera,category,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `posts` | authenticated | INSERT | author_alias,author_hash,carrera,category,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,shares_count,title,updated_at,user_id |
| `posts` | authenticated | SELECT | author_alias,author_hash,carrera,category,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `posts` | authenticated | UPDATE | author_alias,carrera,category,content,deleted_at,expires_at,gif_url,image_url,is_legal_hold,is_pinned,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,title |
| `profiles` | anon | INSERT | accepted_terms_at,accepted_terms_version,carne,carne_hash,carrera,created_at,cui,cui_hash,full_name,id,is_verified,reputation_score,updated_at,verified_at |
| `profiles` | anon | SELECT | accepted_terms_at,accepted_terms_version,carne,carne_hash,carrera,created_at,cui,cui_hash,full_name,id,is_verified,reputation_score,updated_at,verified_at |
| `profiles` | authenticated | INSERT | accepted_terms_at,accepted_terms_version,carne,carne_hash,carrera,created_at,cui,cui_hash,full_name,id,is_verified,reputation_score,updated_at,verified_at |
| `profiles` | authenticated | SELECT | accepted_terms_at,accepted_terms_version,carne,carne_hash,carrera,created_at,cui,cui_hash,full_name,id,is_verified,reputation_score,updated_at,verified_at |
| `profiles` | authenticated | UPDATE | accepted_terms_at,accepted_terms_version,carrera,full_name |
| `safe_comments` | anon | INSERT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_mine,is_op,is_post_author,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `safe_comments` | anon | SELECT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_mine,is_op,is_post_author,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `safe_comments` | anon | UPDATE | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_mine,is_op,is_post_author,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `safe_comments` | authenticated | INSERT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_mine,is_op,is_post_author,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `safe_comments` | authenticated | SELECT | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_mine,is_op,is_post_author,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `safe_comments` | authenticated | UPDATE | author_alias,author_hash,content,created_at,deleted_at,gif_url,id,is_legal_hold,is_mine,is_op,is_post_author,likes_count,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,parent_id,post_id,updated_at |
| `safe_marketplace_items` | anon | INSERT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_mine,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `safe_marketplace_items` | anon | SELECT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_mine,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `safe_marketplace_items` | anon | UPDATE | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_mine,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `safe_marketplace_items` | authenticated | INSERT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_mine,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `safe_marketplace_items` | authenticated | SELECT | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_mine,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `safe_marketplace_items` | authenticated | UPDATE | author_alias,building_code,category,contact_instagram,contact_messenger,contact_telegram,contact_whatsapp,created_at,deleted_at,description,facultad,id,image_urls,is_free,is_legal_hold,is_mine,is_sponsored,location_detail,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,price,reported_count,sede,social_links,sponsor_badge_text,status,title,updated_at,upvotes,video_url |
| `safe_posts_feed` | anon | INSERT | author_alias,author_hash,carrera,category,comment_count,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_mine,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `safe_posts_feed` | anon | SELECT | author_alias,author_hash,carrera,category,comment_count,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_mine,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `safe_posts_feed` | anon | UPDATE | author_alias,author_hash,carrera,category,comment_count,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_mine,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `safe_posts_feed` | authenticated | INSERT | author_alias,author_hash,carrera,category,comment_count,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_mine,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `safe_posts_feed` | authenticated | SELECT | author_alias,author_hash,carrera,category,comment_count,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_mine,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `safe_posts_feed` | authenticated | UPDATE | author_alias,author_hash,carrera,category,comment_count,comments_count,content,created_at,deleted_at,expires_at,gif_url,hot_score,id,image_url,is_legal_hold,is_mine,is_pinned,likes,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,quoted_post_id,reposts_count,title,updated_at |
| `safe_seccion_reviews` | anon | INSERT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,dificultad,id,is_mine,recomienda,seccion,semestre,updated_at,upvotes |
| `safe_seccion_reviews` | anon | SELECT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,dificultad,id,is_mine,recomienda,seccion,semestre,updated_at,upvotes |
| `safe_seccion_reviews` | anon | UPDATE | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,dificultad,id,is_mine,recomienda,seccion,semestre,updated_at,upvotes |
| `safe_seccion_reviews` | authenticated | INSERT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,dificultad,id,is_mine,recomienda,seccion,semestre,updated_at,upvotes |
| `safe_seccion_reviews` | authenticated | SELECT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,dificultad,id,is_mine,recomienda,seccion,semestre,updated_at,upvotes |
| `safe_seccion_reviews` | authenticated | UPDATE | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,dificultad,id,is_mine,recomienda,seccion,semestre,updated_at,upvotes |
| `safe_student_groups` | anon | INSERT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,is_mine,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `safe_student_groups` | anon | SELECT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,is_mine,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `safe_student_groups` | anon | UPDATE | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,is_mine,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `safe_student_groups` | authenticated | INSERT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,is_mine,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `safe_student_groups` | authenticated | SELECT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,is_mine,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `safe_student_groups` | authenticated | UPDATE | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,is_mine,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `seccion_reputation` | anon | INSERT | curso_codigo,pct_recomienda,recomendados,seccion,total |
| `seccion_reputation` | anon | SELECT | curso_codigo,pct_recomienda,recomendados,seccion,total |
| `seccion_reputation` | anon | UPDATE | curso_codigo,pct_recomienda,recomendados,seccion,total |
| `seccion_reputation` | authenticated | INSERT | curso_codigo,pct_recomienda,recomendados,seccion,total |
| `seccion_reputation` | authenticated | SELECT | curso_codigo,pct_recomienda,recomendados,seccion,total |
| `seccion_reputation` | authenticated | UPDATE | curso_codigo,pct_recomienda,recomendados,seccion,total |
| `seccion_review_upvotes` | authenticated | INSERT | created_at,review_id,user_id |
| `seccion_review_upvotes` | authenticated | SELECT | created_at,review_id,user_id |
| `seccion_review_upvotes` | authenticated | UPDATE | created_at,review_id,user_id |
| `seccion_reviews` | anon | SELECT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,deleted_at,dificultad,id,is_legal_hold,recomienda,seccion,semestre,updated_at,upvotes |
| `seccion_reviews` | authenticated | INSERT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,deleted_at,dificultad,id,is_legal_hold,recomienda,seccion,semestre,updated_at,upvotes,user_id |
| `seccion_reviews` | authenticated | SELECT | carga_tareas,catedratico_nombre,comentario,created_at,curso_codigo,deleted_at,dificultad,id,is_legal_hold,recomienda,seccion,semestre,updated_at,upvotes |
| `seccion_reviews` | authenticated | UPDATE | carga_tareas,catedratico_nombre,comentario,dificultad,recomienda,semestre |
| `sponsor_requests` | anon | INSERT | brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id |
| `sponsor_requests` | anon | SELECT | brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id |
| `sponsor_requests` | anon | UPDATE | brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id |
| `sponsor_requests` | authenticated | INSERT | brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id |
| `sponsor_requests` | authenticated | SELECT | brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id |
| `sponsor_requests` | authenticated | UPDATE | brand_name,contact_name,contact_phone,created_at,email,expected_placement,id,proposal_details,status,user_id |
| `student_group_reports` | anon | INSERT | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `student_group_reports` | anon | UPDATE | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `student_group_reports` | authenticated | INSERT | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `student_group_reports` | authenticated | SELECT | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `student_group_reports` | authenticated | UPDATE | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `student_group_upvotes` | anon | INSERT | created_at,group_id,user_id |
| `student_group_upvotes` | anon | UPDATE | created_at,group_id,user_id |
| `student_group_upvotes` | authenticated | INSERT | created_at,group_id,user_id |
| `student_group_upvotes` | authenticated | SELECT | created_at,group_id,user_id |
| `student_group_upvotes` | authenticated | UPDATE | created_at,group_id,user_id |
| `student_groups` | anon | SELECT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `student_groups` | authenticated | INSERT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes,user_id |
| `student_groups` | authenticated | SELECT | author_alias,carrera,created_at,curso,deleted_at,description,id,image_url,is_legal_hold,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,updated_at,upvotes |
| `student_groups` | authenticated | UPDATE | author_alias,carrera,curso,deleted_at,description,image_url,is_legal_hold,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,section,title |
| `user_notifications` | anon | INSERT | actor_alias,body,comment_id,created_at,id,post_id,push_sent_at,read_at,title,type,user_id |
| `user_notifications` | anon | SELECT | actor_alias,body,comment_id,created_at,id,post_id,push_sent_at,read_at,title,type,user_id |
| `user_notifications` | anon | UPDATE | actor_alias,body,comment_id,created_at,id,post_id,push_sent_at,read_at,title,type,user_id |
| `user_notifications` | authenticated | INSERT | actor_alias,body,comment_id,created_at,id,post_id,push_sent_at,read_at,title,type,user_id |
| `user_notifications` | authenticated | SELECT | actor_alias,body,comment_id,created_at,id,post_id,push_sent_at,read_at,title,type,user_id |
| `user_notifications` | authenticated | UPDATE | actor_alias,body,comment_id,created_at,id,post_id,push_sent_at,read_at,title,type,user_id |
| `user_reports` | anon | INSERT | created_at,id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_alias,reported_user_id,reporter_id |
| `user_reports` | anon | UPDATE | created_at,id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_alias,reported_user_id,reporter_id |
| `user_reports` | authenticated | INSERT | created_at,id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_alias,reported_user_id,reporter_id |
| `user_reports` | authenticated | SELECT | created_at,id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_alias,reported_user_id,reporter_id |
| `user_reports` | authenticated | UPDATE | created_at,id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,reported_user_alias,reported_user_id,reporter_id |
| `user_roles` | anon | INSERT | created_at,role,user_id |
| `user_roles` | anon | SELECT | created_at,role,user_id |
| `user_roles` | anon | UPDATE | created_at,role,user_id |
| `user_roles` | authenticated | INSERT | created_at,role,user_id |
| `user_roles` | authenticated | SELECT | created_at,role,user_id |
| `user_roles` | authenticated | UPDATE | created_at,role,user_id |
| `v_public_comments` | anon | INSERT | author_alias,author_hash,content,created_at,gif_url,id,is_my_comment,is_post_author,moderation_status,parent_id,post_id |
| `v_public_comments` | anon | SELECT | author_alias,author_hash,content,created_at,gif_url,id,is_my_comment,is_post_author,moderation_status,parent_id,post_id |
| `v_public_comments` | anon | UPDATE | author_alias,author_hash,content,created_at,gif_url,id,is_my_comment,is_post_author,moderation_status,parent_id,post_id |
| `v_public_comments` | authenticated | INSERT | author_alias,author_hash,content,created_at,gif_url,id,is_my_comment,is_post_author,moderation_status,parent_id,post_id |
| `v_public_comments` | authenticated | SELECT | author_alias,author_hash,content,created_at,gif_url,id,is_my_comment,is_post_author,moderation_status,parent_id,post_id |
| `v_public_comments` | authenticated | UPDATE | author_alias,author_hash,content,created_at,gif_url,id,is_my_comment,is_post_author,moderation_status,parent_id,post_id |
| `v_public_posts` | anon | INSERT | author_alias,author_hash,carrera,category,comment_count,content,created_at,gif_url,id,image_url,is_my_post,is_pinned,likes,moderation_status,quoted_post_id,reposts_count,title |
| `v_public_posts` | anon | SELECT | author_alias,author_hash,carrera,category,comment_count,content,created_at,gif_url,id,image_url,is_my_post,is_pinned,likes,moderation_status,quoted_post_id,reposts_count,title |
| `v_public_posts` | anon | UPDATE | author_alias,author_hash,carrera,category,comment_count,content,created_at,gif_url,id,image_url,is_my_post,is_pinned,likes,moderation_status,quoted_post_id,reposts_count,title |
| `v_public_posts` | authenticated | INSERT | author_alias,author_hash,carrera,category,comment_count,content,created_at,gif_url,id,image_url,is_my_post,is_pinned,likes,moderation_status,quoted_post_id,reposts_count,title |
| `v_public_posts` | authenticated | SELECT | author_alias,author_hash,carrera,category,comment_count,content,created_at,gif_url,id,image_url,is_my_post,is_pinned,likes,moderation_status,quoted_post_id,reposts_count,title |
| `v_public_posts` | authenticated | UPDATE | author_alias,author_hash,carrera,category,comment_count,content,created_at,gif_url,id,image_url,is_my_post,is_pinned,likes,moderation_status,quoted_post_id,reposts_count,title |
| `whatsapp_group_reports` | anon | INSERT | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `whatsapp_group_reports` | anon | UPDATE | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `whatsapp_group_reports` | authenticated | INSERT | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `whatsapp_group_reports` | authenticated | SELECT | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `whatsapp_group_reports` | authenticated | UPDATE | created_at,group_id,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,reason,user_id |
| `whatsapp_group_upvotes` | anon | INSERT | created_at,group_id,user_id |
| `whatsapp_group_upvotes` | anon | UPDATE | created_at,group_id,user_id |
| `whatsapp_group_upvotes` | authenticated | INSERT | created_at,group_id,user_id |
| `whatsapp_group_upvotes` | authenticated | SELECT | created_at,group_id,user_id |
| `whatsapp_group_upvotes` | authenticated | UPDATE | created_at,group_id,user_id |
| `whatsapp_groups` | anon | INSERT | author_alias,carrera,created_at,curso,description,id,image_url,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,upvotes,user_id |
| `whatsapp_groups` | anon | SELECT | author_alias,carrera,created_at,curso,description,id,image_url,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,upvotes,user_id |
| `whatsapp_groups` | anon | UPDATE | author_alias,carrera,created_at,curso,description,id,image_url,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,upvotes,user_id |
| `whatsapp_groups` | authenticated | INSERT | author_alias,carrera,created_at,curso,description,id,image_url,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,upvotes,user_id |
| `whatsapp_groups` | authenticated | SELECT | author_alias,carrera,created_at,curso,description,id,image_url,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,upvotes,user_id |
| `whatsapp_groups` | authenticated | UPDATE | author_alias,carrera,created_at,curso,description,id,image_url,link,moderated_at,moderated_by,moderation_confidence,moderation_label,moderation_reason,moderation_status,platform,reported_count,section,title,upvotes,user_id |

## 4. Funciones: SECURITY DEFINER y EXECUTE

| Función | SECURITY DEFINER | search_path | anon EXECUTE | authenticated EXECUTE |
|---|---|---|---|---|
| `_cancelar_jobs_panel(p_tabla text, p_id uuid)` | True | `search_path=""` | False | False |
| `after_comment_insert_author()` | True | `search_path=""` | False | False |
| `after_post_insert_author()` | True | `search_path=""` | False | False |
| `apply_moderation_batch(p_items jsonb)` | True | `search_path=""` | False | False |
| `calculate_hot_score(p_likes integer, p_comments integer, p_reposts integer, p...)` | False | `search_path=""` | True | True |
| `check_author_alias_validity()` | True | `search_path=""` | True | True |
| `check_content_moderation()` | False | `search_path=pg_catalog` | True | True |
| `check_whatsapp_groups_limit()` | True | `search_path=""` | False | False |
| `claim_moderation_job(p_worker text)` | True | `search_path=""` | False | False |
| `claim_moderation_jobs(p_worker_id text, p_limit integer)` | True | `search_path=""` | False | False |
| `complete_moderation_job(p_job_id uuid)` | True | `search_path=""` | False | False |
| `count_total_profiles()` | True | `search_path=""` | True | True |
| `delete_inappropriate_posts()` | True | `search_path=""` | False | False |
| `delete_old_posts(months_old integer)` | True | `search_path=""` | False | False |
| `eliminar_contenido_moderado(p_tabla text, p_item_id uuid, p_justificacion text)` | True | `search_path=""` | False | True |
| `enforce_content_immutability_and_legal_hold()` | True | `search_path=""` | True | True |
| `enforce_system_defaults_on_insert()` | True | `search_path=""` | True | True |
| `enqueue_from_report()` | True | `search_path=""` | False | False |
| `enqueue_moderation(p_table text, p_id uuid, p_hash text, p_priority integer,...)` | True | `search_path=""` | False | False |
| `fail_moderation_job(p_job_id uuid, p_error text)` | True | `search_path=""` | False | False |
| `force_marketplace_item_owner()` | True | `search_path=public` | False | False |
| `generate_anonymous_alias()` | True | `search_path=""` | False | True |
| `generate_author_hash(p_user_id uuid, p_salt text)` | True | `search_path=public` | True | True |
| `get_admin_dashboard_stats()` | True | `search_path=""` | True | True |
| `get_admin_users_summary()` | True | `search_path=""` | True | True |
| `get_posts_with_comment_counts()` | True | `search_path=""` | True | True |
| `get_push_secrets()` | True | `search_path=""` | False | False |
| `get_user_activity_admin(p_user_id uuid)` | True | `search_path=""` | True | True |
| `get_user_profiles(p_user_ids uuid[])` | True | `search_path=""` | False | True |
| `get_verification_stats()` | True | `search_path=""` | True | True |
| `handle_comment_author_hash()` | True | `search_path=""` | False | False |
| `handle_entity_report_auto_quarantine()` | True | `search_path=""` | True | True |
| `handle_new_user_profile()` | True | `search_path=public` | False | False |
| `handle_post_author_hash()` | True | `search_path=""` | False | False |
| `handle_post_initial_scores()` | True | `search_path=""` | True | True |
| `handle_profile_sensitive_data()` | True | `search_path=""` | True | True |
| `is_my_comment(p_comment_id uuid)` | True | `search_path=""` | True | True |
| `is_my_group(p_id uuid)` | True | `search_path=""` | True | True |
| `is_my_marketplace_item(p_id uuid)` | True | `search_path=""` | True | True |
| `is_my_post(p_post_id uuid)` | True | `search_path=""` | True | True |
| `is_my_seccion_review(p_review_id uuid)` | True | `search_path=""` | True | True |
| `is_pemtree_admin(p_user_id uuid)` | True | `search_path=""` | False | True |
| `is_pemtree_moderator(p_user_id uuid)` | True | `search_path=""` | False | True |
| `is_risk_report_reason(p_reason text)` | True | `search_path=""` | True | True |
| `is_valid_anonymous_alias(p_alias text)` | True | `search_path=""` | True | True |
| `legacy_marketplace_reports_iud()` | False | `search_path=public, pg_temp` | True | True |
| `legacy_student_group_reports_iud()` | False | `search_path=public, pg_temp` | True | True |
| `legacy_user_reports_iud()` | False | `search_path=public, pg_temp` | True | True |
| `limpieza_semestral_pemtree()` | True | `search_path=""` | False | False |
| `marcar_pendientes_error(p_horas integer)` | True | `search_path=""` | False | False |
| `moderate_marketplace_item(target_item_id uuid, new_status integer, p_label text, p_...)` | True | `search_path=public` | False | True |
| `ocultar_contenido_moderado(p_tabla text, p_item_id uuid, p_justificacion text)` | True | `search_path=""` | False | True |
| `panel_aprobar(p_tabla text, p_id uuid, p_reason text)` | True | `search_path=""` | False | True |
| `panel_cola_revision(p_umbral double precision)` | True | `search_path=""` | False | True |
| `panel_rechazar(p_tabla text, p_id uuid, p_reason text)` | True | `search_path=""` | False | True |
| `panel_remoderar(p_tabla text, p_id uuid)` | True | `search_path=""` | False | True |
| `prevent_nonmoderator_restore()` | True | `search_path=""` | True | True |
| `purge_expired_soft_deletes()` | True | `search_path=""` | False | False |
| `purge_inappropriate_content()` | True | `search_path=""` | False | True |
| `purge_old_content(p_months integer)` | True | `search_path=""` | False | True |
| `purge_reported_groups()` | True | `search_path=""` | False | True |
| `recalcular_contadores()` | True | `search_path=""` | False | False |
| `refresh_active_posts_hot_score()` | True | `search_path=""` | False | False |
| `report_forum_comment(p_comment_id uuid, p_reason text, p_details text)` | True | `search_path=public` | False | True |
| `report_forum_post(p_post_id uuid, p_reason text, p_details text)` | True | `search_path=public` | False | True |
| `report_marketplace_item(target_item_id uuid, report_reason text, target_seller_id...)` | True | `search_path=public` | False | True |
| `reset_moderation_on_edit()` | False | `search_path=public` | True | True |
| `restaurar_contenido_moderado(p_tabla text, p_item_id uuid)` | True | `search_path=""` | False | True |
| `rls_auto_enable()` | True | `search_path=pg_catalog` | False | False |
| `sync_post_comments_counter()` | True | `search_path=""` | True | True |
| `sync_seccion_review_upvotes()` | True | `search_path=""` | True | True |
| `trg_enqueue_comments()` | True | `search_path=""` | False | False |
| `trg_enqueue_marketplace()` | True | `search_path=""` | False | False |
| `trg_enqueue_posts()` | True | `search_path=""` | False | False |
| `trg_enqueue_student_groups()` | True | `search_path=""` | False | False |
| `upvote_seccion_review(p_review_id uuid)` | True | `search_path=""` | False | True |
| `user_exists(p_user_id uuid)` | True | `search_path=""` | False | True |
| `v_moderation_queue()` | False | `search_path=""` | False | False |
| `verificar_contadores()` | True | `search_path=""` | False | False |

## 5. Vistas

### `marketplace_reports`
```sql
 SELECT id,
    entity_id AS item_id,
    reporter_id AS user_id,
    reason,
    created_at,
    entity_owner_id AS seller_user_id,
    (metadata ->> 'seller_alias'::text) AS seller_alias,
    COALESCE((metadata ->> 'legacy_status'::text), 'pending'::text) AS status,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
   FROM entity_reports er
  WHERE (entity_type = 'marketplace_item'::text);
```

### `safe_comments`
```sql
 SELECT id,
    post_id,
    parent_id,
    content,
    author_alias,
    author_hash,
    is_op,
    is_op AS is_post_author,
    likes_count,
    gif_url,
    created_at,
    updated_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    deleted_at,
    is_legal_hold,
    is_my_comment(id) AS is_mine
   FROM comments c
  WHERE ((deleted_at IS NULL) AND (moderation_status = 0));
```

### `safe_marketplace_items`
```sql
 SELECT id,
    title,
    description,
    price,
    is_free,
    category,
    facultad,
    sede,
    building_code,
    location_detail,
    contact_whatsapp,
    contact_telegram,
    image_urls,
    video_url,
    is_sponsored,
    sponsor_badge_text,
    author_alias,
    upvotes,
    moderation_status,
    created_at,
    contact_instagram,
    contact_messenger,
    social_links,
    reported_count,
    status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    updated_at,
    deleted_at,
    is_legal_hold,
    is_my_marketplace_item(id) AS is_mine
   FROM marketplace_items
  WHERE ((deleted_at IS NULL) AND ((moderation_status = 0) OR is_my_marketplace_item(id)) AND ((status = ANY (ARRAY['available'::text, 'reserved'::text])) OR is_my_marketplace_item(id)));
```

### `safe_posts_feed`
```sql
 SELECT id,
    title,
    category,
    content,
    author_alias,
    author_hash,
    likes,
    reposts_count,
    comments_count,
    comments_count AS comment_count,
    hot_score,
    carrera,
    image_url,
    gif_url,
    is_pinned,
    quoted_post_id,
    created_at,
    updated_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    expires_at,
    deleted_at,
    is_legal_hold,
    is_my_post(id) AS is_mine
   FROM posts p
  WHERE ((deleted_at IS NULL) AND (moderation_status = 0) AND ((expires_at IS NULL) OR (expires_at > now())));
```

### `safe_seccion_reviews`
```sql
 SELECT id,
    curso_codigo,
    seccion,
    recomienda,
    catedratico_nombre,
    dificultad,
    carga_tareas,
    comentario,
    semestre,
    upvotes,
    created_at,
    updated_at,
    is_my_seccion_review(id) AS is_mine
   FROM seccion_reviews sr
  WHERE (deleted_at IS NULL);
```

### `safe_student_groups`
```sql
 SELECT id,
    title,
    carrera,
    curso,
    section,
    link,
    description,
    author_alias,
    upvotes,
    reported_count,
    created_at,
    image_url,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    platform,
    updated_at,
    deleted_at,
    is_legal_hold,
    is_my_group(id) AS is_mine
   FROM student_groups
  WHERE ((deleted_at IS NULL) AND ((moderation_status = 0) OR is_my_group(id)));
```

### `seccion_reputation`
```sql
 SELECT curso_codigo,
    seccion,
    count(id) AS total,
    count(id) FILTER (WHERE recomienda) AS recomendados,
        CASE
            WHEN (count(id) = 0) THEN NULL::numeric
            ELSE round((((count(id) FILTER (WHERE recomienda))::numeric / (count(id))::numeric) * (100)::numeric))
        END AS pct_recomienda
   FROM seccion_reviews
  GROUP BY curso_codigo, seccion;
```

### `student_group_reports`
```sql
 SELECT entity_id AS group_id,
    reporter_id AS user_id,
    reason,
    created_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
   FROM entity_reports er
  WHERE (entity_type = 'group'::text);
```

### `user_reports`
```sql
 SELECT id,
    reporter_id,
    reported_user_id,
    (metadata ->> 'reported_user_alias'::text) AS reported_user_alias,
    reason,
    created_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
   FROM entity_reports er
  WHERE (entity_type = 'user'::text);
```

### `v_public_comments`
```sql
 SELECT id,
    post_id,
    parent_id,
    content,
    author_alias,
    author_hash,
    gif_url,
    created_at,
    moderation_status,
    is_op AS is_post_author,
    is_mine AS is_my_comment
   FROM safe_comments;
```

### `v_public_posts`
```sql
 SELECT id,
    title,
    category,
    content,
    author_alias,
    author_hash,
    likes,
    reposts_count,
    carrera,
    image_url,
    gif_url,
    is_pinned,
    quoted_post_id,
    created_at,
    moderation_status,
    comments_count AS comment_count,
    is_mine AS is_my_post
   FROM safe_posts_feed;
```

### `whatsapp_group_reports`
```sql
 SELECT group_id,
    user_id,
    reason,
    created_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
   FROM student_group_reports;
```

### `whatsapp_group_upvotes`
```sql
 SELECT group_id,
    user_id,
    created_at
   FROM student_group_upvotes;
```

### `whatsapp_groups`
```sql
 SELECT id,
    title,
    carrera,
    curso,
    section,
    link,
    description,
    user_id,
    author_alias,
    upvotes,
    reported_count,
    created_at,
    image_url,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    platform
   FROM student_groups;
```

## 6. Storage

Buckets existentes: **ninguno** (tabla `storage.buckets` vacía).

| Política | cmd | roles | USING | WITH CHECK |
|---|---|---|---|---|
| Users can delete own files in marketplace bucket | DELETE | `{authenticated}` | `((bucket_id = 'marketplace'::text) AND (auth.uid() = owner))` | `None` |
| Authenticated upload to marketplace bucket | INSERT | `{authenticated}` | `None` | `(bucket_id = 'marketplace'::text)` |
| Subida pública de imágenes para comunidad | INSERT | `{public}` | `None` | `(bucket_id = ANY (ARRAY['images'::text, 'public'::text, 's3'::text, 'media'::text, 'pemtree'::text]))` |
| Lectura pública de imágenes | SELECT | `{public}` | `(bucket_id = ANY (ARRAY['images'::text, 'public'::text, 's3'::text, 'media'::text, 'pemtree'::text]))` | `None` |
| Public read marketplace bucket | SELECT | `{public}` | `(bucket_id = 'marketplace'::text)` | `None` |
| Users can update own files in marketplace bucket | UPDATE | `{authenticated}` | `((bucket_id = 'marketplace'::text) AND (auth.uid() = owner))` | `None` |

## 7. Pruebas empíricas (SQL con `SET LOCAL ROLE`)

Ejecutadas contra la BD real. `ERR` = excepción de PostgreSQL.

| Prueba | Resultado |
|---|---|
| `anon` → `select count(*) from posts` | **8** (RLS permite todo salvo `moderation_status = 2`) |
| `anon` → `select count(*) from v_public_posts` | 0 |
| `anon` → `select count(*) from safe_posts_feed` | 0 |
| `anon` → `select count(*) from profiles` | 0 (sin política para anon → OK) |
| `anon` → `select count(*) from user_roles` | 0 → OK |
| `anon` → `select count(*) from moderation_audit_log` | 0 → OK |
| `anon` → `select count(*) from entity_reports` | 0 → OK |
| `anon` → `select count(*) from whatsapp_groups` | **ERR 42501** `permission denied for table student_groups` |
| `anon` → `INSERT INTO sponsor_requests(...)` | **ÉXITO** (sin rate-limit / captcha) |
| `anon` → `INSERT INTO post_polls(...)` | ERR 42501 (bloqueado por RLS) |
| `authenticated` → `has_table_privilege(profiles,'UPDATE')` | **false** → la política de UPDATE existe pero el GRANT no |
| `authenticated` → `INSERT INTO user_roles` | ERR 42501 → OK |
| `authenticated` → `select count(*) from posts` | 8 |
| `authenticated` → `select count(*) from moderation_audit_log` | 0 → OK |
| `authenticated` → `INSERT INTO sponsor_requests(user_id=<otro uuid>)` | solo bloqueado por FK, no por RLS (permite suplantación con UUIDs válidos) |
| `select public.is_pemtree_admin()` (0 args) | `false` (existe la sobrecarga invoker) |

## 8. Pruebas REST reales con la publishable/anon key

`GET /rest/v1/<recurso>` con `apikey` + `Authorization: Bearer <anon key>`:

| Endpoint | HTTP | Cuerpo |
|---|---|---|
| `posts?select=id,title,author_hash,moderation_status` | **200** | 8 filas, incluye `author_hash` |
| `profiles?select=id,cui,carne,full_name,is_verified` | 200 | `[]` (protegido por RLS) |
| `user_roles?select=*` | 200 | `[]` |
| `moderation_audit_log?select=*` | 200 | `[]` |
| `entity_reports?select=*` | 200 | `[]` |
| `safe_posts_feed?select=id,title` | 200 | `[]` ← **inconsistente con `posts` (8 filas)** |
| `v_public_posts?select=id,title` | 200 | `[]` |
| `whatsapp_groups?select=id,title` | **401** | `42501 permission denied for table student_groups` |
| `seccion_reviews?select=id,curso_codigo` | 200 | 12 filas |
| `moderation_jobs?select=*` | **401** | `42501 permission denied` |

## 9. Semántica de `moderation_status` (deducida del catálogo)

- `0` = pendiente (valor forzado por `enforce_system_defaults_on_insert` en INSERT)
- `1` = apropiado/aprobado (`apply_moderation_batch`)
- `2` = inapropiado/oculto
- `3` = error de moderación

Las vistas `safe_*` filtran `moderation_status = 0` (pendientes), mientras las políticas RLS
filtran `moderation_status IS DISTINCT FROM 2`. **Ambos criterios son incompatibles.**
