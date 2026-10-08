# 11 — Métricas de UX y trazabilidad

> KPIs, taxonomía de eventos y matriz que enlaza cada requisito con su
> implementación y pruebas.

---

## 1. Principios de medición

- **UX-MET-001 — Minimización de datos.** Solo se instrumentan eventos
  agregados y no identificables; nunca se envían datos académicos, de carné o
  contenido de publicaciones a analítica.
- **UX-MET-002 — Consentimiento y transparencia.** Los eventos de producto son
  anónimos y se documentan en las normas de la comunidad.
- **UX-MET-003 — Accionabilidad.** Toda métrica tiene un dueño y una decisión
  asociada; no se mide por medir.

---

## 2. Taxonomía de eventos

Nombre en formato `dominio_accion` (snake_case, sin datos personales).

| Evento | Cuándo se emite | Propiedades (agregadas) |
|---|---|---|
| `app_open` | Arranque de la app | `platform`, `theme` |
| `nav_change` | Cambio de destino principal | `destino`, `plataforma` |
| `auth_modal_open` | Se abre el flujo de autenticación | `origen` (acción interrumpida) |
| `auth_signup_start` / `auth_signup_done` | Registro iniciado/terminado | `metodo` (email/google) |
| `otp_resend` | Reenvío de OTP | `intento` |
| `mfa_enroll_start` / `mfa_enroll_done` | Enrolamiento TOTP | `tiempo` |
| `mfa_grace_skip` | El usuario pospone el MFA dentro del período de gracia | `dia` |
| `mfa_challenge_fail` | Fallo de desafío TOTP | `motivo` (sin datos sensibles) |
| `forum_post_create` | Publicación creada | `canal`, `tiene_encuesta`, `tiene_adjunto` |
| `forum_comment_create` | Comentario creado | `es_respuesta` |
| `market_listing_create` | Anuncio creado | `categoria`, `es_gratis` |
| `market_contact_click` | Clic en contacto externo | `red` (whatsapp/telegram/instagram) |
| `market_listing_sold` | Anuncio marcado vendido | `dias_publicado` |
| `group_share` / `group_open` | Grupo compartido/abierto | `plataforma` |
| `carne_validation_done` | Carné validado | `resultado` |
| `report_sent` | Reporte enviado | `tipo_entidad`, `motivo` |
| `error_shown` | Error mostrado al usuario | `pantalla`, `categoria` |
| `media_fallback_used` | Se usó el fallback de almacenamiento | `origen` |
| `sponsored_impression` | Se mostró una unidad patrocinada | `seccion` (foro/grupos/marketplace), `patrocinador`, `categoria` |
| `sponsored_click` | Clic/CTA en una unidad patrocinada | `seccion`, `patrocinador`, `cta` |
| `sponsored_hide` | El usuario ocultó una unidad patrocinada | `seccion`, `patrocinador` |
| `sponsored_report` | El usuario reportó una unidad patrocinada | `seccion`, `patrocinador`, `motivo` |
| `sponsored_why_open` | El usuario abrió "¿Por qué veo esto?" | `seccion` |

---

## 3. KPIs

| KPI | Definición | Objetivo |
|---|---|---|
| Finalización de onboarding | `auth_signup_done` + `mfa_enroll_done` / inicios | ≥ 60 % |
| Abandono en MFA | `mfa_grace_skip` + caídas entre `mfa_enroll_start` y `done` | ≤ 25 % |
| Contacto exitoso | `market_contact_click` por anuncio visto | creciente |
| Resolución de reportes | reportes cerrados / recibidos (semanal) | ≥ 90 % |
| Adopción de Grupos | `group_open` / usuarios activos | creciente |
| Efectividad de errores | `error_shown` con acción posterior | ≥ 70 % |
| CTR de patrocinios | `sponsored_click` / `sponsored_impression` (por sección) | informativo |
| Carga publicitaria | unidades patrocinadas / elementos orgánicos | ≤ 1:6 |
| Molestia publicitaria | `sponsored_hide` + `sponsored_report` / impresiones | ≤ 5 % |

---

## 4. Matriz de trazabilidad

Leyenda de estado: ✅ cubierto · 🟡 parcial · ❌ pendiente.

> La columna **Prueba** cita el archivo existente en `test/`,
> `integration_test/` o `supabase/tests/` que respalda el requisito.

