# Autenticación con Supabase: Login y Sign Up

Documento de lógica, flujos y recomendaciones para un sistema de autenticación que usa **solo Supabase** (Auth + PostgreSQL + RLS) como base de datos y backend, con **costo cero**, **OAuth con Google**, **verificación de correo mediante token** y **MFA con TOTP**.

> Verifica los límites del plan gratuito en https://supabase.com/pricing antes de decidir, porque cambian con el tiempo.

---

## 1. Alcance y decisiones de arquitectura

| Decisión | Elección | Motivo |
|---|---|---|
| Backend | Supabase Auth (GoTrue) | Ya incluye registro, login, tokens, OAuth y recuperación |
| Base de datos | PostgreSQL de Supabase | Tabla `auth.users` administrada por Supabase + tabla propia `public.profiles` |
| Autorización | Row Level Security (RLS) | Sin backend propio, la seguridad vive en la BD |
| Proveedores | Email + contraseña, Google OAuth | Los dos pedidos |
| Verificación de correo | Token enviado por correo (enlace o código OTP de 6 dígitos) | Nativo de Supabase |
| Segundo factor (MFA) | TOTP con app autenticadora | Incluido en todos los planes; el MFA por SMS requiere proveedor externo y genera costo |
| Flujo OAuth | PKCE (por defecto en `supabase-js` v2) | Más seguro que el flujo implícito |
| Costo | Plan Free de Supabase + Google Cloud Console gratuito + SMTP gratuito | Ver sección 10 |

### Componentes

```mermaid
flowchart LR
    U["Usuario"] --> F["Frontend - cliente web"]
    F -->|"supabase-js con anon key"| A["Supabase Auth"]
    A --> DB[("PostgreSQL")]
    A -->|"correo con token"| M["SMTP - correo"]
    A <-->|"OAuth 2.0 + PKCE"| G["Google Identity"]
    F -->|"consultas con JWT"| DB
    DB --- R["RLS: auth.uid"]
```

**Regla clave:** el frontend solo usa la `anon key` (pública). La `service_role key` **nunca** va en el cliente ni en el repositorio.

---

## 2. Modelo de datos

`auth.users` lo gestiona Supabase; no la modifiques directamente. Crea tu propia tabla de perfil enlazada por `id`.

```sql
-- Perfil público del usuario
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text,
  full_name   text,
  avatar_url  text,
  provider    text,                       -- 'email' | 'google'
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Cada usuario solo ve y edita su propio perfil
create policy "perfil_select_propio" on public.profiles
  for select using (auth.uid() = id);

create policy "perfil_update_propio" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Trigger: crear el perfil automáticamente al registrarse (email o Google)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url, provider)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url',
    new.raw_app_meta_data ->> 'provider'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

**Por qué un trigger:** garantiza que siempre exista el perfil sin depender del cliente, y funciona igual para registro por correo y por Google.

---

## 3. Flujo de Sign Up (correo y contraseña)

```mermaid
flowchart TD
    A(["Inicio: pantalla de registro"]) --> B["Usuario ingresa correo, contraseña y nombre"]
    B --> C{"Validación en cliente: formato de correo y contraseña segura"}
    C -->|"No"| C1["Mostrar errores de validación"] --> B
    C -->|"Sí"| D["auth.signUp con email, password y emailRedirectTo"]
    D --> E{"Supabase responde"}
    E -->|"Error de red o rate limit"| E1["Mostrar mensaje genérico e invitar a reintentar"] --> B
    E -->|"Contraseña débil"| E2["Mostrar requisitos de contraseña"] --> B
    E -->|"OK"| F["Se crea registro en auth.users con email_confirmed_at = null"]
    F --> G["Trigger crea fila en public.profiles"]
    G --> H["Supabase envía correo con token de verificación"]
    H --> I["Pantalla: Revisa tu correo para confirmar tu cuenta"]
    I --> J{"Usuario abre el correo"}
    J -->|"No llega"| K["Botón: Reenviar correo con auth.resend, con cooldown de 60 s"] --> H
    J -->|"Abre el enlace o ingresa el código"| L["Flujo de verificación - sección 4"]
