# 14 — Arquitectura de Interfaz Discord, Riel de Servidores y Reubicación de Navegación

> Especificación de requisitos y documentación técnica del nuevo sistema de distribución visual de dos columnas inspirado en Discord, el panel de canales con tarjeta de usuario invernal y la reubicación ergonómica del botón de configuración y normas legales en la plataforma **Comunidad Universitaria USAC**.  
> Convenciones, trazabilidad y sistema de diseño en [`README.md`](README.md), [`03-foro.md`](03-foro.md) y [`08-navegacion-shell-y-reglas.md`](08-navegacion-shell-y-reglas.md).

---

## 1. Visión y Propósito del Rediseño

Para ofrecer una experiencia de usuario familiar, inmersiva y de alto rendimiento a los estudiantes sancarlistas, el **Foro Estudiantil** adopta una estructura de distribución visual compuesta por **dos columnas principales** y una **tarjeta fija inferior**, acompañada de una simplificación de la barra superior institucional (Zanate):

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ Barra Superior Zanate (Limpia, sin ícono de engranaje ni sobrecarga visual)       │
├─────────────┬────────────────────────────────┬────────────────────────────────────┤
│ Rail        │ Panel Canales / Mensajes (240) │ Feed Central o Espacio de Carrera  │
│ Servidores  │                                │                                    │
│ (76px)      │ - Encabezado servidor          │                                    │
│             │ - Fila de canal / chat         │                                    │
│ [Squircle]  │   · Avatar circular (38px)     │                                    │
│             │   · Insignia online (10px)     │                                    │
│ [Squircle]  │   · Tipografía Medium/SemiBold │                                    │
│             │                                │                                    │
│ ...         │ ────────────────────────────── │                                    │
│             │ [ Tarjeta Perfil Invernal    ] │                                    │
│ [ + ]       │ [ · Avatar ~44px + Insignia  ] │                                    │
│ [ Escudo ]  │ [ · Alias + Chevron v        ] │                                    │
│ (Normas)    │ [ · En línea                 ] │                                    │
└─────────────┴────────────────────────────────┴────────────────────────────────────┘
```

---

## 2. Componentes Clave y Distribución Visual

### 2.1 Barra Lateral de Servidores (`ForumServerRail`)
- **Dimensiones:** Ancho fijo calibrado en **76px** (rango ergonómico 72px – 80px).
- **Contenedor:** Contenedor scrolleable vertical con espaciado uniforme (`ListView`, padding vertical de 4px).
- **Íconos de Servidor (Squircles 48x48px):**
  - **Estado Inactivo:** Borde redondeado suave (`borderRadius: 20px`), fondo neutro contrastado (`#313338` en modo oscuro / blanco en modo claro).
  - **Estado Activo:** Se expande sutilmente hacia una geometría más cuadrada (`borderRadius: 14px`), adoptando el azul oficial USAC (`#004B87`) con sombra de resplandor.
  - **Píldora Indicadora Vertical:** Barra blanca animada en el extremo izquierdo (`width: 4px`, `height: 36px` activo vs `0px` inactivo) con transición cúbica suave (`Curves.easeOutCubic`, 200ms).
- **Acciones Inferiores del Riel:**
  1. **Separador discreto:** Barra horizontal de 36x2px para jerarquía visual.
  2. **Botón Agregar Servidor (`+`):** Squircle de 48x48px con icono verde Discord (`#23A55A` / `#16A34A`) que despliega el explorador de facultades y carreras (`ForumCarreraPickerDialog`).
  3. **Botón Normas y Descargo Legal (`Escudo`):** Ubicado **directamente abajo** del botón de agregar servidor. Squircle de 48x48px con `Icons.shield_outlined` en azul distintivo, brindando acceso inmediato a las 7 reglas de convivencia y aviso de autonomía en `RulesScreen`.

---

### 2.2 Panel de Canales y Navegación Directa (`ForumChannelSidebar`)
- **Dimensiones y Adaptabilidad:** 
  - **Móvil:** La barra lateral (drawer) ocupa **el 100% del ancho de la pantalla** (`width: MediaQuery.sizeOf(context).width`), permitiendo que el panel de canales se expanda horizontalmente (`Expanded`) en todo el espacio contiguo al riel de 76px, incluyendo botón de cierre (`Icons.close_rounded`) en la cabecera.
  - **Escritorio:** Ampliado a **280px** de ancho fijo para lectura cómoda y balance visual.
- **Filas de Canal / Chat:**
  - **Avatar Circular:** Contenedor circular de **38px** de diámetro (rango 36px – 40px) que enmarca el icono representativo del canal o foto de usuario.
  - **Insignia de Estado:** Punto circular de **10px** en la esquina inferior derecha (`Positioned(right: -1, bottom: -1)`) en color verde online Discord (`#23A55A`) con borde recortado de 2px a tono del fondo del canal.
  - **Tipografía:** Peso `FontWeight.w600` (Semi-bold) en el canal activo y `FontWeight.w500` (Medium) en inactivos, alineada verticalmente al centro.

---

