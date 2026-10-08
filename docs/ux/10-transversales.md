# 10 — Requisitos Transversales de UX

> Especificación de requisitos de experiencia de usuario transversales (UX-X) para
> la plataforma **Comunidad Universitaria USAC**. Abarca manejo de errores y
> mensajería, estados vacíos, carga con skeletons, funcionamiento sin conexión y
> caché resiliente, notificaciones y snackbars, accesibilidad WCAG 2.2 AA,
> responsividad y adaptación de modales (breakpoints 700px y 1100px),
> internacionalización es-GT, rendimiento percibido y privacidad de datos
> personales. Convenciones, matriz de roles y plantilla en [`README.md`](README.md).

---

## 1. Visión y alcance transversal

Los requisitos contenidos en este documento definen los estándares de calidad y
comportamiento interactivo compartidos por todos los subsistemas funcionales de la
aplicación: Foro Estudiantil ([`03-foro.md`](03-foro.md)), Marketplace y Tutorías
([`04-marketplace.md`](04-marketplace.md)), Directorio de Grupos de Estudio
([`05-grupos.md`](05-grupos.md)), Perfil y Cuenta ([`06-perfil-y-cuenta.md`](06-perfil-y-cuenta.md)),
Autenticación y MFA/SSO ([`07-autenticacion.md`](07-autenticacion.md)), y Cascarón de
Navegación ([`08-navegacion-shell-y-reglas.md`](08-navegacion-shell-y-reglas.md)).

Estos estándares garantizan que un estudiante de la Universidad de San Carlos de
Guatemala experimente consistencia predecible, lenguaje comprensible, accesibilidad
universal y protección inquebrantable de su privacidad académica en cualquier
dispositivo (web de escritorio, tableta, teléfono Android o iOS).

---

## 2. Relación con el inventario de UX (Secciones 6 y 8)

Este documento resuelve sistemáticamente las deficiencias, discrepancias y vacíos
identificados en el levantamiento de código:

1. **Tokens y componentes reutilizables (Inventario 6):**
   - Estandarización de componentes canónicos: `EmptyStateWidget`, `SkeletonCard`,
     `OfflineBanner`, y contenedores responsivos `MaxWidthContainer` y `Responsive`.
   - Adopción estricta de tokens de color de [`09-sistema-diseno.md`](09-sistema-diseno.md)
     cumpliendo contraste accesible en tema claro (`#F8FAFC`) y oscuro (`#0B132B`).
2. **Vacíos y ambigüedades estructurales (Inventario 8):**
   - **8.2 Persistencia del seudónimo:** Garantizar la disociación y sincronización de
     identidad seudónima en la nube sin exponer datos reales ([ver `UX-X-015`]).
   - **8.3 Falsa expectativa en validación de carné:** Reemplazar simulaciones por
     verificación honesta con consentimiento informado riguroso ([ver `UX-X-015`]).
   - **8.5 Ausencia de fallback en servicio de imágenes:** Resiliencia y respaldo
     automático ante caídas de Cloudflare R2 ([ver `UX-X-003`]).
   - **8.7 Falta de temporizador visual en OTP:** Indicadores de espera y control de
     límites de tasa (*Rate Limit*) en pantalla ([ver `UX-X-002`]).
   - **Expiración prematura de caché offline:** Corrección de la purga tras 45 segundos
     en `CacheService`, habilitando lectura desconectada continua ([ver `UX-X-006`]).

---

## 3. Matriz de aplicación transversal por módulo

