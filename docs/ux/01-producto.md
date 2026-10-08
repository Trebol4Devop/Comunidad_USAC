# 01 — Producto, alcance y roles

> Requisitos de producto y definición de actores. Convenciones y plantilla en
> [`README.md`](README.md).

---

## 1. Visión

**Comunidad Universitaria USAC** es una plataforma colaborativa, estudiantil,
autónoma y sin fines de lucro para la Universidad de San Carlos de Guatemala.
Centraliza en un solo lugar la información y los intercambios que hoy ocurren
dispersos en grupos de WhatsApp, publicaciones de Facebook y pasillos: dudas
académicas, apuntes, horarios, grupos de curso y un marketplace/tutorías
entre pares.

El producto declara explícitamente **independencia institucional**: no
representa ni cuenta con afiliación oficial de las autoridades universitarias.

### 1.1 Pilares de valor
1. **Foro académico estructurado** por facultad y carrera, con canales temáticos.
2. **Directorio de grupos de estudio** con reputación comunitaria.
3. **Marketplace y tutorías peer-to-peer** sin comisiones ni custodia de fondos.
4. **Dualidad de identidad**: privacidad por seudónimo en el foro; verificación
   opcional de carné para generar confianza en las transacciones.
5. **Proveedor de identidad académica (SSO)** para apps satélite como PEMTREE.

---

## 2. Objetivos de experiencia

| Objetivo | Cómo se mide | Requisitos relacionados |
|---|---|---|
| Incorporación sin fricción | % que completa registro + MFA TOTP sin abandonar | UX-AUTH |
| Confianza en las transacciones | % de vendedores con identidad verificada; reportes de fraude | UX-MKT, UX-PRF |
| Descubrimiento de funcionalidades | % de usuarios que acceden a Grupos y Marketplace | UX-NAV, UX-GRP |
| Comunidad sana | tiempo de resolución de reportes | UX-FORO, UX-MKT, UX-GRP |
| Accesibilidad | cumplimiento WCAG 2.2 AA verificable | UX-X |

---

## 3. Alcance

### 3.1 Incluido
- Foro estudiantil con canales, publicaciones, comentarios anidados, encuestas,
  reacciones, guardado, citado y reporte.
- Marketplace de productos, servicios y tutorías, con patrocinios.
- Directorio de grupos de estudio (WhatsApp, Telegram, Discord, Drive).
- Perfil, alias, avatar, verificación de carné y actividad propia.
- Autenticación: correo/contraseña, OTP, recuperación, Google OAuth, MFA TOTP y
  SSO para PEMTREE.
- Cascarón de navegación, tema claro/oscuro, normas y descargos.
- Sistemas transversales: estados, accesibilidad, responsividad, i18n.

### 3.2 No objetivos (Won't, por ahora)
- **UX-PRD-001 — Sin pagos en la plataforma.** La app no procesa pagos ni
  custodia fondos; toda transacción es directa entre estudiantes.
- **UX-PRD-002 — Sin mensajería interna.** La comunicación ocurre por canales
  externos (WhatsApp, Telegram, Instagram, Messenger).
- **UX-PRD-003 — Sin integración oficial con Registro y Estadística.** La
  validación de carné es informada y de mejor esfuerzo (ver UX-PRF).
- **UX-PRD-004 — Sin aplicación de escritorio distribuida.** El foco son web y
  móvil; el escritorio es un objetivo secundario derivado de Flutter.

### 3.3 Supuestos
- Los estudiantes usan principalmente teléfono; el diseño prioriza móvil y
  escala a desktop.
- Muchos accesos ocurren con conexión intermitente → se requiere caché y
  estados offline ([ver UX-X en `10-transversales.md`](10-transversales.md)).
- La mayoría del contenido está en español de Guatemala.

---

## 4. Roles y actores

### 4.1 Definiciones

- **UX-PRD-010 — Visitante (no autenticado).**
  - **Estado objetivo:** puede **leer** foro, marketplace, grupos y normas, y
    buscar/filtrar, sin cuenta. Tiene un alias local autogenerado.
  - **Restricción:** cualquier acción de escritura (publicar, comentar, votar,
    guardar, reportar, solicitar patrocinio) abre el flujo de autenticación y,
    tras autenticarse, **reanuda la acción** solicitada.
  - **Criterios de aceptación:**
    - **Given** un visitante en el foro, **When** pulsa "Me gusta", **Then** se
      abre el inicio de sesión y, al completarlo, se aplica el "Me gusta".
    - **Given** un visitante, **When** navega al feed, **Then** ve contenido
      público sin errores ni callejones sin salida.

