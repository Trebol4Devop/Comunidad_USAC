# 12 — Patrocinios y contenido promovido

> Modelo transversal del **contenido patrocinado** (identidad, panel, etiquetado,
> frecuencia, moderación, métricas, accesibilidad, **ciclo de vida y
> administración del patrocinador**). Es consumido por el Foro
> ([`03-foro.md`](03-foro.md), prefijo `UX-FORO`) y por Grupos
> ([`05-grupos.md`](05-grupos.md), prefijo `UX-GRP`), y se apoya en el
> Marketplace ([`04-marketplace.md`](04-marketplace.md), prefijo `UX-MKT`).
> Convenciones y plantilla en [`README.md`](README.md).

---

## 1. Principios del contenido patrocinado

1. **Nativo pero etiquetado.** Una unidad patrocinada se integra con el mismo
   lenguaje visual de la sección donde aparece, pero **nunca se disfraza**: lleva
   etiqueta visible y un tratamiento de acento propio.
2. **La experiencia primero.** El usuario no debe sentir el feed "invadido": la
   frecuencia está acotada y el contenido orgánico mantiene prioridad.
3. **Una sola fuente de verdad.** Los datos del negocio (catálogo, contacto,
   identidad) provienen del Marketplace/Perfil; el patrocinio solo los *promueve*.
4. **Moderado como todo lo demás.** Ningún patrocinio se publica sin pasar por
   moderación ni puede auto-aprobarse.
5. **Transparencia y control.** Siempre se puede saber por qué se ve un anuncio,
   ocultarlo y reportarlo.

---

## 2. Identidad y cuenta de patrocinador (UX-SPN-001…010)

### UX-SPN-001 — Perfil público de patrocinador
- **Actor / rol:** Patrocinador (estudiante verificado o vendedor externo verificado); visible para todos
- **Prioridad:** Must
- **Estado objetivo:** todo patrocinador tiene un **perfil público** con: logotipo,
  nombre comercial, descripción corta, categoría, sede/facultades donde opera,
  canales de contacto y su catálogo de anuncios patrocinados. Es el destino de los
  enlaces que aparecen en Foro y Grupos.
- **Precondiciones:** cuenta con rol/atributo de patrocinador aprobado (requiere estar previamente verificado mediante carné o admisión externa).
- **UI / contenido:** encabezado con logo, nombre, distintivo **"Patrocinador"**
  verificado; bio; chips de categoría y sede; grid del catálogo; botones de
  contacto; botón "Ver todos sus anuncios".
