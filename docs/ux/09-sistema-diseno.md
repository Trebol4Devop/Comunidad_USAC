# 09 — Sistema de diseño

> Tokens, componentes, temas y adaptabilidad. La accesibilidad detallada está en
> [`10-transversales.md`](10-transversales.md).

---

## 1. Identidad visual

La app usa **Material 3** con una identidad cromática inspirada en la USAC
(azul institucional + oro), tipografía **Inter**, y un tratamiento tipo
**Discord** en el foro (rail de servidores + sidebar de canales + feed).

### 1.1 Tokens de color

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `primary` | `#004B87` | `#0066CC` | Azul USAC, acciones primarias |
| `secondary` | `#EAB308` | `#EAB308` | Oro USAC, acentos y marketplace |
| `accent` | `#2563EB` | `#2563EB` | Azul de acción |
| `bg` | `#F8FAFC` | `#0B132B` | Fondo de `Scaffold` |
| `surface` | `#FFFFFF` | `#1C2541` | Tarjetas y superficie |
| `surfaceSubtle` | `#F1F5F9` | `#151E34` | Fondos sutiles, chips |
| `border` | `#E2E8F0` | `#334155` | Bordes de tarjeta/input |
| `textPrimary` | `#0F172A` | `#F8FAFC` | Texto principal |
| `textSecondary` | `#64748B` | `#94A3B8` | Texto secundario/metadatos |
| `forumRail` | `#E3E5E8` | `#1E1F22` | Rail de servidores |
| `forumSidebar` | `#F2F3F5` | `#2B2D31` | Sidebar de canales |
| `forumFeed` | `#FFFFFF` | `#313338` | Área de feed |
| `forumUserBar` | `#E3E5E8` | `#232428` | Barra de usuario inferior |

### 1.2 Tipografía
- Familia base: **Inter**.
- Escala: `titleLarge` (negrita, títulos de pantalla), `titleMedium`
  (semi-negrita, títulos de tarjetas/modales), `bodyMedium` (lectura),
  `bodySmall` (metadatos, tiempo relativo, badges).

### 1.3 Geometría
- Radios: `8` (chips), `10` (inputs/botones), `14` (tarjetas), `16` (modales).
- Padding de inputs: `14` horizontal × `12` vertical.
- Separaciones de tarjeta: `6` vertical × `12` horizontal.

### 1.4 Breakpoints
| Nombre | Rango | Comportamiento |
|---|---|---|
| Móvil | `< 700px` | Una columna; `NavigationBar` + FAB; modales como hoja inferior |
| Tablet | `700px – 1100px` | Intermedio; se pueden mostrar columnas auxiliares |
| Desktop | `>= 1100px` | Multi-columna; pestañas superiores; sidebar de populares |
| Ancho ultra | `>= 1050px` | Se habilita "Comunidades más populares" a la derecha |

### 1.5 Contenedores
- `MaxWidthContainer` limita el ancho de lectura (900–1200px según pantalla) y
  centra el contenido en bloque.

---

## 2. Requisitos del sistema de diseño

### UX-DSN-001 — Tema claro y oscuro conmutable
- **Actor / rol:** Todos
- **Prioridad:** Must
- **Estado objetivo:** la app ofrece tema claro y oscuro completos, conmutables
  en caliente desde el AppBar y desde perfil; el contraste cumple WCAG AA en
  ambos.
- **Estados:** al cambiar de tema, la preferencia se mantiene durante la sesión.
- **Accesibilidad:** ningún texto informativo por debajo de 4.5:1.
- **Criterios de aceptación:**
  - **Given** tema claro, **When** el usuario activa oscuro, **Then** toda la UI
    cambia sin recargar y con contraste AA.
  - **Given** el foro en oscuro, **When** se muestran tarjetas y metadatos,
    **Then** el texto secundario sigue siendo legible (≥ 4.5:1).

### UX-DSN-002 — Uso consistente de tokens
- **Actor / rol:** Equipo de desarrollo
- **Prioridad:** Must
- **Estado objetivo:** los colores, radios y tipografía provienen de tokens
  centrales; ninguna pantalla introduce colores "quemados" fuera de los tokens
  (salvo marcas de estado documentadas, p. ej. "VENDIDO").
- **Criterios de aceptación:**
  - **Given** una nueva pantalla, **When** se implementa, **Then** usa los
    tokens `primary`, `surface`, `border`, etc., y no literales de color.

### UX-DSN-003 — Componentes reutilizables base
- **Actor / rol:** Equipo de desarrollo
- **Prioridad:** Must
- **Estado objetivo:** existen y se reutilizan componentes canónicos para:
  - **Estado vacío** (icono + título + descripción + acción primaria).
  - **Carga** (*skeletons* de tarjeta).
  - **Sin conexión** (banner con reintento).
  - **Distintivo de identidad** (neutro en foro, verificado en marketplace).
  - **Visor de imagen** con zoom.
  - **Diálogo de reporte** unificado.