### 4.1 Producto y navegación

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-PRD-010 Visitante solo lectura | `core/services/supabase_service.dart`; migración `enforce_anonymous_read_only.sql` | `supabase/tests/anonymous_read_only_test.sql`; `integration_test/guest_navigation_test.dart` | ✅ |
| UX-PRD-011 Escritura requiere AAL2 | `shared/widgets/totp_session_guard.dart` | `test/widgets/totp_session_guard_test.dart`; `supabase/tests/totp_aal2_writes_test.sql` | ✅ |
| UX-MAP-001 Deep links | `main.dart` (`_onGenerateRoute`) | `test/sso_test.dart` | 🟡 |
| UX-MAP-002 Retorno en subpantallas | `features/forum/screens/post_detail_screen.dart` | `integration_test/forum_flow_test.dart` | 🟡 |
| UX-MAP-003 Enlaces externos | `core/utils/url_utils.dart` | `test/utils/storage_url_test.dart` | 🟡 |
| UX-NAV-001 Tres destinos (08) | `features/navigation/app_shell.dart`; `features/forum/widgets/discord/forum_server_rail.dart` | `test/widgets/app_shell_test.dart` | 🟡 |
| UX-NAV-002 Preservación de estado (08) | `app_shell.dart` (`IndexedStack`) | ❌ | 🟡 |
| UX-NAV-005/006 Tabs / NavigationBar (08) | `app_shell.dart` | `test/widgets/app_shell_test.dart` | 🟡 |
| UX-NAV-008 Aviso comunitario (08) | `app_shell.dart` (`_showDisclaimerModal`) | 🟡 | 🟡 |
| UX-REG-002 Las 7 reglas | `features/rules/screens/rules_screen.dart` | `test/widgets/rules_screen_test.dart` | ✅ |

### 4.2 Foro

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-FORO-001 Feed y canales | `features/forum/screens/forum_screen.dart` | `test/forum_test.dart`; `integration_test/forum_flow_test.dart` | ✅ |
| UX-FORO-002 Rail de servidores | `features/forum/widgets/discord/forum_server_rail.dart` | `test/discord_forum_test.dart` | 🟡 |
| UX-FORO-003 Explorador de carreras | `features/forum/widgets/discord/forum_carrera_picker_dialog.dart` | `test/core/categories_catalog_test.dart` | 🟡 |
| UX-FORO-008 Tarjeta de publicación | `features/forum/widgets/post_card.dart` | `test/forum_test.dart` | 🟡 |
| UX-FORO-010 Comentarios anidados | `features/forum/widgets/comment_item.dart`; `core/services/forum_service.dart` | `test/services/forum_service_test.dart`; `supabase/tests/comments_rls_test.sql` | ✅ |
| UX-FORO-012 Encuestas | `forum_screen.dart`; `supabase/tests/counters_triggers_test.sql` | `test/forum_test.dart` | 🟡 |
| UX-FORO-013 Me gusta | `core/services/forum_service.dart` | `test/services/forum_service_test.dart` | 🟡 |
| UX-FORO-014 Marcadores | `core/services/forum_service.dart` | `supabase/tests/posts_rls_test.sql` | 🟡 |
| UX-FORO-016 Reporte | `features/shared/widgets/report_dialog.dart` | `test/widgets/shared/report_dialog_test.dart`; `supabase/tests/rpc_moderation_test.sql` | ✅ |
| UX-FORO-017 Crear post | `features/forum/widgets/create_post_dialog.dart` | `test/widgets/dialogs/create_post_dialog_test.dart` | ✅ |

### 4.3 Marketplace

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-MKT-004 Filtros y búsqueda | `features/marketplace/screens/marketplace_screen.dart` | `test/widgets/marketplace_screen_test.dart` | ✅ |
| UX-MKT-005/006 Grid y galería | `features/marketplace/widgets/marketplace_card.dart`; `features/shared/widgets/image_viewer_dialog.dart` | `test/widgets/shared/image_viewer_dialog_test.dart` | ✅ |
| UX-MKT-008 Ciclo de vida del artículo | `core/services/marketplace_service.dart` | `test/services/marketplace_service_test.dart` | 🟡 |
| UX-MKT-009 Contacto directo | `core/models/marketplace_item.dart`; `core/utils/url_utils.dart` | `test/models/marketplace_item_model_test.dart` | ✅ |
| UX-MKT-012 Crear anuncio | `features/marketplace/widgets/create_listing_dialog.dart` | `test/widgets/dialogs/create_listing_dialog_test.dart` | ✅ |
| UX-MKT-013 Filtro semántico | `core/services/marketplace_service.dart` | `test/services/marketplace_validation_test.dart` | ✅ |
| UX-MKT-014 Validación de carné (vendedor) | `features/profile/widgets/carne_validation_modal.dart` | `test/widgets/shared/carne_validation_modal_test.dart` | 🟡 |
| UX-MKT-015 Fallback de imágenes `[Mejora]` | `core/services/storage_service.dart` | `test/services/storage_service_test.dart` | ❌ |
| UX-MKT-002/003 Patrocinios | `features/marketplace/widgets/sponsor_carousel.dart`; `sponsor_request_dialog.dart` | `test/widgets/sponsor_carousel_test.dart`; `sponsor_request_dialog_test.dart` | ✅ |

