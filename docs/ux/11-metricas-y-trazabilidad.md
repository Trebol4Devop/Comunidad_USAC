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

**Estado:** la taxonomía y los KPIs de este documento son propuestas; la app no
instrumenta ni envía eventos de analítica actualmente. La confirmación por OTP
por correo fue retirada, así que no se define un evento para reenviarla. El
evento de omitir la gracia MFA solo aplicaría si esa experiencia futura se
aprueba y se implementa.

Nombre en formato `dominio_accion` (snake_case, sin datos personales).

| Evento | Cuándo se emite | Propiedades (agregadas) |
|---|---|---|
| `app_open` | Arranque de la app | `platform`, `theme` |
| `nav_change` | Cambio de destino principal | `destino`, `plataforma` |
| `auth_modal_open` | Se abre el flujo de autenticación | `origen` (acción interrumpida) |
| `auth_signup_start` / `auth_signup_done` | Registro iniciado/terminado | `metodo` (email/google) |
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

Leyenda de estado: Cubierto · Parcial · Pendiente · Sin evaluar · No aplica.

El estado indica el nivel de evidencia de implementación descrito en esta
matriz; no significa por sí solo que una función esté desplegada en remoto ni
que la prueba haya pasado en la ejecución más reciente. La columna **Prueba**
cita el archivo existente en `test/`, `integration_test/` o `supabase/tests/`
que respalda el requisito, cuando se identificó una prueba específica. El valor
`Pendiente` indica que no se ha documentado una prueba específica para esa fila;
consulta los resultados fechados antes de afirmar que una suite pasa.

### 4.1 Producto y navegación

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-PRD-010 Visitante solo lectura | `core/services/supabase_service.dart`; migración `enforce_anonymous_read_only.sql` | `supabase/tests/anonymous_read_only_test.sql`; `integration_test/guest_navigation_test.dart` | Cubierto |
| UX-PRD-011 Segundo factor en la interfaz | `shared/widgets/totp_session_guard.dart`; la exigencia global de AAL2 está en `20261004000000_require_aal2_and_verified_sellers.sql`, pendiente en remoto | `test/widgets/totp_session_guard_test.dart`; `supabase/tests/authenticated_aal1_write_denied_test.sql` (pendiente de validar con la migración) | Parcial |
| UX-PRD-016 Vendedor externo verificado | campos en `profiles` y panel admin (nuevo) | Pendiente | Pendiente |
| UX-PRD-026 No lucro, financiamiento y datos | `features/rules/screens/rules_screen.dart`; `features/profile/screens/profile_screen.dart` (`UX-PRF-011`) | Pendiente | Parcial |
| UX-MAP-001 Deep links | `main.dart` (`_onGenerateRoute`) | `integration_test/sso_flow_test.dart` (ruta local `/auth/authorize`; no prueba callbacks de deep link por plataforma) | Parcial |
| UX-MAP-002 Retorno en subpantallas | `features/forum/screens/post_detail_screen.dart` | `test/forum_test.dart` (renderiza detalle; no prueba retorno a pantalla anterior) | Parcial |
| UX-MAP-003 Enlaces externos | `core/utils/url_utils.dart` | Sin prueba específica de apertura segura de enlaces externos | Parcial |
| UX-NAV-001 Cuatro destinos principales (08) | `features/navigation/app_shell.dart` | `test/widgets/app_shell_test.dart` | Parcial |
| UX-NAV-002 Preservación de estado (08) | `app_shell.dart` (`IndexedStack`) | Pendiente | Parcial |
| UX-NAV-005/006 Tabs / NavigationBar (08) | `app_shell.dart` (`Responsive.isMobile`, breakpoint 700) | `test/widgets/app_shell_test.dart` | Parcial |
| UX-NAV-008 Aviso comunitario (08) | `app_shell.dart` (`_showDisclaimerModal`) | `test/widgets/app_shell_test.dart` (apertura, contenido, acciones y foco) | Parcial |
| UX-REG-002 Las 7 reglas | `features/rules/screens/rules_screen.dart` | `test/widgets/rules_screen_test.dart` | Cubierto |

### 4.2 Foro

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-FORO-001 Feed y canales | `features/forum/screens/forum_screen.dart` | `test/forum_test.dart` (error/reintento); `integration_test/forum_flow_test.dart` (crea y consulta mediante el servicio, sin comprobar que el post aparezca en pantalla) | Parcial |
| UX-FORO-002 Rail de servidores | `features/forum/widgets/discord/forum_server_rail.dart` | `test/discord_forum_test.dart` | Parcial |
| UX-FORO-003 Explorador de carreras | `features/forum/widgets/discord/forum_carrera_picker_dialog.dart` | `test/core/categories_catalog_test.dart` | Parcial |
| UX-FORO-008 Tarjeta de publicación | `features/forum/widgets/post_card.dart` | `test/forum_test.dart` | Parcial |
| UX-FORO-010 Comentarios anidados | `features/forum/widgets/comment_item.dart`; `core/services/forum_service.dart` | `test/forum_test.dart` (renderizado anidado); `test/services/forum_service_test.dart` (árbol); `supabase/tests/comments_rls_test.sql` | Cubierto |
| UX-FORO-012 Encuestas | `features/forum/screens/forum_screen.dart`; `features/forum/widgets/create_post_dialog.dart`; `core/services/forum_service.dart` | `test/widgets/dialogs/create_post_dialog_test.dart` (controles); `test/services/forum_service_test.dart` (crear/votar); `test/models/post_model_test.dart` | Parcial |
| UX-FORO-013 Me gusta | `core/services/forum_service.dart` | `test/services/forum_service_test.dart` | Parcial |
| UX-FORO-014 Marcadores | `core/services/forum_service.dart` | `test/services/forum_service_test.dart` (insertar/quitar marcador) | Parcial |
| UX-FORO-016 Reporte | `features/shared/widgets/report_dialog.dart` | `test/widgets/shared/report_dialog_test.dart`; `supabase/tests/rpc_moderation_test.sql` | Cubierto |
| UX-FORO-017 Crear post | `features/forum/widgets/create_post_dialog.dart`; `core/services/forum_service.dart` | `test/widgets/dialogs/create_post_dialog_test.dart` (formulario/validación); `test/services/forum_service_test.dart` (persistencia) | Parcial |

