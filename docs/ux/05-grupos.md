# 05 — Directorio de Grupos de Estudio

> Especificación de requisitos de experiencia de usuario (UX) para el Directorio
> Colaborativo de Grupos de Estudio (WhatsApp, Telegram, Discord y Google Drive) de
> la plataforma **Comunidad Universitaria USAC**. Convenciones, matriz de roles y
> plantilla de especificación en [`README.md`](README.md).

---

## 1. Visión y propósito del área

El **Directorio de Grupos de Estudio** es el módulo centralizado donde los estudiantes
de las distintas facultades y escuelas no facultativas de la Universidad de San Carlos
de Guatemala descubren, comparten y validan enlaces directos a canales de comunicación
académica externa (grupos de WhatsApp por sección, comunidades de Telegram, servidores
de Discord y carpetas colaborativas de Google Drive).

### 1.1 Objetivos de experiencia
1. **Descubrimiento inmediato:** Permitir que cualquier alumno encuentre el grupo
   exacto de su curso y sección en menos de 10 segundos, filtrando por unidad
   académica o buscando por nombre de materia.
2. **Reputación comunitaria transparente:** Erradicar enlaces fraudulentos, grupos
   cerrados o enlaces expirados mediante un sistema descentralizado de votos de
   apoyo (*Upvotes*) y denuncias directas (*Reportes*).
3. **Higiene periódica:** Avisar con claridad a la comunidad sobre la depuración
   semestral de enlaces inactivos para mantener el catálogo limpio y actualizado
   ciclo a ciclo.
4. **Acceso universal sin fricción:** Garantizar lectura pública inmediata para
   visitantes, reservando la autenticación reforzada únicamente para la creación,
   votación y moderación de contenido.

---

## 2. Relación con el inventario y mejoras estructurales

Este documento formaliza y eleva la experiencia documentada en el **Inventario UX**,
abordando directamente:
- **Inventario 4.4 (`GroupsScreen`):** Componentes clave de la pantalla, incluyendo el
  banner de bienvenida contextual, el aviso de limpieza de inicio de semestre, la
  cuadrícula de tarjetas `GroupCard` y el modal `CreateGroupDialog`.
- **Inventario 8.4 (Vacío de descubribilidad):** Corrección obligatoria del acceso
  oculto en la arquitectura Discord mediante la incorporación de un punto de entrada
  directo y de primer nivel en el cascarón de navegación global (`AppShell`).

---

## 3. Matriz de capacidades del área

| Capacidad | Visitante | Estudiante Registrado | Estudiante Verificado | Moderador | Administrador |
|---|:---:|:---:|:---:|:---:|:---:|
| Explorar catálogo de grupos y filtrar por facultad | ✅ | ✅ | ✅ | ✅ | ✅ |
| Buscar cursos por texto libre | ✅ | ✅ | ✅ | ✅ | ✅ |
| Abrir enlace externo del grupo ("Unirse") | ✅ | ✅ | ✅ | ✅ | ✅ |
| Copiar enlace de invitación al portapapeles | ✅ | ✅ | ✅ | ✅ | ✅ |
| Descartar banner de depuración semestral | ✅ | ✅ | ✅ | ✅ | ✅ |
| Votar reputación comunitaria (*Upvote*) | ❌ *(interceptado)* | ✅ *(AAL2)* | ✅ *(AAL2)* | ✅ *(AAL2)* | ✅ *(AAL2)* |
| Compartir / registrar nuevo grupo | ❌ *(interceptado)* | ✅ *(AAL2)* | ✅ *(AAL2)* | ✅ *(AAL2)* | ✅ *(AAL2)* |
| Reportar enlace caído o indebido | ❌ *(interceptado)* | ✅ *(AAL2)* | ✅ *(AAL2)* | ✅ *(AAL2)* | ✅ *(AAL2)* |
| Ocultar o dar de baja enlace reportado | ❌ | ❌ | ❌ | ✅ | ✅ |

> **Nota de seguridad:** Toda acción de escritura (votar, registrar, reportar)
> exige sesión activa con elevación multifactor **AAL2** (TOTP). Si un visitante
> intenta ejecutarla, el sistema presenta `AuthModal` y, al autenticarse, reanuda la
> acción sin perder el contexto [ver [`07-autenticacion.md`](07-autenticacion.md)].

---

## 4. Requisitos de experiencia de usuario (UX-GRP)