### 4.4 Grupos

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-GRP-001 Acceso directo `[Mejora]` | `app_shell.dart`; `features/groups/screens/groups_screen.dart` | `test/widgets/groups_screen_test.dart`; `integration_test/groups_flow_test.dart` | 🟡 |
| UX-GRP-002 Filtrado por facultad/carrera | `core/services/groups_service.dart` | `test/services/groups_service_test.dart` | ✅ |
| UX-GRP-005 Detección de plataforma | `core/models/whatsapp_group.dart` | `test/models/whatsapp_group_model_test.dart` | ✅ |
| UX-GRP-008 Compartir grupo | `features/groups/widgets/create_group_dialog.dart` | `test/widgets/dialogs/create_group_dialog_test.dart` | ✅ |
| UX-GRP-006/007 Upvote y reporte | `core/services/groups_service.dart` | `supabase/tests/groups_marketplace_rls_test.sql` | 🟡 |

### 4.5 Perfil y cuenta

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-PRF-001/002 Avatar y alias | `features/profile/screens/profile_screen.dart`; `features/profile/widgets/alias_modal.dart` | `test/widgets/profile_screen_test.dart`; `test/widgets/shared/alias_modal_test.dart` | ✅ |
| UX-PRF-003 Alias en la nube `[Mejora]` | `core/services/local_storage_service.dart`; `profile_service.dart` | `test/services/local_storage_service_test.dart` | ❌ |
| UX-PRF-006 Facultad/carrera/sede | `features/profile/screens/profile_screen.dart`; `core/models/facultad.dart` | `test/models/facultad_model_test.dart` | 🟡 |
| UX-PRF-008/009/010 Actividad y eliminación | `core/services/{forum,groups,marketplace}_service.dart` | `test/widgets/profile_screen_test.dart` | 🟡 |
| UX-PRF-013 Verificación con carné | `features/profile/widgets/carne_validation_modal.dart` | `test/widgets/shared/carne_validation_modal_test.dart` | 🟡 |
| UX-PRF-014 MFA en perfil | `features/profile/screens/totp_enrollment_screen.dart` | `test/widgets/totp_enrollment_screen_test.dart` | ✅ |
| UX-PRF-015 Sesión / logout | `core/services/supabase_service.dart` | `test/services/supabase_service_test.dart`; `integration_test/profile_flow_test.dart` | ✅ |

### 4.6 Autenticación y SSO

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-AUTH-001 Visitante + barrera contextual | `features/shared/widgets/auth_modal.dart` | `test/widgets/shared/auth_modal_test.dart`; `integration_test/guest_navigation_test.dart` | ✅ |
| UX-AUTH-002 Registro | `core/services/supabase_service.dart` | `test/services/supabase_service_test.dart` | 🟡 |
| UX-AUTH-003 OTP con cuenta regresiva `[Mejora]` | `auth_modal.dart` | `test/widgets/shared/auth_modal_test.dart` | ❌ |
| UX-AUTH-005 Recuperación de contraseña `[Mejora]` | `supabase_service.dart` | `test/services/supabase_service_test.dart` | 🟡 |
| UX-AUTH-006 Google OAuth PKCE | `supabase_service.dart`; `main.dart` | `test/sso_test.dart` | 🟡 |
| UX-AUTH-008 MFA con gracia `[Mejora]` | `shared/widgets/totp_session_guard.dart` | `test/widgets/totp_session_guard_test.dart` | ❌ |
| UX-AUTH-009/010/011 TOTP, respaldo y desafío | `features/profile/screens/totp_enrollment_screen.dart`; `totp_session_guard.dart` | `test/widgets/totp_enrollment_screen_test.dart`; `supabase/tests/totp_aal2_writes_test.sql` | ✅ |
| UX-AUTH-013 Validación de redirect SSO | `features/sso/sso_security_validator.dart` | `test/sso_test.dart` | ✅ |
| UX-AUTH-014 Consentimiento y tokens en fragmento | `features/sso/screens/sso_authorize_screen.dart` | `integration_test/sso_flow_test.dart` | ✅ |
| UX-AUTH-015 Redirect local `[Mejora]` | `sso_authorize_screen.dart` | `test/sso_test.dart` | 🟡 |