### 4.3 Marketplace

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-MKT-004 Filtros y búsqueda | `features/marketplace/screens/marketplace_screen.dart` | `test/widgets/marketplace_screen_test.dart` (comprueba controles y toque del filtro gratuito; no verifica resultados de búsqueda/facetas) | Parcial |
| UX-MKT-005/006 Grid y galería | `features/marketplace/widgets/marketplace_card.dart`; `features/shared/widgets/image_viewer_dialog.dart` | `test/widgets/marketplace_screen_test.dart` (renderiza una tarjeta); `test/widgets/shared/image_viewer_dialog_test.dart` (visor/InteractiveViewer; sin prueba de galería multipágina) | Parcial |
| UX-MKT-008 Ciclo de vida del artículo | `core/services/marketplace_service.dart` | `test/services/marketplace_service_test.dart` | Parcial |
| UX-MKT-009 Contacto directo | `core/models/marketplace_item.dart`; `core/utils/url_utils.dart` | `test/models/marketplace_item_model_test.dart` (formato de URLs de contacto; sin prueba de apertura desde la tarjeta) | Parcial |
| UX-MKT-012 Crear anuncio | `features/marketplace/widgets/create_listing_dialog.dart`; `core/services/marketplace_service.dart` | `test/widgets/dialogs/create_listing_dialog_test.dart` (campos/validaciones); `test/services/marketplace_service_test.dart` (persistencia; sin prueba del envío desde el diálogo) | Parcial |
| UX-MKT-013 Filtro semántico | `core/services/marketplace_service.dart` | `test/services/marketplace_validation_test.dart` | Cubierto |
| UX-MKT-014 Verificación para vender | `features/profile/widgets/carne_validation_modal.dart` (borrador local no verificado); `core/services/marketplace_service.dart` (bloquea si falta verificación backend) | `test/widgets/shared/carne_validation_modal_test.dart`; `test/widgets/marketplace_screen_test.dart` | Parcial |
| UX-MKT-015 Resiliencia de carga de imágenes `[Mejora]` | `core/services/storage_service.dart` solo usa Worker R2; `MarketplaceCard` sí muestra placeholder ante error de visualización | `test/services/storage_service_test.dart` (cubre éxito R2 y error con retorno `null`; no prueba fallback) | Parcial |
| UX-MKT-016 Carta de presentación del vendedor | No existe una página pública propia del Marketplace; la bio general del perfil no es equivalente | Sin prueba; no existe `SellerProfileScreen` | Pendiente |
| UX-MKT-017 Límites del vendedor no patrocinador | validaciones de creación e interfaz (nuevo) | Pendiente | Pendiente |
| UX-MKT-002/003 Patrocinios | `features/marketplace/widgets/sponsor_carousel.dart`; `sponsor_request_dialog.dart` | `test/widgets/sponsor_carousel_test.dart`; `sponsor_request_dialog_test.dart` | Cubierto |

### 4.4 Grupos

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-GRP-001 Acceso directo | `features/navigation/app_shell.dart`; `features/groups/screens/groups_screen.dart` | `test/widgets/app_shell_test.dart` (navegación móvil a Grupos); `test/widgets/groups_screen_test.dart`; `integration_test/groups_flow_test.dart` (flujo de servicio/BD) | Cubierto |
| UX-GRP-002 Filtrado por facultad/carrera | `core/services/groups_service.dart`; `features/groups/screens/groups_screen.dart` | `test/services/groups_service_test.dart` (filtra por facultad; no cubre búsqueda ni todos los filtros de carrera) | Parcial |
| UX-GRP-005 Detección de plataforma | `core/models/whatsapp_group.dart` | `test/models/whatsapp_group_model_test.dart` | Cubierto |
| UX-GRP-008 Compartir grupo | `features/groups/widgets/create_group_dialog.dart`; `core/services/groups_service.dart` | `test/widgets/groups_screen_test.dart` (abre el diálogo); `test/widgets/dialogs/create_group_dialog_test.dart` (campos/validación); `test/services/groups_service_test.dart` (creación en servicio, sin envío UI integrado) | Parcial |
| UX-GRP-006/007 Upvote y reporte | `core/services/groups_service.dart`; `features/groups/widgets/group_card.dart` | `test/services/groups_service_test.dart` (upvote/reporte); `supabase/tests/counters_triggers_test.sql` (contadores de upvote/reporte; sin flujo de interfaz) | Parcial |

### 4.5 Perfil y cuenta