```

**Notas de lógica**

- Con "Confirm email" activado, `signUp` **no devuelve sesión**: el usuario no puede iniciar sesión hasta verificar.
- Si el correo ya existe, Supabase responde de forma ofuscada (sin revelar que existe) para evitar enumeración de usuarios. Muestra siempre el mismo mensaje: *"Si el correo es válido, te enviamos un mensaje de confirmación."*
- Guarda el nombre en `options.data` (`raw_user_meta_data`) para que el trigger lo copie al perfil.

```ts
const { data, error } = await supabase.auth.signUp({
  email,
  password,
  options: {
    emailRedirectTo: `${window.location.origin}/auth/callback`,
    data: { full_name: nombre },
  },
});
```

---

## 4. Verificación de correo con token

Supabase ofrece dos variantes. Elige **una** y configúrala en las plantillas de correo (Authentication → Email Templates).

### Variante A: enlace con token (recomendada para web)

```mermaid
sequenceDiagram
    actor U as Usuario
    participant M as Correo
    participant F as Frontend /auth/callback
    participant A as Supabase Auth
    participant DB as PostgreSQL

    U->>M: Abre el correo de confirmación
    M->>F: Clic en el enlace con token_hash y type=signup
    F->>A: auth.verifyOtp con token_hash y type
    alt Token válido y vigente
        A->>DB: Actualiza email_confirmed_at
        A-->>F: Sesión: access token y refresh token
        F-->>U: Redirige al dashboard
    else Token expirado o ya usado
        A-->>F: Error
        F-->>U: Mensaje de enlace inválido y opción de reenviar
    end
```

Plantilla de correo para esta variante:

```html
<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=signup">
  Confirmar mi correo
</a>
```

```ts
// /auth/confirm
const token_hash = url.searchParams.get('token_hash');
const type = url.searchParams.get('type'); // 'signup'
const { error } = await supabase.auth.verifyOtp({ token_hash, type });
```

### Variante B: código OTP de 6 dígitos (ideal para móvil o SPA sin rutas de callback)

Plantilla: `Tu código es: {{ .Token }}`

```ts
const { error } = await supabase.auth.verifyOtp({
  email,
  token: codigoIngresado,
  type: 'signup',
});
```

```mermaid
flowchart TD
    A["Usuario recibe código de 6 dígitos"] --> B["Ingresa el código en la app"]
    B --> C["auth.verifyOtp con email, token y type signup"]
    C --> D{"Resultado"}
    D -->|"Válido"| E["Cuenta verificada y sesión iniciada"] --> F(["Dashboard"])
    D -->|"Incorrecto"| G["Contador de intentos"] --> H{"Más de 5 intentos?"}
    H -->|"No"| B
    H -->|"Sí"| I["Bloquear temporalmente y pedir nuevo código"]
    D -->|"Expirado"| J["Botón Reenviar código"] --> A
```

**Reglas del token:** es de un solo uso, expira (por defecto 1 hora; configurable en Authentication → Providers → Email → *OTP expiry*) y se invalida al pedir uno nuevo.

---

## 5. Flujo de Login (correo y contraseña)

```mermaid
flowchart TD
    A(["Inicio: pantalla de login"]) --> B["Usuario ingresa correo y contraseña"]
    B --> C["auth.signInWithPassword"]
    C --> D{"Resultado"}
    D -->|"Credenciales inválidas"| E["Mensaje genérico: correo o contraseña incorrectos"] --> F{"Demasiados intentos?"}
    F -->|"No"| B
    F -->|"Sí"| G["Esperar o mostrar CAPTCHA"] --> B
    D -->|"Correo no confirmado"| H["Mensaje: confirma tu correo y botón Reenviar"] --> I["auth.resend type signup"]
    D -->|"OK"| J["Se recibe sesión: access token JWT y refresh token"]
    J --> K["supabase-js guarda la sesión y programa el refresh automático"]
    K --> L["Redirigir a ruta protegida"]
    L --> M(["Dashboard"])
