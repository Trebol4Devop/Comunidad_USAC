# 12 — Patrocinios y contenido promovido

> Modelo transversal del **contenido patrocinado** (identidad, panel, etiquetado,
> frecuencia, moderación, métricas y accesibilidad). Es consumido por el Foro
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

## 2. Identidad y cuenta de patrocinador (UX-SPN)

### UX-SPN-001 — Perfil público de patrocinador
- **Actor / rol:** Patrocinador; visible para todos
- **Prioridad:** Must
- **Estado objetivo:** todo patrocinador tiene un **perfil público** con: logotipo,
  nombre comercial, descripción corta, categoría, sede/facultades donde opera,
  canales de contacto y su catálogo de anuncios patrocinados. Es el destino de los
  enlaces que aparecen en Foro y Grupos.
- **Precondiciones:** cuenta con rol/atributo de patrocinador aprobado.
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

## 3. Integración en el Foro
Se especifica en [`03-foro.md`](03-foro.md) como `UX-FORO-021`…

## 4. Integración en Grupos
Se especifica en [`05-grupos.md`](05-grupos.md) como `UX-GRP-010`…

---

## 5. Trazabilidad
Ver [`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md).