| Requisito | Implementacion | Prueba | Estado |
|---|---|---|---|
| UX-PRF-001/002 Avatar y alias | `features/profile/screens/profile_screen.dart`; `features/profile/widgets/alias_modal.dart` | `test/widgets/profile_screen_test.dart`; `test/widgets/shared/alias_modal_test.dart` (alias); `test/services/local_storage_service_test.dart` (persistencia local de color/icono, sin prueba del selector de avatar) | Parcial |
| UX-PRF-003 Alias en la nube `[Mejora]` | `core/services/local_storage_service.dart` (persistencia local; sincronización con `profiles` no implementada) | `test/services/local_storage_service_test.dart` (solo almacenamiento local) | Pendiente |
| UX-PRF-006 Facultad/carrera/sede | `features/profile/screens/profile_screen.dart`; `core/models/facultad.dart` | `test/models/facultad_model_test.dart`; `test/widgets/profile_screen_test.dart` (muestra secciones académicas, no prueba selección/guardado) | Parcial |
| UX-PRF-008/009/010 Actividad y eliminacion | `core/services/profile_service.dart`; `features/profile/screens/profile_screen.dart` | `test/services/profile_service_test.dart` (eliminación de post/grupo/anuncio); `test/widgets/profile_screen_test.dart` (estados vacíos; sin flujo de eliminación en UI) | Parcial |
| UX-PRF-013 Verificacion con carne | `features/profile/widgets/carne_validation_modal.dart` | `test/widgets/shared/carne_validation_modal_test.dart` (consentimiento, validaciones y borrador no verificado; no acredita verificación institucional real) | Parcial |
| UX-PRF-014 MFA en perfil | `features/profile/screens/totp_enrollment_screen.dart`; `core/services/supabase_service.dart` | `test/widgets/totp_enrollment_screen_test.dart` (enrolamiento); `test/services/supabase_service_test.dart` (rechaza baja sin código válido; sin flujo UI completo de administración) | Parcial |
| UX-PRF-015 Sesion / logout | `core/services/supabase_service.dart`; `features/profile/screens/profile_screen.dart` | `test/services/supabase_service_test.dart` (inicio/cierre de sesión del servicio); `integration_test/profile_flow_test.dart` (alias y carné, no prueba logout) | Parcial |
| UX-PRF-016 Menu inicial: bienvenida y 'Omitir' `[Mejora]` | pantalla `OnboardingScreen` (nuevo); clave `usac_onboarding_done` en `SharedPreferences` | Pendiente | Pendiente |
| UX-PRF-017 Contexto academico en primer uso `[Mejora]` | reutiliza selectores de `profile_screen.dart`; `core/models/facultad.dart` | Pendiente | Pendiente |
| UX-PRF-018 Seleccion de intereses de contenido `[Mejora]` | tabla `user_interests` (nuevo); almacenamiento local como fallback | Pendiente | Pendiente |
| UX-PRF-019 Preferencias de notificaciones en primer uso `[Mejora]` | `notification_preferences` local existe para flags del Foro; no cubre todos los canales del onboarding; sin integración Flutter verificada | Pendiente | Pendiente |
| UX-PRF-020 Identidad inicial: alias y avatar `[Mejora]` | `ProfileScreen` permite editar/generar alias y personalizar avatar; onboarding nuevo | `profile_screen_test.dart` cubre generación/guardado de alias; no prueba selector de avatar ni onboarding | Parcial (perfil; onboarding pendiente) |
| UX-PRF-021 Cierre del menu inicial y primer feed `[Mejora]` | `OnboardingScreen` (nuevo); logica de fallback a area comun en `forum_screen.dart` | Pendiente | Pendiente |
| UX-PRF-022 Centro de preferencias e intereses `[Mejora]` | `ProfileScreen` tiene controles de tema, normas y sesión; no existe hub `PreferencesScreen` | `profile_screen_test.dart` cubre la pantalla de perfil, no el hub | Pendiente |
| UX-PRF-023 Gestion de intereses: anadir, quitar y restablecer `[Mejora]` | No se encontró `user_interests` en migraciones ni código Flutter; `PreferencesScreen` inexistente | Pendiente | Pendiente |
| UX-PRF-024 Contenido silenciado y 'Deshacer' `[Mejora]` | No se encontró `content_mutes` ni `PreferencesScreen`; solo hay ocultamiento local de anuncios patrocinados en `SponsoredPreferencesService` | `test/services/sponsored_preferences_service_test.dart` cubre ocultamiento por anuncio/usuario, no lista general ni deshacer | Parcial (solo anuncios patrocinados) |
| UX-PRF-025 Preferencias de patrocinios: frecuencia y transparencia `[Mejora]` | `notification_preferences` local no incluye `sponsor_frequency` ni preferencias de transparencia; modelo y `PreferencesScreen` pendientes | Pendiente | Pendiente |
| UX-PRF-026 Sincronizacion de preferencias `[Mejora]` | `notification_preferences` local existe para flags del Foro; `user_interests`, `content_mutes` y preferencias de patrocinios requieren modelo por definir; sincronización pendiente | Pendiente | Pendiente |
| UX-PRF-027 Modelo de categorias personalizadas por pantalla (opt-in) `[Mejora]` | `forum_screen.dart`; `marketplace_screen.dart`; `groups_screen.dart`; `user_interests` (nuevo); `PreferencesScreen` (nuevo) | Pendiente | Pendiente |
| UX-PRF-028 Control "+ Categorias" y selector por pantalla `[Mejora]` | `forum_screen.dart`; `marketplace_screen.dart`; `groups_screen.dart`; selector de categorias (nuevo) | Pendiente | Pendiente |
| UX-PRF-029 Sugerencias contextuales de categorias `[Mejora]` | `core/models/facultad.dart`; `PreferencesScreen` (nuevo) | Pendiente | Pendiente |
| UX-PRF-030 Estado sin resultados en pantalla filtrada `[Mejora]` | `shared/widgets/empty_state_widget.dart`; `forum_screen.dart`; `marketplace_screen.dart`; `groups_screen.dart` | Pendiente | Pendiente |
| UX-PRF-031 Tarjeta de presentacion por perfil `[Mejora]` | `post_card.dart`; `comment_item.dart`; `marketplace_card.dart`; `group_card.dart`; `ProfileCardSheet` (nuevo); tabla `profile_card_visibility` (nuevo) | Pendiente | Pendiente |
| UX-PRF-032 Consentimiento por campo y visibilidad (default anonimo) `[Mejora]` | `profiles`; tabla `profile_card_visibility` (nuevo); `SharedPreferences` como fallback de visitante | Pendiente | Pendiente |
| UX-PRF-033 Campos revelables y limites por contexto `[Mejora]` | `profile_screen.dart` (UX-PRF-006/007); `profile_card_visibility` (nuevo) | Pendiente | Pendiente |
| UX-PRF-034 Control y previsualizacion de mi tarjeta `[Mejora]` | `PreferencesScreen` (nuevo); `ProfileCardSheet` (nuevo); `profile_card_visibility` (nuevo) | Pendiente | Pendiente |
| UX-PRF-035 Admisión de vendedor externo | panel admin y formulario de solicitud (nuevo) | Pendiente | Pendiente |


### 4.6 Autenticación y SSO

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-AUTH-001 Visitante + barrera contextual | `features/shared/widgets/auth_modal.dart` | `test/widgets/shared/auth_modal_test.dart`; `integration_test/guest_navigation_test.dart` | Cubierto |
| UX-AUTH-002 Registro | `features/shared/widgets/auth_modal.dart`; `core/services/supabase_service.dart` | `test/widgets/shared/auth_modal_test.dart` (registro con Supabase simulado y guía de confirmación; no valida el envío remoto) | Parcial |
| UX-AUTH-003 Confirmación OTP por correo `[Retirada]` | No se solicita ni valida un código OTP; si Supabase devuelve una cuenta pendiente de confirmar, la interfaz indica revisar el correo. El método/configuración remotos no están verificados | `test/widgets/shared/auth_modal_test.dart` (sin código; comprueba la guía de confirmación) | No aplica |
| UX-AUTH-005 Recuperación de contraseña por correo `[Fuera de alcance]` | No hay flujo ni envío de recuperación por correo, conforme a la decisión de alcance | `test/widgets/shared/auth_modal_test.dart` (comprueba que no se ofrece recuperación) | No aplica |
| UX-AUTH-006 Google OAuth PKCE | `core/services/supabase_service.dart` (`signInWithGoogle`); `main.dart`; configuración remota de proveedor/redirect no verificada | `test/widgets/shared/auth_modal_test.dart` (solo comprueba que aparece el botón; no prueba OAuth/callback) | Parcial |
| UX-AUTH-008 MFA con gracia `[Mejora]` | `shared/widgets/totp_session_guard.dart` exige enrolamiento/desafío; no implementa inducción ni período de gracia | `test/widgets/totp_session_guard_test.dart` (prueba el guardián actual, no una gracia) | Pendiente |
| UX-AUTH-009/011 TOTP y desafío (UX-AUTH-010 recuperación aplazada) | `features/profile/screens/totp_enrollment_screen.dart`; `shared/widgets/totp_session_guard.dart`; política global de AAL2 pendiente en remoto | `test/widgets/totp_enrollment_screen_test.dart`; `test/widgets/totp_session_guard_test.dart`; `test/services/supabase_service_test.dart` (Auth simulado) | Cubierto |
| UX-AUTH-013 Validación de redirect SSO | `features/sso/sso_security_validator.dart` | `test/sso_test.dart` | Cubierto |
| UX-AUTH-014 SSO Authorization Code + PKCE | Servidor OAuth/clientes no configurados; SSO deshabilitado | `integration_test/sso_flow_test.dart` solo comprueba la pantalla y estados locales; no hace intercambio OAuth real | Pendiente |
| UX-AUTH-015 Redirect local `[Mejora]` | `sso_authorize_screen.dart` reescribe ciertos redirects PEMTREE/Netlify a `localhost:5173` al ejecutarse en web local; no hay banner ni selector y SSO sigue deshabilitado | `test/sso_test.dart` solo valida la allowlist; sin prueba del redirect efectivo o del selector | Parcial |
| UX-AUTH-016 Acceso según dominio de correo | lógica de autenticación y panel admin de dominios (nuevo) | Pendiente | Pendiente |

