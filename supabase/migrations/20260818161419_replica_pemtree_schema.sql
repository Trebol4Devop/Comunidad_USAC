create table public.posts (
  id uuid not null default gen_random_uuid(),
  title text not null,
  category text not null,
  content text not null,
  author_alias text not null,
  likes integer default 0,
  user_id uuid,
  created_at timestamptz default now(),
  carrera text default 'sistemas',
  image_url text,
  moderation_status integer default 0,
  moderation_label text,
  moderation_confidence double precision,
  moderation_reason text,
  moderated_at timestamptz,
  moderated_by uuid,
  constraint posts_pkey primary key (id),
  constraint posts_user_id_fkey foreign key (user_id) references auth.users (id) on delete set null,
  constraint posts_moderated_by_fkey foreign key (moderated_by) references auth.users (id)
);
alter table public.posts enable row level security;

create table public.comments (
  id uuid not null default gen_random_uuid(),
  post_id uuid,
  author_alias text not null,
  content text not null,
  user_id uuid,
  created_at timestamptz default now(),
  parent_id uuid,
  moderation_status integer default 0,
  moderation_label text,
  moderation_confidence double precision,
  moderation_reason text,
  moderated_at timestamptz,
  moderated_by uuid,
  constraint comments_pkey primary key (id),
  constraint comments_post_id_fkey foreign key (post_id) references public.posts (id) on delete cascade,
  constraint comments_user_id_fkey foreign key (user_id) references auth.users (id) on delete set null,
  constraint fk_comments_parent_cascade foreign key (parent_id) references public.comments (id) on delete cascade,
  constraint comments_moderated_by_fkey foreign key (moderated_by) references auth.users (id)
);
alter table public.comments enable row level security;

create table public.post_likes (
  post_id uuid not null,
  user_id uuid not null,
  created_at timestamptz default now(),
  constraint post_likes_pkey primary key (post_id, user_id),
  constraint post_likes_post_id_fkey foreign key (post_id) references public.posts (id) on delete cascade,
  constraint post_likes_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);
alter table public.post_likes enable row level security;

create table public.user_reports (
  id uuid not null default gen_random_uuid(),
  reporter_id uuid not null,
  reported_user_id uuid not null,
  reported_user_alias text,
  reason text not null,
  created_at timestamptz default now(),
  moderation_status integer default 0,
  moderation_label text,
  moderation_confidence double precision,
  moderation_reason text,
  moderated_at timestamptz,
  moderated_by uuid,
  constraint user_reports_pkey primary key (id),
  constraint unique_user_report unique (reporter_id, reported_user_id),
  constraint user_reports_reporter_id_fkey foreign key (reporter_id) references auth.users (id) on delete cascade,
  constraint user_reports_moderated_by_fkey foreign key (moderated_by) references auth.users (id)
);
alter table public.user_reports enable row level security;

create table public.whatsapp_groups (
  id uuid not null default gen_random_uuid(),
  title text not null,
  carrera text not null default 'todas',
  curso text not null,
  section text,
  link text not null,
  description text,
  user_id uuid,
  author_alias text not null default 'Estudiante Anónimo',
  upvotes integer default 0,
  reported_count integer default 0,
  created_at timestamptz default now(),
  image_url text,
  moderation_status integer default 0,
  moderation_label text,
  moderation_confidence double precision,
  moderation_reason text,
  moderated_at timestamptz,
  moderated_by uuid,
  constraint whatsapp_groups_pkey primary key (id),
  constraint whatsapp_groups_moderated_by_fkey foreign key (moderated_by) references auth.users (id)
);
alter table public.whatsapp_groups enable row level security;

create table public.whatsapp_group_upvotes (
  group_id uuid not null,
  user_id uuid not null,
  created_at timestamptz default now(),
  constraint whatsapp_group_upvotes_pkey primary key (group_id, user_id),
  constraint whatsapp_group_upvotes_group_id_fkey foreign key (group_id) references public.whatsapp_groups (id) on delete cascade,
  constraint whatsapp_group_upvotes_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);
alter table public.whatsapp_group_upvotes enable row level security;

create table public.whatsapp_group_reports (
  group_id uuid not null,
  user_id uuid not null,
  reason text,
  created_at timestamptz default now(),
  moderation_status integer default 0,
  moderation_label text,
  moderation_confidence double precision,
  moderation_reason text,
  moderated_at timestamptz,
  moderated_by uuid,
  constraint whatsapp_group_reports_pkey primary key (group_id, user_id),
  constraint whatsapp_group_reports_group_id_fkey foreign key (group_id) references public.whatsapp_groups (id) on delete cascade,
  constraint whatsapp_group_reports_moderated_by_fkey foreign key (moderated_by) references auth.users (id)
);
alter table public.whatsapp_group_reports enable row level security;

create table public.user_roles (
  user_id uuid not null,
  role text not null,
  created_at timestamptz default now(),
  constraint user_roles_pkey primary key (user_id),
  constraint user_roles_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade,
  constraint user_roles_role_check check (role = any (array['admin'::text, 'moderator'::text]))
);
alter table public.user_roles enable row level security;

create table public.moderation_audit_log (
  id uuid not null default gen_random_uuid(),
  moderator_id uuid,
  entity_table text not null,
  entity_id uuid not null,
  justification text not null,
  created_at timestamptz default now(),
  is_automated boolean default false,
  moderation_label text,
  confidence double precision,
  constraint moderation_audit_log_pkey primary key (id),
  constraint moderation_audit_log_moderator_id_fkey foreign key (moderator_id) references auth.users (id) on delete set null
);
alter table public.moderation_audit_log enable row level security;