### 4.7 Sistema de diseño y transversales

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-DSN-001 Tema claro/oscuro | `core/config/app_theme.dart`; `main.dart` | 🟡 | 🟡 |
| UX-DSN-003 Componentes base | `shared/widgets/empty_state_widget.dart`; `network_state_widgets.dart`; `identity_badge_chip.dart` | `test/widgets/shared/empty_state_test.dart`; `network_state_widgets_test.dart`; `identity_badge_chip_test.dart` | ✅ |
| UX-DSN-004 Breakpoints | `core/utils/responsive.dart` | `test/utils/responsive_test.dart` | ✅ |
| UX-X-003 Fallback de multimedia | `core/services/storage_service.dart` | `test/services/storage_service_test.dart` | ❌ |
| UX-X-006 Sin conexión / SWR | `core/services/cache_service.dart` | `test/cache_service_test.dart` | ✅ |
| UX-X-007 Notificaciones / snackbars | `features/shared/widgets/network_state_widgets.dart` | `test/widgets/shared/network_state_widgets_test.dart` | 🟡 |
| UX-X-011 Responsive 700/1100 | `core/utils/responsive.dart` | `test/utils/responsive_test.dart` | ✅ |
| UX-X-012 Modales adaptativos | `shared/widgets/*` (`showModalBottomSheet`/`showDialog`) | `test/widgets/dialogs/create_post_dialog_test.dart` | 🟡 |
| UX-X-013 Localización es-GT | `core/utils/time_utils.dart`; textos en `lib/` | `test/utils/time_utils_test.dart` | 🟡 |
| UX-X-014 Rendimiento percibido | `features/forum/screens/forum_screen.dart` (optimista) | `test/forum_test.dart` | 🟡 |
| UX-X-015 Privacidad | `features/shared/widgets/identity_badge_chip.dart`; `features/profile/screens/profile_screen.dart` | `test/widgets/shared/identity_badge_chip_test.dart` | 🟡 |
| UX-X-016 Transparencia de patrocinios `[Mejora]` | `shared/widgets/*` + nuevo etiquetado | ❌ | ❌ |
| UX-DSN-008 Lenguaje visual de patrocinios `[Mejora]` | `core/config/app_theme.dart`; nuevo `SponsoredLabel` | ❌ | ❌ |

### 4.8 Patrocinios

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-SPN-001 Perfil de patrocinador | perfil público de patrocinador (nuevo) | ❌ | ❌ |
| UX-SPN-002 Panel del patrocinador | panel `Sponsor Studio` (nuevo) | ❌ | ❌ |
| UX-SPN-003 Etiquetado de patrocinios | `09-sistema-diseno.md` (`UX-DSN-008`) | ❌ | ❌ |
| UX-SPN-004 Frecuencia y rotación | servicio de inserción (nuevo) | ❌ | ❌ |
| UX-SPN-005 Transparencia y control | `report_dialog.dart`; preferencias locales | `test/widgets/shared/report_dialog_test.dart` | 🟡 |
| UX-SPN-006 Moderación de patrocinios | moderación existente; `rpc_moderation_test.sql` | `supabase/tests/rpc_moderation_test.sql` | 🟡 |
| UX-SPN-007 Métricas de patrocinio | analítica nueva | `11-metricas-y-trazabilidad.md` | ❌ |
| UX-SPN-008 Accesibilidad de patrocinios | `10-transversales.md` (`UX-X-016`) | ❌ | ❌ |
| UX-SPN-009 Vínculo con Marketplace | `marketplace_service.dart`; `sponsor_carousel.dart` | `test/widgets/sponsor_carousel_test.dart` | 🟡 |
| UX-SPN-010 Segmentación contextual | servicio de targeting (nuevo) | ❌ | ❌ |
| UX-FORO-021 Publicación patrocinada en el feed `[Mejora]` | nuevo `PromotedPostCard`; `forum_screen.dart` | ❌ | ❌ |
| UX-FORO-022 Interacciones del patrocinio `[Mejora]` | `PromotedPostCard` | ❌ | ❌ |
| UX-FORO-023 Espacio de promociones (opt-in) | `forum_screen.dart` | ❌ | ❌ |
| UX-FORO-024 Convivencia y no intrusión | `forum_screen.dart`; moderación | ❌ | ❌ |
| UX-GRP-010 Tarjeta patrocinada en Grupos `[Mejora]` | nuevo `SponsoredGroupCard`; `groups_screen.dart` | ❌ | ❌ |
| UX-GRP-011 Perfil de patrocinador afín al curso `[Mejora]` | nuevo `SponsoredProfileBand` | ❌ | ❌ |
| UX-GRP-012 Control y transparencia en Grupos | `groups_screen.dart`; `report_dialog.dart` | ❌ | ❌ |