### 4.7 Sistema de diseño y transversales

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-DSN-001 Tema claro/oscuro | `core/config/app_theme.dart`; `main.dart`; `core/services/local_storage_service.dart` | `test/services/local_storage_service_test.dart` | Parcial |
| UX-DSN-003 Componentes base | `shared/widgets/empty_state_widget.dart`; `network_state_widgets.dart`; `identity_badge_chip.dart` | `test/widgets/shared/empty_state_test.dart`; `network_state_widgets_test.dart`; `identity_badge_chip_test.dart` | Cubierto |
| UX-DSN-004 Breakpoints | `core/utils/responsive.dart` | `test/utils/responsive_test.dart` | Cubierto |
| UX-X-003 Fallback de multimedia | `core/services/storage_service.dart` | `test/services/storage_service_test.dart` | Pendiente |
| UX-X-006 Sin conexión / SWR | `core/services/cache_service.dart`; servicios de Foro, Grupos y Marketplace (fallback persistido en consultas predeterminadas tras fallo) | `test/cache_service_test.dart` (TTL, persistencia y stale); `test/widgets/shared/network_state_widgets_test.dart` (banner/reintento; sin flujo offline integrado) | Parcial |
| UX-X-007 Notificaciones / snackbars | `features/shared/widgets/network_state_widgets.dart`; mensajes SnackBar locales en features | `test/widgets/profile_screen_test.dart` (SnackBar de guardado); `test/widgets/shared/network_state_widgets_test.dart` (banner/reintento, no SnackBar); sin prueba de sistema global | Parcial |
| UX-X-011 Responsive 700/1100 | `core/utils/responsive.dart` | `test/utils/responsive_test.dart` | Cubierto |
| UX-X-012 Modales adaptativos | `shared/widgets/*` (`showModalBottomSheet`/`showDialog`) | `test/widgets/dialogs/create_post_dialog_test.dart` | Parcial |
| UX-X-013 Localización es-GT | `core/utils/time_utils.dart`; textos en `lib/` | `test/utils/time_utils_test.dart` | Parcial |
| UX-X-014 Rendimiento percibido | `features/forum/screens/forum_screen.dart` (interacciones optimistas) | `test/forum_test.dart` (fallo de like y estado restaurado; sin medición de latencia/rendimiento) | Parcial |
| UX-X-015 Privacidad | `features/shared/widgets/identity_badge_chip.dart`; `features/profile/screens/profile_screen.dart` | `test/widgets/shared/identity_badge_chip_test.dart` | Parcial |
| UX-X-016 Transparencia de patrocinios `[Mejora]` | `features/marketplace/widgets/sponsored_content_controls.dart`; preferencias locales (sin sincronización) | `test/widgets/sponsored_content_controls_test.dart`; `test/services/sponsored_preferences_service_test.dart` | Parcial |
| UX-DSN-008 Lenguaje visual de patrocinios `[Mejora]` | `features/marketplace/widgets/marketplace_card.dart`; `sponsor_carousel.dart` | `test/widgets/sponsor_carousel_test.dart` | Parcial |

### 4.8 Patrocinios