- **Criterios de aceptación:**
  - **Given** una lista sin resultados, **When** se renderiza, **Then** se usa el
    componente de estado vacío con acción sugerida.
  - **Given** contenido con imagen, **When** el usuario la toca, **Then** se abre
    el visor con zoom y cierre evidente.

### UX-DSN-004 — Jerarquía tipográfica legible
- **Actor / rol:** Todos
- **Prioridad:** Should
- **Estado objetivo:** cada pantalla usa a lo sumo tres niveles tipográficos
  visibles y evita párrafos en tamaños menores a los de metadatos.
- **Criterios de aceptación:**
  - **Given** una tarjeta de publicación, **When** se muestra, **Then** el título
    usa `titleMedium` y los metadatos `bodySmall`.

### UX-DSN-005 — Iconografía consistente
- **Actor / rol:** Todos
- **Prioridad:** Should
- **Estado objetivo:** se usa un único set de iconos (Material) con tamaños
  normalizados (`18`–`22` en acciones, `20` en AppBar) y siempre con etiqueta o
  tooltip en acciones sin texto.
- **Criterios de aceptación:**
  - **Given** un botón de solo icono, **When** el usuario mantiene el cursor o el
    lector lo enfoca, **Then** se anuncia su propósito.

### UX-DSN-006 — Movimiento sobrio y con propósito
- **Actor / rol:** Todos
- **Prioridad:** Could
- **Estado objetivo:** las transiciones (apertura de modal, cambio de destino,
  feedback de éxito) duran entre 150–300 ms y respetan la preferencia de
  "reducir movimiento" del sistema.
- **Criterios de aceptación:**
  - **Given** "reducir movimiento" activo, **When** se abre un modal, **Then** no
    hay animación de desplazamiento llamativa.

### UX-DSN-007 — Coherencia entre el foro "Discord" y el resto
- **Actor / rol:** Todos
- **Prioridad:** Should
- **Estado objetivo:** el lenguaje visual tipo Discord del foro convive con el
  resto de la app sin romper la identidad USAC; los colores neutros del foro se
  derivan de los tokens para mantener contraste en ambos temas.
- **Criterios de aceptación:**
  - **Given** el rail y la sidebar, **When** se cambia de tema, **Then** conservan
    contraste AA y no usan blancos/negros puros sin token.

### UX-DSN-008 — Lenguaje visual del contenido patrocinado
- **Actor / rol:** Todos; Patrocinador
- **Prioridad:** Must
- **Estado objetivo:** el contenido patrocinado usa un **token de acento propio**
  (dorado `#EAB308`) sobre el lenguaje visual de la sección donde vive, con una
  **etiqueta canónica** "Patrocinado" (chip de fondo dorado translúcido + texto
  oscuro, contraste AA) y un borde de acento tenue en la tarjeta. Debe verse
  **integrado pero distinguible** en Foro, Grupos y Marketplace.
- **Problema actual [Mejora]:** no existe un token unificado para el etiquetado de
  patrocinios; el carrusel actual
  ([`sponsor_carousel.dart`](../../comunidad_universitaria/lib/features/marketplace/widgets/sponsor_carousel.dart))
  usa estilos propios no reutilizables. Se centraliza aquí para
  [`UX-SPN-003`](12-patrocinios.md).
- **Precondiciones:** cualquier unidad patrocinada renderizada.
- **UI / contenido:** chip "Patrocinado"; logotipo del patrocinador con distintivo
  verificado; borde/acento dorado tenue; CTA con estilo primario de la sección.
- **Estados:** activo | pausado/finalizado (se atenúa y muestra "Promoción
  finalizada") | en revisión (visible solo en el panel del patrocinador).
- **Validaciones y reglas de negocio:** la etiqueta es **obligatoria** y su estilo
  no puede ocultarse ni reducir su contraste por debajo de AA.
- **Accesibilidad:** el chip no depende solo del color; el texto "Patrocinado" es
  legible y se anuncia a lectores de pantalla.
- **Responsive:** mismo tratamiento en móvil y desktop.
- **Criterios de aceptación:**
  - **Given** una unidad patrocinada en Foro, Grupos o Marketplace, **When** se
    renderiza, **Then** muestra el chip "Patrocinado" con el token dorado y
    contraste AA.
  - **Given** el tema oscuro, **When** se muestra el chip, **Then** conserva
    legibilidad y distinción frente al contenido orgánico.

---

## 3. Trazabilidad
Ver [`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md).