- **Estados:** carga (skeleton) | activo | sin catálogo ("Este patrocinador aún no
  publica promociones") | perfil oculto por moderación.
- **Validaciones y reglas de negocio:** no puede operar sin aprobación; un
  patrocinador suspendido deja de promocionar y su perfil muestra "no disponible".
- **Accesibilidad:** logotipo con texto alternativo; encabezados jerárquicos;
  contraste AA del distintivo.
- **Responsive:** encabezado de una columna en móvil; dos columnas (perfil +
  catálogo) en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** un patrocinador aprobado, **When** un estudiante abre su perfil
    desde una tarjeta patrocinada, **Then** ve su identidad, contacto y catálogo.
  - **Given** un patrocinador suspendido, **When** se abre su perfil, **Then** se
    muestra como no disponible y no permite promocionar.

### UX-SPN-002 — Panel del patrocinador (Sponsor Studio)
- **Actor / rol:** Patrocinador
- **Prioridad:** Must
- **Estado objetivo:** desde su perfil, el patrocinador accede a un panel para
  (1) editar su perfil público, (2) crear/editar promociones, (3) ver métricas y
  (4) pausar/reanudar una promoción.
- **UI / contenido:** pestañas "Perfil", "Promociones", "Métricas"; formulario de
  promoción con título, texto corto, 1–3 imágenes (o 1 video), llamado a la
  acción, sede/facultad objetivo y vigencia (fecha inicio/fin).
- **Estados:** vacío ("Aún no tienes promociones") | borrador | en revisión |
  activa | pausada | finalizada | rechazada (con motivo).
- **Validaciones y reglas de negocio:** reutiliza el filtro de términos prohibidos
  del Marketplace; al guardar, la promoción pasa a **en revisión** (nunca
  publicada de inmediato).
- **Accesibilidad:** formularios con etiquetas y errores anunciados.
- **Responsive:** panel de una columna en móvil; dos en desktop.
- **Criterios de aceptación:**
  - **Given** un patrocinador, **When** crea una promoción válida, **Then** esta
    queda "en revisión" y no aparece en Foro/Grupos hasta ser aprobada.
  - **Given** una promoción activa, **When** el patrocinador la pausa, **Then**
    deja de mostrarse en todas las secciones de inmediato.

### UX-SPN-003 — Identidad visual y etiquetado del contenido patrocinado
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** toda unidad patrocinada se distingue sin ambigüedad
  mediante: etiqueta textual **"Patrocinado"** (o "Publicidad"), logotipo y nombre
  del patrocinador, distintivo verificado y un acento cromático propio sobre el
  lenguaje visual de la sección.
- **Problema actual [Mejora]:** hoy el carrusel de patrocinadores del Marketplace
  ([`sponsor_carousel.dart`](../../comunidad_universitaria/lib/features/marketplace/widgets/sponsor_carousel.dart))
  no tiene un modelo de etiquetado reutilizable para insertarse en Foro/Grupos;
  se define aquí como token de diseño ([ver `UX-DSN-008` en `09-sistema-diseno.md`](09-sistema-diseno.md)).
- **Validaciones y reglas de negocio:** la etiqueta es **obligatoria e
  ineludible**; ningún tema oscuro (dark pattern) puede ocultarla.
- **Accesibilidad:** la etiqueta se anuncia explícitamente a lectores de pantalla
  ("Contenido patrocinado por X") antes del cuerpo.
- **Responsive:** misma posición de etiqueta en móvil y desktop.
- **Criterios de aceptación:**
  - **Given** una unidad patrocinada, **When** se renderiza en cualquier sección,
    **Then** muestra la etiqueta "Patrocinado" y el nombre del patrocinador.
  - **Given** un lector de pantalla, **When** recorre el feed, **Then** anuncia el
    contenido como patrocinado antes de leerlo.

### UX-SPN-004 — Frecuencia, rotación y no intrusión
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** el sistema **acota** cuánto contenido patrocinado ve cada
  usuario: como máximo **1 unidad patrocinada por cada 6 elementos orgánicos**,
  nunca dos consecutivas, nunca antes del primer elemento orgánico y un **tope por
  usuario/día** configurable. Las promociones rotan para repartir impresiones.
- **Precondiciones:** existen promociones activas relevantes para el contexto.
- **Estados:** sin promociones relevantes → no se inserta ninguna (el feed se ve
  igual que sin patrocinios).
- **Validaciones y reglas de negocio:** nunca se inserta por encima de contenido
  fijado; nunca se reduce la posición de contenido orgánico, solo se intercala.
- **Accesibilidad:** sin efecto.
- **Responsive:** mismo ritmo en móvil y desktop, ajustado al número de ítems
  visibles.
- **Criterios de aceptación:**
  - **Given** un feed de 18 publicaciones orgánicas, **When** se cargan los
    patrocinios, **Then** aparecen como máximo 3 unidades y nunca dos seguidas.
  - **Given** un usuario que ya alcanzó su tope diario, **When** vuelve a abrir el
    feed, **Then** no se le muestra contenido patrocinado ese día.

### UX-SPN-005 — Transparencia y control del usuario
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** cada unidad patrocinada ofrece: **"¿Por qué veo esto?"**
  (explica la segmentación por sede/facultad, sin datos sensibles), **"Ocultar
  este anuncio"** y **"Reportar"**. Las preferencias se recuerdan.
- **UI / contenido:** menú desbordante (⋮) en la unidad con esas tres acciones;
  hoja/ diálogo explicativo breve.
- **Estados:** explicación mostrada | oculto (no vuelve a aparecer) | reportado.
- **Validaciones y reglas de negocio:** nunca se segmenta por datos sensibles ni
  personales; la explicación es comprensible y en español.
- **Accesibilidad:** acciones con etiqueta accesible y foco gestionado.
- **Responsive:** menú como hoja inferior en móvil; popover en desktop.
- **Criterios de aceptación:**
  - **Given** una unidad patrocinada, **When** el usuario pulsa "¿Por qué veo
    esto?", **Then** se explica la razón sin exponer datos personales.
  - **Given** que el usuario oculta un anuncio, **When** recarga la sección,
    **Then** ese anuncio no vuelve a mostrarse.

### UX-SPN-006 — Moderación y aprobación
- **Actor / rol:** Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** todo contenido patrocinado entra en **cola de moderación**;
  se aprueba, rechaza con motivo o retira. El patrocinador no puede auto-aprobarse.
  El contenido patrocinado cumple las mismas 7 reglas comunitarias.
- **Validaciones y reglas de negocio:** se aplican los términos prohibidos; un
  patrocinio reportado de forma reiterada se pausa preventivamente.
- **Accesibilidad:** estados de moderación anunciados.
- **Responsive:** igual.
- **Criterios de aceptación:**
  - **Given** una promoción nueva, **When** se guarda, **Then** no se muestra
    hasta que un moderador la apruebe.
  - **Given** una promoción con contenido prohibido, **When** se revisa, **Then**
    se rechaza con un motivo visible para el patrocinador.

### UX-SPN-007 — Métricas del patrocinio
- **Actor / rol:** Patrocinador, Admin
- **Prioridad:** Should
- **Estado objetivo:** el panel muestra impresiones, clics, CTR y tasa de
  ocultamiento/reporte por promoción y por sección (Foro, Grupos). El sistema
  vigila la **carga publicitaria** agregada.
- **Validaciones y reglas de negocio:** métricas agregadas y anónimas; nunca se
  expone a quién se mostró.
- **Criterios de aceptación:**
  - **Given** una promoción activa, **When** el patrocinador abre Métricas,
    **Then** ve impresiones, clics y CTR por sección.
  - **Given** una carga publicitaria por encima del umbral, **When** el sistema lo
    detecta, **Then** reduce automáticamente la frecuencia.

### UX-SPN-008 — Accesibilidad y rendimiento del contenido patrocinado
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** el contenido patrocinado cumple los mismos estándares que
  el orgánico: contraste AA, foco y teclado, imágenes con texto alternativo, carga
  diferida y sin reproducción automática con sonido.
- **Criterios de aceptación:**
  - **Given** una unidad patrocinada con video, **When** aparece en pantalla,
    **Then** no se reproduce con sonido automáticamente.
  - **Given** conexión lenta, **When** se carga el feed, **Then** la unidad
    patrocinada carga de forma diferida sin bloquear el contenido orgánico.

### UX-SPN-009 — Vínculo único con Marketplace y perfil público
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** la promoción reutiliza los datos del anuncio del Marketplace
  y del perfil del patrocinador; al tocarla, lleva a la ficha del producto o al
  perfil. Un cambio en el catálogo se refleja en la promoción.
- **Criterios de aceptación:**
  - **Given** una promoción vinculada a un anuncio, **When** el anuncio se marca
    como vendido, **Then** la promoción deja de mostrarse.
  - **Given** un toque en la unidad, **When** se procesa, **Then** se abre la ficha
    del producto o el perfil del patrocinador, según el CTA.

### UX-SPN-010 — Segmentación responsable por contexto académico
- **Actor / rol:** Todos
- **Prioridad:** Should
- **Estado objetivo:** la promoción puede dirigirse a una sede, facultad o carrera;
  a falta de coincidencia, se degrada a un patrocinio general de bajo alcance.
- **Validaciones y reglas de negocio:** prohibida la segmentación por datos
  sensibles; el usuario puede ver la razón (enlace con UX-SPN-005).
- **Criterios de aceptación:**
  - **Given** una promoción dirigida a Ingeniería y un usuario de Medicina,
    **When** navega el feed, **Then** no ve esa promoción específica.
  - **Given** el usuario en el servidor de Ingeniería, **When** hay una promoción
    dirigida a Ingeniería, **Then** sí es candidata a mostrarse (sujeta a
    frecuencia).

---

## 3. Ciclo de vida y administración del patrocinador (UX-SPN-011…016)

### UX-SPN-011 — Solicitud de cuenta de patrocinador
- **Actor / rol:** Estudiante registrado (con o sin carné) / Vendedor externo verificado
- **Prioridad:** Must
- **Estado objetivo:** el usuario que desea patrocinar llena un formulario de solicitud para
  obtener el rol de patrocinador; la solicitud queda en estado `pending` hasta la
  aprobación o rechazo por parte del admin. El usuario recibe confirmación
  inmediata y puede consultar el estado de su solicitud en cualquier momento.
- **Problema actual [Mejora]:** `sponsor_request_dialog.dart` captura la solicitud
  pero **no valida duplicados** — un mismo usuario puede enviar múltiples
  solicitudes. La tabla `sponsor_requests` soporta el flujo
  (`status CHECK('pending','in_review','approved','rejected')`), pero la capa
  Flutter no bloquea el reenvío. Se requiere consultar la existencia de una
  solicitud previa antes de abrir el formulario.
- **Precondiciones:** usuario autenticado con AAL2; si es estudiante sin carné verificado debe validarlo (UX-PRF-013) antes de activar el patrocinio; si es no estudiante debe estar admitido como Vendedor externo verificado (UX-PRF-035); no posee ya el rol de
  patrocinador ni una solicitud activa (`status IN ('pending','in_review')`).
- **UI / contenido:** botón "Convertirme en patrocinador" en el perfil o en el
  Marketplace; diálogo `sponsor_request_dialog.dart` (existente) con los campos
  que hoy persiste `sponsor_requests`: nombre comercial (`brand_name`), nombre y
  teléfono de contacto (`contact_name`, `contact_phone`), correo (`email`),
  descripción de la propuesta (`proposal_details`) y colocación esperada
  (`expected_placement`). Botón "Enviar solicitud". Si ya existe solicitud activa,
  muestra su estado en lugar del formulario: "Tu solicitud está en revisión".
  Nota [Mejora]: la categoría y la sede/facultad objetivo que menciona UX-SPN-010
  requerirían columnas nuevas en `sponsor_requests`.
- **Interacciones:** al enviar, se inserta una fila en `sponsor_requests` con
  `status = 'pending'`; se muestra un snackbar de confirmación "Tu solicitud fue
  enviada. Te notificaremos cuando sea revisada.". Al intentar abrir el formulario
  con solicitud existente, se navega a la vista de estado en lugar de abrir el
  formulario.
- **Estados:** sin solicitud (formulario disponible) | solicitud `pending` (muestra
  estado "Pendiente de revisión") | solicitud `in_review` (muestra "En revisión")
  | solicitud `approved` (rol ya activo, botón no visible) | solicitud `rejected`
  (muestra motivo y opción "Volver a solicitar").
- **Validaciones y reglas de negocio:**
  - El sistema verifica si existe una fila en `sponsor_requests` para el usuario
    con `status IN ('pending','in_review')` antes de permitir el envío; si existe,
    bloquea la duplicación. [Mejora: carencia actual en `sponsor_request_dialog.dart`.]
  - El índice `idx_sponsor_requests_status` (migration `20260918020004`)
    respalda la consulta por estado.
  - El nombre comercial es obligatorio (máx. 80 caracteres); la descripción, entre
    10 y 500 caracteres.
- **Accesibilidad:** formulario con etiquetas explícitas en cada campo; errores de
  validación anunciados por lector de pantalla; botón de envío desactivado hasta
  que los campos obligatorios estén completos.
- **Responsive:** diálogo a ancho completo en móvil; modal centrado de 480 px en
  desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante autenticado sin solicitud previa, **When** completa el
    formulario y pulsa "Enviar solicitud", **Then** se inserta una fila en
    `sponsor_requests` con `status = 'pending'` y el usuario ve "Tu solicitud fue
    enviada".
  - **Given** un usuario con solicitud en estado `pending`, **When** intenta abrir
    el formulario nuevamente, **Then** el sistema bloquea la duplicación y muestra
    el estado actual "Pendiente de revisión".
  - **Given** una solicitud rechazada, **When** el usuario elige "Volver a
    solicitar", **Then** puede enviar una nueva solicitud (la anterior queda en
    `rejected`).