### 2.3 Tarjeta de Perfil de Usuario Inferior (`User Footer Card`)
- **Ubicación:** Flotante / fija al pie del panel de canales, superpuesta al final de la columna.
- **Geometría:** Margen perimetral (`fromLTRB(10, 4, 10, 10)`) con bordes redondeados pronunciados arriba y abajo (`borderRadius: BorderRadius.circular(16)`).
- **Fondo Invernal Efecto Hielo:**
  - Degradado lineal diagonal (`LinearGradient`) con paleta azul glacial:
    - `#0284C7` (Sky 600)
    - `#0369A1` (Sky 700)
    - `#075985` (Sky 800)
    - `#0C4A6E` (Sky 900)
  - Borde de cristal esmerilado con translucidez blanca: `Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2)`.
  - Sombra sutil con halo azul invernal: `blurRadius: 10`, `offset: Offset(0, 3)`.
- **Avatar del Usuario Actual:**
  - Diámetro ergonómico de **44px**.
  - Borde blanco sólido de 2px y fondo con halo cristalino, **sin punto verde de estado** para máxima sobriedad y limpieza estética.
- **Información Textual:**
  - Nombre principal / seudónimo activo en tipografía blanca `FontWeight.w700` (`13px`).
  - Selector desplegable discreto con icono chevron (`Icons.keyboard_arrow_down_rounded`, 20px).
  - **Sin etiqueta 'En línea'**: Presentación limpia y directa sin textos redundantes.
- **Apertura de Perfil desde Abajo:** Al pulsar sobre la tarjeta de usuario, la pantalla de perfil (`ProfileScreen`) se despliega **desde abajo** mediante un modal inferior deslizante (`showModalBottomSheet` con `isScrollControlled: true` y bordes superiores redondeados de 20px), ocupando el 94% de altura de la pantalla y permitiendo cerrarlo deslizando hacia abajo o tocando el botón de regreso.

---

## 3. Reubicación Ergonómica de Acciones y Controles

### 3.1 Limpieza de la Barra Superior Zanate (`AppShell`)
- **Regla:** Se **eliminó el icono de configuración / engranaje** (`Icons.settings_outlined`) de la barra superior donde reside el logotipo y título de Zanate.
- **Objetivo UX:** Eliminar la duplicidad de controles, garantizar una barra superior despejada y evitar confusiones entre "ajustes de la aplicación" y "ajustes del usuario".

### 3.2 Traslado de Configuración a `ProfileScreen`
- **Ubicación:** `AppBar.actions` en `ProfileScreen`.
- **Componente:** `PopupMenuButton<String>` con tooltip `"Ajustes"` e icono `Icons.settings_outlined`.
- **Opciones Disponibles:**
  1. **Conmutador de Tema:** Permite alternar en vivo entre tema claro y tema oscuro mediante el callback global `onToggleTheme`.
  2. **Normas y Descargo Legal:** Navega hacia `RulesScreen` para consulta de los 7 principios de convivencia y el descargo de responsabilidad institucional.
  3. **Seguridad y Enrolamiento TOTP:** Acceso directo a `TotpEnrollmentScreen` para gestión de autenticación de dos factores (2FA / AAL2).

### 3.3 Reubicación de Normas Comunitarias en el Riel de Servidores
- **Ubicación:** `ForumServerRail`, inmediatamente después del botón de agregar servidor (`+`).
- **Objetivo UX:** Ofrecer acceso contextual directo a las reglas del foro y transparencia legal sin obligar a los estudiantes a buscar en submenús ocultos.

---

## 4. Trazabilidad de Archivos Modificados

| Componente | Archivo | Modificación |
|---|---|---|
| `ForumServerRail` | [`forum_server_rail.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/forum/widgets/discord/forum_server_rail.dart) | Ancho 76px, squircles 48x48px con radio dinámico 20px/14px, píldora animada y botón de normas bajo el botón `+`. |
| `ForumChannelSidebar` | [`forum_channel_sidebar.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/forum/widgets/discord/forum_channel_sidebar.dart) | Filas con avatar 38px + badge 10px, User Footer Card con degradado invernal, avatar 44px, chevron y estado "En línea". |
| `ForumScreen` | [`forum_screen.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/forum/screens/forum_screen.dart) | Inyección de `activeAlias` y callback `onOpenProfile` en versiones de escritorio y drawer móvil. |
| `AppShell` | [`app_shell.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/navigation/app_shell.dart) | Eliminación del botón de configuración en la barra superior móvil donde está Zanate (`actions: isMobile ? null : [...]`). |
| `ProfileScreen` | [`profile_screen.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/profile/screens/profile_screen.dart) | Incorporación del botón de configuración (`Icons.settings_outlined`) en `AppBar.actions` con menú de tema, normas y TOTP. |
| Pruebas Unitarias | [`discord_forum_test.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/test/discord_forum_test.dart) | Verificación de squircles, botón de normas bajo el `+`, User Footer Card y estado online. |
| Pruebas de Shell | [`app_shell_test.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/test/widgets/app_shell_test.dart) | Verificación de remoción del icono de ajustes en la barra superior de Zanate. |

---

## 5. Verificación y Calidad

- **Análisis Estático:** `flutter analyze` reporta **0 errores y 0 advertencias**.
- **Pruebas Automatizadas:**
  - `flutter test test/discord_forum_test.dart`: **9/9 pruebas pasadas con éxito**.
  - `flutter test test/widgets/app_shell_test.dart`: **13/13 pruebas pasadas con éxito**.