| Requisito | Implementación | Prueba | Estado |
|---|---|---|---|
| UX-SPN-001 Perfil de patrocinador | perfil público de patrocinador (nuevo) | Pendiente | Pendiente |
| UX-SPN-002 Panel del patrocinador | panel `Sponsor Studio` (nuevo) | Pendiente | Pendiente |
| UX-SPN-003 Etiquetado de patrocinios | `features/marketplace/widgets/sponsored_content_controls.dart`, usado en `MarketplaceCard` y `SponsorCarousel`; colores literales y sin integración en Foro/Grupos | `test/widgets/sponsored_content_controls_test.dart`; `test/widgets/sponsor_carousel_test.dart` | Parcial (Marketplace) |
| UX-SPN-004 Frecuencia y rotación | servicio de inserción (nuevo) | Pendiente | Pendiente |
| UX-SPN-005 Transparencia y control | `features/marketplace/widgets/sponsored_content_controls.dart`; `core/services/sponsored_preferences_service.dart` (ocultamientos locales por usuario) | `test/widgets/sponsored_content_controls_test.dart`; `test/services/sponsored_preferences_service_test.dart` | Parcial (Marketplace; sin sincronización entre dispositivos) |
| UX-SPN-006 Moderación de patrocinios | `core/services/marketplace_service.dart` llama `moderate_marketplace_item`; no existe cola de aprobación específica de promociones | `supabase/tests/rpc_moderation_test.sql` (permisos de moderación de anuncios Marketplace; no prueba aprobación de promociones) | Parcial |
| UX-SPN-007 Métricas de patrocinio | Analítica no instrumentada; eventos/KPIs solo propuestos en este documento | Sin instrumentación ni prueba específica | Pendiente |
| UX-SPN-008 Accesibilidad de patrocinios | `features/marketplace/widgets/sponsored_content_controls.dart`; requisitos completos en `10-transversales.md` (`UX-X-016`) | `test/widgets/sponsored_content_controls_test.dart` (etiqueta semántica y tamaño táctil; sin auditoría de contraste, teclado o carga diferida) | Parcial |
| UX-SPN-009 Vínculo con Marketplace | `core/services/marketplace_service.dart`; `features/marketplace/widgets/sponsor_carousel.dart` | `test/services/marketplace_service_test.dart` (lectura de anuncios patrocinados); `test/widgets/sponsor_carousel_test.dart` (presentación/contacto; sin perfil público integrado) | Parcial |
| UX-SPN-010 Segmentación contextual | servicio de targeting (nuevo) | Pendiente | Pendiente |
| UX-SPN-011 Solicitud de cuenta de patrocinador | `sponsor_requests` en `20261001000000_adopt_remote_schema.sql`; `features/marketplace/widgets/sponsor_request_dialog.dart` (sin validación de duplicados) | `test/widgets/sponsor_request_dialog_test.dart` (campos/validaciones); `test/services/marketplace_service_test.dart` (error de inserción; no flujo exitoso integrado) | Parcial |
| UX-SPN-012 Aprobación/rechazo de solicitud | `sponsor_requests.status` e índice en `20261001000000_adopt_remote_schema.sql`; políticas locales en `20261004000000_require_aal2_and_verified_sellers.sql` (sin verificación de aplicación remota); pantalla Flutter inexistente | Pendiente (panel y RLS remoto por verificar) | Pendiente |
| UX-SPN-013 Vigencia y renovación de promoción | tabla `sponsored_promotions` (nuevo); `marketplace_items` sin `fecha_fin` | Pendiente | Pendiente |
| UX-SPN-014 Suspensión y baja del patrocinador | No hay estado de suspensión de patrocinador; `profiles.is_verified` y `seller_verification_status` son verificaciones distintas | Pendiente | Pendiente |
| UX-SPN-015 Notificaciones de ciclo de vida | Infraestructura local de notificaciones para eventos del Foro (`user_notifications`, preferencias y suscripciones); sin tipos/eventos de patrocinio ni integración Flutter; endpoint push etiquetado PEMTREE sin verificar para Comunidad_USAC | Pendiente | Pendiente |
| UX-SPN-016 Panel admin de solicitudes | `idx_sponsor_requests_status` en `20261001000000_adopt_remote_schema.sql`; políticas locales en `20261004000000_require_aal2_and_verified_sellers.sql` (sin verificación de aplicación remota); pantalla Flutter inexistente | Pendiente (panel y RLS remoto por verificar) | Pendiente |
| UX-FORO-021 Publicación patrocinada en el feed `[Mejora]` | nuevo `PromotedPostCard`; `forum_screen.dart` | Pendiente | Pendiente |
| UX-FORO-022 Interacciones del patrocinio `[Mejora]` | `PromotedPostCard` | Pendiente | Pendiente |
| UX-FORO-023 Espacio de promociones (opt-in) | `forum_screen.dart` | Pendiente | Pendiente |
| UX-FORO-024 Convivencia y no intrusión | `forum_screen.dart`; moderación | Pendiente | Pendiente |
| UX-GRP-010 Tarjeta patrocinada en Grupos `[Mejora]` | nuevo `SponsoredGroupCard`; `groups_screen.dart` | Pendiente | Pendiente |
| UX-GRP-011 Perfil de patrocinador afín al curso `[Mejora]` | nuevo `SponsoredProfileBand` | Pendiente | Pendiente |
| UX-GRP-012 Control y transparencia en Grupos | Aún no integrado; el control existe solo en Marketplace | Pendiente | Pendiente |

### 4.9 Requisitos antes no trazados individualmente

La comparación de IDs de encabezados `### UX-*` con las filas previas de §4 encontró 41 requisitos sin una fila de evidencia individual. Se evaluaron ahora contra el código y los tests existentes. `Parcial` indica que hay implementación, pero al menos un criterio está incompleto o carece de prueba directa; `Pendiente` indica que falta la capacidad. La presencia de un test no equivale a auditoría visual o WCAG.