### UX-SPN-012 — Aprobación/rechazo de solicitud
- **Actor / rol:** Admin / Moderador
- **Prioridad:** Must
- **Estado objetivo:** el panel admin lista las solicitudes de patrocinio por
  estado; el admin puede aprobar (activa el rol de patrocinador) o rechazar con un
  motivo textual obligatorio visible para el solicitante. El solicitante es
  notificado del resultado.
- **Problema actual [Mejora]:** `sponsor_requests.status` y el índice
  `idx_sponsor_requests_status` existen en BD, y `20260918020500_admin_panels_rls_policies.sql`
  establece las políticas RLS para admins. Sin embargo, **no existe ninguna
  pantalla Flutter** que liste y gestione estas solicitudes; el admin no tiene hoy
  forma de aprobar o rechazar desde la app.
- **Precondiciones:** admin o moderador autenticado con AAL2; existe al menos una
  solicitud en `sponsor_requests`.
- **UI / contenido:** pantalla de administración (nuevo) con lista de solicitudes
  paginada, filtrable por `status`; cada fila muestra: nombre comercial, usuario
  solicitante (alias), fecha, estado actual y acciones "Aprobar" / "Rechazar". Al
  rechazar, se abre un campo de texto obligatorio "Motivo del rechazo" (mín.
  20 caracteres).
