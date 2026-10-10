create trigger trg_check_whatsapp_groups_limit before insert on public.whatsapp_groups for each row execute function public.check_whatsapp_groups_limit();
create trigger trg_moderate_posts before insert or update on public.posts for each row execute function public.check_content_moderation();
create trigger trg_moderate_comments before insert or update on public.comments for each row execute function public.check_content_moderation();
create trigger trg_moderate_user_reports before insert or update on public.user_reports for each row execute function public.check_content_moderation();
create trigger trg_moderate_whatsapp_group_reports before insert or update on public.whatsapp_group_reports for each row execute function public.check_content_moderation();
create trigger trg_moderate_whatsapp_groups before insert or update on public.whatsapp_groups for each row execute function public.check_content_moderation();
create trigger trg_reset_moderation_posts before update on public.posts for each row execute function public.reset_moderation_on_edit();
create trigger trg_reset_moderation_comments before update on public.comments for each row execute function public.reset_moderation_on_edit();
create trigger trg_reset_moderation_whatsapp_groups before update on public.whatsapp_groups for each row execute function public.reset_moderation_on_edit();
create trigger trg_reset_moderation_user_reports before update on public.user_reports for each row execute function public.reset_moderation_on_edit();
create trigger trg_reset_moderation_whatsapp_group_reports before update on public.whatsapp_group_reports for each row execute function public.reset_moderation_on_edit();
create trigger trg_prevent_nonmoderator_restore_posts before update on public.posts for each row execute function public.prevent_nonmoderator_restore();
create trigger trg_prevent_nonmoderator_restore_comments before update on public.comments for each row execute function public.prevent_nonmoderator_restore();
create trigger trg_prevent_nonmoderator_restore_groups before update on public.whatsapp_groups for each row execute function public.prevent_nonmoderator_restore();
create trigger trg_sync_post_likes after insert or delete on public.post_likes for each row execute function _triggers.sync_post_likes_counter();
create trigger trg_sync_group_upvotes after insert or delete on public.whatsapp_group_upvotes for each row execute function _triggers.sync_group_upvotes_counter();
create trigger trg_sync_group_reported after insert or delete on public.whatsapp_group_reports for each row execute function _triggers.sync_group_reported_counter();
create trigger trg_notify_comment_inserted after insert on public.comments for each row execute function _triggers.notify_comment_inserted();
create trigger trg_notify_new_post after insert on public.posts for each row execute function _triggers.notify_new_post();
create trigger trg_notify_post_liked after insert on public.post_likes for each row execute function _triggers.notify_post_liked();

-- RLS policies
create policy "Lectura pública del foro (anon)" on public.posts for select to anon using (moderation_status is distinct from 2);
create policy "Lectura pública del foro (auth)" on public.posts for select to authenticated using ((moderation_status is distinct from 2) or public.is_pemtree_moderator(auth.uid()));
create policy "Permitir crear publicaciones a usuarios autenticados" on public.posts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Actualizar propias publicaciones" on public.posts for update to authenticated using ((select auth.uid()) = user_id);
create policy "Eliminar propias publicaciones o admin" on public.posts for delete to authenticated using (((select auth.uid()) = user_id) or public.is_pemtree_admin((select auth.uid())));

create policy "Lectura pública de comentarios (anon)" on public.comments for select to anon using (moderation_status is distinct from 2);
create policy "Lectura pública de comentarios (auth)" on public.comments for select to authenticated using ((moderation_status is distinct from 2) or public.is_pemtree_moderator((select auth.uid())));
create policy "Permitir crear comentarios a usuarios autenticados" on public.comments for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Actualizar propios comentarios" on public.comments for update to authenticated using ((select auth.uid()) = user_id);
create policy "Eliminar propios comentarios o admin" on public.comments for delete to authenticated using (((select auth.uid()) = user_id) or public.is_pemtree_admin((select auth.uid())));

create policy "Permitir lectura de likes a todos" on public.post_likes for select to public using (true);
create policy "Permitir dar like a usuarios autenticados" on public.post_likes for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Permitir quitar el propio like" on public.post_likes for delete to public using ((select auth.uid()) = user_id);

create policy "Permitir crear reportes a usuarios autenticados" on public.user_reports for insert to authenticated with check ((select auth.uid()) = reporter_id);
create policy "Permitir ver reportes propios o a admin/moderador" on public.user_reports for select to authenticated using (((select auth.uid()) = reporter_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));
create policy "Actualizar reportes de usuarios dueño, admin o moderador" on public.user_reports for update to authenticated using (((select auth.uid()) = reporter_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));
create policy "Borrar reportes de usuarios dueño, admin o moderador" on public.user_reports for delete to authenticated using (((select auth.uid()) = reporter_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));