```

**Notas de lógica**

- Usa **mensaje genérico** para credenciales inválidas (no digas si falló el correo o la contraseña).
- Para distinguir "correo no confirmado" el error es `email_not_confirmed`; puedes manejarlo con `error.code`.
- Si el usuario tiene un factor MFA inscrito, tras `signInWithPassword` la sesión queda en nivel `aal1` y debe pasar por el paso de verificación de la sección 9.
- Un usuario que se registró solo con Google no tiene contraseña; si intenta `signInWithPassword` recibirá credenciales inválidas. Sugiere en la UI "Continuar con Google".

---

## 6. Login / Sign Up con Google (OAuth 2.0 + PKCE)

En OAuth, **login y registro son el mismo flujo**: si el correo de Google no existe, Supabase crea el usuario; si existe, inicia sesión. Google ya entrega el correo verificado, por lo que **no hace falta token de correo**.

```mermaid
sequenceDiagram
    actor U as Usuario
    participant F as Frontend
    participant A as Supabase Auth
    participant G as Google
    participant DB as PostgreSQL

    U->>F: Clic en Continuar con Google
    F->>A: auth.signInWithOAuth provider google con redirectTo
    A-->>F: URL de autorización con code_challenge
    F->>G: Redirección a pantalla de consentimiento
    U->>G: Elige cuenta y acepta permisos
    G->>A: Redirige a /auth/v1/callback con code
    A->>G: Intercambia code por datos del usuario
    G-->>A: Perfil: email, nombre, avatar, email_verified
    alt Usuario nuevo
        A->>DB: Inserta en auth.users
        DB->>DB: Trigger crea public.profiles
    else Usuario existente
        A->>DB: Actualiza identidad y último login
    end
    A-->>F: Redirige a redirectTo con code
    F->>A: auth.exchangeCodeForSession con code
    A-->>F: Sesión: access token y refresh token
    F-->>U: Redirige al dashboard
```

```ts
await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: { redirectTo: `${window.location.origin}/auth/callback` },
});

// /auth/callback
const code = new URL(window.location.href).searchParams.get('code');
await supabase.auth.exchangeCodeForSession(code);
```

### Configuración paso a paso (gratis)

1. **Google Cloud Console** → crear proyecto → *APIs & Services* → *OAuth consent screen* (tipo External, agrega correos de prueba mientras esté en modo Testing).
2. *Credentials* → *Create credentials* → *OAuth client ID* → tipo **Web application**.
3. En *Authorized redirect URIs* agrega: `https://<TU-PROJECT-REF>.supabase.co/auth/v1/callback`
4. Copia **Client ID** y **Client Secret**.
5. En Supabase: *Authentication → Providers → Google* → activar y pegar ambos valores.
6. En Supabase: *Authentication → URL Configuration* → define **Site URL** y agrega en **Redirect URLs** tus rutas (`http://localhost:3000/**` para desarrollo y tu dominio de producción).

### Caso especial: mismo correo, dos métodos

```mermaid
flowchart TD
    A["Usuario se registró con correo y contraseña"] --> B["Luego usa Continuar con Google con el mismo correo"]
    B --> C{"Correo de ambos métodos verificado?"}
    C -->|"Sí"| D["Supabase vincula las identidades en un solo usuario"]
    C -->|"No"| E["Riesgo: cuenta no verificada puede ser tomada por otra persona"]
    E --> F["Exigir verificación de correo antes de permitir uso de la cuenta"]
```

Por eso es importante **mantener obligatoria la confirmación de correo**: evita que alguien "pre-registre" el correo de otra persona con una contraseña propia.

---

## 7. Sesión, rutas protegidas y cierre de sesión

```mermaid
flowchart TD
    A["Usuario abre la app"] --> B["auth.getSession lee sesión local"]
    B --> C{"Existe sesión?"}
    C -->|"No"| D["Redirigir a /login"]
    C -->|"Sí"| E{"Access token vigente?"}
    E -->|"Sí"| G["Acceso permitido"]
    E -->|"No"| F["supabase-js usa el refresh token para obtener nuevo access token"]
    F --> H{"Refresh exitoso?"}
    H -->|"Sí"| G
    H -->|"No"| D
    G --> I["Peticiones a la BD con JWT, RLS aplica auth.uid"]
    I --> J{"Cerrar sesión?"}
    J -->|"Sí"| K["auth.signOut: borra sesión local y revoca refresh token"] --> D
```

Recomendaciones:

- Escucha cambios con `supabase.auth.onAuthStateChange((event, session) => ...)` (eventos `SIGNED_IN`, `SIGNED_OUT`, `TOKEN_REFRESHED`, `PASSWORD_RECOVERY`).
- Valida el usuario en el servidor con `auth.getUser()` (verifica contra Supabase) en lugar de confiar solo en `getSession()` para decisiones sensibles.
- La **protección real** son las políticas RLS; las rutas protegidas del frontend son solo experiencia de usuario.

---

## 8. Recuperación de contraseña (complemento necesario)

```mermaid
flowchart TD
    A["Usuario: Olvidé mi contraseña"] --> B["Ingresa su correo"]
    B --> C["auth.resetPasswordForEmail con redirectTo"]
    C --> D["Mensaje genérico: si el correo existe, recibirás un enlace"]
    D --> E["Usuario abre el enlace con token"]
    E --> F["verifyOtp con type recovery, o sesión de recuperación"]
    F --> G{"Token válido?"}
    G -->|"No"| H["Mostrar error y permitir solicitar otro"] --> B
    G -->|"Sí"| I["Formulario de nueva contraseña"]
    I --> J["auth.updateUser con password"]
    J --> K(["Contraseña actualizada y a login o dashboard"])
```