- **Interacciones:** al aprobar, `sponsor_requests.status` pasa a `'approved'` y
  el perfil del usuario adquiere el atributo de patrocinador activo; al rechazar,
  `status` pasa a `'rejected'` y se persiste el motivo; en ambos casos, se
  dispara la notificación al solicitante (ver UX-SPN-015).
- **Estados:** lista vacía ("No hay solicitudes en este estado") | cargando
  (skeleton) | solicitud pendiente | en revisión | aprobada | rechazada.
- **Validaciones y reglas de negocio:**
  - Solo roles `admin` y `moderator` pueden modificar `sponsor_requests.status`
    (garantizado por `admin_panels_rls_policies`).
  - El motivo de rechazo es obligatorio; no se puede confirmar el rechazo sin él.
  - El cambio de `status` es irreversible desde la UI de rechazo; se puede
    reabrir solo mediante una nueva solicitud del usuario.
- **Accesibilidad:** botones de acción con roles ARIA; el diálogo de rechazo
  anuncia el campo de motivo como requerido; foco gestionado al abrir/cerrar el
  diálogo.
- **Responsive:** lista en columna única en móvil; tabla con columnas en desktop;
  diálogo de rechazo adaptativo.
- **Criterios de aceptación (Gherkin):**
  - **Given** una solicitud con `status = 'pending'`, **When** el admin la aprueba,
    **Then** `sponsor_requests.status` pasa a `'approved'` y el solicitante
    adquiere el atributo de patrocinador activo.
  - **Given** una solicitud `pending`, **When** el admin la rechaza con un motivo
    de al menos 20 caracteres, **Then** `status` pasa a `'rejected'` y el
    solicitante puede ver el motivo en su panel.
  - **Given** el campo de motivo vacío, **When** el admin intenta confirmar el
    rechazo, **Then** el botón de confirmación permanece desactivado y se muestra
    "El motivo es obligatorio".