| Requisito | Implementación | Prueba / evidencia | Estado |
|---|---|---|---|
| UX-AUTH-004 Inicio de sesión con correo y contraseña | `features/shared/widgets/auth_modal.dart`; `core/services/supabase_service.dart` | `test/widgets/shared/auth_modal_test.dart`; `test/services/supabase_service_test.dart` | Parcial |
| UX-AUTH-007 Cierre de sesión y revocación local | `features/profile/screens/profile_screen.dart`; `shared/widgets/totp_session_guard.dart`; `supabase_service.dart` | `test/services/supabase_service_test.dart` | Parcial |
| UX-AUTH-011 Desafío TOTP | `features/shared/widgets/totp_session_guard.dart` | `test/widgets/totp_session_guard_test.dart` | Parcial |
| UX-AUTH-012 Desactivación de TOTP | `features/profile/screens/totp_enrollment_screen.dart`; `supabase_service.dart` | `test/services/supabase_service_test.dart` (solo validación de formato) | Parcial |
| UX-DSN-002 Uso consistente de tokens | `core/config/app_theme.dart`; aún hay estilos y colores literales en features | Sin prueba de consistencia global | Parcial |
| UX-DSN-005 Iconografía consistente | Iconografía Material en `features/`; restricciones/tamaños no normalizados | `test/widgets/app_shell_test.dart` (tooltips parciales) | Parcial |
| UX-DSN-006 Movimiento sobrio | Transiciones locales en `features/forum/widgets/discord/forum_server_rail.dart`; sin preferencia global de reducir movimiento | Sin prueba de `disableAnimations` | Parcial |
| UX-DSN-007 Coherencia visual del Foro | `features/forum/`; tema Discord y tema oscuro implementados | `test/discord_forum_test.dart` (cobertura visual parcial) | Parcial |
| UX-FORO-018 Configuración de encuestas | `features/forum/widgets/create_post_dialog.dart`; `core/services/forum_service.dart` | `test/widgets/dialogs/create_post_dialog_test.dart`; `test/services/forum_service_test.dart` | Parcial |
| UX-FORO-019 Estados y modo sin conexión | `features/forum/screens/forum_screen.dart`; `core/services/cache_service.dart` | `test/cache_service_test.dart`; `test/widgets/shared/network_state_widgets_test.dart` (sin flujo integrado) | Parcial |
| UX-FORO-020 Acceso contextual del Foro al directorio de Grupos | `features/navigation/app_shell.dart` ofrece Grupos como destino raíz; el rail del Foro excluye servidores de Grupos y no hay enlace contextual que conserve facultad/carrera | `test/widgets/app_shell_test.dart` (acceso raíz); `test/discord_forum_test.dart` (Grupos no aparece en el rail); sin prueba de transición contextual | Parcial |
| UX-GRP-003 Aviso de depuración semestral | `features/groups/screens/groups_screen.dart`; `core/services/local_storage_service.dart` | `test/widgets/groups_screen_test.dart` (descartar aviso); `test/services/local_storage_service_test.dart` (persistencia de preferencia) | Parcial |
| UX-GRP-004 Vista responsiva de grupos | `features/groups/screens/groups_screen.dart`; `features/groups/widgets/group_card.dart`; `core/utils/responsive.dart` | `test/widgets/groups_screen_test.dart` (móvil, escritorio y cuadrícula a 800 dp; sin auditoría visual exhaustiva) | Parcial |
| UX-GRP-007 Reporte de grupos | `core/services/groups_service.dart`; `features/shared/widgets/report_dialog.dart` | `test/services/groups_service_test.dart`; `test/widgets/shared/report_dialog_test.dart` | Parcial |
| UX-GRP-009 Abrir y copiar enlace | `features/groups/widgets/group_card.dart`; `core/utils/url_utils.dart` | `test/widgets/groups_screen_test.dart` (rechaza esquemas inseguros; no prueba apertura válida ni copiado) | Parcial |
| UX-MKT-001 Banner e identidad de comercio | `features/marketplace/screens/marketplace_screen.dart` | `test/widgets/marketplace_screen_test.dart` | Parcial |
| UX-MKT-003 Solicitud de patrocinio | `features/marketplace/widgets/sponsor_carousel.dart`; `sponsor_request_dialog.dart`; `marketplace_service.dart` | `test/widgets/sponsor_carousel_test.dart`; `test/widgets/sponsor_request_dialog_test.dart` | Parcial |
| UX-MKT-006 Galería y visor de imágenes | `features/marketplace/widgets/marketplace_card.dart`; `features/shared/widgets/image_viewer_dialog.dart` | `test/widgets/shared/image_viewer_dialog_test.dart` (InteractiveViewer/cierre); sin prueba de navegación por galería multipágina | Parcial |
| UX-MKT-007 Precio en Quetzales y gratuidad | `core/models/marketplace_item.dart`; `features/marketplace/widgets/marketplace_card.dart` | `test/models/marketplace_item_model_test.dart`; `test/widgets/marketplace_screen_test.dart` | Parcial |
| UX-MKT-010 Votación de utilidad | `features/marketplace/widgets/marketplace_card.dart`; `core/services/marketplace_service.dart` | Sin test específico de upvote | Parcial |
| UX-MKT-011 Reporte de anuncios | `features/marketplace/widgets/marketplace_card.dart`; `features/shared/widgets/report_dialog.dart`; `core/services/marketplace_service.dart` | `test/widgets/shared/report_dialog_test.dart`; `test/services/marketplace_service_test.dart` (RPC/servicio; sin flujo UI integrado completo) | Parcial |
| UX-NAV-003 Cabecera y distintivo no oficial | `features/navigation/app_shell.dart` | `test/widgets/app_shell_test.dart` | Parcial |
| UX-NAV-004 Acceso a normas y alternador de tema | `app_shell.dart`; `main.dart`; `core/services/local_storage_service.dart` | `test/widgets/app_shell_test.dart`; `test/services/local_storage_service_test.dart` | Parcial |
| UX-NAV-006 NavigationBar móvil | `features/navigation/app_shell.dart` | `test/widgets/app_shell_test.dart` (no incluye prueba a 320 dp) | Parcial |
| UX-PRF-002 Edición y generación de alias | `features/profile/screens/profile_screen.dart`; `features/profile/widgets/alias_modal.dart` | `test/widgets/profile_screen_test.dart`; `test/widgets/shared/alias_modal_test.dart` | Parcial |
| UX-PRF-004 Personalización de avatar | `features/profile/screens/profile_screen.dart`; `core/services/local_storage_service.dart` | `test/services/local_storage_service_test.dart` (sin flujo UI del selector) | Parcial |
| UX-PRF-007 Canales de contacto | `features/profile/screens/profile_screen.dart`; `local_storage_service.dart`; `features/marketplace/widgets/create_listing_dialog.dart` | `test/widgets/profile_screen_test.dart`; `test/services/local_storage_service_test.dart` | Parcial |
| UX-PRF-009 Gestión de grupos propios | `features/profile/screens/profile_screen.dart`; `core/services/profile_service.dart` | `test/widgets/profile_screen_test.dart` (solo vacío); `test/services/profile_service_test.dart` | Parcial |
| UX-PRF-010 Gestión de anuncios propios | `features/profile/screens/profile_screen.dart`; `core/services/profile_service.dart` | `test/widgets/profile_screen_test.dart` (solo vacío); `test/services/profile_service_test.dart` | Parcial |
| UX-PRF-012 Preferencias, tema y normas | `features/profile/screens/profile_screen.dart`; `main.dart`; `local_storage_service.dart` | `test/services/local_storage_service_test.dart`; `test/widgets/app_shell_test.dart` | Parcial |
| UX-REG-001 Pantalla de normas | `features/rules/screens/rules_screen.dart` | `test/widgets/rules_screen_test.dart` | Parcial |
| UX-REG-003 Descargo institucional | `features/rules/screens/rules_screen.dart` | `test/widgets/rules_screen_test.dart` (sin medir contraste) | Parcial |
| UX-REG-004 Enlaces oficiales | `features/rules/screens/rules_screen.dart`; `core/utils/url_utils.dart` | `test/widgets/rules_screen_test.dart` (secciones/textos; sin prueba de apertura de enlaces oficiales) | Parcial |
| UX-REG-005 Acceso y retorno a normas | `features/navigation/app_shell.dart`; `features/profile/screens/profile_screen.dart`; `features/rules/screens/rules_screen.dart` | `test/widgets/app_shell_test.dart` (acceso a RulesScreen; sin prueba específica de retorno) | Parcial |
| UX-X-001 Errores amigables | Errores y reintento en `features/groups/screens/groups_screen.dart`; sin taxonomía común | `test/widgets/groups_screen_test.dart` (sin catálogo global de errores) | Parcial |
| UX-X-002 Rate limiting y temporizadores | No se encontró tratamiento transversal de 429, tiempo de espera ni reintento condicionado | Sin prueba específica | Pendiente |
| UX-X-004 Estados vacíos accionables | `features/shared/widgets/empty_state_widget.dart`; pantallas de Foro, Grupos y Marketplace | `test/widgets/shared/empty_state_test.dart` (flujo parcial) | Parcial |
| UX-X-005 Skeletons y CLS | `features/shared/widgets/network_state_widgets.dart`; skeleton en Marketplace | `test/widgets/shared/network_state_widgets_test.dart` (sin medición CLS) | Parcial |
| UX-X-008 Contraste WCAG 2.2 AA | Temas en `core/config/app_theme.dart`; contraste no medido | Sin auditoría o test de ratios | Parcial |
| UX-X-009 Foco, teclado y lectores de pantalla | Semantics/tooltips parciales en `features/navigation/app_shell.dart` y controles patrocinados | Tests de navegación; sin auditoría de teclado/lector | Parcial |
| UX-X-010 Objetivos táctiles | Controles nuevos con mínimos locales; no normalizados globalmente | `test/widgets/sponsored_content_controls_test.dart` (sin medición global) | Parcial |