- **UX-PRD-011 — Estudiante registrado.**
  - **Estado objetivo:** puede escribir en foro y marketplace, personalizar
    perfil y unirse/reportar grupos.
  - **Restricción:** toda escritura exige sesión **AAL2** (MFA TOTP).

- **UX-PRD-012 — Estudiante verificado.**
  - **Estado objetivo:** estudiante con carné validado; en marketplace sus
    publicaciones muestran el distintivo de identidad verificada y su nombre
    validado en lugar del alias. [ver UX-PRF-* y UX-MKT-*]

- **UX-PRD-013 — Moderador.**
  - **Estado objetivo:** dispone de herramientas para revisar contenido en
    revisión/oculto y resolver reportes.
  - **Regla:** la moderación **no reescribe la autoría** del contenido.

- **UX-PRD-014 — Administrador.**
  - **Estado objetivo:** acceso completo de moderación y gestión.

- **UX-PRD-015 — Patrocinador.**
  - **Estado objetivo:** cuenta comercial aprobada con **perfil público** propio y
    un panel para publicar promociones. Su contenido puede aparecer **destacado en
    el carrusel del Marketplace**, como **publicación patrocinada en el Foro** y
    como **aparición ocasional en Grupos**, siempre etiquetado como patrocinado.
  - **Regla:** requiere solicitud y aprobación previas; todo su contenido pasa por
    moderación y no puede auto-aprobarse.
  - **Detalle:** ver el modelo transversal en
    [`12-patrocinios.md`](12-patrocinios.md) (`UX-SPN`).

### 4.2 Matriz de capacidades
La matriz resumida vive en [`README.md`](README.md#4-roles-y-matriz-de-capacidades-resumen);
el detalle de cada capacidad se especifica en el documento de su área.

---

## 5. Principios de diseño

- **UX-PRD-020 — Identidad al servicio del usuario, con contexto.** El mismo
  usuario puede ser seudónimo en el foro y verificable en el marketplace. La UI
  debe dejar claro **qué identidad se usará en cada contexto**.
- **UX-PRD-021 — La seguridad no debe sorprender.** Toda exigencia de seguridad
  (MFA, validación) se explica **antes** de solicitarla y ofrece salida o ayuda.
  [ver UX-AUTH]
- **UX-PRD-022 — Nunca dejar al usuario en un estado sin salida.** Todo error,
  vacío o bloqueo ofrece una acción siguiente (reintentar, volver, explicar).
- **UX-PRD-023 — Feedback inmediato.** Cada acción muestra estado de progreso y
  confirmación; usar actualización optimista con reversión ante fallo.
- **UX-PRD-024 — Transparencia.** Los avisos (independencia institucional,
  ausencia de custodia de fondos, depuración de grupos) son visibles y
  consultables, no letra pequeña escondida.
- **UX-PRD-025 — Publicidad honesta y no intrusiva.** El contenido patrocinado
  siempre se etiqueta, respeta límites de frecuencia y puede ocultarse/reportarse;
  nunca se disfraza de contenido orgánico. [ver `12-patrocinios.md`](12-patrocinios.md)
- **UX-PRD-026 — Sin fines de lucro, financiamiento transparente y protección de
  datos.** Comunidad Universitaria USAC es un proyecto **sin fines de lucro** que
  se financia mediante **patrocinios y donaciones**. **No vende datos**, **no
  utiliza rastreadores publicitarios** y **no reporta información a las
  autoridades de la USAC**, salvo cuando lo exija una **obligación legal**. Esta
  declaración es canónica y se refleja en la tarjeta de privacidad
  ([`06-perfil-y-cuenta.md`](06-perfil-y-cuenta.md), `UX-PRF-011`) y en el descargo
  legal ([`08-navegacion-shell-y-reglas.md`](08-navegacion-shell-y-reglas.md),
  `UX-REG-003`).

---

## 6. Métricas de éxito del producto
El detalle operativo (eventos y KPIs) está en
[`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md).

---

## 7. Trazabilidad
Ver matriz global en [`11-metricas-y-trazabilidad.md`](11-metricas-y-trazabilidad.md).