### UX-SPN-013 — Vigencia y renovación de promoción
- **Actor / rol:** Patrocinador / Admin
- **Prioridad:** Must
- **Estado objetivo:** cada promoción tiene una fecha de inicio y una fecha de fin;
  al vencer, el sistema la marca automáticamente como `finalizada` y deja de
  mostrarla en feeds. El patrocinador puede renovarla desde el Sponsor Studio con
  una nueva fecha de fin, lo que regresa la promoción a `en revisión`.
- **Problema actual [Mejora]:** la tabla `sponsored_promotions` **no existe aún**
  en la base de datos (no encontrada en el baseline ni en migrations); es una tabla
  pendiente de crear. `marketplace_items` tiene `created_at` pero no `fecha_fin`.
  Sin esta tabla, la lógica de vigencia no puede implementarse.
- **Precondiciones:** el patrocinador tiene una cuenta aprobada y al menos una
  promoción creada en `sponsored_promotions` (nuevo).
- **UI / contenido:** en el Sponsor Studio, cada tarjeta de promoción muestra la
  vigencia ("Activa hasta: DD/MM/AAAA"); al vencer, el estado cambia a
  "Finalizada" con un botón "Renovar". El diálogo de renovación solicita nueva
  fecha de fin (mín. 7 días desde hoy, máx. 90 días).
- **Interacciones:** el sistema evalúa periódicamente las fechas de fin; al
  vencer, actualiza el estado a `finalizada` y retira la promoción de todos los
  feeds. Al renovar, el patrocinador elige la nueva fecha y el estado vuelve a
  `in_review`.
- **Estados:** activa (con contador de días restantes) | por vencer (≤ 7 días,
  resaltado en amarillo) | finalizada | en revisión (tras renovar) | aprobada |
  rechazada (con motivo).
- **Validaciones y reglas de negocio:**
  - La fecha de fin no puede ser anterior a la fecha de inicio ni a hoy.
  - Una promoción finalizada no puede renovarse con una fecha en el pasado.
  - La renovación obliga a nueva moderación (evita evasión de revisión).
  - Dependencia de implementación: requiere tabla `sponsored_promotions` (nuevo)
    con columnas `id`, `sponsor_id`, `status`, `fecha_inicio`, `fecha_fin`,
    `moderation_status`, `created_at`, `updated_at`.
- **Accesibilidad:** el contador de días restantes tiene texto alternativo; el
  cambio de estado se anuncia con un snackbar accesible.
- **Responsive:** tarjetas de gestión en columna única en móvil; grid de dos
  columnas en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** una promoción con `fecha_fin` en el pasado, **When** el sistema la
    evalúa, **Then** su estado cambia a `finalizada` y deja de aparecer en feeds.
  - **Given** un patrocinador con una promoción finalizada, **When** la renueva con
    una fecha futura válida, **Then** el estado vuelve a `in_review` y no se
    publica hasta que el admin la apruebe nuevamente.
  - **Given** el campo de nueva fecha vacío o en el pasado, **When** el patrocinador
    intenta confirmar la renovación, **Then** se muestra "La fecha de fin debe ser
    al menos 7 días desde hoy".