---

## 9. MFA con TOTP (segundo factor)

Se usa **TOTP** (códigos de 6 dígitos que cambian cada 30 s, con Google Authenticator, Authy, 1Password, etc.). Está incluido en todos los planes de Supabase. El MFA por SMS requiere un proveedor de SMS externo, por eso se descarta para costo cero.

### Conceptos

| Concepto | Significado |
|---|---|
| `aal1` | Sesión con un solo factor (contraseña, Google o enlace por correo) |
| `aal2` | Sesión con segundo factor verificado |
| Factor | Un autenticador inscrito; Supabase guarda el secreto en `auth.mfa_factors` |
| Challenge | Intento de verificación asociado a un factor |

Supabase **no obliga** a usar MFA por sí mismo: tú decides en el frontend y en RLS cuándo exigir `aal2`.

### 9.1 Inscripción (activar MFA)

```mermaid
flowchart TD
    A(["Usuario autenticado: Seguridad, Activar MFA"]) --> B["mfa.enroll con factorType totp"]
    B --> C["Supabase devuelve id del factor, secreto y código QR"]
    C --> D["Mostrar QR y secreto manual para la app autenticadora"]
    D --> E["Usuario escanea el QR e ingresa el primer código de 6 dígitos"]
    E --> F["mfa.challenge con factorId"]
    F --> G["mfa.verify con factorId, challengeId y code"]
    G --> H{"Código válido?"}
    H -->|"No"| I["Mostrar error, permitir reintento"] --> E
    H -->|"Sí"| J["Factor pasa a verified y la sesión sube a aal2"]
    J --> K["Sugerir inscribir un segundo factor como respaldo"]
    K --> L(["MFA activo"])
```

```ts
// 1. Inscribir
const { data, error } = await supabase.auth.mfa.enroll({
  factorType: 'totp',
  friendlyName: 'Mi celular',
});
// data.id -> factorId ; data.totp.qr_code -> imagen del QR ; data.totp.secret -> clave manual

// 2. Desafío y verificación
const { data: ch } = await supabase.auth.mfa.challenge({ factorId: data.id });
const { error: vErr } = await supabase.auth.mfa.verify({
  factorId: data.id,
  challengeId: ch.id,
  code: codigoIngresado,
});
```

Nota: un factor que no se verifica queda como no verificado; limpia los factores sin verificar cuando el usuario abandona la inscripción.

### 9.2 Login con paso de segundo factor

Aplica a **cualquier primer factor** (contraseña, Google, enlace por correo): primero se autentica con el método elegido y después, si el usuario tiene MFA, se sube a `aal2`.

```mermaid
flowchart TD
    A(["Usuario inicia sesión con contraseña, Google o correo"]) --> B["Sesión aal1 creada"]
    B --> C["mfa.getAuthenticatorAssuranceLevel"]
    C --> D{"nextLevel es aal2 y currentLevel es aal1?"}
    D -->|"No: sin MFA inscrito"| E["Acceso al dashboard"]
    D -->|"Sí: tiene MFA"| F["Redirigir a pantalla de verificación MFA"]
    F --> G["mfa.listFactors y elegir factor TOTP verificado"]
    G --> H["Usuario ingresa código de 6 dígitos"]
    H --> I["mfa.challenge y mfa.verify"]
    I --> J{"Resultado"}
    J -->|"Válido"| K["Sesión aal2"] --> E
    J -->|"Inválido"| L["Contador de intentos"] --> M{"Demasiados intentos?"}
    M -->|"No"| H
    M -->|"Sí"| N["Bloqueo temporal y opción de cerrar sesión"]
    J -->|"Perdió el dispositivo"| O["Usar factor de respaldo o flujo de recuperación"]
```

```ts
const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();

if (aal.nextLevel === 'aal2' && aal.currentLevel !== aal.nextLevel) {
  // redirigir a /mfa/verify
}
```

Guard de rutas: además de `ProtectedRoute` (hay sesión), agrega la condición "si `nextLevel` es `aal2`, entonces `currentLevel` debe ser `aal2`".

### 9.3 Aplicar MFA en la base de datos (RLS)