### UX-GRP-001 — Acceso directo y visible desde la navegación principal
- **Actor / rol:** Visitante, Estudiante registrado, Estudiante verificado, Moderador, Administrador
- **Prioridad:** Must
- **Estado objetivo:** El estudiante puede acceder al Directorio de Grupos de Estudio con un solo toque o clic desde el cascarón principal de la aplicación (`AppShell`), contando con una pestaña dedicada "Grupos" tanto en la barra inferior móvil (`NavigationBar`) como en la barra superior desktop, además de conservar el punto de entrada contextual existente dentro del Server Rail del foro estudiantil.
- **Problema actual [Mejora]:** En la implementación actual ([`app_shell.dart:169-215`](../../comunidad_universitaria/lib/features/navigation/app_shell.dart#L169-L215)), el menú principal solo expone dos destinos: "Foro" y "Marketplace". El directorio entero de grupos se encuentra escondido como si fuera un servidor interno de Discord dentro del foro ([`forum_screen.dart:604-620`](../../comunidad_universitaria/lib/features/forum/screens/forum_screen.dart#L604-L620), [`forum_server_rail.dart:28-60`](../../comunidad_universitaria/lib/features/forum/widgets/discord/forum_server_rail.dart#L28-L60)), provocando un grave vacío de descubribilidad (Inventario UX 8.4) para alumnos que acuden exclusivamente a buscar grupos de WhatsApp de sus asignaturas.
- **Precondiciones:** La aplicación se encuentra en ejecución en cualquier dispositivo o plataforma soportada.
- **UI / contenido:**
  - En móvil: Tercer destino en la `NavigationBar` inferior con etiqueta "Grupos", icono `Icons.groups_outlined` en reposo e icono relleno `Icons.groups` en estado activo.
  - En desktop: Tercera pestaña en la barra superior horizontal con icono `Icons.groups_outlined`, etiqueta "Grupos de Estudio" e indicador inferior de acento activo (`#2563EB`).
  - En el Foro (Desktop/Móvil): El botón con icono de mensajería en `ForumServerRail` se preserva como acceso rápido contextual, navegando o sincronizando de inmediato la vista de grupos hacia la facultad activa.
  - Preservación de estado: El contenedor principal aloja la pantalla dentro de un `IndexedStack` para no perder la posición de scroll ni los filtros aplicados al alternar entre pestañas.
- **Interacciones:**
  - Al pulsar "Grupos" en la barra de navegación, la vista conmuta instantáneamente a `GroupsScreen`.
  - En móvil, el botón flotante contextual (FAB) cambia automáticamente a "Compartir Grupo" (color verde `#198754`, icono `Icons.group_add`).
  - Al regresar desde otra sección, se conservan los filtros y la posición exacta donde se encontraba el usuario.
- **Estados:**
  - *Inicial:* Pestaña "Foro" activa por omisión al abrir la app.
  - *Activo:* Pestaña "Grupos" seleccionada con realce visual y color institucional.
  - *Transición:* Conmutación inmediata en memoria sin pantallas intermedias ni parpadeos.
- **Validaciones y reglas de negocio:**
  - El acceso a la lectura del directorio de grupos es público y libre; no requiere inicio de sesión previo.
  - Si el usuario accede a grupos desde el botón contextual del rail del foro, la vista hereda la facultad que estaba activa en ese momento (`activeFacultadId`).
- **Accesibilidad:**
  - Etiqueta semántica `Semantics(label: 'Directorio de grupos de estudio')`.
  - Destino táctil de 48x48 dp mínimo en la barra inferior móvil.
  - Navegación por teclado disponible mediante tabulador y teclas de flecha en desktop [ver [`10-transversales.md`](10-transversales.md)].
- **Responsive:**
  - Móvil (< 700 px): Destino en `NavigationBar` Material 3 inferior junto a "Foro" y "Marketplace".
  - Desktop / Tablet (>= 700 px): Pestaña en barra de navegación horizontal superior integrada en el AppBar de `AppShell`.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante navegando en la pantalla de inicio desde un dispositivo móvil, **When** pulsa el icono "Grupos" en la barra inferior de navegación, **Then** la vista cambia inmediatamente al Directorio de Grupos de Estudio sin recargar la página y muestra el FAB "Compartir Grupo".
  - **Given** un usuario que navega en el foro dentro del servidor de la Facultad de Ingeniería (código `08`), **When** pulsa el botón de grupos de estudio ubicado en la barra lateral izquierda del foro, **Then** la vista se traslada al directorio de grupos presentando automáticamente preseleccionada la Facultad de Ingeniería.

---

### UX-GRP-002 — Filtrado por facultad, carrera y búsqueda de cursos
- **Actor / rol:** Visitante, Estudiante registrado, Estudiante verificado, Moderador, Administrador
- **Prioridad:** Must
- **Estado objetivo:** El estudiante puede filtrar el directorio de grupos por Facultad / Escuela, refinar opcionalmente por Carrera universitaria o buscar mediante texto libre por nombre de curso, código o sección. Si el alumno tiene perfil registrado con facultad asignada, el sistema preconfigura los filtros con su contexto académico personal.
- **Problema actual [Mejora]:** En el código actual ([`groups_screen.dart:40-124`](../../comunidad_universitaria/lib/features/groups/screens/groups_screen.dart#L40-L124)), si bien el servicio de datos soporta `searchQuery` con índices trigram en PostgreSQL ([`groups_service.dart:60-63`](../../comunidad_universitaria/lib/core/services/groups_service.dart#L60-L63)), no existe un campo de texto de búsqueda visual en la interfaz de `GroupsScreen`, obligando al alumno a desplazarse manualmente entre decenas de tarjetas para ubicar su asignatura.
- **Precondiciones:** El catálogo institucional de facultades y carreras (`USACConstants.facultades`) se encuentra disponible en memoria.
- **UI / contenido:**
  - Selector desplegable "Facultad / Unidad" con opción "Todas las Facultades" y lista completa de las 10 facultades y escuelas de la USAC.
  - Selector dependiente "Carrera" con opción "Todas las Carreras", habilitado según la facultad seleccionada.
  - Barra de búsqueda interactiva con icono `Icons.search`, texto de sugerencia "Buscar por curso, código o sección...", y botón para limpiar `Icons.close`.
  - Contador informativo en tiempo real (ej. "14 grupos encontrados").
  - Chips de acceso rápido para unidades académicas con mayor volumen (Ingeniería, Medicina, Ciencias Económicas, Humanidades).
- **Interacciones:**
  - Al seleccionar una facultad, el selector de carrera actualiza inmediatamente sus opciones disponibles.
  - Al ingresar texto en el campo de búsqueda (con *debounce* de 300 ms), el listado filtra los resultados de manera reactiva.
  - Al pulsar el botón "X" del campo de búsqueda, se restablecen los resultados correspondientes a los selectores de facultad y carrera activos.
  - Al cambiar de facultad, el selector de carrera se reinicia automáticamente al valor "Todas".
- **Estados:**
  - *Inicial:* Presenta los grupos de la facultad del perfil del usuario (si está autenticado) o "Todas".
  - *Carga:* Cuadrícula con esqueletos animados (`SkeletonCard`) mientras se resuelve la consulta.
  - *Vacío:* Componente `EmptyStateWidget` indicando "No se encontraron grupos para este filtro", con botón de acción "Compartir Enlace" y sugerencia de restablecer filtros.
  - *Error:* Mensaje explicativo con botón "Reintentar".
  - *Sin conexión:* Recupera la última consulta persistida desde caché local (`student_groups`) con banner de aviso offline.
- **Validaciones y reglas de negocio:**
  - La resolución de facultades emplea la lista canónica de alias y palabras clave definida en `GroupsService._facultyAliases` ([`groups_service.dart:10-23`, `94-123`](../../comunidad_universitaria/lib/core/services/groups_service.dart#L10-L23)).
  - Los cursos de "Área Común" se asocian de forma bidireccional con las facultades que comparten tronco académico.
  - La búsqueda no distingue entre mayúsculas, minúsculas ni tildes diacríticas.
- **Accesibilidad:**
  - Campos de entrada con etiquetas accesibles asociadas (`InputDecoration.labelText`).
  - Anuncio verbal accesible vía lector de pantalla con la cantidad de resultados encontrados tras la filtración.
- **Responsive:**
  - Móvil (< 700 px): Selectores y buscador organizados en bloque vertical compacto.
  - Desktop / Tablet (>= 700 px): Disposición en fila horizontal dentro de un `MaxWidthContainer(1100)` maximizando el área útil de lectura.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que navega en el directorio, **When** escribe "Matemática Básica 1" en la barra de búsqueda, **Then** la lista muestra únicamente los grupos cuyo curso, título o descripción coincidan con ese texto.
  - **Given** un usuario que filtra por una carrera sin grupos registrados en el ciclo lectivo, **When** se procesa la consulta, **Then** la pantalla exhibe el estado vacío con el mensaje "No se encontraron grupos para este filtro" y el botón para "Compartir Enlace".

---

### UX-GRP-003 — Banner informativo de depuración semestral de enlaces
- **Actor / rol:** Visitante, Estudiante registrado, Estudiante verificado, Moderador, Administrador
- **Prioridad:** Should
- **Estado objetivo:** La plataforma informa con claridad y anticipación sobre la política de limpieza semestral de enlaces inactivos, exhibiendo un banner informativo destacado en la cabecera del directorio que el estudiante puede descartar de forma persistente para el ciclo en curso.
- **Problema actual [Mejora]:** En [`groups_screen.dart:77-89`, `266-294`](../../comunidad_universitaria/lib/features/groups/screens/groups_screen.dart#L77-L89), el banner se descarta mediante una bandera booleana genérica en SharedPreferences (`LocalStorageService.dismissCleanupNotice()`), sin asociarse al identificador del semestre activo (ej. `2026_S1`). Al iniciar un nuevo semestre lectivo, el banner no vuelve a desplegarse para recordar a los alumnos la actualización de sus grupos.
- **Precondiciones:** El estudiante accede a la vista de `GroupsScreen`.
- **UI / contenido:**
  - Contenedor con fondo ámbar/amarillo institucional (`#FFF3CD`), borde sutil (`#FFEEBA`) y bordes redondeados de 12 px.
  - Icono informativo `Icons.info_outline` en tono ámbar oscuro (`#856404`).
  - Texto oficial: "Para evitar enlaces caídos, los grupos se depuran automáticamente al iniciar cada nuevo semestre académico."
  - Botón de cierre "X" (`Icons.close`) en la esquina derecha superior.
  - Botón o enlace sutil "¿Cómo mantener activo mi grupo?" que enlaza a las reglas comunitarias [ver [`08-navegacion-shell-y-reglas.md`](08-navegacion-shell-y-reglas.md)].
- **Interacciones:**
  - Al pulsar el botón "X", el banner se oculta con una animación suave de colapso vertical.
  - La acción se almacena en el dispositivo del usuario vinculada al semestre lectivo actual, garantizando que no vuelva a aparecer en visitas posteriores durante el mismo ciclo.
- **Estados:**
  - *Visible:* Si el usuario no ha descartado el aviso correspondiente al periodo académico activo.
  - *Oculto:* Si el usuario ya lo descartó en el ciclo en curso.
- **Validaciones y reglas de negocio:**
  - La depuración semestral respalda el principio de calidad comunitaria (Inventario UX 1.2 y 4.4).
  - Los grupos con actividad reciente o con alta cantidad de upvotes pueden ser renovados por sus creadores sin perder su historial.
- **Accesibilidad:**
  - El contraste entre el texto (`#856404`) y el fondo (`#FFF3CD`) supera el ratio de 4.5:1 exigido por WCAG 2.2 AA.
  - Botón de cierre con tooltip explícito "Cerrar aviso informativo" y objetivo táctil de 40x40 dp mínimo.
- **Responsive:**
  - Ancho fluido adaptado a `MaxWidthContainer(1100)`; en pantallas estrechas el texto se acomoda a 2 o 3 líneas sin cortar el botón de cierre.
- **Criterios de aceptación (Gherkin):**
  - **Given** un alumno que ingresa al directorio de grupos por primera vez en el semestre académico, **When** carga la pantalla, **Then** observa el banner amarillo en la parte superior con el mensaje de depuración semestral.
  - **Given** un alumno que presiona el botón de cierre "X" del banner de depuración, **When** vuelve a ingresar a la sección de grupos o recarga la aplicación, **Then** el banner no se vuelve a mostrar durante el resto del semestre académico.

---

### UX-GRP-004 — Cuadrícula y listado responsivo de tarjetas de grupos
- **Actor / rol:** Visitante, Estudiante registrado, Estudiante verificado, Moderador, Administrador
- **Prioridad:** Must
- **Estado objetivo:** Los grupos se despliegan en una estructura responsiva ordenada: lista vertical optimizada para lectura en móviles y cuadrícula de 2 columnas en tablets y escritorios, presentando de forma condensada toda la información requerida para que el alumno evalúe si unirse.
- **Problema actual [Mejora]:** En la versión de escritorio actual ([`groups_screen.dart:340-346`](../../comunidad_universitaria/lib/features/groups/screens/groups_screen.dart#L340-L346)), la tarjeta tiene una relación de aspecto fija (`childAspectRatio: 1.6`) que produce desbordamientos visuales (*overflow de píxeles*) o recorte de textos si el grupo contiene una imagen miniatura (`imageUrl`) o una descripción superior a dos líneas.
- **Precondiciones:** Existen grupos publicados que cumplen con los filtros aplicados.
- **UI / contenido:**
  - Tarjeta Material 3 con bordes redondeados (12 px), elevación suave y padding de 16 px (`GroupCard`).
  - Fila superior de metadatos:
    - Chip identificador de plataforma con icono oficial y color de marca.
    - Chip de sección académica (ej. "Sección A", "Sección B", "Sección Única").
    - Menú de opciones adicionales (`Icons.more_vert`).
  - Nombre del curso principal en tipografía destacada (`titleMedium`, 16 px, negrita).
  - Título complementario o propósito específico si difiere del nombre de la materia.
  - Descripción y observaciones (máximo 2 líneas visibles con puntos suspensivos).
  - Previsualización opcional de imagen/logotipo con botón de lupa para expandir a pantalla completa en `ImageViewerDialog`.
  - Fila de autoría: Icono de usuario, seudónimo del creador (`authorAlias`) y tiempo transcurrido relativo (ej. "hace 3 días", mediante `TimeUtils.timeAgo`).
  - Línea divisoria sutil (`Divider`).
  - Fila inferior de acciones:
    - Botón de Upvote interactivo con recuento numérico.
    - Botón de copia rápida de enlace al portapapeles.
    - Botón primario prominente "Unirse al Grupo" estilizado con el color de la plataforma.
- **Interacciones:**
  - Al pulsar la imagen en miniatura, se abre el visor `ImageViewerDialog` con zoom interactivo (0.8x a 4.0x).
  - Al pulsar el menú de tres puntos, se despliega la opción "Reportar enlace caído/spam".
  - Gesto de arrastrar hacia abajo (*Pull-to-refresh*) para refrescar la lista de tarjetas en móvil.
- **Estados:**
  - *Carga:* Cuadrícula de tarjetas esqueleto con animación *shimmer*.
  - *Con datos:* Lista ordenada prioritariamente por mayor cantidad de upvotes y secundariamente por fecha de creación más reciente.
  - *Sin conexión:* Tarjetas provenientes de la caché local con distintivo de datos guardados.
- **Validaciones y reglas de negocio:**
  - Solo se muestran grupos cuyo estado de moderación esté activo (`moderation_status < 2`).
  - Si el curso no tiene sección especificada, la interfaz muestra por defecto "Sección Única".
- **Accesibilidad:**
  - Cada tarjeta está estructurada como un contenedor accesible con jerarquía de encabezados adecuada.
  - Soporte completo para navegación mediante teclado y lectores de pantalla.
- **Responsive:**
  - Móvil (< 700 px): `ListView.builder` vertical a 1 columna continua.
  - Tablet / Desktop (>= 700 px): `GridView.builder` a 2 columnas con espaciado uniforme de 16 px y altura adaptable al contenido.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que navega en una computadora de escritorio con pantalla de 1280 px, **When** accede al directorio de grupos, **Then** las tarjetas se presentan en una cuadrícula de 2 columnas dentro de un contenedor centrado de 1100 px máximo.
  - **Given** una tarjeta de grupo que contiene una imagen adjunta de horario o programa, **When** el alumno presiona la imagen, **Then** se abre el visor modal a pantalla completa con fondo oscurecido permitiendo hacer zoom con doble toque o rueda del mouse.

---

### UX-GRP-005 — Detección automática de plataforma y metadatos por dominio
- **Actor / rol:** Estudiante registrado, Estudiante verificado, Moderador, Administrador (al registrar); todos los roles (al explorar)
- **Prioridad:** Must
- **Estado objetivo:** La plataforma detecta automáticamente el servicio de mensajería o almacenamiento a partir de la URL suministrada por el estudiante, asignando de manera inmediata la identidad visual, icono y colores característicos sin exigir que el usuario seleccione la plataforma de forma manual.
- **Problema actual [Mejora]:** En [`whatsapp_group.dart:59-88`](../../comunidad_universitaria/lib/core/models/whatsapp_group.dart#L59-L88), la detección se basa en coincidencia simple de subcadenas, pero no valida que el protocolo de red sea obligatoriamente HTTPS ni bloquea enlaces acortadores genéricos que puedan ocultar malware o phishing.
- **Precondiciones:** El estudiante introduce una URL en el formulario de creación de grupo o el sistema renderiza un enlace existente.
- **UI / contenido:**
  - Asignación cromática e iconográfica oficial por plataforma:
    - **WhatsApp:** Fondo verde `#25D366` con 12% de opacidad, borde verde, icono `Icons.chat` y texto "WhatsApp". Detectado para dominios `chat.whatsapp.com` y `wa.me`.
    - **Telegram:** Fondo celeste `#0088CC` con 12% de opacidad, borde celeste, icono `Icons.send_rounded` y texto "Telegram". Detectado para dominios `t.me` y `telegram.me`.
    - **Discord:** Fondo morado blurple `#5865F2` con 12% de opacidad, borde morado, icono `Icons.headset_mic_rounded` y texto "Discord". Detectado para dominios `discord.gg` y `discord.com`.
    - **Google Drive:** Fondo dorado `#FBBC05` con 12% de opacidad, borde dorado, icono `Icons.folder_shared_outlined` y texto "Drive". Detectado para dominios `drive.google.com` y `docs.google.com`.
    - **Enlace Web / Otro:** Fondo azul USAC `#004B87` con 12% de opacidad, borde azul, icono `Icons.link` y texto "Enlace Web".
  - En el diálogo de creación: Chip de previsualización que conmuta en tiempo real al pegar el enlace en el campo de texto.
- **Interacciones:**
  - Al escribir o pegar un enlace en el formulario, el chip de plataforma actualiza inmediatamente su icono, color y etiqueta informativa.
- **Estados:**
  - *Detección exitosa:* Badge correspondiente visible con colores oficiales de la marca.
  - *Dominio genérico:* Badge "Enlace Web" para sitios académicos o repositorios no clasificados.
  - *URL no válida:* Borde de advertencia rojo y mensaje de validación bloqueante.
- **Validaciones y reglas de negocio:**
  - La URL debe comenzar estrictamente con el protocolo `https://`. Se prohíbe el protocolo plano `http://` y esquemas no seguros (`javascript:`, `data:`).
  - Bloqueo preventivo de acortadores anónimos comunes (`bit.ly`, `tinyurl.com`, `is.gd`) exigiendo enlaces directos a los servicios soportados.
- **Accesibilidad:**
  - La plataforma nunca se comunica exclusivamente mediante color; siempre va acompañada por el nombre textual de la aplicación y su icono semántico.
- **Responsive:**
  - El chip conserva dimensiones estándar de 24 px de alto con texto de 11 px en negrita en cualquier dispositivo.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que pega en el formulario de registro la URL "https://t.me/derecho_usac_2026", **When** el campo procesa el texto, **Then** la interfaz muestra de inmediato el chip celeste de Telegram con el icono oficial de envío.
  - **Given** un estudiante que intenta registrar un enlace con protocolo inseguro "http://chat.whatsapp.com/invitacion", **When** valida el formulario, **Then** el sistema impide el envío y muestra el mensaje de error "El enlace debe comenzar con https://".

---

### UX-GRP-006 — Votación comunitaria de reputación (Upvote)
- **Actor / rol:** Estudiante registrado, Estudiante verificado, Moderador, Administrador (emiten votos); Visitante (invitado a autenticarse)
- **Prioridad:** Must
- **Estado objetivo:** La comunidad valida la legitimidad y utilidad de los enlaces mediante votos de reputación (*Upvotes*). Los estudiantes autenticados pueden otorgar o retirar su voto con un solo toque; la interfaz responde de inmediato mediante actualización optimista y persiste el registro en PostgreSQL bajo control de unicidad.
- **Problema actual [Mejora]:** En la implementación actual ([`groups_screen.dart:126-160`](../../comunidad_universitaria/lib/features/groups/screens/groups_screen.dart#L126-L160)), si un visitante intenta votar se le abre `AuthModal`, pero tras iniciar sesión con éxito no se emite retroalimentación háptica o un SnackBar confirmando que el voto pendiente fue finalmente procesado.
- **Precondiciones:** El estudiante visualiza una tarjeta de grupo en el directorio.
- **UI / contenido:**
  - Botón interactivo tipo chip ovalado con bordes redondeados (20 px).
  - Estado no votado: Fondo neutro (gris claro en modo light, gris oscuro en dark), icono de contorno `Icons.thumb_up_alt_outlined` y cifra numérica en color neutro.
  - Estado votado por mí: Fondo tintado con color primario institucional al 12%, icono relleno `Icons.thumb_up` y cifra en color primario resaltado.
  - Tooltip: "Apoyar este grupo / enlace válido".
- **Interacciones:**
  - Si el usuario es Visitante: Al presionar el botón de Upvote se despliega `AuthModal` con el título "Inicia Sesión para Votar" y el subtítulo "Para apoyar y verificar enlaces de grupos, debes iniciar sesión.". Una vez autenticado, el sistema ejecuta automáticamente el voto pendiente y muestra un SnackBar de confirmación.
  - Si el usuario está Autenticado: Al presionar, el contador conmuta de forma optimista (+1 si vota, -1 si retira) y el aspecto visual del botón cambia de inmediato. En segundo plano se ejecuta `GroupsService.toggleUpvote()`.
  - Si falla la conexión: La interfaz revierte suavemente el contador y el aspecto del botón a su estado previo, notificando el fallo mediante un SnackBar.
- **Estados:**
  - *No votado:* Contador en N, aspecto en reposo.
  - *Votado:* Contador en N+1, aspecto resaltado.
  - *Reversión:* Restitución inmediata del estado ante fallo del servidor.
- **Validaciones y reglas de negocio:**
  - Control de unicidad estricto: La tabla `student_group_upvotes` tiene como clave primaria compuesta `(group_id, user_id)`, impidiendo votos duplicados.
  - Sincronización por trigger: El recuento de votos en `student_groups.upvotes` se actualiza atómicamente en PostgreSQL ante inserciones y eliminaciones de votos.
  - Auto-upvote inicial: Al crear un nuevo grupo, el creador recibe automáticamente el primer voto asignado a su cuenta ([`groups_service.dart:237`, `251-254`](../../comunidad_universitaria/lib/core/services/groups_service.dart#L237)).
- **Accesibilidad:**
  - Lectura accesible para lectores de pantalla: "Votado por X estudiantes. Toca dos veces para apoyar o retirar tu voto".
  - Área táctil de al menos 44x36 dp con efecto visual de pulsación (*InkWell splash*).
- **Responsive:**
  - Ubicado de forma constante en la parte inferior izquierda de cada tarjeta en todos los tamaños de pantalla.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante con sesión activa que visualiza una tarjeta con 8 upvotes que no ha votado previamente, **When** presiona el botón de upvote, **Then** el contador sube instantáneamente a 9, el icono cambia a relleno y el voto queda guardado en la base de datos.
  - **Given** un visitante sin sesión iniciada que pulsa el botón de upvote, **When** completa satisfactoriamente su autenticación en el modal desplegado, **Then** el modal se cierra, el contador de upvotes se incrementa en 1 y se muestra un SnackBar con el mensaje "Tu voto ha sido registrado".

---

### UX-GRP-007 — Reporte comunitario de enlaces caídos, llenos o indebidos
- **Actor / rol:** Estudiante registrado, Estudiante verificado, Moderador, Administrador (reportan); Moderador y Admin (gestionan denuncias)
- **Prioridad:** Must
- **Estado objetivo:** La comunidad dispone de un canal ágil y estructurado para denunciar enlaces que han expirado, grupos saturados, publicidad no autorizada o fraudes, activando el flujo de moderación comunitaria sin exponer al usuario que reporta.
- **Problema actual [Mejora]:** En [`groups_screen.dart:325-333`](../../comunidad_universitaria/lib/features/groups/screens/groups_screen.dart#L325-L333), la acción de reportar no valida si el usuario cuenta con sesión iniciada antes de enviar el registro a `entity_reports`; si se invoca como visitante, la inserción puede ser denegada por RLS o registrarse con `reporter_id = null` sin informar adecuadamente al usuario.
- **Precondiciones:** El estudiante detecta una anomalía en un grupo publicado en el directorio.
- **UI / contenido:**
  - Menú de opciones de la tarjeta (`Icons.more_vert`) en la esquina superior derecha.
  - Opción "Reportar enlace caído/spam" con icono de advertencia rojo `Icons.flag_outlined`.
  - Diálogo modal unificado `ReportDialog` que incluye:
    - Título: "Reportar Grupo".
    - Subtítulo: Nombre del curso y título del grupo denunciado.
    - Lista de motivos estandarizados con selección excluyente:
      1. "El enlace de invitación está expirado o revocado"
      2. "El grupo es de otra sección o curso"
      3. "Grupo lleno / límite de participantes"
      4. "Spam, publicidad o cobros de dinero"
      5. "Otro motivo"
    - Campo de observaciones opcional para complementar detalles.
    - Botones de acción: "Cancelar" y "Enviar Reporte".
  - Notificación SnackBar de confirmación: "Gracias. Hemos recibido tu reporte sobre el enlace."
- **Interacciones:**
  - Al pulsar "Reportar enlace caído/spam", si el usuario es visitante, se abre `AuthModal` indicando que se requiere cuenta para enviar reportes responsables.
  - El usuario elige un motivo de la lista y presiona "Enviar Reporte".
  - El diálogo se cierra de inmediato y se inserta el reporte en la tabla `entity_reports` con `entity_type = 'group'`.
- **Estados:**
  - *Selección de motivo:* Opciones seleccionables con respuesta táctil inmediata.
  - *Envío en curso:* Botón de confirmación con indicador de carga (*spinner*).
  - *Confirmación:* SnackBar de éxito visible durante 3 segundos.
- **Validaciones y reglas de negocio:**
  - Almacenamiento en la tabla consolidada `entity_reports` vinculada a `student_groups.id` ([`20260914120000_consolidate_report_tables.sql`](../../supabase/migrations_historical/20260914120000_consolidate_report_tables.sql)).
  - Auto-moderación preventiva: Cuando un grupo acumula múltiples reportes no resueltos (`reported_count >= 5`), el sistema incrementa automáticamente su estado de moderación a pendiente de revisión (`moderation_status = 1`), ocultándolo del feed público para salvaguardar a los estudiantes.
- **Accesibilidad:**
  - Enfoque inicial automático en el selector de motivos al abrir el diálogo.
  - Cierre accesible mediante tecla Esc o botón Atrás del sistema operativo.
- **Responsive:**
  - Móvil: Despliegue en BottomSheet deslizable desde el borde inferior.
  - Desktop: Diálogo centrado con ancho fijo de 440 px.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que encuentra un enlace de WhatsApp con el cupo de participantes agotado, **When** abre el menú de la tarjeta y envía el reporte con el motivo "Grupo lleno / límite de participantes", **Then** el diálogo se cierra y aparece el SnackBar "Gracias. Hemos recibido tu reporte sobre el enlace.".
  - **Given** un visitante sin sesión que intenta reportar un enlace, **When** presiona la opción de reporte, **Then** se abre el modal de autenticación requiriendo iniciar sesión para evitar abusos automatizados.

---

### UX-GRP-008 — Compartir y registrar nuevo grupo de estudio
- **Actor / rol:** Estudiante registrado, Estudiante verificado, Moderador, Administrador (publican); Visitante (interceptado por AuthModal)
- **Prioridad:** Must
- **Estado objetivo:** Cualquier estudiante autenticado puede compartir un enlace de grupo para su sección, curso o comunidad de facultad, completando un diálogo estructurado y accesible que valida la coherencia académica y la seguridad del enlace, publicando el registro de inmediato en el directorio.
- **Problema actual [Mejora]:** En [`create_group_dialog.dart:186-189`](../../comunidad_universitaria/lib/features/groups/widgets/create_group_dialog.dart#L186-L189), cuando el usuario selecciona "todas" en carrera para una facultad específica, el código genera un ID artificial `'${_selectedFacultad}_todas'`. Esta cadena viola la clave foránea estricta de la tabla `carreras` (`student_groups_carrera_catalogo_fkey`, migración `20260914190000_add_catalogs.sql`), provocando excepciones al guardar si la BD tiene activada la integridad referencial. Debe corregirse asignando la clave canónica de la facultad o el código general registrado en el catálogo.
- **Precondiciones:** El estudiante desea registrar un nuevo grupo de estudio.
- **UI / contenido:**
  - Disparador: Botón FAB flotante en móvil ("Compartir Grupo", verde `#198754`, icono `Icons.group_add`) o botón en la cabecera del directorio en escritorio.
  - Modal adaptativo (`CreateGroupDialog`):
    - Encabezado con icono temático, título "Compartir Enlace de Grupo", autor activo visible ("Publicado por: Alias") y botón "Alias" para modificar el seudónimo al vuelo mediante `AliasModal`.
    - Selector "Tipo de Grupo / Propósito": "Curso Académico", "Objetos Perdidos & Hallazgos", "Comunidad de Facultad / Sede", "Deportes & Actividades Extracurriculares", "Avisos & Organización Estudiantil", "Interés General / Otro".
    - Selectores combinados de "Facultad / Unidad" y "Carrera".
    - Si el tipo es "Curso Académico": Campos independientes para "Nombre del Curso" (obligatorio, ej. "Física 1") y "Sección" (ej. "Sección A").
    - Si es otro tipo de grupo: Campo "Nombre o Propósito del Grupo" (mínimo 4 caracteres).
    - Campo "Enlace de Invitación": Prefijo con icono `Icons.link`, placeholder representativo y validación estricta de prefijo HTTPS.
    - Campo "Descripción, reglas o notas": Campo multilínea opcional (hasta 2 líneas).
    - Selector opcional de imagen o banner: Botón para elegir archivo con `ImagePicker` y vista previa con botón de eliminación "X".
    - Botones de pie: "Cancelar" y "Compartir Grupo" (verde `#0F5132`).
- **Interacciones:**
  - Si es Visitante: Al presionar "Compartir Grupo" se abre `AuthModal` con el título "Inicia Sesión para Compartir".
  - Al cambiar de tipo de grupo, los campos de formulario se reconfiguran dinámicamente sin perder los datos previamente escritos.
  - Al seleccionar una imagen, se carga en segundo plano hacia el almacenamiento en la nube mostrando un indicador de progreso circular.
  - Al guardar exitosamente, el modal se cierra, el grupo se inserta optimistamente al inicio del feed (índice 0) y se despliega un SnackBar verde de éxito.
- **Estados:**
  - *Inicial:* Formulario limpio con la facultad y carrera preseleccionadas según el contexto activo.
  - *Subiendo imagen:* Botón de imagen inhabilitado con spinner.
  - *Enviando:* Botón primario bloqueado con spinner y texto "Guardando...".
  - *Error:* Alerta visual roja con mensaje de error comprensible.
- **Validaciones y reglas de negocio:**
  - Requiere sesión con nivel de garantía **AAL2** (MFA TOTP verificado) para operaciones de inserción [ver [`07-autenticacion.md`](07-autenticacion.md)].
  - El enlace debe ser HTTPS y responder a una sintaxis de URL válida.
  - El nombre del curso es obligatorio y debe tener al menos 3 caracteres reales.
  - Se asigna automáticamente `upvotes = 1` y se inserta el voto del autor en `student_group_upvotes`.
  - Se invalida la memoria caché del namespace `student_groups` mediante `CacheService.invalidateAll()`.
- **Accesibilidad:**
  - El diálogo respeta los límites del teclado virtual en pantallas móviles (`viewInsets.bottom`), evitando que el teclado tape los campos de texto inferiores.
  - Indicadores claros de campos obligatorios mediante etiquetas y validación en vivo.
- **Responsive:**
  - Móvil (< 700 px): BottomSheet con bordes superiores redondeados y altura máxima de 90% de pantalla.
  - Desktop (>= 700 px): Diálogo centrado con ancho restringido a 620 px y scroll interno independiente.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante con sesión iniciada que completa todos los campos del grupo para el curso "Álgebra Lineal - Sección C", **When** presiona el botón "Compartir Grupo", **Then** el modal se cierra, el grupo aparece inmediatamente al inicio de la lista y se muestra el SnackBar "Grupo estudiantil compartido con éxito.".
  - **Given** un estudiante que ingresa un enlace sin el protocolo de seguridad obligatorio "http://chat.whatsapp.com/ejemplo", **When** intenta enviar el formulario, **Then** el sistema bloquea el guardado y resalta el campo de enlace con el mensaje "El enlace debe comenzar con https://".

---

### UX-GRP-009 — Acceso externo directo y copia de enlace de invitación
- **Actor / rol:** Visitante, Estudiante registrado, Estudiante verificado, Moderador, Administrador
- **Prioridad:** Must
- **Estado objetivo:** El estudiante puede unirse al grupo externo con un solo toque abriendo la aplicación nativa correspondiente (WhatsApp, Telegram, Discord, Drive o navegador) mediante `url_launcher`, o copiar limpiamente la URL al portapapeles para remitirla a otros compañeros o abrirla en un navegador secundario.
- **Problema actual [Mejora]:** En [`group_card.dart:318-326`](../../comunidad_universitaria/lib/features/groups/widgets/group_card.dart#L318-L326), `UrlUtils.openUrl` abre el enlace externo, pero si el sistema operativo no posee instalada la aplicación nativa (ej. Discord o Telegram) y el enlace utiliza un esquema directo de aplicación, la acción puede fallar silenciosamente sin ofrecer un fallback web transparente (`https://`) o alertar al estudiante sobre cómo proceder.
- **Precondiciones:** El estudiante visualiza una tarjeta de grupo con enlace verificado.
- **UI / contenido:**
  - Botón primario prominente "Unirse al Grupo" estilizado con el color y el icono oficial de la plataforma detectada (ej. verde `#25D366` para WhatsApp, morado `#5865F2` para Discord).
  - Botón secundario contorneado de copia rápida (`IconButton.outlined`, icono `Icons.copy`, tooltip "Copiar enlace").
  - SnackBar de confirmación de copia: "Enlace del grupo copiado al portapapeles" (fondo oscuro neutro, duración 2.5 segundos).
- **Interacciones:**
  - Al pulsar "Unirse al Grupo", el sistema ejecuta el intent nativo con modo `LaunchMode.externalApplication`, transfiriendo el foco a la app correspondiente o al navegador web por defecto.
  - Al pulsar el botón de copia, la URL se copia al portapapeles del dispositivo y se dispara la confirmación en el SnackBar.
- **Estados:**
  - *En reposo:* Botones habilitados y listos para interactuar.
  - *Copiado:* SnackBar visible informando la copia exitosa.
  - *Fallo de apertura:* Diálogo o SnackBar informativo ofreciendo copiar el enlace si no se pudo abrir la aplicación externa.
- **Validaciones y reglas de negocio:**
  - La apertura siempre se realiza en un proceso externo para no interrumpir el estado de la sesión de Comunidad USAC.
  - La acción de unirse y copiar es pública y no requiere inicio de sesión (capacidad abierta según matriz de roles).
- **Accesibilidad:**
  - Etiqueta semántica completa: "Unirse al grupo de [Curso] en [Plataforma]".
  - Botón de copia con descripción adecuada para tecnologías de asistencia.
- **Responsive:**
  - En pantallas móviles con ancho inferior a 360 px, el texto del botón se comprime a "Unirse" para evitar cortes de texto o desbordamientos en la barra de acciones de la tarjeta.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante con la aplicación de WhatsApp instalada en su teléfono móvil, **When** pulsa "Unirse al Grupo" en una tarjeta de WhatsApp, **Then** el teléfono abre directamente WhatsApp en la pantalla de confirmación de ingreso al grupo.
  - **Given** un estudiante que desea enviar el enlace a un compañero por correo u otra vía, **When** presiona el icono de copiar enlace en la tarjeta, **Then** el enlace se almacena en el portapapeles y se muestra el mensaje "Enlace del grupo copiado al portapapeles".

---

### UX-GRP-010 — Aparición patrocinada ocasional en el directorio
- **Actor / rol:** Todos (visible); Patrocinador (origen)
- **Prioridad:** Could
- **Estado objetivo:** el directorio de grupos puede intercalar **tarjetas patrocinadas** con el mismo lenguaje visual que las `GroupCard`, etiquetadas obligatoriamente como **"Patrocinado"** con el acento dorado del sistema ([`UX-SPN-003`](12-patrocinios.md)). Cada aparición enlaza al **perfil público del patrocinador** ([`UX-SPN-001`](12-patrocinios.md)) o a su producto.
- **Problema actual [Mejora]:** hoy no existe ningún formato promovido en Grupos; se introduce respetando el modelo transversal de patrocinios.
- **Precondiciones:** existen promociones aprobadas relevantes a la facultad/carrera activa.
- **UI / contenido:** tarjeta hermana de `GroupCard` con: chip `Patrocinado`, logotipo y nombre del patrocinador con distintivo verificado, una línea descriptiva, categoría, y CTA ("Ver perfil", "Contactar"). Visualmente integrada (mismo radio, borde y sombra) pero con acento dorado sutil.
- **Interacciones:** toque en la tarjeta o el CTA abre el perfil del patrocinador; el resto del directorio permanece igual.
- **Estados:** sin promociones relevantes (no se inserta nada) | cargando (skeleton de tarjeta) | activa | pausada/finalizada (se retira) | sin imagen (fallback de avatar de marca).
- **Validaciones y reglas de negocio:** máximo **1 tarjeta patrocinada por cada 8 grupos orgánicos**, máximo 1 por pantalla/scroll inicial, y solo promociones **aprobadas** ([`UX-SPN-006`](12-patrocinios.md)). Nunca ocupa la primera posición del directorio.
- **Accesibilidad:** etiqueta "Patrocinado" anunciada antes del contenido; CTA con etiqueta completa ("Ver el perfil del patrocinador [Nombre]"); contraste AA.
- **Responsive:** en la cuadrícula de móvil se comporta como una tarjeta más sin romper el grid; en desktop respeta el número de columnas.
- **Criterios de aceptación (Gherkin):**
  - **Given** un directorio con 16 grupos orgánicos y una promoción aprobada para la facultad activa, **When** el usuario recorre la lista, **Then** ve como máximo 2 tarjetas patrocinadas, separadas por al menos 8 grupos y etiquetadas "Patrocinado".
  - **Given** un directorio sin promociones relevantes, **When** se carga, **Then** no aparece ninguna tarjeta patrocinada ni espacio vacío.

### UX-GRP-011 — Enlace ocasional al perfil del patrocinador vinculado al curso
- **Actor / rol:** Todos
- **Prioridad:** Could
- **Estado objetivo:** cuando un patrocinador ofrece un servicio **afín al curso o a la facultad** que el usuario está explorando (p. ej. tutorías, material, impresiones), puede aparecer una **aparición ocasional que enlaza a su perfil**, presentada como recomendación contextual y no como un grupo real. Nunca se mezcla con enlaces de grupos legítimos sin distinción.
- **Problema actual [Mejora]:** se define el vínculo contexto↔patrocinador (p. ej. curso de Cálculo → tutorías de Cálculo) para que la aparición sea relevante y no molesta.
- **Precondiciones:** existe un patrocinador con categoría afín a la facultad/carrera/curso activo.
- **UI / contenido:** banda o tarjeta discreta con texto "¿Buscas apoyo en [curso]? [Nombre] ofrece [servicio]" y botón "Ver perfil". Siempre con etiqueta "Patrocinado".
- **Interacciones:** el botón abre el perfil del patrocinador; se puede ocultar ("No mostrar de [categoría]").
- **Estados:** visible | oculto por preferencia del usuario | sin coincidencias afines (no aparece).
- **Validaciones y reglas de negocio:** solo se muestra si hay afinidad real con el curso/facultad/carrera; no se permite dirigir a un perfil por datos sensibles; el usuario puede ocultar esa categoría ([`UX-SPN-005`](12-patrocinios.md)).
- **Accesibilidad:** se anuncia como recomendación patrocinada; el botón tiene etiqueta descriptiva.
- **Responsive:** banda a ancho completo sobre el grid en móvil; tarjeta lateral o banda en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** un usuario filtrando grupos de "Cálculo I" y un patrocinador de tutorías de Cálculo aprobado, **When** se carga el directorio, **Then** puede aparecer una aparición patrocinada que enlaza a su perfil, etiquetada "Patrocinado".
  - **Given** que el usuario pulsa "No mostrar de Tutorías", **When** vuelve al directorio, **Then** no se muestran apariciones de esa categoría.

### UX-GRP-012 — Frecuencia, transparencia y control en Grupos
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** las apariciones patrocinadas en Grupos respetan la política transversal de frecuencia y no intrusión ([`UX-SPN-004`](12-patrocinios.md)), ofrecen **"¿Por qué veo esto?"**, **"Ocultar"** y **"Reportar"**, y no alteran el orden de los grupos orgánicos.
- **Problema actual [Mejora]:** se formaliza el control y la transparencia para que el directorio siga siendo una herramienta de estudio, no un tablón publicitario.
- **Precondiciones:** directorio con o sin patrocinios.
- **UI / contenido:** menú (⋮) en la tarjeta patrocinada con las tres acciones; hoja/diálogo explicativo breve.
- **Interacciones:** Ocultar retira la aparición y la recuerda; Reportar abre `ReportDialog` ([`UX-GRP-007`](#ux-grp-007--reporte-comunitario-de-enlaces-caídos-llenos-o-indebidos)).
- **Estados:** normal | oculto (recordado) | reportado | promoción retirada.
- **Validaciones y reglas de negocio:** tope de frecuencia duro; el contenido orgánico nunca se reordena; las métricas de patrocinio no contaminan el recuento de grupos.
- **Accesibilidad:** controles con etiquetas accesibles; la etiqueta patrocinada se anuncia primero.
- **Responsive:** menú como hoja inferior en móvil; popover en desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** una tarjeta patrocinada en Grupos, **When** el usuario pulsa "¿Por qué veo esto?", **Then** se explica la afinidad con su facultad/carrera sin exponer datos personales.
  - **Given** que el usuario oculta una aparición patrocinada, **When** recarga el directorio, **Then** esa aparición no vuelve a mostrarse.

---

## 5. Trazabilidad con código y base de datos

| Requisito | Archivo(s) Flutter involucrado(s) | Tabla / RPC / Trigger Supabase | Test automatizado sugerido |
|---|---|---|---|
| **UX-GRP-001** | `lib/features/navigation/app_shell.dart`, `forum_server_rail.dart` | N/A (cascarón de navegación de interfaz) | `test/features/navigation/app_shell_groups_tab_test.dart` |
| **UX-GRP-002** | `lib/features/groups/screens/groups_screen.dart`, `groups_service.dart` | `student_groups` (índices `idx_student_groups_*_trgm`) | `test/features/groups/groups_filter_and_search_test.dart` |
| **UX-GRP-003** | `lib/features/groups/screens/groups_screen.dart`, `local_storage_service.dart` | `SharedPreferences` (`usac_cleanup_notice_dismissed`) | `test/features/groups/cleanup_banner_persistence_test.dart` |
| **UX-GRP-004** | `lib/features/groups/widgets/group_card.dart`, `groups_screen.dart` | `student_groups` (`moderation_status < 2`) | `test/features/groups/group_card_responsive_grid_test.dart` |
| **UX-GRP-005** | `lib/core/models/whatsapp_group.dart`, `group_card.dart` | `student_groups.platform` | `test/core/models/whatsapp_group_platform_detection_test.dart` |
| **UX-GRP-006** | `lib/features/groups/screens/groups_screen.dart`, `groups_service.dart` | `student_group_upvotes`, trigger de recuento en `student_groups.upvotes` | `test/features/groups/groups_upvote_toggle_test.dart` |
| **UX-GRP-007** | `lib/features/groups/widgets/group_card.dart`, `report_dialog.dart` | `entity_reports` (`entity_type = 'group'`), `student_groups.reported_count` | `test/features/groups/report_group_dialog_test.dart` |
| **UX-GRP-008** | `lib/features/groups/widgets/create_group_dialog.dart`, `groups_service.dart` | `student_groups`, `carreras` (FK de catálogo), Supabase Storage bucket | `test/features/groups/create_group_dialog_validation_test.dart` |
| **UX-GRP-009** | `lib/features/groups/widgets/group_card.dart`, `url_utils.dart` | N/A (`url_launcher` y portapapeles del sistema) | `test/features/groups/open_and_copy_group_link_test.dart` |
| **UX-GRP-010** | nuevo `SponsoredGroupCard`, `groups_screen.dart` | tabla de promociones (`sponsored_promotions`, `moderation_status = 1`) | `test/features/groups/sponsored_card_frequency_test.dart` |
| **UX-GRP-011** | nuevo `SponsoredProfileBand`, `groups_screen.dart` | `sponsors` (categoría, facultades afines), `sponsored_promotions` | `test/features/groups/sponsor_affinity_link_test.dart` |
| **UX-GRP-012** | `groups_screen.dart`, `report_dialog.dart`, `local_storage_service.dart` | `sponsored_hides` (preferencia por usuario), `entity_reports` (`entity_type = 'sponsored'`) | `test/features/groups/sponsored_controls_test.dart` |