### UX-SPN-014 — Suspensión y baja del patrocinador
- **Actor / rol:** Admin / Moderador
- **Prioridad:** Must
- **Estado objetivo:** el admin puede suspender temporalmente (pausar todas las
  promociones activas) o dar de baja definitivamente a un patrocinador. En ambos
  casos, todas sus promociones desaparecen de feeds de inmediato y su perfil
  público muestra "No disponible". La reactivación (para suspensiones temporales)
  restaura las promociones con vigencia vigente.
- **Problema actual [Mejora]:** no existe una columna `suspended` ni
  `suspended_at` en la tabla `profiles`; la suspensión de patrocinadores no puede
  implementarse en la BD actual. `profiles.is_verified` existe
  (`idx_profiles_unverified`) pero no cubre la suspensión de cuentas de
  patrocinador. Requiere campo adicional (nuevo) en perfiles o en la tabla de
  patrocinadores.
- **Precondiciones:** admin autenticado con AAL2; el patrocinador a suspender/dar
  de baja existe y está en estado activo.
- **UI / contenido:** en la pantalla de administración (nuevo), opción "Suspender"
  y "Dar de baja" en el menú de acciones del patrocinador; diálogo de confirmación
  con campo de motivo obligatorio y advertencia "Esta acción retirará todas sus
  promociones activas de inmediato".
- **Interacciones:** al suspender, se actualiza el estado del patrocinador a
  `suspended` y todas sus promociones pasan a `pausada_por_admin`; el perfil
  muestra "No disponible". Al reactivar, las promociones con vigencia vigente
  vuelven a `aprobada`. Al dar de baja, el estado es permanente: el perfil se
  archiva y no puede reactivarse.
- **Estados:** activo | suspendido (temporalmente) | dado de baja (permanente).
- **Validaciones y reglas de negocio:**
  - El motivo de suspensión/baja es obligatorio y queda registrado (auditoría).
  - Solo el admin puede dar de baja definitiva; moderador puede suspender
    temporalmente.
  - Una baja definitiva no puede revertirse desde la UI; requiere intervención
    directa en la BD por el admin de sistema.
  - Dependencia de implementación: requiere campo de estado de suspensión en
    `profiles` o en tabla de patrocinadores (nuevo).
- **Accesibilidad:** diálogo de confirmación con foco atrapado; el botón
  destructivo ("Dar de baja") tiene contraste AA y etiqueta clara.
- **Responsive:** diálogo adaptativo; botones apilados en móvil.
- **Criterios de aceptación (Gherkin):**
  - **Given** un patrocinador activo con dos promociones activas, **When** el admin
    lo suspende con un motivo, **Then** ambas promociones desaparecen de todos los
    feeds y el perfil muestra "No disponible".
  - **Given** un patrocinador suspendido, **When** el admin lo reactiva, **Then**
    sus promociones con vigencia vigente vuelven a mostrarse sin requerir nueva
    moderación.
  - **Given** el campo de motivo vacío, **When** el admin intenta confirmar la
    suspensión, **Then** el botón de confirmación permanece desactivado.

### UX-SPN-015 — Notificaciones de ciclo de vida
- **Actor / rol:** Patrocinador
- **Prioridad:** Should
- **Estado objetivo:** el sistema notifica al patrocinador en los eventos clave del
  ciclo de vida: (1) solicitud aprobada o rechazada (con motivo), (2) promoción
  aprobada o rechazada (con motivo), (3) promoción por vencer (aviso con 7 días de
  antelación), (4) cuenta suspendida o dada de baja. Las notificaciones son
  accesibles desde la app y/o por correo.
- **Problema actual [Mejora]:** no existe tabla de notificaciones en el baseline
  ni en las migrations actuales; la infraestructura de notificaciones es
  dependencia de implementación (nuevo).
- **Precondiciones:** el patrocinador tiene una cuenta activa o en proceso de
  solicitud.
- **UI / contenido:** notificación en la campana de la app (si existe el módulo de
  notificaciones) y/o correo electrónico; el mensaje indica el evento y, si
  procede, el motivo o la acción requerida. Ejemplo: "Tu solicitud de patrocinio
  fue aprobada. ¡Ya puedes crear tu primera promoción!" / "Tu promoción
  '[Título]' vence en 7 días. Renuévala desde tu panel."