> `UX-PRF-005` está marcado obsoleto en su documento; `UX-AREA-001` es una plantilla del README, no un requisito de producto. Se excluyen de evaluación funcional hasta actualizar la plantilla/documentación.

> **Dependencias transversales y de datos**
>
> Los requisitos de esta sección dependen de dos requisitos transversales ya
> definidos en sus respectivos documentos autoritativos (no se duplican aquí):
> - **`UX-DSN-008`** — Lenguaje visual del contenido patrocinado
>   ([`09-sistema-diseno.md`](09-sistema-diseno.md)); estado: Pendiente (ver §4.7).
> - **`UX-X-016`** — Transparencia y accesibilidad del contenido patrocinado
>   ([`10-transversales.md`](10-transversales.md)); estado: Pendiente (ver §4.7).
>
> **Tablas de BD pendientes de crear** (bloqueantes para los requisitos indicados):
> - `sponsored_promotions` — con columnas `id`, `sponsor_id`, `status`,
>   `fecha_inicio`, `fecha_fin`, `moderation_status`, `created_at`, `updated_at`
>   (bloqueante para UX-SPN-013, UX-GRP-010, UX-GRP-011).
> - `sponsored_hides` — preferencias de ocultamiento por usuario/unidad
>   (bloqueante para UX-SPN-005, UX-GRP-012).
> - Tabla de **notificaciones** (bloqueante para UX-SPN-015).
> - Campo de **estado de suspensión** en `profiles` (`suspended_at` o similar)
>   (bloqueante para UX-SPN-014).

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
| UX-FORO-009 | Botón "Compartir enlace" en el detalle | `post_detail_screen.dart` |
| UX-FORO-010 | Control para hilos profundos en móvil | `comment_item.dart`; `forum_service.dart` |
| UX-FORO-012 | Prueba UI de encuesta sin votos (la guarda de porcentaje ya existe) | `post_card.dart`; `post_detail_screen.dart`; nueva prueba en `forum_test.dart` |
| UX-FORO-013 | Prueba UI del rollback de like fallido en el feed (el feedback ya existe) | `forum_screen.dart`; nueva prueba en `forum_test.dart` |
| UX-FORO-014 | "Deshacer" al quitar marcador en `# mis-guardados` | `forum_screen.dart` |
| UX-FORO-015 | Elegir otro canal al citar desde un canal específico | `forum_screen.dart`; `create_post_dialog.dart` |
| UX-FORO-017 | Fallback de imágenes al crear post | `create_post_dialog.dart`; `storage_service.dart` |
| UX-FORO-020 | Acceso contextual Foro → Grupos, conservando facultad/carrera | `forum_screen.dart`; `app_shell.dart` |
| UX-MKT-014 | Integración institucional para estudiantes y admisión de vendedores externos; el modal solo guarda borrador local no verificado | `carne_validation_modal.dart`; `marketplace_service.dart` |
| UX-MKT-015 | Fallback R2 → Supabase Storage y feedback al fallar la carga (el placeholder de visualización ya existe) | `storage_service.dart`; `marketplace_card.dart` |
| UX-MKT-016 | Página pública de Marketplace con presentación y catálogo del vendedor (no confundir con la bio general del perfil) | nueva pantalla/servicio |
| UX-PRF-003 | Sincronización del alias con Supabase; actualmente la persistencia es solo local | `local_storage_service.dart`; `profile_service.dart` |
| UX-AUTH-008 | Resolver si habrá período de gracia y reconciliar sus criterios con AAL2 antes de implementarlo | `totp_session_guard.dart`; `07-autenticacion.md` |
| UX-AUTH-015 | Respeto transparente del redirect local | `sso_authorize_screen.dart` |
| UX-X-* | Mejoras transversales (estados, errores, accesibilidad, i18n, rendimiento) | ver `10-transversales.md` |
| UX-SPN-003 / UX-DSN-008 | Token de estilo patrocinado y etiqueta reutilizable fuera de Marketplace; revisar contraste AA (el control actual solo se comparte dentro de Marketplace) | `sponsored_content_controls.dart`; `app_theme.dart` |
| UX-SPN-004 | Inserción con tope de frecuencia (1:6) y rotación | nuevo servicio de inserción |
| UX-SPN-005 / UX-X-016 | Sincronizar preferencias ocultas y completar accesibilidad; integrar los controles al añadir patrocinios fuera de Marketplace | `sponsored_preferences_service.dart`; `10-transversales.md` |
| UX-FORO-021/022 | Publicación patrocinada nativa en el feed | nuevo `PromotedPostCard`; `forum_screen.dart` |
| UX-GRP-010/011 | Tarjeta patrocinada y perfil afín en Grupos | nuevo `SponsoredGroupCard`; `groups_screen.dart` |
| UX-SPN-011 | Validación de duplicados en la solicitud de patrocinador | `sponsor_request_dialog.dart` |
| UX-SPN-012 / UX-SPN-016 | Panel admin de solicitudes (aprobación/rechazo) | `sponsor_requests`; nueva pantalla admin |
| UX-SPN-013 | Vigencia y renovación de promociones | tabla `sponsored_promotions` (nuevo) |
| UX-SPN-014 | Suspensión y baja del patrocinador | estado de suspensión en `profiles` (nuevo) |
| UX-SPN-015 | Notificaciones de ciclo de vida | tabla de notificaciones (nuevo) |
| UX-PRF-016 a UX-PRF-021 | Menú inicial de nuevos usuarios (contexto, intereses, notificaciones, identidad y cierre) | `OnboardingScreen` (nuevo); clave `usac_onboarding_done` |
| UX-PRF-022 | Centro de preferencias e intereses (hub unificado) | `PreferencesScreen` (nuevo); `profile_screen.dart:1337` |
| UX-PRF-023 | Gestión de intereses: añadir, quitar y restablecer | tabla `user_interests` (nuevo) |
| UX-PRF-024 | Contenido silenciado y "Deshacer" | tabla `content_mutes` (nuevo) |
| UX-PRF-025 | Preferencias de patrocinios (frecuencia y transparencia) | `notification_preferences` (nuevo) |
| UX-PRF-026 | Sincronización de preferencias (local + nube) | Supabase; `cache_service.dart` |
| UX-PRF-027 | Modelo opt-in de categorías personalizadas por pantalla (arranque mínimo) | `forum_screen.dart`; `marketplace_screen.dart`; `groups_screen.dart`; `user_interests` (nuevo) |
| UX-PRF-028 | Control "+ Categorías" y selector con búsqueda en cada pantalla | `forum_screen.dart`; `marketplace_screen.dart`; `groups_screen.dart`; selector (nuevo) |
| UX-PRF-029 | Sugerencias contextuales de categorías sin preselección | `core/models/facultad.dart`; `PreferencesScreen` (nuevo) |
| UX-PRF-030 | Estado sin resultados con "Añadir categorías" y "Ver todo" | `empty_state_widget.dart`; `forum_screen.dart`; `marketplace_screen.dart`; `groups_screen.dart` |
| UX-PRF-031 | Tarjeta de presentación por perfil al tocar el avatar | `post_card.dart`; `comment_item.dart`; `marketplace_card.dart`; `group_card.dart`; `ProfileCardSheet` (nuevo) |
| UX-PRF-032 | Consentimiento por campo y visibilidad anónima por defecto | `profiles`; tabla `profile_card_visibility` (nuevo); `SharedPreferences` |
| UX-PRF-033 | Campos revelables y límites por contexto (Foro vs Marketplace) | `profile_screen.dart`; `profile_card_visibility` (nuevo) |
| UX-PRF-034 | Control y previsualización de mi tarjeta en preferencias | `PreferencesScreen` (nuevo); `ProfileCardSheet` (nuevo) |
| UX-PRD-016 | Definición e identidad de vendedor externo verificado | `profiles` (nuevo campo) |
| UX-AUTH-016 | Clasificación de acceso por dominio de correo y gestión de dominios | lógica de autenticación y panel admin (nuevo) |
| UX-PRF-035 | Flujo de admisión de vendedor externo con documentos | formulario de admisión y panel admin (nuevo) |
| UX-MKT-017 | Aplicación de límites a vendedores no patrocinadores | validaciones en creación de anuncio y conteo (nuevo) |