create policy "Lectura pública de grupos (anon)" on public.whatsapp_groups for select to anon using (moderation_status is distinct from 2);
create policy "Lectura pública de grupos (auth)" on public.whatsapp_groups for select to authenticated using ((moderation_status is distinct from 2) or public.is_pemtree_moderator((select auth.uid())));
create policy "Crear grupos solo autenticados" on public.whatsapp_groups for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Editar grupos dueño, admin o moderador" on public.whatsapp_groups for update to authenticated using (((select auth.uid()) = user_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));
create policy "Borrar grupos dueño, admin o moderador" on public.whatsapp_groups for delete to authenticated using (((select auth.uid()) = user_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));

create policy "Lectura pública de votos de grupos" on public.whatsapp_group_upvotes for select to public using (true);
create policy "Votar en grupos solo usuarios autenticados" on public.whatsapp_group_upvotes for insert to public with check ((select auth.uid()) = user_id);
create policy "Retirar voto solo por el usuario que lo emitió" on public.whatsapp_group_upvotes for delete to public using ((select auth.uid()) = user_id);

create policy "Reportar grupos solo autenticados" on public.whatsapp_group_reports for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Ver reportes propios o admin/moderador" on public.whatsapp_group_reports for select to authenticated using (((select auth.uid()) = user_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));
create policy "Actualizar reportes de grupos admin o moderador" on public.whatsapp_group_reports for update to authenticated using (public.is_pemtree_admin((select auth.uid())) or public.is_pemtree_moderator((select auth.uid())));
create policy "Borrar reportes de grupos dueño, admin o moderador" on public.whatsapp_group_reports for delete to authenticated using (((select auth.uid()) = user_id) or ((auth.uid() is not null) and public.is_pemtree_admin((select auth.uid()))) or ((auth.uid() is not null) and public.is_pemtree_moderator((select auth.uid()))));

create policy "Leer rol propio" on public.user_roles for select to authenticated using ((select auth.uid()) = user_id);

create policy "Solo admins pueden ver auditoría" on public.moderation_audit_log for select to authenticated using (((select auth.uid()) is not null) and public.is_pemtree_admin((select auth.uid())));

create policy "Ver mis preferencias de notificación" on public.notification_preferences for select to public using ((select auth.uid()) = user_id);
create policy "Crear mis preferencias de notificación" on public.notification_preferences for insert to public with check ((select auth.uid()) = user_id);
create policy "Actualizar mis preferencias de notificación" on public.notification_preferences for update to public using ((select auth.uid()) = user_id);

create policy "Ver mis suscripciones de notificación" on public.notification_subscriptions for select to public using ((select auth.uid()) = user_id);
create policy "Crear mis suscripciones de notificación" on public.notification_subscriptions for insert to public with check ((select auth.uid()) = user_id);
create policy "Actualizar mis suscripciones de notificación" on public.notification_subscriptions for update to public using ((select auth.uid()) = user_id);
create policy "Borrar mis suscripciones de notificación" on public.notification_subscriptions for delete to public using ((select auth.uid()) = user_id);

create policy "Ver mis notificaciones" on public.user_notifications for select to public using ((select auth.uid()) = user_id);
create policy "Actualizar mis notificaciones (leídas)" on public.user_notifications for update to public using ((select auth.uid()) = user_id);
create policy "Borrar mis notificaciones" on public.user_notifications for delete to public using ((select auth.uid()) = user_id);

create policy "Lectura pública de docentes" on public.docentes for select to public using (true);
create policy "Solo admin actualiza docentes" on public.docentes for update to authenticated using (public.is_pemtree_admin((select auth.uid()))) with check (public.is_pemtree_admin((select auth.uid())));

create policy "Lectura pública de reseñas de docentes" on public.docente_reviews for select to public using (true);
create policy "Usuarios autenticados pueden reseñar" on public.docente_reviews for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "El autor puede actualizar su reseña" on public.docente_reviews for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "El autor o admin pueden borrar la reseña" on public.docente_reviews for delete to authenticated using (((select auth.uid()) = user_id) or public.is_pemtree_admin((select auth.uid())));

-- Grants
grant usage on schema public to anon, authenticated, service_role;
grant all on table public.posts, public.comments, public.post_likes, public.user_reports, public.whatsapp_groups, public.whatsapp_group_upvotes, public.whatsapp_group_reports, public.user_roles, public.moderation_audit_log, public.notification_preferences, public.notification_subscriptions, public.user_notifications, public.docentes, public.docente_reviews to anon, authenticated, service_role;
grant all on table public.docente_reputation to anon, authenticated, service_role;
grant execute on function public.is_pemtree_admin(uuid) to authenticated;
grant execute on function public.is_pemtree_moderator(uuid) to authenticated;
grant execute on function public.ocultar_contenido_moderado(text, uuid, text) to authenticated;
grant execute on function public.restaurar_contenido_moderado(text, uuid) to authenticated;
grant execute on function public.eliminar_contenido_moderado(text, uuid, text) to authenticated;
grant execute on function public.apply_moderation_batch(jsonb) to authenticated;
grant execute on function public.get_user_profiles(uuid[]) to authenticated;
grant execute on function public.v_moderation_queue() to authenticated;
grant execute on function public.get_push_secrets() to service_role;;