El frontend se puede saltar; **RLS no**. Esta política restrictiva exige `aal2` solo a los usuarios que ya tienen un factor verificado:

```sql
create policy "exigir_aal2_si_tiene_mfa"
on public.profiles
as restrictive
to authenticated
using (
  (select auth.jwt() ->> 'aal') = 'aal2'
  or (
    select count(*) = 0
    from auth.mfa_factors
    where user_id = (select auth.uid())
      and status = 'verified'
  )
);
```

Repite la política en cada tabla sensible. Si quieres MFA obligatorio para todos, usa solo `(select auth.jwt() ->> 'aal') = 'aal2'`.

### 9.4 Recuperación y desactivación

Supabase **no ofrece códigos de recuperación**. Su alternativa documentada es permitir inscribir **más de un factor TOTP (hasta 10)**, de modo que un segundo autenticador sirva de respaldo.

```mermaid
flowchart TD
    A["Usuario pierde su dispositivo con la app autenticadora"] --> B{"Tiene un segundo factor inscrito?"}
    B -->|"Sí"| C["Verificar con el factor de respaldo y llegar a aal2"] --> D["Desinscribir el factor perdido con mfa.unenroll"] --> E["Inscribir un factor nuevo"]
    B -->|"No"| F["Recuperación manual fuera de la app"]
    F --> G["Verificar identidad por un canal confiable y eliminar el factor desde el panel de administración"]
    G --> H["Usuario vuelve a iniciar sesión e inscribe un factor nuevo"]
```

- Desinscribir un factor (`mfa.unenroll`) requiere estar en `aal2`.
- Recomendación de UX: al activar MFA, **obligar o sugerir fuertemente** un segundo factor.
- Alternativa más elaborada (opcional): generar tú códigos de respaldo de un solo uso, guardarlos **hasheados** en una tabla propia con RLS y validarlos desde una Edge Function. Es más trabajo y hay que diseñarlo con cuidado; para el alcance de un proyecto académico, el segundo factor TOTP suele bastar.

### 9.5 Lista de operaciones de la API

| Operación | Método |
|---|---|
| Inscribir | `supabase.auth.mfa.enroll({ factorType: 'totp' })` |
| Crear desafío | `supabase.auth.mfa.challenge({ factorId })` |
| Verificar | `supabase.auth.mfa.verify({ factorId, challengeId, code })` |
| Desafío y verificación juntos | `supabase.auth.mfa.challengeAndVerify({ factorId, code })` |
| Listar factores | `supabase.auth.mfa.listFactors()` |
| Nivel de aseguramiento | `supabase.auth.mfa.getAuthenticatorAssuranceLevel()` |
| Eliminar factor | `supabase.auth.mfa.unenroll({ factorId })` |

---

## 10. Cómo mantenerlo en costo cero

| Pieza | Opción gratuita | Cuidado |
|---|---|---|
| Supabase | Plan Free | Los proyectos inactivos se pausan tras un periodo sin actividad; hay límites de BD, almacenamiento y usuarios activos mensuales |
| Google OAuth | Google Cloud Console sin costo | En modo *Testing* solo funcionan los correos de prueba; para público general hay que publicar la app |
| Envío de correos | **SMTP personalizado gratuito** | El SMTP integrado de Supabase tiene un límite muy bajo de correos por hora y es solo para pruebas |
| CAPTCHA | hCaptcha o Cloudflare Turnstile (ambos con capa gratuita) | Se activa en Authentication → Attack Protection |
| Hosting del frontend | Vercel, Netlify o Cloudflare Pages (capas gratuitas) | Opcional según tu proyecto |

**Importante sobre el correo:** para producción o para una demo con varios usuarios, configura un SMTP propio (por ejemplo Resend o Brevo, ambos con capa gratuita) en *Project Settings → Authentication → SMTP Settings*. Si no, los correos de verificación dejarán de llegar al alcanzar el límite y parecerá que el registro "no funciona".

---

## 11. Recomendaciones para hacerlo más elaborado y seguro

### Seguridad

- **RLS activado en todas las tablas** del esquema `public`; sin políticas, nadie accede.
- **Nunca** exponer `service_role key`. Si necesitas lógica privilegiada, usa **Edge Functions** (también gratuitas dentro de los límites del plan).
- **Redirect URLs estrictas:** solo dominios propios, sin comodines amplios en producción.
- **Política de contraseñas:** mínimo 8 a 12 caracteres; configurable en Authentication → Providers → Email.
- **CAPTCHA** en registro y login para frenar bots y fuerza bruta.
- **Rate limits** de Auth: revisa y ajusta en Authentication → Rate Limits.
- **Mensajes genéricos** en login, registro y recuperación (anti-enumeración).
- **`security definer set search_path = ''`** en funciones disparadas por triggers (como en la sección 2).
- **MFA con TOTP** (sección 9): obligatorio para roles administrador y opcional para usuarios normales, reforzado con RLS exigiendo `aal2`.