---

## 6. Cómo mantener esta matriz
1. Todo requisito nuevo debe agregar (o actualizar) su fila en la sección 4.
2. Si un requisito pasa a implementado, se actualiza **Estado** y se referencia
   el PR.
3. Los requisitos con estado `Pendiente` alimentan el backlog de QA y el de la sección 5.

---

## 7. Avance de implementación y bloqueos externos (2026-10-30)

Esta actualización describe cambios presentes en el árbol de trabajo; no convierte
por sí sola los 181 requisitos en conformes. Actualiza la evidencia de los IDs
indicados cuando se cierre la revisión y se integre el cambio correspondiente.

| ID | Avance comprobable | Estado / límite |
|---|---|---|
| UX-NAV-001, UX-NAV-005/006 | Foro, Marketplace y Grupos están en la navegación principal; las pestañas desktop anuncian su selección y admiten teclado. | Cubierto en navegación base; falta revisión visual en dispositivos y tecnologías de asistencia. |
| UX-GRP-002, UX-GRP-005/006, UX-X-001/010 | Grupos incorpora búsqueda con debounce, validación de URL HTTPS/host, reintento, feedback de voto y objetivo táctil de 48 dp. | Parcial: el filtro por facultad/carrera y el umbral automático de moderación siguen dependiendo de datos/reglas de backend. |
| UX-FORO-009/011/013/016/017/019 | Se corrigió el destino del reporte de post, se separan errores y vacíos con reintento, se informa el fallo de like, se deshabilita el envío vacío y se ajustó el mínimo del título. | Parcial: falta compartir por deep link funcional, fallback de almacenamiento y validación integral offline. |
| UX-X-006 | La copia persistida puede recuperarse cuando la consulta de red falla aunque haya superado el TTL de frescura. | Parcial: solo se usa como fallback en consultas predeterminadas; faltan filtros persistidos y pruebas de dispositivo sin conexión. |
| UX-MKT-008/012/014, UX-PRF-013 | La app ya no declara verificado un carné aportado por el usuario. Publicar requiere `profiles.seller_verification_status = 'verified'`; el backend fuerza la identidad del propietario y bloquea auto-patrocinio/cambios de moderación. | Pendiente de integración institucional y pantalla/proceso de revisión de personal. Hasta entonces la publicación queda bloqueada; no existe verificación automática. |
| UX-SPN-005, UX-X-016 | Marketplace cuenta con explicación, ocultamiento local y reporte de unidades patrocinadas. Las solicitudes tienen control de propietario y transición de estado administrativa en la migración nueva. | Parcial: no hay panel administrativo operativo ni sincronización entre dispositivos; Foro y Grupos no tienen inserción patrocinada. |
| UX-AUTH-008 | Se conserva el requisito AAL2 sin abrir escritura durante una gracia ambigua. | Pendiente: producto debe resolver la contradicción entre la gracia de siete días y el guard AAL2 obligatorio. |
| UX-AUTH-013/014 | No se emiten tokens `mock_sso_*`; no se exponen refresh tokens en redirecciones. | Pendiente/bloqueado: OAuth Authorization Server, registro de clientes y flujo de autorización de PEMTREE no están configurados; la pantalla SSO permanece deshabilitada. |
| UX-AUTH-016, UX-PRD-016, UX-PRF-035, UX-MKT-017 | No se simula admisión por dominio ni validación de vendedores externos. | Pendiente: requiere lista de dominios administrable, proceso de admisión, almacenamiento documental protegido y revisión humana. |
| UX-MET-001/002/003 | Sin cambios de instrumentación ni envío de eventos. | Pendiente: definir destino/consentimiento/retención y desplegar almacenamiento antes de emitir analítica de uso. |
| UX-SPN-004/013/014/015, UX-GRP-010/011/012, UX-FORO-021/022/023 | No se agregó rotación, frecuencia global 1:6, vigencia, suspensión, notificaciones ni promociones en Foro/Grupos. | Pendiente: requiere modelo backend y panel de administración; los controles actuales solo cubren Marketplace. |

La migración `20261004000000_require_aal2_and_verified_sellers.sql` y sus
pruebas pgTAP se agregaron al repositorio, pero no se ejecutaron en una instancia
PostgreSQL/Supabase en esta sesión: Supabase CLI y `psql` no están disponibles.
La conformidad de RLS debe confirmarse ejecutando la suite SQL en CI antes del
despliegue.