- **Interacciones:** al tocar la notificación, se navega a la pantalla relevante
  (panel de solicitudes, Sponsor Studio o el detalle de la promoción).
- **Estados:** no leída | leída | acción requerida (p. ej. renovar antes de que
  expire).
- **Validaciones y reglas de negocio:**
  - Las notificaciones de aviso de vencimiento se envían exactamente 7 días antes
    de `fecha_fin`; no se repiten.
  - Las notificaciones de aprobación/rechazo se envían en el momento del cambio
    de estado.
  - Dependencia de implementación: requiere tabla de notificaciones (nuevo) o
    integración con servicio de correo transaccional.
- **Accesibilidad:** notificaciones con texto descriptivo completo; no dependen
  solo del color para transmitir el estado.
- **Responsive:** notificaciones in-app adaptativas; correo con plantilla legible
  en móvil.
- **Criterios de aceptación (Gherkin):**
  - **Given** una solicitud aprobada por el admin, **When** el sistema procesa la
    aprobación, **Then** el solicitante recibe una notificación "Tu solicitud de
    patrocinio fue aprobada".
  - **Given** una promoción con 7 días para vencer, **When** el sistema la detecta,
    **Then** envía un aviso "Tu promoción '[Título]' vence en 7 días" sin que el
    patrocinador deba revisarlo manualmente.
  - **Given** una cuenta suspendida, **When** el admin ejecuta la suspensión,
    **Then** el patrocinador recibe una notificación con el motivo registrado.

### UX-SPN-016 — Panel admin de solicitudes
- **Actor / rol:** Admin
- **Prioridad:** Must
- **Estado objetivo:** pantalla dedicada en el panel de administración (nuevo) que
  lista las solicitudes de `sponsor_requests` ordenadas por
  `(status, created_at DESC)`, permite filtrar por estado
  (`pending` / `in_review` / `approved` / `rejected`), revisar los detalles de
  cada solicitud y ejecutar la aprobación o rechazo en una sola vista.
- **Problema actual [Mejora]:** el índice `idx_sponsor_requests_status`
  (migration `20260918020004`) y las políticas RLS de
  `20260918020500_admin_panels_rls_policies.sql` ya existen y dan soporte a este
  panel, pero **no existe ninguna pantalla Flutter** para gestionarlo. La tabla
  `sponsor_requests` tiene columnas `status`, `user_id` (FK `auth.users`) y
  `created_at`.
- **Precondiciones:** admin autenticado con AAL2; acceso al panel de
  administración.
- **UI / contenido:** pantalla (nuevo) con:
  - Barra de filtros por `status` (chips o pestañas): "Pendientes",
    "En revisión", "Aprobadas", "Rechazadas".
  - Lista paginada de solicitudes; cada ítem muestra: nombre comercial, alias del
    solicitante, fecha de envío, estado y badge de color.
  - Al tocar un ítem: vista de detalle con datos del emprendimiento, historial de
    estados y botones de acción "Aprobar" / "Rechazar".
  - Indicador de conteo por estado en las pestañas ("Pendientes (3)").
- **Interacciones:** filtrar por estado actualiza la lista; aprobar o rechazar
  activa el flujo de UX-SPN-012; tras la acción, la solicitud desaparece del
  filtro activo y el contador se actualiza.
- **Estados:** lista vacía ("No hay solicitudes en este estado") | cargando
  (skeleton de filas) | con resultados | error de red (con opción de reintentar).
- **Validaciones y reglas de negocio:**
  - Solo roles `admin` pueden acceder al panel (garantizado por
    `admin_panels_rls_policies`).
  - El ordenamiento por `(status, created_at DESC)` está soportado por
    `idx_sponsor_requests_status`.
  - El panel no permite editar los datos de la solicitud, solo aprobarla o
    rechazarla.
- **Accesibilidad:** lista con roles de tabla accesibles; filtros anunciados como
  "Filtrar solicitudes por estado"; estado de carga anunciado.
- **Responsive:** lista en columna única en móvil; tabla con columnas
  (nombre, fecha, estado, acciones) en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** el admin abre el panel de solicitudes y filtra por "Pendientes",
    **When** se carga la lista, **Then** ve únicamente solicitudes con
    `status = 'pending'` ordenadas de más reciente a más antigua.
  - **Given** el admin aprueba una solicitud desde el panel, **When** confirma la
    acción, **Then** la fila desaparece del filtro "Pendientes" y aparece en
    "Aprobadas", y el contador se actualiza de inmediato.
  - **Given** que no hay solicitudes pendientes, **When** el admin abre el filtro
    "Pendientes", **Then** ve el estado vacío "No hay solicitudes en este estado".