### UX

- Estados de carga y deshabilitar botones durante las peticiones.
- Botón **Reenviar correo** con cuenta regresiva de 60 s.
- Medidor de fortaleza de contraseña y botón mostrar/ocultar.
- Mensajes de error traducidos y mapeados por `error.code`, no por texto.
- Recordar la ruta a la que quería ir el usuario y redirigirlo allí tras el login.

### Estructura de carpetas sugerida (frontend)

```
src/
├─ lib/
│  └─ supabaseClient.ts        // createClient con URL y anon key (variables de entorno)
├─ auth/
│  ├─ AuthProvider.tsx          // contexto + onAuthStateChange
│  ├─ useAuth.ts                // hook: user, session, loading
│  ├─ ProtectedRoute.tsx        // guard de rutas
│  └─ authService.ts            // signUp, signIn, signInGoogle, signOut, resend, reset
├─ pages/
│  ├─ Login.tsx
│  ├─ SignUp.tsx
│  ├─ VerifyEmail.tsx           // pantalla "revisa tu correo" + reenviar
│  ├─ AuthCallback.tsx          // exchangeCodeForSession / verifyOtp
│  ├─ ForgotPassword.tsx
│  └─ ResetPassword.tsx
└─ .env                         // VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY (no subir a Git)
```

---

## 12. Checklist de implementación

- [ ] Crear proyecto en Supabase
- [ ] Ejecutar el SQL de `profiles`, RLS y trigger (sección 2)
- [ ] Activar *Confirm email* en Authentication → Providers → Email
- [ ] Personalizar plantillas de correo (enlace con `token_hash` o código OTP)
- [ ] Configurar Site URL y Redirect URLs
- [ ] Crear credenciales OAuth en Google Cloud y activarlas en Supabase
- [ ] Configurar SMTP personalizado gratuito
- [ ] Activar CAPTCHA y revisar rate limits
- [ ] Implementar `AuthProvider`, rutas protegidas y callback
- [ ] Implementar inscripción TOTP (QR, verificación y segundo factor de respaldo)
- [ ] Implementar pantalla de verificación MFA y guard por `aal2`
- [ ] Agregar políticas RLS restrictivas con `aal2` en tablas sensibles
- [ ] Probar: registro, verificación, reenvío, login, Google, MFA, recuperación, cierre de sesión, token expirado
- [ ] Verificar que ninguna tabla pública quede sin RLS (Supabase Security Advisor)

---

## 13. Casos de prueba mínimos

| # | Caso | Resultado esperado |
|---|---|---|
| 1 | Registro con correo válido | Se crea usuario sin confirmar y llega correo |
| 2 | Login sin confirmar correo | Rechazado con opción de reenviar |
| 3 | Verificar con token válido | `email_confirmed_at` se llena y entra con sesión |
| 4 | Verificar con token expirado o reusado | Error y opción de reenviar |
| 5 | Registro con correo ya existente | Mismo mensaje genérico, sin revelar existencia |
| 6 | Login con contraseña incorrecta | Mensaje genérico |
| 7 | Google con cuenta nueva | Usuario y perfil creados, sesión activa |
| 8 | Google con correo ya registrado | Se vincula o inicia sesión sin duplicar usuario |
| 9 | Acceso a datos de otro usuario por API | Bloqueado por RLS |
| 10 | Cerrar sesión y volver atrás | Redirige a login |
| 11 | Inscribir TOTP con código correcto | Factor verificado y sesión `aal2` |
| 12 | Inscribir TOTP con código incorrecto | Error y factor sin verificar |
| 13 | Login con MFA activo, solo primer factor | Redirige a verificación MFA, sin acceso a datos protegidos |
| 14 | Consulta a tabla protegida con sesión `aal1` y MFA inscrito | Bloqueada por la política RLS `aal2` |
| 15 | Login con Google y MFA inscrito | Exige también el código TOTP |
| 16 | Perder el dispositivo con un segundo factor inscrito | Recuperación con el factor de respaldo |
| 17 | Desinscribir un factor sin estar en `aal2` | Rechazado |
