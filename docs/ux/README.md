# Especificación de Requisitos de UX — Comunidad Universitaria USAC

Documento maestro de requisitos de experiencia de usuario para la plataforma
**Comunidad Universitaria USAC** (app Flutter: foro, marketplace, grupos,
perfil, autenticación, MFA TOTP y SSO).

> **Naturaleza de este documento:** está redactado en modo **"deber ser"**
> (should-be). Describe la experiencia objetivo que el producto debe ofrecer,
> no un reflejo literal de lo implementado hoy. Cuando un requisito corrige una
> carencia detectada en la implementación actual, se marca con la etiqueta
> **[Mejora]** y se cita el archivo/afirmación que la motiva.

---

## 1. Cómo leer este documento

Cada archivo de área contiene **requisitos numerados** con una plantilla
uniforme (sección 3). Los requisitos son atómicos, verificables y trazables.

### Índice de archivos

| Archivo | Contenido |
|---|---|
| [`README.md`](README.md) | Este archivo: convenciones, plantilla, glosario y matriz de roles |
| [`01-producto.md`](01-producto.md) | Visión, propuesta de valor, alcance, no-objetivos, supuestos, transparencia y financiamiento, métricas de éxito |
| [`02-navegacion.md`](02-navegacion.md) | Mapa de navegación, jerarquía de pantallas, puntos de entrada |
| [`03-foro.md`](03-foro.md) | Foro estudiantil (feed, canales, posts, comentarios, encuestas) |
| [`04-marketplace.md`](04-marketplace.md) | Marketplace y tutorías (catálogo, publicar, contacto, patrocinios) |
| [`05-grupos.md`](05-grupos.md) | Directorio de grupos de estudio (WhatsApp/Telegram/Discord/Drive) |
| [`06-perfil-y-cuenta.md`](06-perfil-y-cuenta.md) | Perfil, alias, avatar, carné, actividad propia, menú inicial de nuevos usuarios, intereses y tarjeta de presentación (visibilidad por campo) |
| [`07-autenticacion.md`](07-autenticacion.md) | Login, registro, OTP, recuperación, logout, MFA TOTP, SSO |
| [`08-navegacion-shell-y-reglas.md`](08-navegacion-shell-y-reglas.md) | Cascarón de navegación, tema, normas y descargos |
| [`09-sistema-diseno.md`](09-sistema-diseno.md) | Design tokens, componentes, temas claro/oscuro, breakpoints |
| [`10-transversales.md`](10-transversales.md) | Errores, estados vacíos, red/offline, accesibilidad, i18n, rendimiento |
| [`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md) | Analítica, KPIs y matriz de trazabilidad requisito → código → test |
| [`12-patrocinios.md`](12-patrocinios.md) | Contenido patrocinado: identidad, panel, etiquetado, frecuencia, moderación, métricas, ciclo de vida y administración del patrocinador |

---

## 2. Convención de identificadores

Formato: **`UX-<AREA>-###`**

| Área | Prefijo | Archivo |
|---|---|---|
| Producto / estrategia | `UX-PRD` | 01 |
| Estructura y enrutado | `UX-MAP` | 02 |
| Foro | `UX-FORO` | 03 |
| Marketplace | `UX-MKT` | 04 |
| Grupos | `UX-GRP` | 05 |
| Perfil y cuenta | `UX-PRF` | 06 |
| Autenticación y MFA/SSO | `UX-AUTH` | 07 |
| Cascarón y reglas | `UX-NAV` / `UX-REG` | 08 |
| Sistema de diseño | `UX-DSN` | 09 |
| Transversales | `UX-X` | 10 |
| Métricas | `UX-MET` | 11 |
| Patrocinios | `UX-SPN` | 12 |

- Los identificadores son **estables**: no se renumeran; se marcan como
  `(obsoleto)` si se retiran.
- Un requisito transversal (p. ej. accesibilidad) se declara una vez en `10` y
  se **referencia** desde los requisitos de área con `[ver UX-X-00X]`.

## 3. Plantilla de requisito

```markdown
### UX-AREA-001 — Título corto y accionable
- **Actor / rol:** <ver matriz de roles en README>
- **Prioridad:** Must | Should | Could | Won't
- **Estado objetivo:** <qué debe pasar; en "deber ser">
- **Problema actual [Mejora]:** <solo si corrige una carencia; cita archivo:línea>
- **Precondiciones:** ...
- **UI / contenido:** elementos, etiquetas, jerarquía visual
- **Interacciones:** qué puede hacer el usuario y qué ocurre
- **Estados:** inicial | carga | vacío | error | éxito | sin conexión
- **Validaciones y reglas de negocio:** ...
- **Accesibilidad:** foco, contraste, lectores de pantalla, tamaño táctil
- **Responsive:** comportamiento móvil / tablet / desktop
- **Criterios de aceptación (Gherkin):**
  - **Given** ... **When** ... **Then** ...
```

### Reglas de redacción
- Cada requisito debe poder **probarse**. Nada de "ser intuitivo".
- Los textos de interfaz van entre comillas y en español (`es-GT`).
- Si aplica una regla de seguridad o de negocio de la BD, se cita la migración
  o el servicio que la respalda.

---

## 4. Roles y matriz de capacidades (resumen)

Detalle completo en [`01-producto.md`](01-producto.md).

| Capacidad | Visitante | Estudiante | Verificado | Moderador | Admin |
|---|:--:|:--:|:--:|:--:|:--:|
| Leer foro / marketplace / grupos | Sí | Sí | Sí | Sí | Sí |
| Publicar / comentar / votar | No | Sí | Sí | Sí | Sí |
| Publicar en marketplace con nombre verificado | No | No | Sí | Sí | Sí |
| Moderar contenido y reportes | No | No | No | Sí | Sí |
| Solicitar patrocinio | No | Sí | Sí | Sí | Sí |
| Gestión global | No | No | No | No | Sí |

**Guards transversales:** toda escritura exige sesión **AAL2** (MFA TOTP).
Ver [`07-autenticacion.md`](07-autenticacion.md).

---

## 5. Glosario

| Término | Significado |
|---|---|
| **Alias / seudónimo** | Nombre público seudónimo del estudiante en el foro (p. ej. `Estudiante USAC #482`). |
| **AAL** | *Authenticator Assurance Level*: AAL1 = sesión básica; AAL2 = con segundo factor (TOTP). |
| **AAL2 guard** | Capa que bloquea escritura/navegación hasta elevar la sesión con TOTP. |
| **Carrera / canal** | En el foro, canal temático dentro de un servidor de facultad. |
| **MFA / TOTP** | Autenticación multifactor por aplicación de códigos temporales. |
| **OTP** | Código de un solo uso enviado por correo. |
| **PKCE** | Extensión de OAuth 2.0 para clientes públicos. |
| **Punto seguro** | Punto de encuentro físico verificado del campus para intercambios. |
| **Sede / servidor** | Unidad académica (facultad o centro universitario) usada como "servidor" del foro. |
| **SSO / PEMTREE** | Proveedor de identidad académica y app satélite que la consume. |

---

## 6. Estado de los documentos

| Documento | Requisitos | Versión | Última actualización |
|---|---:|---|---|
| README | — | v1.0 | 2026-10-07 |
| 01-producto | 17 (`UX-PRD`) | v1.2 | 2026-10-08 |
| 02-navegacion | 3 (`UX-MAP`) | v1.0 | 2026-10-07 |
| 03-foro | 24 (`UX-FORO`) | v1.1 | 2026-10-07 |
| 04-marketplace | 15 (`UX-MKT`) | v1.0 | 2026-10-07 |
| 05-grupos | 12 (`UX-GRP`) | v1.1 | 2026-10-07 |
| 06-perfil-y-cuenta | 34 (`UX-PRF`) | v1.3 | 2026-10-08 |
| 07-autenticacion | 15 (`UX-AUTH`) | v1.0 | 2026-10-07 |
| 08-navegacion-shell-y-reglas | 13 (`UX-NAV`, `UX-REG`) | v1.0 | 2026-10-07 |
| 09-sistema-diseno | 8 (`UX-DSN`) | v1.1 | 2026-10-07 |
| 10-transversales | 16 (`UX-X`) | v1.1 | 2026-10-07 |
| 11-metricas-y-trazabilidad | 3 (`UX-MET`) | v1.0 | 2026-10-07 |
| 12-patrocinios | 16 (`UX-SPN`) | v1.1 | 2026-10-08 |

**Total: 176 requisitos identificados.** Cada área usa un prefijo propio para
evitar colisiones de identificadores (p. ej. navegación-estructura es `UX-MAP`,
mientras que el cascarón es `UX-NAV`).