---

## 5. Backlog de mejoras (`[Mejora]`)

Requisitos que corrigen carencias del código actual. Son los candidatos
prioritarios para el siguiente ciclo de trabajo.

| ID | Ajuste | Archivo citado |
|---|---|---|
| UX-FORO-001 | Selector de canales sin abrir el drawer en móvil | `forum_screen.dart` |
| UX-FORO-002 | Submenú de carreras sin desbordarse | `forum_server_rail.dart` |
| UX-FORO-003 | Explorador con agrupación y filtros por sede | `forum_carrera_picker_dialog.dart` |
| UX-FORO-004 | `# mis-guardados` para visitantes con invitación a iniciar sesión | `forum_channel_sidebar.dart` |
| UX-FORO-005 | Alias sincronizado en la nube | `local_storage_service.dart` |
| UX-FORO-006 | Reintento y skeletons en populares | `popular_servers_sidebar.dart` |
| UX-FORO-007 | Búsqueda en tiempo real (debounce) en móvil | `forum_screen.dart` |
| UX-FORO-008 | Reporte con `ReportDialog` y carga de imagen robusta | `post_card.dart` |
| UX-FORO-009 | Botón "Compartir enlace" en el detalle | `post_detail_screen.dart` |
| UX-FORO-010 | Control para hilos profundos en móvil | `comment_item.dart`; `forum_service.dart` |
| UX-FORO-011 | Botón de envío con estado deshabilitado claro | `post_detail_screen.dart` |
| UX-FORO-012 | Blindaje de porcentajes (`totalVotes == 0`) | `forum_screen.dart` |
| UX-FORO-013 | SnackBar al revertir un like fallido | `forum_screen.dart` |
| UX-FORO-014 | "Deshacer" al quitar marcador en `# mis-guardados` | `forum_screen.dart` |
| UX-FORO-015 | Elección libre de canal al citar | `forum_screen.dart` |
| UX-FORO-016 | `ReportDialog` obligatorio al reportar | `post_card.dart` |
| UX-FORO-017 | Fallback de imágenes al crear post | `create_post_dialog.dart`; `storage_service.dart` |
| UX-FORO-020 | Acceso directo a Grupos | `forum_server_rail.dart` |
| UX-MKT-014 | Verificación real de carné (no simulada) | `carne_validation_modal.dart` |
| UX-MKT-015 | Fallback de almacenamiento | `storage_service.dart` |
| UX-GRP-001 | Acceso directo desde navegación principal | `app_shell.dart` |
| UX-PRF-003 | Persistencia del alias en la nube | `local_storage_service.dart` |
| UX-AUTH-003 | Cuenta regresiva al reenviar OTP | `auth_modal.dart` |
| UX-AUTH-005 | Cuenta regresiva en recuperación | `auth_modal.dart` |
| UX-AUTH-008 | Período de gracia / explicación previa del MFA | `totp_session_guard.dart` |
| UX-AUTH-015 | Respeto transparente del redirect local | `sso_authorize_screen.dart` |
| UX-NAV-001 | Tercer destino Grupos en la navegación | `app_shell.dart` |
| UX-NAV-007 | FAB contextual coherente | `app_shell.dart` |
| UX-X-* | Mejoras transversales (estados, errores, accesibilidad, i18n, rendimiento) | ver `10-transversales.md` |
| UX-SPN-003 / UX-DSN-008 | Etiquetado de patrocinios reutilizable y contraste AA | `app_theme.dart`; nuevo `SponsoredLabel` |
| UX-SPN-004 | Inserción con tope de frecuencia (1:6) y rotación | nuevo servicio de inserción |
| UX-SPN-005 / UX-X-016 | "¿Por qué veo esto?", ocultar y reportar | `report_dialog.dart`; preferencias |
| UX-FORO-021/022 | Publicación patrocinada nativa en el feed | nuevo `PromotedPostCard`; `forum_screen.dart` |
| UX-GRP-010/011 | Tarjeta patrocinada y perfil afín en Grupos | nuevo `SponsoredGroupCard`; `groups_screen.dart` |

---

## 6. Cómo mantener esta matriz
1. Todo requisito nuevo debe agregar (o actualizar) su fila en la sección 4.
2. Si un requisito pasa a implementado, se actualiza **Estado** y se referencia
   el PR.
3. Los requisitos con estado `❌` alimentan el backlog de QA y el de la sección 5.
