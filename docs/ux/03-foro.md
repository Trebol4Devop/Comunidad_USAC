# 03 — Foro estudiantil y comunidades académicas

> Requisitos de experiencia de usuario para el foro de discusión académica estructurada por facultades y carreras de la plataforma **Comunidad Universitaria USAC**.  
> Convenciones, roles y plantilla en [`README.md`](README.md). Trazabilidad global en [`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md).

---

## 1. Visión del área y arquitectura Discord

El **Foro Estudiantil** es el núcleo de deliberación, consulta y colaboración académica de la comunidad sancarlista. Adopta una arquitectura inspirada en Discord, adaptada a la estructura orgánica de la Universidad de San Carlos de Guatemala:

```
[Rail de Servidores (72px)] ──> [Sidebar de Canales (240px)] ──> [Feed Central Scrolleable] ──> [Panel Popular (>=1050px)]
   - USAC Campus Central          - Encabezado de Facultad/Carrera  - Cabecera con buscador         - Top 5 comunidades activas
   - Facultades oficiales         - # todos-los-temas                - Banner nuevo tema            - Contador de actividad
   - Submenú de Carreras          - # dudas-y-pensum                - Tarjetas de publicaciones     - Acceso instantáneo
   - Directorio de Grupos         - # catedraticos-opiniones        - Encuestas interactivas
   - Explorador de Carreras (+)   - # apuntes-y-recursos            - Post citado incrustado
                                  - # horarios-y-secciones          - Reacciones (Like/Marcador)
                                  - # mis-guardados (Personal)
                                  - Barra de usuario (User Bar)
```

### 1.1 Principios rectores del foro
1. **Anonimato protector y constructivo:** La identidad pública por defecto es un seudónimo modificable (ej. `"Estudiante USAC #482"`), garantizando que los estudiantes puedan consultar sobre catedráticos, prerrequisitos y pensums sin temor a represalias académicas ([ver UX-PRF en `06-perfil-y-cuenta.md`](06-perfil-y-cuenta.md)).
2. **Canales temáticos canónicos:** Se evitan los hilos caóticos generales mediante 5 canales canónicos fijos por carrera que resuelven los dolores cotidianos del estudiante USAC.
3. **Descubrimiento sin fricción:** Navegación jerárquica clara entre campus central, facultades y carreras específicas, mitigando la dispersión informativa.
4. **Resiliencia ante conectividad intermitente:** Operación fluida mediante caché local para lectura offline y reversión optimista ante fallos de red ([ver UX-X en `10-transversales.md`](10-transversales.md)).

---

## 2. Requisitos de experiencia (UX-FORO)

### UX-FORO-001 — Feed central y selector de canales temáticos canónicos
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** El usuario visualiza un feed de publicaciones ordenadas cronológicamente de forma inversa (más recientes primero) filtradas por el servidor (facultad/carrera) y canal temático activo (`# todos-los-temas`, `# dudas-y-pensum`, `# catedraticos-opiniones`, `# apuntes-y-recursos`, `# horarios-y-secciones`). La cabecera muestra el nombre del canal, icono y descripción concisa. En dispositivos móviles, un selector de canales horizontal ("chip strip" o selector contextual) permite alternar canales sin obligar a abrir el drawer lateral.
- **Problema actual [Mejora]:** En móvil (`forum_screen.dart:691-725`), cambiar de canal temático requiere abrir obligatoriamente el Drawer lateral (`_scaffoldKey.currentState?.openDrawer()`), lo que oculta el feed y genera alta fricción de descubrimiento para estudiantes que desconocen las categorías existentes.
- **Precondiciones:** Servidor y canal seleccionados o cargados por defecto (`todos-los-temas`).
- **UI / contenido:** Cabecera superior con `# nombre-canal`, icono representativo, descripción explicativa de una línea, indicador de facultad/carrera (`shortCode`), barra de desplazamiento vertical con scrollbar dedicada, y en móvil, cinta de chips desplazable con los canales temáticos canónicos.
- **Interacciones:** Scroll vertical para leer publicaciones; pull-to-refresh (`RefreshIndicator`) para recargar; toque en chip o canal para cambiar de vista; toque en botón de publicar para abrir redacción.
- **Estados:**
  - *Inicial:* Renderiza los canales por defecto con carga optimista.
  - *Carga:* Tarjetas de esqueleto animadas (`SkeletonCard` shimmer).
  - *Vacío:* `EmptyStateWidget` con icono del canal, título "No hay mensajes en #nombre-canal", descripción orientadora y botón "Crear Primera Publicación".
  - *Error:* Banner de error con botón "Reintentar".
  - *Éxito:* Lista de tarjetas de posts renderizadas.
  - *Sin conexión:* Banner ámbar "Sin conexión — Mostrando contenido guardado." cargado de caché local.
- **Validaciones y reglas de negocio:** Las publicaciones con `moderation_status > 0` se ocultan a usuarios normales y solo se muestran a Moderadores/Admins con advertencia visual.
- **Accesibilidad:** Etiquetas Semantics en cada canal ("Canal dudas y pensum"), contraste WCAG AA, foco accesible mediante teclado (tabulación y flechas).
- **Responsive:** Móvil (<768px) con cinta de canales accesible en cabecera o drawer; Tablet/Desktop (>=768px) integrado en columna central de 3 o 4 columnas tipo Discord.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante navegando en la carrera "Ingeniería en Ciencias y Sistemas", **When** pulsa el canal "# catedraticos-opiniones", **Then** el feed se actualiza mostrando únicamente las publicaciones de evaluación y recomendaciones docentes de esa carrera, actualizando el encabezado y la URL o estado.
  - **Given** un estudiante en un canal recién creado sin publicaciones, **When** el feed termina de cargar, **Then** visualiza un estado vacío con el mensaje "No hay mensajes en #nombre-canal" y un botón de acción principal "Crear Primera Publicación".

---

### UX-FORO-002 — Rail lateral de servidores y navegación por facultades
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Rail vertical de 52-72px a la izquierda con accesos circulares a: Campus Central ("USAC"), Facultades oficiales (Ingeniería, Medicina, etc.), botón de Explorador (`+`) y acceso visual a Grupos. Cada servidor muestra un indicador tipo píldora (Discord pill) que se expande verticalmente al estar activo (24px) o al hacer hover (12px). Al pulsar una facultad con múltiples carreras, se despliega un menú táctil de carreras sin desbordarse de pantalla.
- **Problema actual [Mejora]:** En `forum_server_rail.dart:105-160`, el submenú de carreras se renderiza con un `OverlayPortal` flotante con coordenadas manuales (`_submenuTop`, `_submenuLeft`) que en pantallas táctiles pequeñas puede quedar fuera de la vista o cerrarse abruptamente sin dar tiempo al usuario de seleccionar su carrera.
- **Precondiciones:** La estructura de facultades y carreras de la USAC está inicializada en memoria o base de datos.
- **UI / contenido:** Iconos circulares (36x36px) con siglas de facultad (`shortCode`), icono temático, colores institucionales, píldora blanca indicadora lateral, tooltip flotante con el nombre completo.
- **Interacciones:** Tap en servidor cambia inmediatamente el contexto del feed y carga `# todos-los-temas` de dicha facultad; pulsación larga o segundo tap despliega submenú de carreras; tap fuera cierra el submenú sin perder estado.
- **Estados:** Activo (borde redondeado 10px + color acento + sombra suave), Inactivo (circular 18px + gris neutro), Hover (crecimiento sutil y píldora parcial).
- **Validaciones y reglas de negocio:** Conserva la facultad activa seleccionada en memoria de sesión. Si la facultad no tiene sub-carreras registradas, no intenta desplegar submenú.
- **Accesibilidad:** Indicadores de estado accesibles para lectores de pantalla (`aria-selected`), tooltips con nombres desglosados ("Facultad de Ingeniería"), tamaño de toque mín 48x48px.
- **Responsive:** En Desktop/Tablet (>=768px) columna fija izquierda; en Móvil (<768px) integrado dentro del panel deslizante izquierdo con ancho táctil ergonómico.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante con el servidor "Facultad de Ingeniería" activo, **When** pulsa el icono de "Facultad de Ciencias Médicas" en el rail, **Then** el servidor activo cambia inmediatamente, la píldora indicadora se anima hacia el nuevo icono y el feed carga los temas de Medicina.
  - **Given** un usuario que pulsa una facultad con 8 carreras en una pantalla con poca altura vertical, **When** se abre el submenú de carreras, **Then** este calcula su posición sin salirse del borde superior ni inferior de la pantalla y permite scroll interno táctil fluido.

---

### UX-FORO-003 — Explorador y buscador unificado de carreras universitarias
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Should
- **Estado objetivo:** Diálogo modal explorador (`ForumCarreraPickerDialog`) que permite al estudiante buscar y explorar todas las carreras de todas las facultades y escuelas no facultativas de la USAC mediante un campo de texto con filtro instantáneo en tiempo real (por nombre de carrera, facultad, sede o código).
- **Problema actual [Mejora]:** En `forum_carrera_picker_dialog.dart:37-71`, las carreras se aplanan en una lista larga sin agrupación jerárquica por facultad ni filtros rápidos por sede (Campus Central vs Centros Universitarios CUNOC/CUNOR/etc.), dificultando encontrar carreras con nombres similares.
- **Precondiciones:** Catálogo de facultades y carreras disponible en `USACConstants` / base de datos.
- **UI / contenido:** Diálogo centrado (hasta 580px de ancho) con encabezado "Explorar Carreras y Facultades", campo de búsqueda con icono y botón de limpiar, chips de filtro rápido por área/sede, y listado scrolleable con tarjetas de carrera que incluyen icono de facultad, nombre limpio de carrera, código de pensum y chip de facultad.
- **Interacciones:** Escribir en el buscador filtra la lista en <50ms; tocar una carrera selecciona dicho servidor, lo agrega al rail si no está y cierra el diálogo llevando al feed respectivo; tecla Escape o botón "Cerrar" cancela.
- **Estados:** Carga inicial, Lista filtrada, Vacío con mensaje "No se encontraron carreras que coincidan con tu búsqueda", Éxito de selección.
- **Validaciones y reglas de negocio:** Al seleccionar una carrera, el feed cambia automáticamente al canal `# todos-los-temas` de dicha carrera y resetea cualquier búsqueda textual previa.
- **Accesibilidad:** Foco automático en el campo de texto al abrir; navegación por flechas en la lista; anuncio de resultados disponibles para lectores de pantalla.
- **Responsive:** Móvil como Bottom Sheet de pantalla completa (90% altura); Desktop como Dialog centrado con `maxWidth: 580`.
- **Criterios de aceptación (Gherkin):**
  - **Given** el diálogo de exploración abierto, **When** el usuario escribe "Civil" en el buscador, **Then** la lista filtra en menos de 50ms mostrando únicamente carreras relacionadas con ingeniería civil de campus central y sedes.
  - **Given** un usuario buscando una carrera inexistente como "Aeronáutica Espacial", **When** no hay coincidencias, **Then** se muestra un estado vacío con el texto "No se encontraron carreras que coincidan con tu búsqueda" y un botón "Limpiar filtro".

---

### UX-FORO-004 — Barra lateral de canales temáticos (Channel Sidebar)
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Sidebar de 240px que organiza los canales de texto de la facultad/carrera activa bajo secciones visuales: "CANALES DE DISCUSIÓN" (canales públicos canónicos) y "PERSONAL" (canal `# mis-guardados`). La cabecera muestra el nombre del servidor activo, badge de verificado institucional y flecha desplegable para cambiar de carrera.
- **Problema actual [Mejora]:** En `forum_channel_sidebar.dart:153-160`, el canal `# mis-guardados` es visible para visitantes no autenticados, pero al pulsarlo se muestra un feed vacío sin explicar por qué o requiriendo clics confusos (`forum_screen.dart:196-205`). Debe mostrar una invitación clara a iniciar sesión antes de navegar o un banner formativo.
- **Precondiciones:** Servidor activo definido.
- **UI / contenido:** Encabezado con nombre de servidor, indicador de verificado; títulos de categoría en mayúsculas pequeñas (11px, gris tenue); elementos de canal con prefijo `#`, icono temático a la izquierda, etiqueta en minúsculas conectadas con guiones (`# dudas-y-pensum`), estado resaltado al estar activo.
- **Interacciones:** Tap en canal conmuta el feed al canal seleccionado en menos de 200ms; en móvil cierra el drawer automáticamente; tap en encabezado abre `ForumCarreraPickerDialog`.
- **Estados:** Canal normal inactivo (texto gris, fondo transparente), Hover (fondo sutilmente iluminado), Activo (fondo con contraste, texto primario en negrita).
- **Validaciones y reglas de negocio:** El canal `# mis-guardados` sólo consulta la tabla `post_bookmarks` vinculada al `user_id` de la sesión activa. Para visitantes, muestra estado vacío explicativo.
- **Accesibilidad:** Roles de navegación accesibles, contraste de color acorde a WCAG AA en tema claro y oscuro, soporte de navegación por teclado.
- **Responsive:** Fijo en Desktop y Tablet (240px); embebido en el Drawer móvil ocupando el ancho restante junto al rail.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante en el servidor "Agronomía", **When** pulsa sobre el canal "# apuntes-y-recursos", **Then** el canal se resalta visualmente en la barra lateral y el feed central carga el repositorio de material académico de Agronomía.
  - **Given** un visitante no autenticado que pulsa el canal "# mis-guardados", **When** carga la vista, **Then** ve una ilustración y un mensaje que explica que debe iniciar sesión para guardar y consultar sus marcadores personales, con un botón directo a "Iniciar Sesión".

---

### UX-FORO-005 — Barra de estado de usuario e identidad estudiantil (User Bar)
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Barra fija inferior (54px) en el sidebar de canales con el avatar del usuario, su seudónimo público activo (ej. `"Estudiante USAC #482"`), un punto verde de presencia ("En línea") y botón de acceso rápido al perfil/ajustes (`Icons.settings`). Para usuarios no autenticados, muestra `"Modo Visitante"` con botón destacado `"Acceder"`.
- **Problema actual [Mejora]:** [Vacío 8.2] En `forum_channel_sidebar.dart:166-248` y `local_storage_service.dart:23-40`, el alias sólo se lee de `SharedPreferences` local. Si un estudiante inicia sesión en otro dispositivo o borra datos, su alias se desincroniza del perfil en Supabase y vuelve a un valor aleatorio nuevo. Debe sincronizarse bidireccionalmente con `profiles.forum_alias` en la nube para usuarios autenticados.
- **Precondiciones:** Sesión iniciada o perfil local cargado.
- **UI / contenido:** Avatar circular con inicial, texto de alias truncado con elipsis, subtítulo "En línea" o "Visitante", botón de ajustes con tooltip "Mi Perfil y Preferencias", botón de login si es visitante.
- **Interacciones:** Tap en la barra o en el icono de ajustes navega a `ProfileScreen`; si es visitante, tap en "Acceder" abre `AuthModal`.
- **Estados:** Visitante (avatar genérico, botón acceder), Autenticado (avatar con color del perfil, alias persistido, indicador verde).
- **Validaciones y reglas de negocio:** Cambios en el alias desde el perfil se reflejan reactivamente en la barra de usuario y en los futuros posts.
- **Accesibilidad:** `Semantics` indicando "Sesión activa como [alias]", botones con área táctil mínima de 48x48px.
- **Responsive:** Ocupa el ancho completo inferior del sidebar (240px en desktop, ancho de drawer en móvil).
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante autenticado con alias "Ingeniero Chapín", **When** abre la aplicación en una nueva computadora o sesión web, **Then** la barra de usuario muestra "Ingeniero Chapín" sincronizado desde su perfil de la base de datos sin sobrescribirse con un número aleatorio local.
  - **Given** un visitante no autenticado en el foro, **When** observa la barra inferior del sidebar, **Then** lee "Modo Visitante" y al tocar el botón "Acceder" se despliega de inmediato el modal de autenticación (`AuthModal`).

---

### UX-FORO-006 — Panel lateral de comunidades estudiantiles más populares
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Should
- **Estado objetivo:** Panel lateral derecho en resoluciones `>= 1050px` (o modal bottom sheet en móvil) con el ranking de las 5 comunidades/carreras más activas de la universidad basándose en actividad real reciente (conteo de publicaciones e interacciones).
- **Problema actual [Mejora]:** En `popular_servers_sidebar.dart:90-140`, si el backend falla o tarda en responder, no hay reintento automático ni skeletons diferenciados, y en móvil el icono de fuego de la barra superior (`forum_screen.dart:678-685`) no tiene etiqueta textual, por lo que pocos estudiantes descubren qué hace.
- **Precondiciones:** Datos de popularidad agregados disponibles en `ForumService.fetchPopularServers`.
- **UI / contenido:** Encabezado con icono de tendencia (`Icons.trending_up`), texto "MÁS POPULARES", botón discreto de refrescar; lista de 5 ítems con icono de facultad, nombre corto, badge de publicaciones activas y flecha de acceso.
- **Interacciones:** Tap en una comunidad conmuta instantáneamente el servidor activo y carga su feed principal; tap en refrescar recarga métricas con spinner discreto.
- **Estados:** Carga (indicador sutil), Lista con datos, Vacío ("No hay estadísticas disponibles"), Error (mensaje y reintento).
- **Validaciones y reglas de negocio:** No muestra datos estáticos inventados; si hay menos de 5 servidores activos, muestra únicamente los existentes.
- **Accesibilidad:** Anuncio accesible de lista ordenada ("Top 1: Ingeniería Civil, 45 publicaciones"); contraste suficiente en modo claro y oscuro.
- **Responsive:** Desktop (>=1050px) fija a la derecha (ancho 220px); Tablet (768-1049px) oculta para priorizar lectura del feed; Móvil (<768px) accesible vía botón en cabecera abriendo Bottom Sheet.
- **Criterios de aceptación (Gherkin):**
  - **Given** un usuario en desktop con resolución de 1200px, **When** visualiza el panel lateral derecho, **Then** ve el ranking de las 5 carreras con mayor interacción universitaria con su respectivo conteo de temas recientes.
  - **Given** un usuario que hace clic en "Medicina (Campus Central)" dentro del panel de populares, **When** se procesa la acción, **Then** el foro navega directamente al servidor de Medicina y actualiza el feed con sus publicaciones.

---

### UX-FORO-007 — Búsqueda en tiempo real y filtrado de temas
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Campo de búsqueda integrado en la cabecera del feed que filtra publicaciones por coincidencia en título o contenido en tiempo real, respetando el canal y servidor activo. Incluye botón de limpiar búsqueda (`Icons.clear`) y debounce de 300 ms para optimizar peticiones de red y fluidez de teclado.
- **Problema actual [Mejora]:** En `forum_screen.dart:999-1003`, la búsqueda en desktop sólo se dispara al presionar Enter (`onSubmitted: (val) { ... }`) mientras que en móvil no hay campo de búsqueda persistente en la cabecera del canal, obligando al usuario a desplazarse o perder la capacidad de buscar si no sabe que debe pulsar Enter.
- **Precondiciones:** Feed visible con contenido indexable.
- **UI / contenido:** Input rectangular con bordes redondeados (6px), icono de lupa (`Icons.search`), texto placeholder `"Buscar en #nombre-canal..."`, icono de cruz para limpiar cuando hay texto, indicador de carga si la búsqueda es remota.
- **Interacciones:** Escribir actualiza los resultados automáticamente con debounce (o al pulsar Enter); pulsar la cruz borra el texto y restaura la lista de temas completa inmediatamente.
- **Estados:** Reposo (campo vacío), Escribiendo con texto, Buscando (spinner sutil en suffix), Resultados encontrados, Sin coincidencias (Empty state específico "No se encontraron publicaciones para '[término]'" con botón "Limpiar búsqueda").
- **Validaciones y reglas de negocio:** Búsqueda insensible a mayúsculas, minúsculas y tildes comunes. Trunca espacios en blanco superfluos.
- **Accesibilidad:** `TextField` con etiqueta semántica clara, soporte para lectores de pantalla anunciando "N resultados encontrados", navegación por teclado.
- **Responsive:** En desktop (>=800px) campo fijo de 180-220px en la barra superior; en pantallas pequeñas (<800px) botón de lupa expandible o campo integrado debajo del título.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante en "# dudas-y-pensum", **When** escribe "física 1" en el campo de búsqueda, **Then** tras 300 ms de pausa en la escritura el feed muestra solo publicaciones que contengan "física 1" en el título o descripción.
  - **Given** una búsqueda con el término "xyz123abc" sin resultados, **When** finaliza la consulta, **Then** se muestra un mensaje informativo "No se encontraron publicaciones para 'xyz123abc'" junto a un botón "Restablecer búsqueda" que al presionarse limpia el input y recarga los temas normales.

---

### UX-FORO-008 — Tarjeta de publicación en el feed (Post Card)
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Tarjeta autocontenida que presenta la síntesis visual de una consulta académica: indicador de fijado si aplica, avatar de autor, seudónimo, chip de carrera/facultad, tiempo relativo (`timeAgo`), badge de categoría del canal, título en negrita (hasta 2 líneas), cuerpo de texto truncado (hasta 3 líneas), previsualización de multimedia (imagen o GIF), previsualización de encuesta interactiva (con barras de porcentaje), previsualización de post citado incrustado, y barra inferior con botones de acción (Me gusta con contador, Comentarios con contador, Citar con contador, Guardar marcador, y Reportar para moderación).
- **Problema actual [Mejora]:** En `post_card.dart:865-884`, no hay confirmación visual previa antes de reportar un usuario o post (se llama directo a `ForumService.reportUser` sin modal confirmatorio en algunas rutas del feed), y en tarjetas con imágenes muy pesadas no hay indicador de carga progresiva ni fallback si el enlace de imagen falla (`storage_service.dart:16-107`).
- **Precondiciones:** La publicación existe en la base de datos y no ha sido eliminada.
- **UI / contenido:** Contenedor con borde tenue, radio 10px, elevación ligera, espaciado interno de 16px. En modo oscuro fondo `#2B2D31`, borde `#383A40`; en modo claro fondo `#FFFFFF`, borde `#E2E8F0`. Si el usuario es moderador y el post tiene `moderationStatus > 0`, se exhibe un borde amarillo/rojo con etiqueta "Pendiente de revisión" u "Ocultado por reportes".
- **Interacciones:** Tap en la tarjeta abre el detalle completo (`PostDetailScreen`); tap en Me gusta alterna like con feedback optimista; tap en marcador alterna guardado; tap en citar abre modal de nuevo post con la cita adjunta; tap en las opciones de encuesta registra el voto directamente desde el feed.
- **Estados:** Normal, Fijada (`Icons.push_pin` destacado), Hover en desktop (sutil oscurecimiento/aclarado), En revisión (para moderadores).
- **Validaciones y reglas de negocio:** Si el post está oculto (`moderationStatus == 2`), los visitantes y estudiantes comunes no lo ven en el feed; sólo moderadores y administradores lo ven con la advertencia de moderación.
- **Accesibilidad:** Estructura jerárquica clara de encabezados (título de post en `titleMedium`), botones de acción con etiquetas semánticas ("X me gusta", "X comentarios", "Guardar en marcadores"), tamaño táctil de botones mín 40x40px.
- **Responsive:** Ocupa el ancho completo del contenedor del feed con margen inferior de 10px; se adapta dinámicamente a pantallas móviles reduciendo espaciados sin cortar textos.
- **Criterios de aceptación (Gherkin):**
  - **Given** una publicación con una imagen adjunta, **When** la tarjeta se dibuja en el feed, **Then** muestra una previsualización contenida con esquinas redondeadas y relación de aspecto preservada, y al tocar la imagen se abre el visor con zoom a pantalla completa.
  - **Given** una publicación fijada por administradores, **When** cualquier estudiante entra al canal, **Then** la publicación aparece en la primera posición con el distintivo "Publicación Fijada" y el icono de chincheta.

---

### UX-FORO-009 — Pantalla de detalle de publicación y visualización extendida
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Pantalla dedicada (`PostDetailScreen`) que presenta el contenido íntegro y sin recortes de la consulta académica: título completo, texto extendido preservando párrafos y formato, visor de medios interactivo con capacidad de zoom a pantalla completa (`ImageViewerDialog`), tarjeta de post citado navegable, encuesta con desglose de votos, y la sección de debate con árbol de comentarios jerárquicos.
- **Problema actual [Mejora]:** En `post_detail_screen.dart:280-315`, la AppBar superior contiene botones de Guardar, Citar y Reportar, pero carece de un botón explícito de "Compartir enlace directo / Copiar enlace" para que los estudiantes compartan la consulta por grupos de estudio o WhatsApp.
- **Precondiciones:** Publicación seleccionada desde el feed o abierta mediante enlace directo.
- **UI / contenido:** AppBar con título "Discusión en el Foro", botón de retroceso y acciones (Guardar, Citar, Compartir, Reportar). Tarjeta principal destacada con contenedor de hasta 900px centrado (`MaxWidthContainer`). Debajo, encabezado "Respuestas (N)" y listado jerárquico de comentarios. En la parte inferior, barra fija de redacción.
- **Interacciones:** Scroll fluido; toque en imagen abre `ImageViewerDialog` con zoom 0.8x a 4.0x; toque en post citado abre el detalle del post original; votar en encuesta actualiza porcentajes inmediatamente; redacción de respuesta agrega comentario al árbol.
- **Estados:** Carga inicial de comentarios (spinner centrado), Publicación con comentarios, Publicación sin comentarios (mensaje "Sé el primero en responder a esta consulta"), Error al cargar respuestas (botón reintentar).
- **Validaciones y reglas de negocio:** Conserva el estado de likes y marcadores sincronizado con el feed al regresar; actualiza el contador de comentarios al enviar una respuesta.
- **Accesibilidad:** Navegación de vuelta accesible (`PopScope`), textos de alto contraste, foco dirigido al campo de respuesta al pulsar "Responder".
- **Responsive:** Contenedor centrado con `maxWidth: 900px` en pantallas grandes para óptima legibilidad; en móviles ocupa el 100% del ancho con padding ergonómico.
- **Criterios de aceptación (Gherkin):**
  - **Given** una publicación con un texto largo de 1,200 caracteres, **When** el estudiante abre el detalle, **Then** lee el texto completo sin cortes, con espaciado entre párrafos legible y sin scroll horizontal.
  - **Given** un estudiante que pulsa el botón "Compartir", **When** se dispara la acción, **Then** el enlace directo a la publicación se copia al portapapeles y se muestra una confirmación visual "Enlace copiado al portapapeles".

---

### UX-FORO-010 — Árbol de comentarios jerárquicos y respuestas anidadas
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** Visualización en árbol estructurado de respuestas (`CommentItemWidget`) con indentación visual progresiva (14px por nivel, limitada visualmente a un máximo de 4 niveles en móvil para no comprimir el texto). Cada comentario muestra el alias del autor, distintivo `"AUTOR"` si coincide con el creador del post, tiempo relativo (`timeAgo`), contenido del comentario, GIF adjunto si existe, botón `"Responder"` y botón de reporte.
- **Problema actual [Mejora]:** En `forum_service.dart:605-616` y `comment_item.dart:184-196`, la recursión se corta en profundidad 6 en UI, pero si hay comentarios anidados más profundos quedan invisibles sin ningún indicador de "Ver respuestas adicionales", ocultando aportes de la discusión. Debe existir un control visual explícito que permita desplegar hilos profundos o aplanarlos a partir del nivel 4.
- **Precondiciones:** Detalle del post cargado con comentarios en base de datos.
- **UI / contenido:** Tarjetas de comentario anidadas con fondos sutilmente diferenciados por nivel de profundidad, línea guía vertical que conecta respuestas padre e hijo, distintivo `"AUTOR"` en color primario USAC con esquinas redondeadas, botón `"Responder"` con icono de flecha.
- **Interacciones:** Tap en `"Responder"` en cualquier comentario fija dicho comentario como objetivo de respuesta (`_replyTarget`), muestra el banner "¿Respondiendo a @alias?" en la barra inferior y transfiere el foco al campo de texto. Tap en reporte abre `ReportDialog`.
- **Estados:** Lista vacía de comentarios, Comentarios raíz sin respuestas, Comentarios con árbol multianidado, Prevención de bucles infinitos (detecta referencias circulares en el árbol y las aísla en la raíz de forma segura sin colapsar la interfaz).
- **Validaciones y reglas de negocio:** La prevención algorítmica de ciclos (`hasCycle`) descarta referencias circulares de `parent_id` hasta 15 saltos (`forum_service.dart:605-616`). No se permite que un comentario sea padre de sí mismo.
- **Accesibilidad:** Jerarquía semántica clara de respuestas, botones de responder y reportar con etiquetas accesibles y tamaño de toque adecuado.
- **Responsive:** Indentación visual acotada en móvil (14px * nivel, máx 4 niveles) para preservar legibilidad en pantallas de 360px de ancho.
- **Criterios de aceptación (Gherkin):**
  - **Given** un comentario publicado por el mismo autor del post original, **When** se dibuja en la lista de respuestas, **Then** muestra una etiqueta visible "AUTOR" junto a su seudónimo con fondo tintado institucional.
  - **Given** una cadena de comentarios con 5 niveles de anidamiento en un teléfono móvil, **When** se renderiza la vista, **Then** la indentación se limita a 4 niveles visuales para evitar que el texto quede comprimido ilegiblemente contra el margen derecho.

---

### UX-FORO-011 — Barra de redacción contextual de respuestas en el hilo
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Barra fija en la parte inferior de la pantalla de detalle que permite responder a la consulta principal o a un comentario específico. Si hay un comentario objetivo seleccionado, se exhibe una barra superior que dice: `"Respondiendo a [alias]"` con un botón de cancelar (`Icons.close`). Incluye botón para adjuntar GIF (`GifPickerModal`), campo de texto multilínea y botón de envío con indicador de progreso.
- **Problema actual [Mejora]:** En `post_detail_screen.dart:220-222`, si el usuario intenta enviar un comentario vacío pero con GIF, la condición `text.isEmpty && _commentGifUrl == null` lo previene, pero el botón de envío no ofrece estado deshabilitado visualmente claro, induciendo a toques repetitivos.
- **Precondiciones:** Detalle del post abierto.
- **UI / contenido:** Contenedor con borde superior y fondo acoplado al tema. Banner superior de respuesta con texto azul/ámbar "Respondiendo a [alias]" y botón "X"; fila con botón de GIF (`Icons.gif_box_outlined`), `TextField` con placeholder `"Escribe una respuesta académica..."` y botón circular de enviar (`Icons.send`).
- **Interacciones:** Escribir texto habilita el botón de envío; pulsar botón de GIF abre `GifPickerModal` y muestra la miniatura del GIF seleccionado sobre el campo; pulsar "X" en el banner cancela la respuesta anidada y vuelve a respuesta general; pulsar enviar despacha la respuesta y limpia el campo.
- **Estados:** Reposo (campo vacío, botón de enviar inactivo o deshabilitado), Escribiendo con texto, Con GIF seleccionado (miniatura con botón eliminar), Enviando (spinner en botón de envío y campos deshabilitados para evitar doble envío), Éxito (campo vacío, foco liberado y nuevo comentario visible en el árbol).
- **Validaciones y reglas de negocio:** Toda inserción exige sesión autenticada con nivel AAL2 (MFA TOTP). Para visitantes, abre `AuthModal` y reanuda el envío tras autenticarse con éxito.
- **Accesibilidad:** Anuncio accesible al activar modo de respuesta ("Modo respuesta a [alias] activado"), contraste de color en botones, soporte de teclado en pantalla sin tapar el input (`viewInsets.bottom`).
- **Responsive:** Barra adaptada al área segura (`SafeArea`) inferior en móviles; ancho acoplado al contenedor central en pantallas de escritorio.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que presiona "Responder" en el comentario de "Estudiante #12", **When** se activa el foco en el campo de texto, **Then** aparece un banner superior indicando "Respondiendo a Estudiante #12" y al enviar, la respuesta se anida directamente debajo de ese comentario.
  - **Given** un estudiante que presiona la "X" del banner de respuesta anidada, **When** se cancela la selección, **Then** el banner desaparece y la barra vuelve al modo de respuesta general al post.

---

### UX-FORO-012 — Encuestas estudiantiles interactivas en publicaciones
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Módulo interactivo dentro de la tarjeta del post y del detalle que muestra una pregunta académica y entre 2 y 5 opciones de votación. Permite al estudiante votar por una opción con un solo toque. Tras votar, la opción seleccionada se destaca con icono de verificación (`Icons.check_circle`), las demás opciones muestran barras horizontales de progreso proporcional al porcentaje de votos recibidos, y se muestra el conteo total de votos y porcentajes por opción.
- **Problema actual [Mejora]:** En `forum_screen.dart:360-405` y `post_card.dart:309-405`, el cálculo porcentual puede fallar o mostrar `NaN%` si `totalVotes == 0` durante transiciones rápidas de red. Debe blindarse con formateo robusto y ofrecer retroalimentación de vibración háptica suave al registrar el voto en dispositivos móviles.
- **Precondiciones:** La publicación contiene un objeto `Poll` con al menos 2 opciones.
- **UI / contenido:** Contenedor redondeado con icono de encuesta (`Icons.poll_outlined`), texto de la pregunta en negrita; botones de opción rectangulares con barra de llenado translúcida (color azul institucional), texto de la opción, porcentaje formateado (ej. `"45%"`), conteo de votos individuales y leyenda inferior `"X votos registrados"`.
- **Interacciones:** Toque en una opción registra el voto mediante actualización optimista (incrementa el voto y descuenta el voto anterior si el usuario cambió de opción); toque en otra opción actualiza la preferencia; si el usuario no tiene sesión, se intercepta con `AuthModal`.
- **Estados:** No votado (opciones limpias sin barras de porcentaje para no sesgar al votante), Votado (barras de porcentaje visibles con opción del usuario resaltada), Actualizando voto (transición visual suave), Error de red (reversión al estado previo con mensaje de error).
- **Validaciones y reglas de negocio:** Regla estricta de unicidad de voto: 1 voto por usuario por encuesta en base de datos (`poll_votes` con clave única `(poll_id, user_id)`). Si el usuario vota por otra opción, se ejecuta `UPSERT` reemplazando su voto anterior sin duplicar conteos.
- **Accesibilidad:** Los lectores de pantalla anuncian la pregunta, opciones, estado de selección ("Opción 1: Sí, seleccionada, 65% de 120 votos") y confirmación de voto emitido.
- **Responsive:** Barras de porcentaje y textos adaptables a anchos estrechos en móviles sin desbordar etiquetas numéricas.
- **Criterios de aceptación (Gherkin):**
  - **Given** una encuesta con 10 votos en total, **When** un estudiante vota por la opción "A" que tenía 4 votos, **Then** el contador de "A" sube a 5, el total a 11, se muestra "45%" con barra animada y el icono de verificación queda fijado en la opción "A".
  - **Given** un estudiante que ya votó por "A" y decide cambiar su voto a "B", **When** pulsa la opción "B", **Then** el sistema resta 1 voto a "A", suma 1 voto a "B", recomputa los porcentajes y traslada la marca de verificación hacia "B" sin duplicar el total.

---

### UX-FORO-013 — Reacción de me gusta y valoración de utilidad
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Mecanismo de valoración de consultas y respuestas útiles mediante botón de pulgar arriba ("Me gusta") con recuento dinámico. El estudiante puede dar o retirar su voto de utilidad con retroalimentación instantánea (actualización optimista en interfaz).
- **Problema actual [Mejora]:** En `forum_screen.dart:283-316` y `post_detail_screen.dart:75-102`, si la petición falla por desconexión momentánea, la reversión del contador ocurre silenciosamente sin un mensaje que alerte al estudiante de que su voto no pudo guardarse en el servidor. Debe mostrarse un SnackBar informativo de falla de sincronización.
- **Precondiciones:** Publicación cargada en pantalla.
- **UI / contenido:** Botón tipo píldora con icono de pulgar (`Icons.thumb_up_alt_outlined` inactivo, `Icons.thumb_up` activo con fondo azul translúcido) y número entero de likes.
- **Interacciones:** Tap activa o desactiva el like. Si el usuario no ha iniciado sesión, se abre `AuthModal`; al autenticarse exitosamente, el like se aplica de forma automática sin obligar al usuario a pulsar el botón nuevamente.
- **Estados:** No gustado (icono delineado, color neutro), Gustado (icono lleno, color primario USAC, fondo iluminado), Animación de pulsación al tocar, Reversión con aviso si hay error de red.
- **Validaciones y reglas de negocio:** Unicidad de like por usuario por post (`post_likes` con clave única `(post_id, user_id)`). Clamping numérico para que el contador nunca sea inferior a 0.
- **Accesibilidad:** `Semantics` dinámico que anuncia: "Me gusta, botón, actualmente seleccionado, 14 me gusta" o "Me gusta, no seleccionado".
- **Responsive:** Tamaño táctil mínimo de 48x48px en móvil; integrado armónicamente en el footer de acciones en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** una publicación con 3 likes, **When** un estudiante autenticado pulsa "Me gusta", **Then** el icono se ilumina en azul, el contador sube inmediatamente a 4 y la acción se confirma en el servidor.
  - **Given** una desconexión total de internet, **When** el usuario pulsa "Me gusta" y la petición falla tras el tiempo de espera, **Then** el contador vuelve a su valor original y se notifica con un SnackBar: "No se pudo registrar tu voto. Comprueba tu conexión."

---

### UX-FORO-014 — Marcadores y canal personal de guardados (# mis-guardados)
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Capacidad de guardar cualquier publicación en marcadores personales para consulta rápida posterior. Las publicaciones guardadas se recopilan en el canal especial `# mis-guardados` del sidebar. Al alternar el guardado, se muestra feedback visual en el icono (color ámbar) y una notificación SnackBar temporal: `"Publicación guardada en marcadores."` o `"Publicación eliminada de marcadores."`.
- **Problema actual [Mejora]:** En `forum_screen.dart:353-356`, si el usuario desmarca un post mientras navega dentro del canal `# mis-guardados`, la lista se recarga de inmediato (`_loadPosts()`) haciendo que la tarjeta desaparezca bruscamente bajo el dedo del usuario sin confirmación ni opción de "Deshacer". Debe ofrecerse animación de descarte o un botón de deshacer en el SnackBar.
- **Precondiciones:** Sesión activa del usuario.
- **UI / contenido:** Icono de marcador (`Icons.bookmark_border` inactivo, `Icons.bookmark` lleno en color ámbar `#D97706`). En el sidebar de canales, canal permanente con icono `# mis-guardados`.
- **Interacciones:** Tap en el icono guarda o retira el marcador; si se retira dentro de `# mis-guardados`, se muestra SnackBar con acción "Deshacer" durante 4 segundos antes de remover el post de la vista.
- **Estados:** No guardado, Guardado (ámbar), Canal `# mis-guardados` vacío (muestra `EmptyStateWidget` con mensaje "No tienes publicaciones guardadas"), Error de sincronización (reversión).
- **Validaciones y reglas de negocio:** Los marcadores son estrictamente privados del estudiante (`post_bookmarks` filtrado por `auth.uid() = user_id`). Ningún otro usuario ni moderador puede ver qué posts tiene guardados otra persona.
- **Accesibilidad:** Etiqueta semántica clara ("Guardar en marcadores" / "Eliminar de marcadores"), anuncio audible del cambio de estado.
- **Responsive:** Botón accesible tanto en la tarjeta del feed como en la AppBar del detalle.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que encuentra un post con material de estudio útil, **When** pulsa el icono de marcador, **Then** el icono se colorea en ámbar y aparece el mensaje "Publicación guardada en marcadores".
  - **Given** un estudiante en su canal "# mis-guardados" que desmarca una publicación por error, **When** aparece el SnackBar y pulsa "Deshacer", **Then** el marcador se restablece y la publicación permanece en su lista de guardados.

---

### UX-FORO-015 — Citación de publicaciones académicas (Repost con contexto)
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Should
- **Estado objetivo:** Flujo que permite a un estudiante republicar o citar una consulta previa en un nuevo tema del foro para profundizar, contrastar o compartir aportes. Al pulsar el botón de citar (`Icons.repeat`), se abre el diálogo de creación de post (`CreatePostDialog`) con la referencia del post original precargada, su título prefijado con `"Re: [Título Original]"` y una vista previa incrustada de la consulta citada.
- **Problema actual [Mejora]:** En `forum_screen.dart:407-436`, al citar un post, la categoría por defecto se fuerza a la categoría activa o a `'prerrequisitos'` si se está en un canal especial, sin permitir al usuario reasignar libremente el canal de destino donde tiene más sentido ubicar la nueva consulta. Debe permitirse elegir el canal de publicación del nuevo hilo.
- **Precondiciones:** Post original válido y accesible.
- **UI / contenido:** Botón de repetición (`Icons.repeat`) con contador de citas en la tarjeta. En el modal de creación y en la tarjeta publicada resultante, caja contenedora incrustada con borde gris tenue, icono de comillas (`Icons.format_quote`), alias del autor original, tiempo relativo y título/extracto del post citado.
- **Interacciones:** Tap en citar valida sesión y abre el modal; al publicar, se incrementa el contador `repostsCount` del post original y la nueva publicación aparece al inicio del feed con el bloque citado incrustado. Tap en el bloque citado navega al post original.
- **Estados:** Modal con cita precargada (incluye botón "X" para desvincular la cita si el usuario cambia de opinión), Publicación con cita renderizada, Post citado eliminado o moderado (muestra aviso "La publicación citada ya no está disponible").
- **Validaciones y reglas de negocio:** La referencia se almacena en `posts.quoted_post_id`. No se permiten citas circulares directas (citar un post que ya cita al mismo). Requiere sesión autenticada con nivel AAL2.
- **Accesibilidad:** El lector de pantalla identifica el bloque citado como "Publicación citada de [alias]: [título]".
- **Responsive:** La caja de cita se ajusta al ancho del post tanto en pantallas móviles como de escritorio sin romper márgenes.
- **Criterios de aceptación (Gherkin):**
  - **Given** un post sobre fechas de exámenes de recuperación, **When** otro alumno pulsa "Citar", **Then** se abre el diálogo de nuevo post con la tarjeta del post original incrustada y el título iniciado con "Re: Fechas de exámenes...".
  - **Given** una publicación que cita un post que posteriormente fue eliminado, **When** un usuario visualiza el hilo, **Then** el bloque de cita exhibe el mensaje "La publicación original ya no se encuentra disponible" sin provocar errores ni cierres inesperados.

---

### UX-FORO-016 — Denuncia comunitaria y reporte ético de contenido
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Flujo de reporte seguro y ético accesible en posts, comentarios y usuarios. Al pulsar el icono de bandera (`Icons.flag_outlined`), se despliega `ReportDialog` con opciones claras de denuncia (*Acoso o discriminación*, *Spam o publicidad no autorizada*, *Venta o fraude ilegal*, *Información personal expuesta*, *Contenido ofensivo*, *Otro*), con campo opcional para detalles. Al confirmar, el reporte se envía a la tabla de moderación y se notifica al usuario con un SnackBar de agradecimiento.
- **Problema actual [Mejora]:** En `post_card.dart:872-884`, el reporte de post desde la tarjeta invoca directamente `reportUser` sin abrir `ReportDialog` en algunos puntos, omitiendo la selección de motivo y privando al equipo de moderación de contexto sobre la infracción. Debe unificarse la apertura obligatoria de `ReportDialog`.
- **Precondiciones:** Contenido visible que el usuario considera infractor.
- **UI / contenido:** Diálogo modal con icono de escudo de alerta, título "Reportar Publicación / Comentario", subtítulo con el alias del autor, lista de radio buttons o chips con motivos de denuncia predefinidos, campo de texto multilínea opcional "Detalles adicionales", botón secundario "Cancelar" y primario "Enviar Reporte".
- **Interacciones:** Seleccionar motivo habilita el botón de envío; al enviar se muestra spinner breve, se cierra el diálogo y se exhibe el SnackBar: `"Gracias por tu reporte. Se ha enviado al equipo de moderación."`.
- **Estados:** Selección de motivo, Enviando reporte, Confirmación exitosa, Error de envío (aviso de reintento).
- **Validaciones y reglas de negocio:** Al registrarse múltiples reportes independientes sobre un post (umbral configurado en backend), el post actualiza su `moderation_status = 2` (oculto) de manera preventiva hasta que un Moderador lo revise.
- **Accesibilidad:** Modal con foco atrapado accesible, opciones legibles por lectores de pantalla, botones con contraste y tamaño táctil suficiente.
- **Responsive:** BottomSheet ergonómico en móvil; Dialog centrado (hasta 420px) en tablet/desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** un post con contenido de fraude académico, **When** un estudiante pulsa el botón de reporte, selecciona "Venta o fraude ilegal" y envía, **Then** el diálogo se cierra y el sistema muestra "Gracias por tu reporte. Se ha enviado al equipo de moderación".
  - **Given** un usuario que intenta enviar el formulario de reporte sin seleccionar ningún motivo, **When** presiona "Enviar", **Then** el sistema le solicita seleccionar al menos un motivo antes de continuar.

---

### UX-FORO-017 — Creación y publicación de temas en el foro estudiantil
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin (Visitante interceptado con AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Diálogo modal adaptativo (`CreatePostDialog`) para redactar una nueva consulta o aporte. Permite definir: contexto de publicación (Facultad, Carrera y Canal temático), título claro (mínimo 3 caracteres, obligatorio), contenido detallado (obligatorio), adjunto multimedia opcional (1 imagen o 1 GIF animado del catálogo curado) y módulo opcional de encuesta. Al enviar, el post se crea con `moderation_status = 0` y se inserta inmediatamente en el tope del feed con feedback positivo.
- **Problema actual [Mejora]:** [Vacío 8.5] En `create_post_dialog.dart:204-227` y `storage_service.dart:16-107`, la subida de imágenes apunta únicamente a un Worker de Cloudflare R2 (`workers.dev`); si este falla o está bloqueado por cuota o red, la subida devuelve `null` sin intentar un fallback secundario a Supabase Storage, frustrando al usuario con un error opaco. Debe implementarse reintento automático con fallback a Supabase Storage y progreso visual.
- **Precondiciones:** Sesión autenticada en nivel AAL2 (MFA TOTP verificado).
- **UI / contenido:** Encabezado con título "Nueva Publicación", selectores dropdown o chips de Facultad/Carrera y Canal temático, campo de título con contador de caracteres (3 a 120), campo de contenido multilínea (mín 10 caracteres), barra de adjuntos con botones "Foto" y "GIF", vista previa de imagen o GIF con botón de eliminar ("X"), botón colapsable "Agregar Encuesta", botón secundario "Cancelar" y primario "Publicar Tema".
- **Interacciones:** Seleccionar carrera y canal actualiza los metadatos; escribir valida en vivo la longitud mínima; pulsar "Foto" abre selector de archivos del sistema; pulsar "GIF" abre `GifPickerModal`; pulsar "Publicar" despacha la creación, muestra indicador de carga, cierra el modal e inserta el post en el feed.
- **Estados:** Formulario vacío, Con multimedia adjunta, Con encuesta desplegada, Subiendo imagen (barra de progreso porcentual), Publicando (botón con spinner, inputs bloqueados para evitar duplicación), Éxito (toast de confirmación y cierre), Error (mensaje claro sin perder el texto redactado).
- **Validaciones y reglas de negocio:** Validación obligatoria de título (mínimo 3 caracteres no vacíos). No se permite adjuntar imagen y GIF simultáneamente (uno sustituye al otro). La sesión debe ser AAL2.
- **Accesibilidad:** Formularios con `FormField` accesibles, labels explícitos, manejo de foco con teclado, soporte para lectores de pantalla.
- **Responsive:** Móvil como `ModalBottomSheet` con bordes superiores redondeados y ajuste al teclado (`resizeToAvoidBottomInset`); Desktop/Tablet como `Dialog` centrado con ancho restringido a 540px.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que ingresa un título de 2 letras "Hi", **When** presiona "Publicar Tema", **Then** el formulario bloquea el envío y muestra un mensaje de validación: "El título debe contener al menos 3 caracteres".
  - **Given** una falla de subida de imagen en el proveedor primario Cloudflare R2, **When** el servicio detecta el error HTTP, **Then** intenta automáticamente el respaldo a Supabase Storage sin interrumpir al usuario y concluye la publicación con éxito.

---

### UX-FORO-018 — Configuración de encuestas en el formulario de creación de post
- **Actor / rol:** Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Should
- **Estado objetivo:** Sección colapsable dentro de `CreatePostDialog` que permite incorporar una votación comunitaria a la publicación. Al activar el control "¿Agregar encuesta?", se despliegan: campo para la pregunta específica (con placeholder que por defecto toma el título de la publicación si se deja vacío), y campos para opciones de respuesta (inicialmente 2 opciones obligatorias, con capacidad de agregar dinámicamente hasta 5 opciones y eliminar opciones con un mínimo garantizado de 2).
- **Problema actual [Mejora]:** En `create_post_dialog.dart:104-107`, las opciones iniciales vienen prellenadas con texto genérico `"Opción 1"` y `"Opción 2"`, lo que provoca que estudiantes distraídos publiquen encuestas con esos textos ficticios si olvidan editarlos. Deben presentarse vacías con placeholder orientativo y validación de texto no vacío.
- **Precondiciones:** Modal de creación de post abierto.
- **UI / contenido:** Switch o botón tipo acordeón "Encuesta estudiantil", campo de texto para pregunta de encuesta, lista de campos de opción numerados ("Opción 1", "Opción 2", ...), botón con icono de basura para eliminar opciones (visible si hay >2), y botón "Agregar opción" (`Icons.add`, deshabilitado al alcanzar 5 opciones).
- **Interacciones:** Activar switch revela los campos con animación suave; pulsar "Agregar opción" añade un nuevo campo (hasta 5); pulsar icono de papelera elimina la opción correspondiente; al publicar se empaquetan la pregunta y las opciones válidas hacia `ForumService.createPost`.
- **Estados:** Encuesta desactivada (oculta), Encuesta activa con 2 opciones, Encuesta con 3 a 5 opciones, Límite máximo de 5 opciones alcanzado (botón agregar deshabilitado con tooltip explicativo).
- **Validaciones y reglas de negocio:** Cada opción debe contener al menos 1 caracter no vacío; mínimo 2 opciones con texto válido para permitir la publicación de la encuesta.
- **Accesibilidad:** Los campos de opción anuncian su posición ("Opción 3 de 5"), botones de eliminar con descripción clara para lectores de pantalla.
- **Responsive:** Campos verticales fluidos que no se desbordan ni ocultan botones al desplegar el teclado en dispositivos móviles.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que activa la encuesta y añade 3 opciones ("Mañana", "Tarde", "Noche"), **When** presiona "Publicar", **Then** el post se crea con la encuesta vinculada y las 3 opciones listas para votación.
  - **Given** un estudiante que intenta publicar una encuesta con la opción 2 vacía, **When** presiona "Publicar", **Then** el formulario señala en rojo el campo vacío indicando "Debes ingresar el texto para esta opción o eliminarla".

---

### UX-FORO-019 — Sistema integral de estados de carga, vacío, error y modo sin conexión
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Must
- **Estado objetivo:** El foro ofrece retroalimentación consistente en todas sus pantallas frente a contingencias de red y datos:
  1. *Carga:* Tarjetas esqueleto animadas (`SkeletonCard` shimmer) que replican la anatomía del post en lugar de un spinner genérico.
  2. *Vacío:* Componente `EmptyStateWidget` adaptativo al canal activo (ej. en `# catedraticos-opiniones` invita a comentar sobre docentes; en `# mis-guardados` explica cómo guardar).
  3. *Error:* Mensaje en español con ilustración y botón "Reintentar conexión".
  4. *Sin conexión (Offline):* Banner visible color ámbar `"Sin conexión — Mostrando contenido guardado."` que aprovecha la caché local de `CacheService` y deshabilita temporalmente acciones de escritura con mensajes formativos en lugar de bloqueos opacos.
- **Problema actual [Mejora]:** En `forum_screen.dart:824-831`, la carga muestra un `CircularProgressIndicator` básico en lugar de `SkeletonCard`, produciendo saltos visuales al renderizar la lista; y al perder la conexión, el botón de reintento no siempre revalida la caché de forma determinista.
- **Precondiciones:** Acceso a la pantalla del foro en cualquier estado de red.
- **UI / contenido:** Widgets unificados de `network_state_widgets.dart` y `empty_state_widget.dart`: tarjetas shimmer con formas rectangulares y circulares tenues; banner ámbar con icono `Icons.wifi_off`; botón primario "Reintentar".
- **Interacciones:** Deslizar hacia abajo (pull-to-refresh) fuerza la reconexión; pulsar "Reintentar" dispara `_loadPosts()`; al recuperarse la conectividad, el banner offline desaparece automáticamente.
- **Estados:** Carga shimmer, Lista poblada, Vacío contextual, Error de red recuperable, Sin conexión con fallback en caché.
- **Validaciones y reglas de negocio:** Las publicaciones cacheadas en `CacheService` se conservan de forma persistente y se actualizan en segundo plano en cuanto se restablece la conexión.
- **Accesibilidad:** Anuncio accesible de cambios de estado ("Cargando publicaciones", "Modo sin conexión activado", "Contenido actualizado").
- **Responsive:** Los esqueletos y estados vacíos respetan los mismos anchos máximos y paddings que el feed real.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que abre el foro sin señal de datos en el campus, **When** la aplicación no recibe respuesta del servidor, **Then** carga instantáneamente las publicaciones almacenadas en caché local y muestra en la parte superior el banner: "Sin conexión — Mostrando contenido guardado".
  - **Given** una falla temporal del servidor mientras el usuario tiene conexión, **When** el feed falla al cargar, **Then** muestra una pantalla limpia con el texto "No pudimos conectar con el foro" y un botón "Reintentar" que reejecuta la solicitud al presionarse.

---

### UX-FORO-020 — Desacoplamiento y claridad en el descubrimiento de Grupos de Estudio
- **Actor / rol:** Visitante, Estudiante, Verificado, Moderador, Admin
- **Prioridad:** Should
- **Estado objetivo:** Experiencia diáfana que elimina la fricción de confundir el directorio de enlaces de WhatsApp (`GroupsScreen`) con un servidor de discusión del foro. En el rail de servidores, el acceso a "Grupos de Estudio" debe exhibir un distintivo visual inequívoco que indique que se trata de enlaces externos de mensajería (WhatsApp/Telegram/Discord) y no de un canal de texto del foro. Asimismo, se debe proveer un enlace cruzado contextual desde el canal `# charla-general` o la cabecera hacia el directorio de grupos de la facultad activa ([ver UX-GRP en `05-grupos.md`](05-grupos.md) y [`02-navegacion.md`](02-navegacion.md)).
- **Problema actual [Mejora]:** [Vacío 8.4] En `app_shell.dart:198-215`, `forum_screen.dart:529-540` y `forum_server_rail.dart:600-633`, la funcionalidad completa de Grupos de Estudio está oculta como si fuera un servidor más de Discord (`isGroups = true`). Los estudiantes que entran buscando enlaces de WhatsApp no entienden que deben tocar el icono de WhatsApp en el rail del foro, asumiendo que no existe directorio de grupos.
- **Precondiciones:** Navegación del foro activa.
- **UI / contenido:** Icono verde de WhatsApp con badge "Enlaces Externos / Grupos", tooltip explicativo "Directorio de Grupos de WhatsApp por Facultad", banner sugerido en el feed si no hay grupos en el foro invitando a explorar el directorio.
- **Interacciones:** Toque en el servidor de grupos transiciona con animación clara o abre la sección de grupos informando que son enlaces para unirse a chats externos; desde el feed del foro, botón "Ver grupos de WhatsApp de esta carrera" redirige al subdirectorio correspondiente.
- **Estados:** Foro activo, Transición a Grupos, Banner de sugerencia cruzada.
- **Validaciones y reglas de negocio:** La navegación hacia enlaces de grupos preserva el filtro de la facultad activa del estudiante para no obligarlo a buscar su unidad académica de nuevo.
- **Accesibilidad:** Etiqueta semántica clara ("Acceso al directorio externo de grupos de estudio de WhatsApp").
- **Responsive:** Acceso evidente tanto en el rail de servidores de escritorio como en el menú drawer y accesos rápidos en móvil.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante buscando grupos de WhatsApp de su curso en el foro, **When** observa el rail lateral, **Then** identifica el icono verde con el distintivo claro "Grupos de WhatsApp" y una leyenda orientativa.
  - **Given** un estudiante que navega en el canal de una carrera sin grupos compartidos, **When** visualiza el feed, **Then** se le ofrece un botón directo "Explorar enlaces de WhatsApp de esta carrera" que lo traslada al directorio con la facultad precargada.

---

### UX-FORO-021 — Publicación patrocinada nativa en el feed
- **Actor / rol:** Todos (visible); Patrocinador (origen del contenido)
- **Prioridad:** Should
- **Estado objetivo:** el feed puede intercalar **publicaciones patrocinadas** con la misma anatomía de las tarjetas del foro (avatar/logotipo, nombre, texto, imagen o GIF, CTA), etiquetadas obligatoriamente como **"Patrocinado"** y con el acento visual del sistema de patrocinios ([ver `UX-SPN-003` en `12-patrocinios.md`](12-patrocinios.md)). El patrocinio es una capa transversal, no un canal de discusión.
- **Problema actual [Mejora]:** hoy los patrocinios solo existen como carrusel en el Marketplace ([`sponsor_carousel.dart`](../../comunidad_universitaria/lib/features/marketplace/widgets/sponsor_carousel.dart)); el foro no tiene un mecanismo de inserción. Se introduce aquí respetando la frecuencia de [`UX-SPN-004`](12-patrocinios.md).
- **Precondiciones:** existe al menos una promoción aprobada relevante al servidor/canal activo.
- **UI / contenido:** tarjeta visualmente hermana de `PostCard` pero con: chip `Patrocinado` (acento dorado `#EAB308`), logotipo y nombre del patrocinador con distintivo verificado, texto corto, media, y CTA primario. En la cabecera del canal, opcionalmente, un único bloque "Promoción destacada".
- **Interacciones:** toque en la tarjeta o en el CTA abre la ficha del producto o el perfil del patrocinador; el resto del feed sigue navegable sin cambios. Insertado tras las publicaciones fijadas y nunca antes de la primera publicación orgánica.
- **Estados:** sin promociones relevantes (no se inserta nada) | cargando (skeleton con forma de tarjeta) | activa | pausada (desaparece sin recargar) | media no disponible (fallback gráfico).
- **Validaciones y reglas de negocio:** **máximo 1 unidad patrocinada por cada 6 elementos orgánicos**, máximo 2 por carga de feed, nunca dos consecutivas, nunca por encima de contenido fijado. Solo se muestran promociones **aprobadas** ([`UX-SPN-006`](12-patrocinios.md)).
- **Accesibilidad:** la etiqueta "Patrocinado" se anuncia antes del cuerpo ([`UX-SPN-003`](12-patrocinios.md)); navegación por teclado; texto alternativo en el logotipo.
- **Responsive:** en desktop se integra en la columna del feed; en móvil ocupa el ancho del feed sin romper el chip strip de canales. La "Promoción destacada" se coloca bajo la cabecera en ambos.
- **Criterios de aceptación (Gherkin):**
  - **Given** un feed con 12 publicaciones orgánicas y una promoción aprobada dirigida a la facultad activa, **When** el usuario desplaza el feed, **Then** ve como máximo 2 publicaciones patrocinadas, separadas por al menos 6 orgánicas y claramente etiquetadas "Patrocinado".
  - **Given** un canal sin promociones relevantes, **When** se carga el feed, **Then** no aparece ningún espacio patrocinado ni hueco vacío.

### UX-FORO-022 — Interacciones de la publicación patrocinada
- **Actor / rol:** Todos
- **Prioridad:** Should
- **Estado objetivo:** la publicación patrocinada prioriza un **llamado a la acción** en lugar del debate: muestra CTA primario ("Ver producto", "Contactar", "Ir al perfil"), permite **guardar** y ofrece las acciones de control **Ocultar / ¿Por qué veo esto? / Reportar**. Por defecto **no habilita hilos de comentarios**, para no confundir publicidad con conversación.
- **Problema actual [Mejora]:** no existe un modelo de interacción diferenciado para contenido promovido; se define aquí para evitar que el patrocinio se comporte igual que un post de estudiante.
- **Precondiciones:** la publicación patrocinada está visible.
- **UI / contenido:** barra inferior con CTA a la izquierda y, a la derecha, iconos de Guardar y de menú (⋮) con las acciones de control.
- **Interacciones:** el CTA abre la ficha/perfil; Guardar guarda la promoción en `# mis-guardados`; Ocultar la retira de la vista y la recuerda; Reportar abre `ReportDialog` ([`UX-FORO-016`](#ux-foro-016--denuncia-comunitaria-y-reporte-ético-de-contenido)).
- **Estados:** CTA disponible | guardado | oculto | reportado | promoción finalizada (se atenúa con "Promoción finalizada").
- **Validaciones y reglas de negocio:** el patrocinador **no** recibe "Me gusta" ni comentarios; las métricas de interacción del post patrocinado no contaminan las del contenido orgánico.
- **Accesibilidad:** CTA y controles con etiquetas accesibles y foco gestionado; el menú se anuncia como "Opciones del patrocinio".
- **Responsive:** barra inferior adaptada al ancho; menú como hoja inferior en móvil y popover en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** una publicación patrocinada, **When** el usuario pulsa "Contactar", **Then** se abre el canal de contacto del patrocinador (WhatsApp u otro) y se registra un clic.
  - **Given** una publicación patrocinada, **When** el usuario abre el menú y pulsa "Ocultar", **Then** la tarjeta desaparece y no vuelve a mostrarse en esa sesión.

### UX-FORO-023 — Espacio dedicado de promociones por facultad (opt-in)
- **Actor / rol:** Todos; Patrocinador
- **Prioridad:** Could
- **Estado objetivo:** para no recargar el feed, existe un **espacio opcional** ("Promociones" o `# apoyos`) accesible desde la cabecera del canal o del servidor, que reúne todas las promociones activas del contexto activo. Es de lectura **voluntaria** y no se abre por defecto.
- **Problema actual [Mejora]:** sin un espacio centralizado, cada promoción debe competir en el feed principal; ofrecer un espacio opt-in mantiene el feed limpio y da visibilidad a los patrocinadores.
- **Precondiciones:** hay promociones aprobadas para la facultad/sede.
- **UI / contenido:** acceso discreto en la cabecera ("Promociones de esta facultad") con contador; pantalla/hoja con grid de promociones, cada una con etiqueta "Patrocinado" y CTA.
- **Interacciones:** abrir el espacio lista las promociones; tocar una abre su ficha/perfil; cerrar devuelve al feed.
- **Estados:** sin promociones (acceso oculto o estado vacío informativo) | con promociones | carga (skeletons).
- **Validaciones y reglas de negocio:** el espacio **no** sustituye ni altera el orden del feed orgánico; es puramente aditivo y opt-in.
- **Accesibilidad:** el acceso indica su naturaleza ("Ver promociones patrocinadas"); encabezados jerárquicos.
- **Responsive:** hoja inferior en móvil; panel modal o panel lateral en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** la facultad activa con 4 promociones aprobadas, **When** el usuario pulsa "Promociones de esta facultad", **Then** ve las 4 con etiqueta y CTA.
  - **Given** que el usuario nunca abre el espacio de promociones, **When** usa el foro normalmente, **Then** su experiencia del feed no se ve alterada por el espacio opt-in.

### UX-FORO-024 — Convivencia, moderación y no intrusión en el feed
- **Actor / rol:** Todos; Moderador
- **Prioridad:** Must
- **Estado objetivo:** las publicaciones patrocinadas conviven con el contenido de estudiantes sin degradarlo: no desplazan fijados, no alteran el orden cronológico orgánico (solo intercalan), y **toda** promoción pasa por moderación y puede reportarse como cualquier otro contenido.
- **Problema actual [Mejora]:** se formaliza la convivencia y la moderación de patrocinios, ausente hoy por no existir la función.
- **Precondiciones:** feed con o sin patrocinios.
- **UI / contenido:** borde/acento dorado tenue en la tarjeta; sin cambios en el resto del feed.
- **Interacciones:** pull-to-refresh recalcula la inserción; al pausar/finalizar una promoción, desaparece del feed en la siguiente actualización.
- **Estados:** normal | promoción pausada/finalizada (se retira) | promoción suspendida por moderación (se retira).
- **Validaciones y reglas de negocio:** ningún patrocinio puede fijarse por encima de un fijado de moderación/admin; el tope de frecuencia es duro y global ([`UX-SPN-004`](12-patrocinios.md)); el sistema vigila la "carga publicitaria" ([`UX-SPN-007`](12-patrocinios.md)).
- **Accesibilidad:** igual que el contenido orgánico ([`UX-X-008`](10-transversales.md), [`UX-X-009`](10-transversales.md)).
- **Responsive:** mismo comportamiento en móvil/desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** un canal con una publicación fijada y una promoción, **When** se carga el feed, **Then** la publicación fijada conserva la primera posición y la promoción aparece intercalada más abajo.
  - **Given** una promoción con reportes reiterados, **When** el sistema la suspende, **Then** deja de mostrarse en el feed de inmediato en todos los dispositivos.

---

## 3. Matriz de trazabilidad de requisitos del Foro

| ID | Título | Prioridad | Pantalla / Componente | Código relacionado |
|---|---|:---:|---|---|
| `UX-FORO-001` | Feed central y selector de canales temáticos | Must | `ForumScreen` | `forum_screen.dart:691-888` |
| `UX-FORO-002` | Rail lateral de servidores y navegación | Must | `ForumServerRail` | `forum_server_rail.dart:25-160` |
| `UX-FORO-003` | Explorador y buscador unificado de carreras | Should | `ForumCarreraPickerDialog` | `forum_carrera_picker_dialog.dart:27-142` |
| `UX-FORO-004` | Barra lateral de canales temáticos | Must | `ForumChannelSidebar` | `forum_channel_sidebar.dart:27-164` |
| `UX-FORO-005` | Barra de estado de usuario e identidad (User Bar) | Must | `ForumChannelSidebar` | `forum_channel_sidebar.dart:166-248`, `local_storage_service.dart:23-40` |
| `UX-FORO-006` | Panel lateral de comunidades populares | Should | `PopularServersSidebar` | `popular_servers_sidebar.dart:24-90`, `forum_screen.dart:547-555` |
| `UX-FORO-007` | Búsqueda en tiempo real y filtrado de temas | Must | `ForumScreen` | `forum_screen.dart:946-1004` |
| `UX-FORO-008` | Tarjeta de publicación en el feed (Post Card) | Must | `PostCard` | `post_card.dart:36-576` |
| `UX-FORO-009` | Detalle de publicación y visualización extendida | Must | `PostDetailScreen` | `post_detail_screen.dart:275-450` |
| `UX-FORO-010` | Árbol de comentarios jerárquicos y anidados | Must | `CommentItemWidget` | `comment_item.dart:24-198`, `forum_service.dart:605-626` |
| `UX-FORO-011` | Barra de redacción contextual de respuestas | Must | `PostDetailScreen` | `post_detail_screen.dart:220-267`, `post_detail_screen.dart:820-900` |
| `UX-FORO-012` | Encuestas estudiantiles interactivas | Must | `PostCard`, `PostDetailScreen` | `post_card.dart:280-408`, `forum_screen.dart:360-405` |
| `UX-FORO-013` | Reacción de me gusta y valoración | Must | `PostCard`, `PostDetailScreen` | `forum_screen.dart:283-316`, `post_detail_screen.dart:75-102` |
| `UX-FORO-014` | Marcadores y canal `# mis-guardados` | Must | `ForumScreen`, `PostDetailScreen` | `forum_screen.dart:318-358`, `post_detail_screen.dart:104-135` |
| `UX-FORO-015` | Citación de publicaciones (Repost) | Should | `PostCard`, `CreatePostDialog` | `forum_screen.dart:407-436`, `create_post_dialog.dart:142-145` |
| `UX-FORO-016` | Denuncia comunitaria y reporte ético | Must | `ReportDialog`, `PostCard` | `report_dialog.dart:20-100`, `post_card.dart:872-884` |
| `UX-FORO-017` | Creación y publicación de temas en el foro | Must | `CreatePostDialog` | `create_post_dialog.dart:50-300`, `storage_service.dart:16-107` |
| `UX-FORO-018` | Configuración de encuestas en creación de post | Should | `CreatePostDialog` | `create_post_dialog.dart:102-108`, `create_post_dialog.dart:228-244` |
| `UX-FORO-019` | Estados de carga, vacío, error y offline | Must | `ForumScreen`, `NetworkStateWidgets` | `forum_screen.dart:788-853`, `network_state_widgets.dart:1-92` |
| `UX-FORO-020` | Desacoplamiento y descubrimiento de Grupos | Should | `ForumServerRail`, `AppShell` | `app_shell.dart:198-215`, `forum_server_rail.dart:600-633` |
| `UX-FORO-021` | Publicación patrocinada nativa en el feed | Should | `ForumScreen`, nuevo `PromotedPostCard` | `forum_screen.dart`, `sponsor_carousel.dart` |
| `UX-FORO-022` | Interacciones de la publicación patrocinada | Should | `PromotedPostCard` | `sponsor_carousel.dart`, `report_dialog.dart` |
| `UX-FORO-023` | Espacio de promociones por facultad (opt-in) | Could | `ForumScreen` | `forum_screen.dart` |
| `UX-FORO-024` | Convivencia, moderación y no intrusión | Must | `ForumScreen`, moderación | `forum_screen.dart`, `sponsor_carousel.dart` |