---

## 4. Integración en el Foro (UX-FORO-021…024)

> La definición autoritativa de estos requisitos vive en
> [`03-foro.md`](03-foro.md). Las filas a continuación son un resumen de
> referencia; no se duplica el contenido normativo.

| ID | Título | Prioridad | Referencia |
|---|---|---|---|
| UX-FORO-021 | Publicación patrocinada nativa en el feed | Should | [`03-foro.md § UX-FORO-021`](03-foro.md) |
| UX-FORO-022 | Interacciones de la publicación patrocinada | Should | [`03-foro.md § UX-FORO-022`](03-foro.md) |
| UX-FORO-023 | Espacio dedicado de promociones por facultad (opt-in) | Could | [`03-foro.md § UX-FORO-023`](03-foro.md) |
| UX-FORO-024 | Convivencia, moderación y no intrusión en el feed | Must | [`03-foro.md § UX-FORO-024`](03-foro.md) |

## 5. Integración en Grupos (UX-GRP-010…012)

> La definición autoritativa de estos requisitos vive en
> [`05-grupos.md`](05-grupos.md). Las filas a continuación son un resumen de
> referencia; no se duplica el contenido normativo.

| ID | Título | Prioridad | Referencia |
|---|---|---|---|
| UX-GRP-010 | Aparición patrocinada ocasional en el directorio | Could | [`05-grupos.md § UX-GRP-010`](05-grupos.md) |
| UX-GRP-011 | Enlace ocasional al perfil del patrocinador vinculado al curso | Could | [`05-grupos.md § UX-GRP-011`](05-grupos.md) |
| UX-GRP-012 | Frecuencia, transparencia y control en Grupos | Must | [`05-grupos.md § UX-GRP-012`](05-grupos.md) |

---

## 6. Trazabilidad

> Tabla de referencia rápida de los requisitos propios de este documento.
> La matriz canónica completa (con implementación, prueba y estado) se mantiene
> en [`11-metricas-y-trazabilidad.md` § 4.8](11-metricas-y-trazabilidad.md).

| Requisito | Implementación / anclaje | Estado |
|---|---|---|
| UX-SPN-001 Perfil de patrocinador | perfil público de patrocinador (nuevo) | Pendiente |
| UX-SPN-002 Panel del patrocinador | panel `Sponsor Studio` (nuevo) | Pendiente |
| UX-SPN-003 Etiquetado de patrocinios | `UX-DSN-008`; `sponsor_carousel.dart` | Pendiente |
| UX-SPN-004 Frecuencia y rotación | servicio de inserción (nuevo) | Pendiente |
| UX-SPN-005 Transparencia y control | `report_dialog.dart`; preferencias locales | Parcial |
| UX-SPN-006 Moderación de patrocinios | moderación existente; `rpc_moderation_test.sql` | Parcial |
| UX-SPN-007 Métricas de patrocinio | analítica nueva; ver `11-metricas-y-trazabilidad.md` | Pendiente |
| UX-SPN-008 Accesibilidad de patrocinios | `UX-X-016`; `UX-DSN-008` | Pendiente |
| UX-SPN-009 Vínculo con Marketplace | `marketplace_service.dart`; `sponsor_carousel.dart` | Parcial |
| UX-SPN-010 Segmentación contextual | servicio de targeting (nuevo) | Pendiente |
| UX-SPN-011 Solicitud de cuenta | `sponsor_requests` (BD Parcial); `sponsor_request_dialog.dart` (Parcial sin validación de duplicados) | Parcial |
| UX-SPN-012 Aprobación/rechazo | `sponsor_requests.status`; `admin_panels_rls_policies` (BD Cubierto); pantalla Flutter (nuevo Pendiente) | Pendiente |
| UX-SPN-013 Vigencia y renovación | tabla `sponsored_promotions` (nuevo Pendiente) | Pendiente |
| UX-SPN-014 Suspensión y baja | campo `suspended` en `profiles` (nuevo Pendiente) | Pendiente |
| UX-SPN-015 Notificaciones de ciclo de vida | tabla de notificaciones (nuevo Pendiente) | Pendiente |
| UX-SPN-016 Panel admin de solicitudes | `idx_sponsor_requests_status`; `admin_panels_rls_policies` (BD Cubierto); pantalla Flutter (nuevo Pendiente) | Pendiente |