create table public.notification_preferences (
  user_id uuid not null,
  comment_enabled boolean not null default true,
  reply_enabled boolean not null default true,
  like_enabled boolean not null default true,
  new_post_enabled boolean not null default false,
  carreras text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_preferences_pkey primary key (user_id),
  constraint notification_preferences_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);
alter table public.notification_preferences enable row level security;

create table public.notification_subscriptions (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  constraint notification_subscriptions_pkey primary key (id),
  constraint notification_subscriptions_endpoint_key unique (endpoint),
  constraint notification_subscriptions_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);
alter table public.notification_subscriptions enable row level security;

create table public.user_notifications (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null,
  type text not null,
  title text not null,
  body text not null,
  actor_alias text,
  post_id uuid,
  comment_id uuid,
  read_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz not null default now(),
  constraint user_notifications_pkey primary key (id),
  constraint user_notifications_type_check check (type = any (array['comment'::text, 'reply'::text, 'like'::text, 'new_post'::text])),
  constraint user_notifications_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade,
  constraint user_notifications_post_id_fkey foreign key (post_id) references public.posts (id) on delete set null,
  constraint user_notifications_comment_id_fkey foreign key (comment_id) references public.comments (id) on delete set null
);
alter table public.user_notifications enable row level security;

create table public.docentes (
  id uuid not null default gen_random_uuid(),
  nombre text not null,
  rol text not null,
  nombre_variantes text[] not null default '{}'::text[],
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint docentes_pkey primary key (id),
  constraint docentes_nombre_rol_unique unique (nombre, rol),
  constraint docentes_rol_check check (rol = any (array['catedratico'::text, 'auxiliar'::text]))
);
alter table public.docentes enable row level security;

create table public.docente_reviews (
  id uuid not null default gen_random_uuid(),
  docente_id uuid not null,
  user_id uuid not null,
  recomienda boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint docente_reviews_pkey primary key (id),
  constraint docente_reviews_docente_user_unique unique (docente_id, user_id),
  constraint docente_reviews_docente_id_fkey foreign key (docente_id) references public.docentes (id) on delete cascade,
  constraint docente_reviews_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade
);
alter table public.docente_reviews enable row level security;

create or replace view public.docente_reputation
with (security_invoker = true) as
select d.id as docente_id,
    d.nombre,
    d.rol,
    d.activo,
    count(r.id) as total,
    count(r.id) filter (where r.recomienda) as recomendados,
        case
            when (count(r.id) = 0) then null::numeric
            else round((((count(r.id) filter (where r.recomienda))::numeric / (count(r.id))::numeric) * (100)::numeric))
        end as pct_recomienda
   from (docentes d
     left join docente_reviews r on ((r.docente_id = d.id)))
  group by d.id;

create index idx_comments_moderation_status on public.comments using btree (moderation_status);
create index idx_comments_moderated_by on public.comments using btree (moderated_by);
create index idx_comments_post_id on public.comments using btree (post_id);
create index idx_comments_user_id on public.comments using btree (user_id);
create index idx_comments_created_at on public.comments using btree (created_at);
create index idx_comments_parent_id on public.comments using btree (parent_id);
create index idx_docente_reviews_user_id on public.docente_reviews using btree (user_id);
create index docente_reviews_docente_idx on public.docente_reviews using btree (docente_id);
create index docentes_rol_idx on public.docentes using btree (rol);
create index docentes_activo_idx on public.docentes using btree (activo);
create index idx_moderation_audit_log_moderator_id on public.moderation_audit_log using btree (moderator_id);
create index idx_subscriptions_user on public.notification_subscriptions using btree (user_id);
create index idx_post_likes_user_id on public.post_likes using btree (user_id);
create index idx_posts_moderated_by on public.posts using btree (moderated_by);
create index idx_posts_user_id on public.posts using btree (user_id);
create index idx_posts_created_at on public.posts using btree (created_at);
create index idx_posts_moderation_status on public.posts using btree (moderation_status);
create index idx_notifications_user_created on public.user_notifications using btree (user_id, created_at desc);
create index idx_user_notifications_user_id on public.user_notifications using btree (user_id);
create index idx_user_notifications_comment_id on public.user_notifications using btree (comment_id);
create index idx_user_notifications_post_id on public.user_notifications using btree (post_id);
create index idx_notifications_pending_push on public.user_notifications using btree (created_at) where (push_sent_at is null);
create index idx_user_reports_created_at on public.user_reports using btree (created_at);
create index idx_user_reports_moderation_status on public.user_reports using btree (moderation_status);
create index idx_user_reports_moderated_by on public.user_reports using btree (moderated_by);
create index idx_whatsapp_group_reports_moderated_by on public.whatsapp_group_reports using btree (moderated_by);
create index idx_whatsapp_group_reports_created_at on public.whatsapp_group_reports using btree (created_at);
create index idx_whatsapp_group_reports_moderation_status on public.whatsapp_group_reports using btree (moderation_status);
create index idx_whatsapp_group_upvotes_user_id on public.whatsapp_group_upvotes using btree (user_id);
create index idx_whatsapp_groups_moderated_by on public.whatsapp_groups using btree (moderated_by);
create index idx_whatsapp_groups_moderation_status on public.whatsapp_groups using btree (moderation_status);
create index idx_whatsapp_groups_created_at on public.whatsapp_groups using btree (created_at desc);
create index idx_whatsapp_groups_curso on public.whatsapp_groups using btree (curso);
create index idx_whatsapp_groups_carrera on public.whatsapp_groups using btree (carrera);;
