# Comunidad Universitaria · Suite de Pruebas E2E (`integration_test`)

Este directorio contiene pruebas de integración de la aplicación Flutter de **Comunidad USAC**, ejecutadas mediante el paquete oficial `integration_test`. **PEMTREE es un proyecto cliente separado**; `sso_flow_test.dart` solo prueba la ruta y algunos estados de la pantalla de autorización de Comunidad USAC, no una integración real con PEMTREE ni un intercambio OAuth en vivo.

---

## 📁 Estructura de Archivos

```
integration_test/
├── helpers/
│   └── app_launcher.dart        # Helper para inicializar SupabaseConfig y montar la app
├── guest_navigation_test.dart   # Flujo de navegación de invitado (tabs, modales, responsive)
├── sso_flow_test.dart           # Prueba de pantalla/ruta SSO; no valida OAuth real con PEMTREE
├── forum_flow_test.dart         # Flujo real de foro estudiantil (crear, leer, dar like, borrar)
├── marketplace_flow_test.dart   # Flujo real de marketplace (crear, pausar, alternar upvote, borrar)
├── groups_flow_test.dart        # Flujo real de grupos estudiantiles (crear grupo, upvotes, borrar)
├── profile_flow_test.dart       # Flujo real de perfil (modificar seudónimo, modal de validación)
└── README.md                    # Esta documentación
```

---

## 🚀 Cómo Ejecutar las Pruebas E2E

> **Plataforma:** los comandos de esta guía y `scripts/e2e/run_e2e.sh` están
> preparados para Bash/Linux; el runner usa Bash y selecciona el dispositivo
> `linux`. No ejecutes esos bloques `export` ni el script directamente en
> PowerShell. Flutter detecta Windows y Edge en el entorno del proyecto, pero
> la prueba `guest_navigation_test.dart -d windows` terminó por timeout tras
> 120 segundos el 2026-11-06; por ello no se documenta como ejecución Windows
> validada. Hace falta probarla y preparar instrucciones/runner específico antes
> de dar soporte E2E a Windows.

### 1. Modo Invitado / Sin Backend (Completamente Offline)

Las pruebas `guest_navigation_test.dart` y `sso_flow_test.dart` no requieren conexión a base de datos y se ejecutan directamente:

```bash
cd comunidad_universitaria
flutter test integration_test/guest_navigation_test.dart -d linux
flutter test integration_test/sso_flow_test.dart -d linux
```

### 2. Modo Completo con Backend Local Supabase

Los flujos que interactúan con la base de datos (`forum_flow_test.dart`, `marketplace_flow_test.dart`, `groups_flow_test.dart`, `profile_flow_test.dart`) están **protegidos (gated)** mediante variables de entorno y `--dart-define`. Si no detectan un backend local válido, se omiten (`skip`) automáticamente sin fallar.

Para ejecutarlos contra tu stack local de Supabase:

1. **Inicia el stack local de Supabase**:
   ```bash
   supabase start
   ```

2. **Obtén las credenciales locales**:
   Ejecuta `supabase status` para copiar la URL del API (por defecto `http://127.0.0.1:54321`) y la `anon key`.

3. **Ejecuta la suite completa** (recomendado: un proceso por archivo):
   ```bash
   export SUPABASE_URL=http://127.0.0.1:54321
   export SUPABASE_ANON_KEY=tu_clave_anon_local_aqui
   ./scripts/e2e/run_e2e.sh
   ```

   > En Linux desktop, encadenar todos los archivos en una sola invocación
   > (`flutter test integration_test -d linux`) puede fallar al lanzar la app
   > con `Error waiting for a debug connection`. El runner `run_e2e.sh` ejecuta
   > cada archivo en un proceso separado para evitarlo. Para un solo archivo:
   > `flutter test integration_test/forum_flow_test.dart -d linux --dart-define=...`

Los flujos E2E con escrituras inician sesión con el usuario E2E sembrado por
`supabase/seed.sql` (`e2e@test.com` / `password123`). Esa cuenta es solo para el
entorno local. `supabase db reset` reconstruye la base local, vuelve a aplicar
las migraciones y carga el seed, pero **borra los datos locales existentes**.
Úsalo solo si aceptas perderlos; no ejecutes un reset enlazado a remoto ni uses
esa cuenta de prueba en el proyecto alojado.

---

## 🖥️ Ejecución Headless en CI / Linux (Xvfb)

En servidores Linux sin pantalla física (como runners de GitHub Actions):

```bash
sudo apt-get install -y xvfb libgtk-3-dev
export SUPABASE_URL=http://127.0.0.1:54321
export SUPABASE_ANON_KEY=tu_clave_anon_local_aqui
xvfb-run -a ./scripts/e2e/run_e2e.sh
```

---

## 🔒 Mecanismo de Seguridad y Gating

Para garantizar que los tests **nunca** se ejecuten por error contra la base de datos de producción remota:
- El helper `isLocalSupabaseConfigured` valida estrictamente que el host de `SUPABASE_URL` pertenezca a direcciones locales (`127.0.0.1`, `localhost`, `10.0.2.2`, `supabase`).
- Si la URL apunta a un dominio remoto como `*.supabase.co` o no está definida, todos los tests con escrituras reales se marcan como `skip` de manera automática y preventiva.