| Dimensión transversal | Foro | Marketplace | Grupos | Perfil / Cuenta | Auth / MFA | SSO |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Manejo de errores** (`UX-X-001`, `002`, `003`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Estados vacíos** (`UX-X-004`) | ✅ | ✅ | ✅ | ✅ | N/A | N/A |
| **Carga con skeletons** (`UX-X-005`) | ✅ | ✅ | ✅ | ✅ | N/A | N/A |
| **Modo offline y caché** (`UX-X-006`) | ✅ | ✅ | ✅ | Parcial | N/A | N/A |
| **Notificaciones / Snackbars** (`UX-X-007`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Accesibilidad WCAG 2.2 AA** (`UX-X-008`, `009`, `010`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Responsividad y modales** (`UX-X-011`, `012`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Internacionalización es-GT** (`UX-X-013`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Rendimiento percibido** (`UX-X-014`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Privacidad de datos** (`UX-X-015`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 4. Requisitos transversales de UX (prefijo UX-X)

### UX-X-001 — Taxonomía y presentación de errores amigables al usuario
- **Actor / rol:** Todos (Visitante, Estudiante Registrado, Estudiante Verificado, Moderador, Administrador)
- **Prioridad:** Must
- **Estado objetivo:** La aplicación intercepta cualquier fallo técnico (red, base de datos, validación, autenticación o permisos) y lo presenta al usuario traducido a una taxonomía comprensible en español (`es-GT`). Queda estrictamente prohibido desplegar trazas crudas, excepciones (`AuthException`, `PostgrestException`, `SocketException`), códigos HTTP aislados (ej. "Error 500") o textos en inglés. Cada mensaje de error debe explicar qué ocurrió y brindar una acción de recuperación concreta ("Reintentar", "Revisar datos", "Comprobar conexión").
- **Problema actual [Mejora]:** En [`auth_modal.dart:150-173`](../../comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart#L150-L173), [`url_utils.dart:26-34`](../../comunidad_universitaria/lib/core/utils/url_utils.dart#L26-L34) y [`totp_enrollment_screen.dart:183-211`](../../comunidad_universitaria/lib/features/profile/screens/totp_enrollment_screen.dart#L183-L211), cuando una excepción no coincide con los patrones previstos, el código retorna el mensaje crudo del backend o muestra cadenas de error genéricas sin orientación de solución.
- **Precondiciones:** Ocurre una excepción controlada o no controlada durante una operación asíncrona o validación de formulario.
- **UI / contenido:**
  - Contenedor con borde redondeado (10px), fondo suave de advertencia/error (`#FEF2F2` en tema claro, `#451A1A` en tema oscuro) y borde de acento sutil (`#EF4444`).
  - Icono semántico a la izquierda (`Icons.error_outline` o `Icons.wifi_off`, 20px) contrastado.
  - Título en negrita (`titleMedium` o `bodyMedium` negrita): "No pudimos completar tu solicitud".
  - Descripción en `bodySmall`: texto empático redactado en español explicando el problema sin tecnicismos.
  - Botón de acción reparadora si procede ("Reintentar", "Cerrar", "Verificar credenciales").
- **Interacciones:**
  - Si el error es transitorio de red: pulsar "Reintentar" dispara nuevamente la llamada fallida sin recargar la pantalla completa.
  - Si el error es de formulario: se resalta visualmente el campo afectado y el foco se desplaza automáticamente al primer control inválido.
- **Estados:**
  - *Inicial:* Sin avisos de error.
  - *Error en línea:* Banner bajo el control afectado o snackbar flotante según la gravedad.
  - *Error bloqueante:* Diálogo modal con acción única de reintento o retorno seguro.
- **Validaciones y reglas de negocio:**
  - Mapeo unificado obligatorio:
    - Falla de conexión DNS / Socket -> "No tienes conexión a internet. Revisa tu red y vuelve a intentarlo."
    - Error 401 / Credenciales incorrectas -> "Correo o contraseña incorrectos. Por favor verifica tus datos."
    - Error 403 / Permisos denegados por RLS -> "No tienes permisos para realizar esta acción."
    - Error 404 / Recurso no encontrado -> "El contenido solicitado ya no está disponible o fue eliminado."
    - Error 429 / Rate Limit -> "Has realizado demasiados intentos. Por favor espera unos momentos antes de continuar."
    - Error 500 / Falla interna del servidor -> "Ocurrió un problema en nuestros servidores. Estamos trabajando para resolverlo."
- **Accesibilidad:** Anuncio automático a lectores de pantalla mediante `Semantics(liveRegion: true)`. El texto de error debe cumplir ratio de contraste ≥ 4.5:1 respecto a su fondo.
- **Responsive:** En móvil se adapta a ancho completo dentro del contenedor de formulario; en tablet y desktop mantiene ancho acotado de lectura.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante enviando un formulario con la red interrumpida, **When** la petición falla por `SocketException`, **Then** la app muestra el mensaje "No tienes conexión a internet. Revisa tu red y vuelve a intentarlo" junto a un botón "Reintentar", sin exponer trazas de depuración ni códigos internos.
  - **Given** un usuario que ingresa una contraseña errónea en el inicio de sesión, **When** el servidor responde error de autenticación, **Then** se despliega el mensaje formativo "Correo o contraseña incorrectos. Por favor verifica tus datos" y el foco visual se coloca en el campo de contraseña.

---

### UX-X-002 — Manejo de límites de tasa (rate limiting) y temporizadores visuales de reintento
- **Actor / rol:** Todos (Visitante, Estudiante Registrado)
- **Prioridad:** Must
- **Estado objetivo:** Todo mecanismo sensible a límites de tasa (*rate limits*) de seguridad (reenvío de códigos OTP de correo, reenvío de códigos de restablecimiento de contraseña, emisión de factores TOTP y publicaciones de contenido de alta frecuencia) debe incluir un temporizador visual descendente (*countdown*) que desactive el botón de acción durante el periodo de enfriamiento (cooldown de 60 segundos por defecto), evitando pulsaciones repetitivas accidentales y bloqueos de cuenta.
- **Problema actual [Mejora]:** En [`auth_modal.dart:575-587`](../../comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart#L575-L587) e Inventario 8.7, el botón "Reenviar código" no muestra una cuenta regresiva visible de 60 segundos tras presionarlo; al pulsarlo repetidamente, Supabase bloquea al usuario por límite de peticiones con un mensaje genérico.
- **Precondiciones:** El usuario solicita el despacho de un código OTP o dispara una acción sujeta a límite de frecuencia.
- **UI / contenido:**
  - Botón secundario o de texto (`TextButton` / `OutlinedButton`).
  - Durante el enfriamiento: etiqueta dinámica con tiempo restante en segundos, por ejemplo: `"Reenviar código (54s)"`.
  - Icono sutil de reloj de arena o temporizador circular a escala reducida (14px).
  - Estado visual deshabilitado (opacidad 0.5, sin efecto de clic).
- **Interacciones:**
  - Al pulsar la acción inicial de envío, el botón entra inmediatamente en enfriamiento.
  - El temporizador decrementa cada segundo exacto.
  - Al alcanzar `0s`, el botón recupera su interactividad plena, cambiando la etiqueta a `"Reenviar código"` y emitiendo una animación sutil de activación.
  - Si el backend devuelve de todos modos una respuesta HTTP 429 con cabecera `Retry-After`, el contador se ajusta inmediatamente al tiempo estipulado por el servidor.
- **Estados:**
  - *Activo:* Botón habilitado para solicitar código.
  - *Enfriamiento:* Contador decreciente visible, control bloqueado.
  - *Restablecido:* Vuelve al estado inicial listo para interacción.
- **Validaciones y reglas de negocio:**
  - Duración estándar de enfriamiento en cliente: 60 segundos tras cada reenvío.
  - Si el usuario cierra el modal y lo vuelve a abrir dentro de los 60 segundos, el tiempo restante debe conservarse en memoria para no reiniciar el enfriamiento a cero.
- **Accesibilidad:** Los lectores de pantalla deben anunciar el cambio de estado al completarse la cuenta regresiva ("Ya puedes volver a solicitar el código"). Durante el conteo, no debe saturar al lector cada segundo; solo se anuncia el inicio y la habilitación final.
- **Responsive:** Etiqueta concisa para evitar que el texto desborde en pantallas angostas (< 360px).
- **Criterios de aceptación (Gherkin):**
  - **Given** que el usuario presiona "Reenviar código" en la pantalla de verificación OTP, **When** el código es despachado con éxito, **Then** el botón queda deshabilitado mostrando "Reenviar código (60s)" y disminuye segundo a segundo hasta rehabilitarse al llegar a cero.
  - **Given** que el usuario intenta forzar una petición y el backend retorna un código HTTP 429 de límite de tasa, **When** la respuesta es procesada, **Then** la app presenta un mensaje formativo indicando cuántos segundos debe esperar sin desloguear ni reiniciar el formulario.

---

### UX-X-003 — Resiliencia y fallback en carga y visualización de multimedia
- **Actor / rol:** Estudiante Registrado, Estudiante Verificado, Moderador, Administrador
- **Prioridad:** Must
- **Estado objetivo:** La subida y visualización de fotografías (Marketplace, Foro, Avatares) cuenta con un mecanismo de resiliencia automática: si el servicio primario de almacenamiento (Cloudflare R2 Worker) experimenta fallas, saturación de cuota o bloqueos de red en el campus, el cliente conmuta de forma transparente a un almacenamiento secundario (Supabase Storage). Si la imagen remota no puede cargarse en los feeds, la UI despliega un placeholder accesible con la misma relación de aspecto, impidiendo cuadros rotos o huecos blancos.
- **Problema actual [Mejora]:** En [`storage_service.dart:16-107`](../../comunidad_universitaria/lib/core/services/storage_service.dart#L16-L107), [`create_listing_dialog.dart:154-171`](../../comunidad_universitaria/lib/features/marketplace/widgets/create_listing_dialog.dart#L154-L171) e Inventario 8.5, la carga fotográfica se realiza exclusivamente contra un Cloudflare Worker personal (`workers.dev`); ante un fallo de red retorna `null` silenciosamente y el diálogo muestra un error genérico sin intentar un fallback a los buckets nativos de Supabase ni explicar la causa.
- **Precondiciones:** El estudiante adjunta una imagen JPG, PNG o WebP desde su galería o cámara en diálogos de publicación.
- **UI / contenido:**
  - Durante la subida: Barra de progreso lineal sutil o spinner con texto `"Procesando imagen..."`.
  - En caso de reintento automático: texto informativo `"Reintentando con servidor de respaldo..."`.
  - En tarjetas de visualización con error de carga: Caja contenedora con color de superficie sutil (`surfaceSubtle`), icono `Icons.broken_image_outlined` y texto discreto `"No fue posible cargar la imagen"`.
- **Interacciones:**
  - El usuario selecciona la imagen; la app valida previamente tamaño (máximo 5 MB) y formato.
  - Si el worker primario no responde en 5 segundos, la app ejecuta automáticamente la subida mediante Supabase Storage.
  - Si ambos fallan, el diálogo no borra el texto redactado por el alumno; muestra un diálogo o banner con botón `"Reintentar subida"` o `"Publicar sin imagen"`.
- **Estados:**
  - *Seleccionada:* Vista previa miniatura con botón de eliminar (`Icons.close`).
  - *Subiendo:* Indicador de progreso.
  - *Fallback activo:* Reintento transparente secundario.
  - *Error final:* Notificación explicativa sin pérdida de datos del formulario.
- **Validaciones y reglas de negocio:**
  - Validación en cliente: tamaño máximo de imagen 5 MB; compresión visual recomendada previa al envío a 1280px de ancho máximo para ahorrar datos móviles.
  - Persistencia de URL válida garantizada antes de completar el insert en base de datos.
- **Accesibilidad:** Toda imagen cargada incluye etiqueta semántica de accesibilidad alternativa (`Semantics(image: true, label: "Fotografía de [título]")`).
- **Responsive:** Dimensionamiento proporcional preservando aspect ratio 16:9 en marketplace y 4:3 en foro en cualquier resolución.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante publicando un artículo en Marketplace cuando el worker de Cloudflare R2 no está disponible, **When** presiona "Publicar Anuncio", **Then** el sistema transfiere la subida a Supabase Storage de manera transparente y publica el anuncio con la URL alternativa sin interrumpir al usuario.
  - **Given** una publicación en el feed cuya URL de imagen devuelve error HTTP 404, **When** la tarjeta se dibuja en pantalla, **Then** se renderiza un placeholder con icono neutro y relación de aspecto fija, impidiendo desbordamientos visuales o espacios en blanco deformes.

---

### UX-X-004 — Patrón unificado de estados vacíos contextuales y accionables
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** Toda pantalla, pestaña, feed o lista de resultados que carezca de datos para mostrar despliega el componente canónico de **Estado Vacío** (`EmptyStateWidget`), personalizado contextualmente con: (1) Icono o ilustración temática alusiva, (2) Título empático, (3) Explicación clara del motivo de la ausencia de contenido, y (4) Al menos una llamada a la acción (*Call to Action* / CTA) afirmativa y directa que guíe al estudiante sobre qué hacer a continuación.
- **Problema actual [Mejora]:** En [`empty_state_widget.dart:3-72`](../../comunidad_universitaria/lib/features/shared/widgets/empty_state_widget.dart#L3-L72) y [`forum_screen.dart:882-895`](../../comunidad_universitaria/lib/features/forum/screens/forum_screen.dart#L882-L895), los estados vacíos actuales son planos, utilizan iconos genéricos y no diferencian si la lista está vacía por falta de publicaciones, por un filtro de búsqueda sin coincidencias, o por no haber iniciado sesión en `# mis-guardados`.
- **Precondiciones:** Una consulta a la base de datos o filtro en cliente devuelve 0 elementos.
- **UI / contenido:**
  - Contenedor centrado vertical y horizontalmente con padding de 32dp.
  - Icono temático circular con contenedor traslúcido (fondo `primary` al 8%, icono de 48px).
  - Título en `titleMedium` negrita (18–20px).
  - Descripción en `bodyMedium` (máximo 380px de ancho para óptima legibilidad).
  - Botón de acción primario con icono (`ElevatedButton.icon`).
- **Casos contextuales canónicos:**
  1. *Canal de foro sin temas:* Icono `Icons.forum_outlined` + `"Aún no hay publicaciones en este canal"` + `"Sé la primera persona en compartir una duda o aporte académico."` + Botón `"Crear primera publicación"`.
  2. *Filtro o búsqueda sin resultados:* Icono `Icons.search_off` + `"No encontramos resultados para tu búsqueda"` + `"Intenta cambiar las palabras clave o restablecer los filtros."` + Botón `"Limpiar filtros"`.
  3. *Marketplace sin productos:* Icono `Icons.storefront_outlined` + `"No hay artículos disponibles en esta categoría"` + `"¿Tienes libros, apuntes o comida para ofrecer a tus compañeros?"` + Botón `"Publicar un producto"`.
  4. *Directorio de grupos vacío:* Icono `Icons.groups_outlined` + `"No hay grupos registrados para este curso"` + `"Comparte el enlace de WhatsApp o Discord de tu sección."` + Botón `"Compartir grupo"`.
  5. *Publicaciones guardadas sin sesión:* Icono `Icons.bookmark_border` + `"Inicia sesión para guardar publicaciones"` + `"Tus temas guardados se sincronizarán aquí para consulta rápida."` + Botón `"Iniciar sesión"`.
- **Interacciones:**
  - Al pulsar el botón CTA, la app ejecuta directamente la acción de recuperación: abre el diálogo de creación respectivo, limpia el campo de búsqueda o lanza `AuthModal`.
- **Estados:**
  - *Vacío puro:* Canal o sección virgen.
  - *Vacío por filtrado:* Resultado nulo tras búsqueda de usuario (ofrece limpiar filtro).
  - *Vacío por permisos/sesión:* Requiere inicio de sesión.
- **Validaciones y reglas de negocio:**
  - El botón CTA debe respetar la matriz de roles: si un visitante pulsa "Crear primera publicación", se le intercepta con `AuthModal` y tras autenticarse se abre el creador.
- **Accesibilidad:** El contenido del estado vacío debe tener foco programático accesible y ser leído como un bloque coherente por lectores de pantalla.
- **Responsive:** Escala tipográfica y de padding adecuada en pantallas pequeñas; centrado estricto en desktop dentro de `MaxWidthContainer`.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que busca "Cálculo 4" en una facultad donde no existen coincidencias, **When** se actualiza la lista, **Then** se despliega el estado vacío con icono de búsqueda, el mensaje "No encontramos resultados para tu búsqueda" y el botón "Limpiar filtros", cuyo toque restablece el listado original.
  - **Given** un canal temático nuevo en el foro estudiantil sin entradas, **When** el usuario navega a dicho canal, **Then** ve la invitación a inaugurar la conversación con un botón directo a "Crear primera publicación".

---

### UX-X-005 — Carga progresiva con skeletons adaptativos y prevención de salto de contenido (CLS)
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** La experiencia de carga inicial y transición de pantalla utiliza maquetas esqueléticas animadas (*Skeletons*) que replican de manera fidedigna la geometría, espaciado y proporciones de las tarjetas y listas reales, evitando el parpadeo de interfaces en blanco y eliminando el salto acumulativo de diseño (*Cumulative Layout Shift* - CLS).
- **Problema actual [Mejora]:** En [`network_state_widgets.dart:3-92`](../../comunidad_universitaria/lib/features/shared/widgets/network_state_widgets.dart#L3-L92), el componente `SkeletonCard` consiste en un contenedor estático con colores duros sin animación de brillo (*shimmer*), y posee una única estructura que no refleja la cuadrícula de tarjetas de marketplace (`marketplace_card.dart`), ni las filas de grupos (`group_card.dart`), ni los comentarios anidados (`comment_item.dart`).
- **Precondiciones:** Una pantalla o feed solicita datos asíncronos y aún no cuenta con una versión en caché para mostrar.
- **UI / contenido:**
  - Animación suave de barrido degradado (*shimmer*) con ciclo de 1500 ms de izquierda a derecha.
  - Tokens de color: base `#E2E8F0` y brillo `#F1F5F9` en tema claro; base `#1E293B` y brillo `#334155` en tema oscuro.
  - Tres variantes especializadas de esqueletos:
    1. *Skeleton de Post de Foro:* Avatar circular (32px), dos líneas de metadatos (autor y tiempo), barra de título (alto 16px) y dos barras de cuerpo de texto.
    2. *Skeleton de Tarjeta de Marketplace:* Caja de imagen con relación de aspecto 16:9, etiqueta de precio en esquina superior, título y botones de contacto inferiores.
    3. *Skeleton de Grupo de Estudio:* Tarjeta con cabecera de curso, sección y pastilla de plataforma (WhatsApp/Telegram).
- **Interacciones:**
  - El skeleton se muestra inmediatamente (< 50 ms) tras solicitar los datos.
  - Al completar la carga de red, se efectúa un desvanecimiento cruzado (*cross-fade*) de 200 ms hacia el contenido real, manteniendo fija la posición de scroll.
- **Estados:**
  - *Cargando:* Se despliegan entre 3 y 6 tarjetas esqueléticas para llenar el viewport del dispositivo.
  - *Completado:* Reemplazo suave por la lista real de datos.
- **Validaciones y reglas de negocio:**
  - Si la conexión tarda más de 8 segundos, el skeleton permanece pero se despliega un aviso inferior discreto: "La conexión está lenta. Seguimos cargando...".
- **Accesibilidad:** Si el sistema operativo tiene activada la preferencia de accesibilidad de **"Reducir movimiento"** (`MediaQuery.disableAnimations` o `reducedMotion`), la animación de shimmer se desactiva por completo, mostrando un color plano estático accesible.
- **Responsive:** El skeleton de marketplace se organiza en 1 columna en móvil, 2 en tablet y 3-4 en desktop, replicando exactamente la rejilla receptora.
- **Criterios de aceptación (Gherkin):**
  - **Given** una apertura inicial del catálogo de Marketplace en una pantalla de escritorio (≥ 1100px), **When** se inicia la petición de datos, **Then** se renderiza una cuadrícula de esqueletos con tarjetas de aspecto 16:9 distribuidas en 3 columnas idénticas a las tarjetas definitivas.
  - **Given** un dispositivo con la opción de accesibilidad "Reducir movimiento" habilitada, **When** se visualiza un estado de carga, **Then** el skeleton se dibuja con tonos estáticos sin ningún efecto de barrido animado.

---

### UX-X-006 — Modo sin conexión y persistencia resiliente con Stale-While-Revalidate
- **Actor / rol:** Todos (Visitante, Estudiante Registrado, Estudiante Verificado)
- **Prioridad:** Must
- **Estado objetivo:** La plataforma implementa la estrategia de caché **Stale-While-Revalidate** para permitir la lectura continua de contenidos académicos sin conexión a internet (en pasillos, sótanos o áreas de baja cobertura del campus universitario). Los datos guardados localmente nunca se destruyen por vencimiento de un temporizador corto; se presentan al usuario como datos en caché acompañados del banner no intrusivo `OfflineBanner`. Las acciones que requieren conectividad para escritura informan amigablemente la restricción y protegen los borradores.
- **Problema actual [Mejora]:** En [`cache_service.dart:109-111`](../../comunidad_universitaria/lib/core/services/cache_service.dart#L109-L111) y [`network_state_widgets.dart:94-156`](../../comunidad_universitaria/lib/features/shared/widgets/network_state_widgets.dart#L94-L156), el método `getPersisted` borra y devuelve `null` si han pasado más de 45 segundos desde la captura (`difference > ttlMs return null`), dejando la aplicación vacía y deshabilitada en situaciones reales de desconexión en el campus.
- **Precondiciones:** El estudiante ha navegado previamente por la aplicación y el dispositivo pierde la conectividad a internet.
- **UI / contenido:**
  - Componente `OfflineBanner` anclado bajo la barra superior (AppBar):
    - Color de fondo: `#FEF3C7` (tema claro) / `#451A03` (tema oscuro); borde inferior ámbar `#F59E0B`.
    - Icono `Icons.wifi_off` (16px) en color ámbar oscuro (`#B45309` / `#FBBF24`).
    - Texto explicativo: `"Sin conexión. Mostrando contenido en caché."`
    - Botón de acción `"Reintentar"` con tamaño táctil accesible (mínimo 48×48 dp).
  - Indicador de antigüedad sutil en cabecera de feed: `"Guardado hoy a las 11:20 am"`.
- **Interacciones:**
  - Al abrir un canal o catálogo sin red, el sistema recupera inmediatamente la última copia persistida en almacenamiento local, sin importar si fue guardada hace minutos o días.
  - Al pulsar `"Reintentar"`, la app verifica conectividad y refresca los datos si la red volvió.
  - Al intentar una acción de escritura (crear post, enviar comentario, votar o publicar en marketplace), se despliega un diálogo o snackbar: `"Esta acción requiere conexión a internet. Conéctate a una red e inténtalo de nuevo."` El formulario activo y el texto escrito se preservan intactos en el diálogo o borrador local sin cerrarse.
- **Estados:**
  - *En línea:* Comportamiento ordinario; actualización silenciosa de caché.
  - *Sin conexión con caché:* Visualización de datos locales con `OfflineBanner`.
  - *Sin conexión sin caché previa:* Estado vacío amigable indicando falta de conexión con botón "Reintentar".
- **Validaciones y reglas de negocio:**
  - La caché persistida almacena hasta 50 elementos por canal temático y catálogo.
  - Los datos locales se consideran "stale" para lectura offline indefinida hasta que una nueva sincronización en línea los actualice.
- **Accesibilidad:** El banner offline se anuncia al lector de pantalla una sola vez al detectarse la pérdida de conexión.
- **Responsive:** Ancho completo de pantalla, ajustando el texto y botón en una sola línea en tablet/desktop o apilado compacto en móvil pequeño.
- **Criterios de aceptación (Gherkin):**
  - **Given** que un estudiante cargó el foro hace 40 minutos y entra al sótano del edificio S-12 sin cobertura celular, **When** abre la app, **Then** visualiza las publicaciones previas acompañadas del `OfflineBanner` con texto "Sin conexión. Mostrando contenido en caché.", sin pantallas en blanco ni errores.
  - **Given** un estudiante redactando un tema en el foro mientras pierde la conexión, **When** pulsa "Publicar", **Then** la app emite una advertencia indicando la falta de red y conserva el título y contenido intactos en el diálogo para no perder el avance.

---

### UX-X-007 — Sistema estandarizado de notificaciones flotantes y snackbars
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** Toda notificación efímera del sistema se gestiona a través de un servicio unificado de retroalimentación (`AppFeedback`) que emite snackbars con diseño flotante (`SnackBarBehavior.floating`), respetando las zonas de navegación (por encima de la `NavigationBar` y del botón flotante FAB), con duraciones estandarizadas, iconos semánticos según 4 niveles de severidad (Éxito, Información, Advertencia, Error) y opción de acción de deshacer (*Undo*) en operaciones destructivas.
- **Problema actual [Mejora]:** En [`url_utils.dart:26-53`](../../comunidad_universitaria/lib/core/utils/url_utils.dart#L26-L53), [`marketplace_screen.dart:526-565`](../../comunidad_universitaria/lib/features/marketplace/screens/marketplace_screen.dart#L526-L565) y [`profile_screen.dart:193-289`](../../comunidad_universitaria/lib/features/profile/screens/profile_screen.dart#L193-L289), los `SnackBar` se instancian de manera dispersa, con colores quemados (`Colors.red.shade700`), algunos fijos al borde inferior tapando la navegación y sin consistencia en esquinas redondeadas o acciones.
- **Precondiciones:** Una acción del usuario o evento del sistema requiere confirmar un resultado o alertar sobre un estado no crítico.
- **UI / contenido:**
  - Diseño flotante (`behavior: SnackBarBehavior.floating`) con margen lateral de 16dp y margen inferior adaptativo (mínimo 80dp en móvil para no tapar la barra inferior ni el FAB).
  - Geometría: Bordes redondeados de 10px.
  - Icono semántico a la izquierda (18px) + Texto descriptivo en `bodyMedium` + Botón opcional de acción a la derecha.
  - 4 niveles de severidad estandarizados:
    1. *Éxito:* Fondo `#065F46` (oscuro) / `#ECFDF5` (claro), icono `Icons.check_circle_outline`, duración 3.5 segundos.
    2. *Información:* Fondo `#1E3A8A` (oscuro) / `#EFF6FF` (claro), icono `Icons.info_outline`, duración 4 segundos.
    3. *Advertencia:* Fondo `#78350F` (oscuro) / `#FFFBEB` (claro), icono `Icons.warning_amber_outlined`, duración 5 segundos.
    4. *Error:* Fondo `#7F1D1D` (oscuro) / `#FEF2F2` (claro), icono `Icons.error_outline`, duración 5 segundos con botón "Reintentar" o "Entendido".
- **Interacciones:**
  - Si la acción fue destructiva (eliminar una publicación o retirar un anuncio), se incluye el botón de texto `"Deshacer"`. Si el usuario pulsa `"Deshacer"` dentro del tiempo límite, la eliminación se aborta inmediatamente.
  - Se puede descartar deslizando horizontalmente (*swipe to dismiss*).
- **Estados:**
  - *Aparición:* Animación suave de elevación.
  - *Visible:* Tiempo de lectura proporcional al contenido.
  - *Descarte:* Desvanecimiento o salida lateral.
- **Validaciones y reglas de negocio:**
  - Cola de mensajes secuencial: no deben amontonarse múltiples snackbars simultáneamente; se encolan con descarte del previo si es de menor prioridad.
- **Accesibilidad:** Todo snackbar debe anunciarse inmediatamente mediante lectores de pantalla (`assertive` para errores, `polite` para éxitos). Contraste de texto ≥ 4.5:1 garantizado en ambas paletas.
- **Responsive:** Ancho máximo acotado a 480dp centrado en tablet y desktop; en móvil ocupa el ancho de la pantalla respetando márgenes laterales de 16dp.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante que elimina un post propio desde su perfil, **When** la operación se confirma, **Then** se muestra un snackbar flotante con el texto "Publicación eliminada" y un botón "Deshacer" disponible durante 5 segundos antes de consumar el borrado en la nube.
  - **Given** un usuario navegando en móvil con la barra inferior activa, **When** se dispara un mensaje de confirmación, **Then** el snackbar se ubica flotando por encima de la barra inferior de navegación y del FAB, garantizando la visibilidad total de los controles.

---

### UX-X-008 — Accesibilidad visual y contraste cromático WCAG 2.2 AA
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** Todas las pantallas, tarjetas, componentes, iconos y tipografías de la plataforma cumplen estrictamente con los criterios de éxito de **WCAG 2.2 Nivel AA** tanto en el **Modo Claro** como en el **Modo Oscuro**:
  - Relación de contraste mínima de **4.5:1** para texto normal (< 18pt o < 14pt negrita) respecto a su superficie de fondo.
  - Relación de contraste mínima de **3.0:1** para texto grande (≥ 18pt o ≥ 14pt negrita) y componentes gráficos interactivos (bordes de campos, iconos de acción y chips).
  - Queda prohibido transmitir información de estado (error, éxito, validación o estado de producto "VENDIDO") dependiendo exclusivamente del color; todo estado debe estar respaldado por iconografía semántica y texto legible.
- **Problema actual [Mejora]:** En [`app_theme.dart:15-120`](../../comunidad_universitaria/lib/core/config/app_theme.dart#L15-L120) y [`09-sistema-diseno.md:14-31`](09-sistema-diseno.md#11-tokens-de-color), algunos textos secundarios en modo oscuro sobre fondos de tarjeta `#1C2541` y badges sobre fondos de acento se encuentran al límite del ratio 4.5:1, requiriendo verificación matemática estricta y ajuste de tokens.
- **Precondiciones:** Cualquier pantalla renderizada bajo cualquiera de los dos temas visuales disponibles.
- **UI / contenido:**
  - *Tema Claro:* Fondo `#F8FAFC`, superficie `#FFFFFF`, texto primario `#0F172A` (ratio > 13:1), texto secundario `#475569` (ajustado para garantizar ratio > 4.8:1 contra blanco).
  - *Tema Oscuro:* Fondo `#0B132B`, superficie `#1C2541`, texto primario `#F8FAFC` (ratio > 12:1), texto secundario `#94A3B8` (ratio > 5.1:1 contra `#1C2541`).
  - Distintivo institucional "VENDIDO": Etiqueta con borde contrastado, fondo rojo traslúcido, icono de candado o bloqueo y texto en negrita, garantizando legibilidad total.
  - Insignia de verificación: Icono verde `Icons.verified` acompañado del texto `"Verificado con carné"`.
- **Interacciones:**
  - Al cambiar de tema claro a oscuro desde el conmutador del AppBar o Perfil, todos los elementos actualizan sus tokens sin requerir reinicio de la aplicación y preservando los ratios de contraste.
- **Estados:**
  - Tema Claro activo.
  - Tema Oscuro activo.
- **Validaciones y reglas de negocio:**
  - Toda nueva paleta o componente agregado al repositorio debe validarse contra una herramienta de auditoría de contraste WCAG AA antes de incorporarse.
- **Accesibilidad:** Soporta modo de alto contraste del sistema operativo incrementando los bordes a 2px sólidos si el usuario lo tiene configurado en su dispositivo.
- **Responsive:** Consistente en todas las densidades de pantalla (mdpi, hdpi, xhdpi, retina web).
- **Criterios de aceptación (Gherkin):**
  - **Given** la app configurada en Modo Oscuro, **When** se analizan los metadatos secundarios (fecha y canal) de una tarjeta de publicación sobre fondo `#1C2541`, **Then** el color del texto mantiene una relación de contraste no menor a 4.5:1.
  - **Given** una tarjeta de un producto marcado como "Vendido" en Marketplace, **When** se presenta en pantalla, **Then** el estado se expresa simultáneamente mediante un badge textual con fondo contrastado, un icono de venta concretada y la marca de agua, sin depender únicamente de un matiz rojizo.

---

### UX-X-009 — Foco visible, navegación completa por teclado y soporte de lectores de pantalla
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** La aplicación es 100% operable mediante teclado físico y tecnologías asistenciales de lectura de pantalla (TalkBack en Android, VoiceOver en iOS/macOS, NVDA y JAWS en Windows/Web):
  - Todos los controles interactivos exhiben un indicador de foco visible (*Focus Ring*) de al menos 2px de grosor con alto contraste al ser enfocados por teclado.
  - Orden de tabulación lógico y continuo (de izquierda a derecha y de arriba hacia abajo).
  - Trampa de foco (*Focus Trap*) rigurosa en modales y hojas inferiores: el foco se confina a los controles del modal y retorna al botón disparador al cerrarse.
  - Tecla `Escape` cierra sistemáticamente cualquier modal, diálogo, menú contextual o visor de imágenes a pantalla completa.
  - Todos los botones de icono declaran etiquetas semánticas descriptivas (`tooltip` y `Semantics(label: ..., button: true)`).
- **Problema actual [Mejora]:** En [`auth_modal.dart:23-57`](../../comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart#L23-L57) e [`image_viewer_dialog.dart:20-55`](../../comunidad_universitaria/lib/features/shared/widgets/image_viewer_dialog.dart#L20-L55), los diálogos no atrapan el foco del teclado en web/desktop, permitiendo que la tecla `Tab` navegue a controles ocultos detrás del telón de fondo semitransparente (*backdrop*), desorientando a personas usuarias de lectores de pantalla.
- **Precondiciones:** El usuario navega utilizando la tecla `Tab`, flechas de dirección y `Enter` / `Espacio`, o utiliza un lector de pantalla asistencial activo.
- **UI / contenido:**
  - Anillo de enfoque (*Focus outline*): borde de 2px de color `accent` (`#2563EB`) con halo de separación (*offset*) de 2px.
  - Etiquetas de accesibilidad transparentes en lectores:
    - Botón de Like: `"Me gusta, 24 votos, botón"`.
    - Botón de Guardar: `"Guardar publicación en mis marcadores, botón"`.
    - Selector de Carrera: `"Explorar carreras de la facultad, menú desplegable"`.
    - Botón de WhatsApp: `"Contactar al vendedor por WhatsApp, abre enlace externo"`.
- **Interacciones:**
  - Presionar `Tab` avanza secuencialmente por los elementos interactivos.
  - Presionar `Shift + Tab` retrocede al control previo.
  - Presionar `Enter` o `Espacio` activa el botón o enlace enfocado.
  - Presionar `Escape` en cualquier diálogo abierto lo descarta inmediatamente y devuelve el foco visual al elemento disparador.
- **Estados:**
  - *Enfocado:* Anillo visible de alta visibilidad.
  - *Activo/Pulsado:* Feedback táctil o de ripple.
  - *Desenfocado:* Aspecto habitual.
- **Validaciones y reglas de negocio:**
  - Al abrir un modal, el foco se coloca automáticamente en el primer campo de texto o en el botón de cierre si no hay campos editables.
- **Accesibilidad:** Cumple WCAG 2.2 Criterios 2.1.1 (Teclado), 2.1.2 (Sin trampa de teclado), 2.4.3 (Orden de foco) y 2.4.7 (Foco visible).
- **Responsive:** Idéntica operatividad por teclado tanto en clientes Web como en ejecutables Desktop (Linux x64, Windows, macOS).
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante navegando en web mediante teclado físico que abre el diálogo de creación de publicaciones, **When** presiona sucesivamente la tecla `Tab`, **Then** el foco se mantiene estrictamente dentro de los campos y botones del diálogo sin saltar al contenido del fondo, y al pulsar `Escape` el diálogo se cierra devolviendo el foco al botón disparador.
  - **Given** una persona utilizando lector de pantalla TalkBack que explora una tarjeta de Marketplace, **When** el cursor táctil se sitúa sobre el botón de contacto de WhatsApp, **Then** el sintetizador anuncia "Contactar al vendedor por WhatsApp, abre aplicación externa, botón".

---

### UX-X-010 — Tamaño de objetivo táctil y ergonomía móvil
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** Todo componente interactivo en pantallas móviles y táctiles (botones, iconos de acción, casillas de verificación, chips de filtrado, elementos de listas y enlaces) garantiza un área de toque efectiva mínima de **48 × 48 dp**, superando el criterio de éxito WCAG 2.2 Target Size (Mínimo 24×24 px, recomendado 44–48 dp) y alineándose con las especificaciones de ergonomía de Material 3.
- **Problema actual [Mejora]:** En [`post_card.dart:120-160`](../../comunidad_universitaria/lib/features/forum/widgets/post_card.dart#L120-L160) y [`group_card.dart:200-240`](../../comunidad_universitaria/lib/features/groups/widgets/group_card.dart#L200-L240), varios botones de icono secundarios (como el icono de reporte de 16px o el contador de votos) cuentan con áreas de toque inferiores a 36dp, provocando toques erráticos o pulsaciones accidentales en pantallas de teléfonos de dimensiones reducidas.
- **Precondiciones:** Dispositivo con pantalla táctil interactiva.
- **UI / contenido:**
  - Para iconos pequeños (16–22px): uso mandatorio de `IconButton` con `constraints: BoxConstraints(minWidth: 48, minHeight: 48)` o envoltura en `GestureDetector` con `HitTestBehavior.opaque` y padding expansivo interno.
  - Espaciado mínimo de separación entre objetivos táctiles adyacentes de al menos **8 dp** para mitigar toques involuntarios cruzados.
  - Ubicación ergonómica: los controles primarios móviles (como el botón de publicación o cambio de pestaña) se sitúan dentro de la zona de alcance natural del pulgar en la parte inferior de la pantalla.
- **Interacciones:**
  - Al tocar en la proximidad del icono (dentro del recuadro de 48×48 dp), el evento de pulsación se registra con precisión y emite feedback visual (onda de tinta / ripple).
- **Estados:**
  - *Reposo:* Icono limpio y proporcionado.
  - *Tocado:* Resaltado visual circular de 48dp centrado sobre el icono.
- **Validaciones y reglas de negocio:**
  - Ningún elemento interactivo en móvil puede tener una dimensión física inferior a 48×48 dp.
- **Accesibilidad:** Beneficia a personas con dificultades motrices, temblores o que operan el dispositivo con una sola mano en movimiento dentro del campus.
- **Responsive:** En desktop con cursor de ratón el área visual puede compactarse a 36×36 dp siempre que se mantenga cómoda la interacción con puntero.
- **Criterios de aceptación (Gherkin):**
  - **Given** una tarjeta de publicación con botones de interacción de Like, Marcador y Reporte, **When** se mide el recuadro receptor de eventos de cada control en un teléfono inteligente, **Then** cada uno posee un área táctil mínima verificable de 48 × 48 dp.
  - **Given** la barra de chips de filtrado por categoría en Marketplace, **When** se despliegan horizontalmente en pantalla móvil, **Then** existe una separación física de al menos 8 dp entre cada chip contiguo, previniendo toques accidentales entre categorías vecinas.

---

### UX-X-011 — Adaptabilidad responsiva en breakpoints de 700px y 1100px
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** La plataforma unifica su adaptabilidad responsiva en torno a **dos breakpoints canónicos**:
  1. **Móvil (< 700px):** Disposición vertical de 1 columna; navegación por cascarón inferior (`NavigationBar`) con 3 destinos directos (Foro, Marketplace, Grupos) y FAB contextual; menús y formularios como hojas inferiores (`ModalBottomSheet`).
  2. **Tablet (700px – 1100px):** Disposición intermedia de 2 columnas o barra lateral colapsable; navegación por pestañas superiores o riel compacto; modales centrados en pantalla; cuadrícula de marketplace en 2 columnas.
  3. **Desktop (≥ 1100px):** Disposición completa multi-columna tipo Discord (Rail de servidores de 72px + Sidebar de canales de 240px + Feed central acotado por `MaxWidthContainer` + Sidebar derecha de comunidades populares en ≥ 1050/1100px); cuadrícula de marketplace en 3 a 4 columnas.
- **Problema actual [Mejora]:** En [`responsive.dart:15-35`](../../comunidad_universitaria/lib/core/utils/responsive.dart#L15-L35), [`app_shell.dart:180-215`](../../comunidad_universitaria/lib/features/navigation/app_shell.dart#L180-L215) y [`popular_servers_sidebar.dart:15-25`](../../comunidad_universitaria/lib/features/forum/widgets/discord/popular_servers_sidebar.dart#L15-L25), existen puntos de corte discordantes (sidebar en 1050px mientras `Responsive.isDesktop` usa 1100px; y ciertas vistas de foro evalúan 768px mientras el core define 700px), lo que provoca saltos visuales incongruentes al redimensionar ventanas en navegador.
- **Precondiciones:** La ventana de la aplicación se ejecuta en dispositivos de diversas dimensiones o se redimensiona dinámicamente en el navegador.
- **UI / contenido:**
  - *Móvil (< 700px):* Título de AppBar abreviado ("Comunidad USAC"), navegación inferior fija, ocultamiento de columnas auxiliares.
  - *Tablet (700px – 1100px):* Título completo ("Comunidad Universitaria"), pestañas superiores, catálogo en 2 columnas simétricas.
  - *Desktop (≥ 1100px):* Experiencia inmersiva completa de 4 columnas en foro; catálogo comercial en 3–4 columnas con ancho máximo de lectura contenido a 1200px.
- **Interacciones:**
  - El redimensionamiento de ventana en caliente conmuta los layouts de forma instantánea y fluida sin perder el estado de los formularios activos ni la posición del scroll de la lista.
- **Estados:**
  - Layout Móvil (< 700px).
  - Layout Tablet (700px a 1099px).
  - Layout Desktop (≥ 1100px).
- **Validaciones y reglas de negocio:**
  - Las utilidades booleanas `Responsive.isMobile(context)`, `Responsive.isTablet(context)` y `Responsive.isDesktop(context)` deben ser la única fuente de verdad en toda la base de código.
- **Accesibilidad:** Soporta niveles de zoom del navegador de hasta 200% sin que el texto se trunque o los contenedores se desborden de la pantalla.
- **Responsive:** Adaptación garantizada desde teléfonos compactos (320px de ancho) hasta monitores ultrawide (4K).
- **Criterios de aceptación (Gherkin):**
  - **Given** una ventana de navegador web abierta con ancho de 680px, **When** el usuario redimensiona la ventana a 750px, **Then** la barra inferior de navegación desaparece, las pestañas superiores se activan y la grilla de productos pasa de 1 a 2 columnas manteniendo la posición de scroll actual.
  - **Given** una pantalla de escritorio de 1440px de ancho, **When** se navega en el Foro Estudiantil, **Then** la interfaz despliega simultáneamente el riel de servidores, la barra de canales, el feed central y la barra lateral derecha de comunidades activas sin solapamiento de contenidos.

---

### UX-X-012 — Adaptación polimórfica de modales y diálogos interactivos
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** Todos los formularios y diálogos interactivos (`AuthModal`, `CreatePostDialog`, `CreateListingDialog`, `CreateGroupDialog`, `CarneValidationModal`, `ReportDialog`) utilizan un patrón polimórfico adaptativo según el tamaño de la pantalla:
  - **En móvil (< 700px):** Se despliegan como hoja modal inferior (`showModalBottomSheet`) con bordes redondeados superiores (16dp), tirador de arrastre táctil (*Drag Handle*), soporte de pantalla completa controlada (`isScrollControlled: true`), respeto del área segura (`useSafeArea: true`), y desplazamiento dinámico que eleva los campos por encima del teclado virtual (`MediaQuery.of(context).viewInsets.bottom`), garantizando que los botones de envío nunca queden tapados.
  - **En tablet y desktop (≥ 700px):** Se despliegan como diálogo modal centrado (`showDialog`) con ancho restringido (460dp a 620dp según complejidad), altura máxima acotada al 85% del viewport, barra de desplazamiento visible, botón de cierre superior derecho (`Icons.close`) y cierre alternativo mediante clic exterior en el telón o tecla `Escape`.
- **Problema actual [Mejora]:** En [`auth_modal.dart:29-56`](../../comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart#L29-L56), [`create_listing_dialog.dart:35-50`](../../comunidad_universitaria/lib/features/marketplace/widgets/create_listing_dialog.dart#L35-L50) y [`sponsor_request_dialog.dart:10-25`](../../comunidad_universitaria/lib/features/marketplace/widgets/sponsor_request_dialog.dart#L10-L25), la lógica de apertura de modales está duplicada manualmente y en algunos formularios móviles no se compensa adecuadamente el `viewInsets.bottom`, ocasionando que el teclado tape los botones de acción primarios.
- **Precondiciones:** El usuario detona una acción que requiere interacción modal.
- **UI / contenido:**
  - *Móvil:* Hoja inferior con barra horizontal superior de arrastre (32×4 dp en gris medio), título en cabecera fija, cuerpo con scroll interno y barra inferior con botones fijos de acción.
  - *Desktop:* Tarjeta flotante centrada con sombra de elevación (8dp), esquinas redondeadas de 16dp, botón de cruz de cierre en esquina superior derecha y botones de acción en pie de diálogo.
- **Interacciones:**
  - Al abrirse en móvil, el usuario puede deslizar hacia abajo para descartar (si no hay datos sin guardar).
  - Si el usuario comenzó a escribir datos en un formulario largo e intenta descartar por deslizamiento o tecla Escape, se muestra una confirmación breve: `"¿Deseas descartar los cambios?"`.
  - Al abrirse en desktop, el foco se coloca automáticamente en el primer campo interactivo.
- **Estados:**
  - *Abierto móvil:* Hoja inferior visible con scroll.
  - *Teclado desplegado en móvil:* El contenido se comprime y sube automáticamente; los botones de acción quedan anclados sobre el teclado.
  - *Abierto desktop:* Cuadro centrado estético.
- **Validaciones y reglas de negocio:**
  - Altura máxima del contenido en desktop: 85% del alto de la pantalla; el desbordamiento debe generar scrollbar interno sin desbordar la ventana principal.
- **Accesibilidad:** Cierre por tecla Escape garantizado en desktop; trampa de foco accesible; lectura secuencial coherente.
- **Responsive:** La conmutación entre BottomSheet y Dialog es transparente si el usuario rota el dispositivo (ej. cambio de vertical a horizontal en tablet pequeña).
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante en un teléfono móvil abriendo el diálogo para publicar en Marketplace, **When** toca el campo de descripción y el teclado virtual se despliega, **Then** el modal se contrae y ajusta elevando los controles para que el campo de texto y el botón "Publicar" permanezcan completamente visibles por encima del teclado.
  - **Given** un usuario en navegador de escritorio que abre el modal de autenticación, **When** se presenta la interfaz, **Then** se renderiza como diálogo centrado de 480dp de ancho con esquinas de 16dp, botón superior de cierre accesible y respuesta inmediata a la tecla Escape.

---

### UX-X-013 — Localización e internacionalización en español de Guatemala (es-GT)
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** La plataforma aplica de forma uniforme y estricta la localización lingüística y de formato en **Español de Guatemala (`es-GT`)**:
  - **Moneda:** Quetzales guatemaltecos expresados obligatoriamente con el símbolo `"Q"` seguido del monto con dos decimales y separador de miles por coma (ej. `"Q50.00"`, `"Q1,250.00"`), o la insignia destacada `"GRATIS"`.
  - **Formato de fechas y horas:** Horario en formato de 12 horas con indicador am/pm en minúscula (ej. `"10:30 am"`, `"4:15 pm"`), y fechas en orden día/mes/año (`DD/MM/AAAA`).
  - **Tiempo relativo humanizado (*timeAgo*):** Adaptado al lenguaje cotidiano del estudiante sancarlista: `"Hace un momento"`, `"Hace 10 min"`, `"Hace 2 h"`, `"Ayer a las 3:15 pm"`, `"El 15 de marzo"`.
  - **Glosario y ortografía sancarlista:**
    - Ortografía estricta de `"carné"` (con tilde en la e; queda terminantemente prohibido usar "carnet", "cédula" o "DPI").
    - Terminología académica propia: `"semestre"`, `"pensum"`, `"catedrático"`, `"auxiliar de cátedra"`, `"parciales"`, `"exámenes finales"`, `"retrasadas"`, `"escuela de vacaciones"`.
    - Nomenclatura del campus: Sede Central (Campus Central zona 12), CUM (Centro Universitario Metropolitano zona 11), edificios sancarlistas (*T-3*, *S-12*, *M-5*, *Plaza de los Mártires*, *Iglú*, *Los Arcos*).
- **Problema actual [Mejora]:** En [`marketplace_item.dart:110-145`](../../comunidad_universitaria/lib/core/models/marketplace_item.dart#L110-L145) y [`marketplace_card.dart:80-120`](../../comunidad_universitaria/lib/features/marketplace/widgets/marketplace_card.dart#L80-L120), algunos formatos de fecha utilizan métodos genéricos en inglés o formatos desalineados con las costumbres guatemaltecas, y en algunas partes del código la palabra "carné" carece de la tilde académica formal.
- **Precondiciones:** La app formatea fechas, valores monetarios o cadenas de texto en pantalla.
- **UI / contenido:**
  - Precios: Tipografía en negrita (`titleMedium`), color primario o secundario oro, formato `"QXX.XX"`.
  - Fechas relativas en metadatos de tarjeta: `"Hace 5 min"` en `bodySmall`.
  - Formularios de búsqueda y selectores: Términos sancarlistas rigurosos ("Facultad de Ingeniería", "Edificio T-3", "Segundo Semestre").
- **Interacciones:**
  - Al ingresar un precio en el formulario de venta, el campo aplica máscara automática anteponiendo el símbolo `"Q"` y formateando decimales automáticamente.
- **Estados:**
  - Formato aplicado en tiempo real en todos los feeds y tarjetas.
- **Validaciones y reglas de negocio:**
  - Todo monto monetario debe validarse como no negativo. Si el costo es cero, se transforma automáticamente al distintivo `"GRATIS"`.
  - La configuración regional del dispositivo no debe forzar la moneda a dólares (`$`) ni euros (`€`); la moneda canónica de la comunidad es siempre el Quetzal (`Q`).
- **Accesibilidad:** Los lectores de pantalla deben pronunciar los montos en quetzales (ej. `"Cincuenta quetzales"` en lugar de `"letra Q cincuenta punto cero cero"`).
- **Responsive:** Formatos compactos en metadatos para optimizar espacio en tarjetas móviles.
- **Criterios de aceptación (Gherkin):**
  - **Given** una publicación comercial de un libro con valor registrado de 120 quetzales, **When** se visualiza la tarjeta en el catálogo de Marketplace, **Then** el precio mostrado es exactamente "Q120.00" y el lector de pantalla enuncia "Ciento veinte quetzales".
  - **Given** la interfaz de perfil y de validación de identidad, **When** se presentan los títulos, descripciones y campos de entrada, **Then** la palabra utilizada en todas las etiquetas es "carné" con acento ortográfico en la e.

---

### UX-X-014 — Rendimiento percibido, actualizaciones optimistas y control de latencia visual
- **Actor / rol:** Todos (Visitante, Estudiante Registrado, Estudiante Verificado)
- **Prioridad:** Should
- **Estado objetivo:** La experiencia de usuario maximiza el rendimiento percibido asegurando retroalimentación visual inmediata en menos de **100 milisegundos** ante cualquier toque o clic:
  - **Actualizaciones optimistas de UI con reversión graciosa (*Rollback*):** Al pulsar me gusta (*Like*), guardar en marcadores (*Bookmark*), votar en encuestas o emitir un voto de apoyo (*Upvote*), la interfaz actualiza el contador y conmuta el estado visual del icono de inmediato. Si la petición remota falla tras el intento en segundo plano, la app revierte suavemente el estado y despliega un aviso no intrusivo: `"No se pudo registrar tu interacción. Inténtalo de nuevo."`
  - **Diferenciación estricta entre esqueletos y spinners:** Los skeletons se reservan exclusivamente para la carga de pantallas completas o feeds; los spinners circulares pequeños (`CircularProgressIndicator` de 18dp) se limitan al interior de botones de acción activos para certificar procesamiento sin congelar la pantalla.
  - **Prevención de salto de layout en imágenes:** Todos los contenedores multimedia declaran relaciones de aspecto fijas (`AspectRatio(aspectRatio: 16 / 9)`) con fondos neutros de sustitución mientras se completa la descarga remota.
- **Problema actual [Mejora]:** En [`post_detail_screen.dart:89-105`](../../comunidad_universitaria/lib/features/forum/screens/post_detail_screen.dart#L89-L105) y [`post_card.dart:130-150`](../../comunidad_universitaria/lib/features/forum/widgets/post_card.dart#L130-L150), aunque existe lógica optimista inicial, ante fallos de conexión la reversión puede provocar saltos bruscos en el árbol de comentarios o inconsistencias en los contadores visibles de likes si el usuario navega rápidamente entre pantallas.
- **Precondiciones:** El estudiante realiza una interacción de baja fricción (like, voto, marcador) en una publicación o comentario.
- **UI / contenido:**
  - Al pulsar me gusta: el corazón o icono se tiñe de acento y el contador numérico incrementa en +1 en < 50 ms.
  - En botones de envío (ej. "Publicar", "Guardar perfil"): el texto del botón se sustituye por un spinner compacto de 18px manteniendo el ancho del botón para evitar redimensionamientos bruscos.
- **Interacciones:**
  - El usuario percibe una app hiper-reactiva sin retardos perceptibles.
  - Si la llamada a Supabase es rechazada (por fallo de red o guard de sesión), el botón revierte a su color original, el contador decrementa en -1 y se notifica la causa mediante snackbar.
- **Estados:**
  - *Interacción instantánea:* Cambio visual optimista inmediato.
  - *Confirmación de fondo:* La respuesta del servidor valida el estado silenciosamente.
  - *Rollback:* Reversión transparente ante fallo con mensaje de error amigable.
- **Validaciones y reglas de negocio:**
  - Prevención de rebotes (*Debounce*): se ignoran pulsaciones repetidas ultrarrápidas (< 300 ms) sobre el mismo botón de like para evitar saturación de peticiones.
- **Accesibilidad:** Los lectores de pantalla deben ser notificados de la conmutación de estado sin saturar la lectura continua.
- **Responsive:** Desempeño fluido a 60 fps en dispositivos móviles de gama baja y media.
- **Criterios de aceptación (Gherkin):**
  - **Given** una publicación con 12 me gusta, **When** el estudiante pulsa el botón de me gusta, **Then** el contador visual cambia a 13 y el icono se ilumina en menos de 100 ms antes de recibir la confirmación de la base de datos.
  - **Given** una interacción optimista que falla debido a pérdida súbita de conexión, **When** la petición remota arroja error de tiempo de espera, **Then** el contador regresa a 12 de forma fluida y se muestra un snackbar indicando "No se pudo registrar tu interacción. Inténtalo de nuevo."

---

### UX-X-015 — Privacidad de datos personales, disociación de identidad y consentimiento informado
- **Actor / rol:** Todos (Visitante, Estudiante Registrado, Estudiante Verificado, Moderador, Administrador)
- **Prioridad:** Must
- **Estado objetivo:** La plataforma salvaguarda la privacidad de la comunidad sancarlista bajo una **estricta disociación de identidades**:
  1. **Seudónimo garantizado en el Foro:** Todo aporte comunitario (publicaciones, comentarios, votos, reportes y encuestas) se asocia únicamente al seudónimo editable del estudiante (ej. `"Estudiante USAC #482"`) y su avatar configurado. El correo electrónico institucional (`@estudiante.usac.edu.gt`), nombre civil y número de carné jamás se transmiten en los payloads públicos de la API ni se renderizan en la interfaz del foro.
  2. **Consentimiento informado transparente en validación de carné:** Al ingresar a la verificación voluntaria de carné, la app despliega una pantalla de consentimiento obligatorio que detalla explícitamente: (a) únicamente se verifica el estatus de inscripción activa en la universidad, (b) la plataforma **nunca** consulta ni accede a notas, cursos aprobados ni expedientes académicos, (c) el número de carné se resguarda encriptado y nunca es visible para otros estudiantes.
  3. **Protección contra raspado de contactos en Marketplace:** Los números de teléfono móvil de WhatsApp jamás se muestran como texto plano accesible a bots raspadores; se resguardan detrás de un botón interactivo de contacto que despacha el enlace directo de mensajería.
  4. **Derecho al olvido y autodeterminación de datos:** Todo estudiante puede auditar, editar o eliminar de forma definitiva en cualquier momento sus publicaciones, grupos compartidos y anuncios de venta desde la pestaña "Mi Actividad" en su perfil.
- **Problema actual [Mejora]:** En [`carne_validation_modal.dart:73-85`](../../comunidad_universitaria/lib/features/profile/widgets/carne_validation_modal.dart#L73-L85), [`local_storage_service.dart:23-40`](../../comunidad_universitaria/lib/core/services/local_storage_service.dart#L23-L40) e Inventarios 8.2 y 8.3, la validación de carné actual simula la consulta con un retardo de 700 ms otorgando el distintivo a cualquier número de 6 dígitos (generando falsa expectativa de verificación), el alias no se sincroniza con la cuenta en la nube (perdiéndose al cambiar de equipo), y en Marketplace ciertos enlaces exponen números sin advertencia de privacidad previa.
- **Precondiciones:** El estudiante navega por el foro, publica en marketplace o accede a la configuración de su perfil.
- **UI / contenido:**
  - En Foro: Encabezados de autor que muestran exclusivamente seudónimo + insignia de rol (`Estudiante`, `Moderador`, `Admin`).
  - En Diálogo de Validación de Carné:
    - Tarjeta destacada de privacidad con icono `Icons.security`.
    - 3 puntos informativos sobre la protección de datos: "Solo verificación de estado activo", "Cero acceso a notas académicas", "Carné encriptado y privado".
    - Casilla de verificación (*Checkbox*) de consentimiento obligatorio: `"He leído y autorizo la verificación de mi condición de estudiante activo."`
    - Botón de validación deshabilitado hasta marcar la casilla de consentimiento.
  - En Perfil: Sección destacada "Transparencia de Privacidad" detallando cómo se protegen los datos frente a docentes y compañeros.
- **Interacciones:**
  - El estudiante puede regenerar o aleatorizar su seudónimo con el botón de barajar (`Icons.shuffle`) en cualquier momento; el nuevo seudónimo se sincroniza con su perfil en la nube para persistir entre dispositivos sin alterar su historial de posts.
  - Al eliminar un post en el perfil, la app confirma mediante diálogo modal y elimina el registro de la base de datos o anonimiza los comentarios subordinados para no romper los hilos colectivos.
- **Estados:**
  - *Perfil Seudónimo (Foro):* Privacidad total garantizada.
  - *Vendedor Verificado (Marketplace):* Confianza comercial certificada con nombre validado por consentimiento voluntario.
- **Validaciones y reglas de negocio:**
  - Las políticas de seguridad a nivel de fila (RLS) en PostgreSQL deben bloquear cualquier consulta de usuarios anónimos o estudiantes regulares sobre las columnas `carne` o `email` en la tabla `profiles`.
  - Solo los roles de `moderator` y `admin` con sesión AAL2 pueden auditar identidades ante reportes graves de fraude o acoso.
- **Accesibilidad:** La casilla de consentimiento y el texto de privacidad son plenamente navegables y leídos de forma íntegra por lectores de pantalla antes de permitir la aceptación.
- **Responsive:** Adaptación clara del texto de consentimiento en pantallas angostas con tipografía legible y espaciado holgado.
- **Criterios de aceptación (Gherkin):**
  - **Given** un estudiante participando en un debate del foro sobre una cátedra académica, **When** su comentario es visualizado por cualquier otro usuario o visitante, **Then** la interfaz exhibe únicamente su seudónimo y avatar, garantizando que su nombre real, carné y correo electrónico nunca viajen en la red ni aparezcan en pantalla.
  - **Given** un estudiante que abre el modal de validación de carné, **When** visualiza la pantalla, **Then** el botón de validación se mantiene inactivo y bloqueado hasta que marque explícitamente la casilla de consentimiento informado de verificación de matrícula.

### UX-X-016 — Transparencia y accesibilidad del contenido patrocinado
- **Actor / rol:** Todos; Patrocinador; Moderador
- **Prioridad:** Must
- **Estado objetivo:** todo contenido patrocinado (Foro, Grupos, Marketplace) cumple
  las mismas garantías que el orgánico y, además: (1) se **etiqueta** siempre como
  patrocinado; (2) explica **"¿Por qué veo esto?"** sin exponer datos sensibles;
  (3) puede **ocultarse** y **reportarse**; (4) es accesible con lectores de
  pantalla (la etiqueta se anuncia antes del cuerpo); (5) respeta la preferencia de
  *reducir movimiento* y no reproduce audio automáticamente.
- **Problema actual [Mejora]:** no existía un requisito transversal de transparencia
  publicitaria; se formaliza aquí para [`UX-SPN-005`](12-patrocinios.md) y
  [`UX-SPN-008`](12-patrocinios.md).
- **Precondiciones:** cualquier unidad patrocinada visible.
- **UI / contenido:** chip "Patrocinado"; menú con "¿Por qué veo esto?", "Ocultar",
  "Reportar"; hoja/diálogo explicativo en español.
- **Estados:** visible | oculto (recordado) | reportado | en revisión (no visible al
  usuario final).
- **Validaciones y reglas de negocio:** la segmentación **nunca** usa datos
  personales sensibles; las preferencias de ocultamiento se respetan por sesión y
  por usuario.
- **Accesibilidad:** etiqueta anunciada primero; contraste AA del chip; foco
  gestionado en el menú; sin dependencia exclusiva del color.
- **Responsive:** mismas garantías en móvil y desktop.
- **Criterios de aceptación (Gherkin):**
  - **Given** un lector de pantalla, **When** recorre un feed con una unidad
    patrocinada, **Then** se anuncia "Contenido patrocinado por [Nombre]" antes del
    cuerpo.
  - **Given** un usuario que oculta un anuncio, **When** vuelve a la sección,
    **Then** ese anuncio no reaparece y puede consultar el motivo en
    "¿Por qué veo esto?".

---

## 5. Trazabilidad y referencias cruzadas

Los requisitos transversales aquí formalizados se vinculan directamente con los
documentos de especificación funcional y técnica del proyecto:

- **Producto y Estrategia:** [`01-producto.md`](01-producto.md) (Pilares de valor, roles y privacidad).
- **Mapa de Navegación:** [`02-navegacion.md`](02-navegacion.md) (Jerarquía y puntos de entrada).
- **Foro Estudiantil:** [`03-foro.md`](03-foro.md) (Aplicación de `UX-X-001`, `004`, `005`, `006`, `014`, `015`).
- **Marketplace y Tutorías:** [`04-marketplace.md`](04-marketplace.md) (Aplicación de `UX-X-003`, `004`, `005`, `006`, `013`, `015`).
- **Directorio de Grupos:** [`05-grupos.md`](05-grupos.md) (Aplicación de `UX-X-004`, `006`, `010`).
- **Perfil y Cuenta:** [`06-perfil-y-cuenta.md`](06-perfil-y-cuenta.md) (Aplicación de `UX-X-001`, `007`, `015`).
- **Autenticación y MFA:** [`07-autenticacion.md`](07-autenticacion.md) (Aplicación de `UX-X-001`, `002`, `012`).
- **Cascarón y Reglas:** [`08-navegacion-shell-y-reglas.md`](08-navegacion-shell-y-reglas.md) (Aplicación de `UX-X-011`, `012`).
- **Sistema de Diseño:** [`09-sistema-diseno.md`](09-sistema-diseno.md) (Tokens de color, tipografía y `UX-X-008`).
- **Métricas y Pruebas:** [`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md) (Matriz de trazabilidad y validación E2E).
- **Patrocinios:** [`12-patrocinios.md`](12-patrocinios.md) (Aplicación de `UX-X-007`, `008`, `009`, `016`).
