# 06 — Detección de Conectividad y Modo Offline con `connectivity_plus`

> Arquitectura del servicio de red, ciclo de vida reactivo, integración con la cartografía offline y visualización según los estándares de UX sancarlista (`UX-X-006`).

---

## 1. Visión General y Propósito

En el campus central de la Universidad de San Carlos de Guatemala (USAC) —especialmente en sótanos de edificios docentes (ej. S-12, T-3), pasillos cerrados o áreas con alta saturación celular— los estudiantes experimentan pérdidas frecuentes de señal o fluctuaciones intermitentes entre Wi-Fi universitario y redes móviles (3G/4G).

Para asegurar que la experiencia cartográfica nunca se congele ni lance excepciones de socket no controladas, se implementó la biblioteca **`connectivity_plus`** (v7.3.2) coordinada a través de un servicio transversal centralizado: **[`ConnectivityService`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/core/services/connectivity_service.dart)**.

### Objetivos Clave
1. **Detección Preventiva**: Determinar si existe una interfaz de red operativa antes de disparar solicitudes HTTP hacia Cloudflare R2 o consultas RPC hacia Supabase.
2. **Ahorro de Batería y Recursos**: Evitar la apertura inútil de sockets y esperas de timeout (6 segundos) cuando el dispositivo carece de conexión.
3. **Reactividad en Tiempo Real**: Notificar instantáneamente a las pantallas mediante un `Stream<bool>` cuando la red conmuta entre conectado y desconectado.
4. **Auto-resincronización**: Al recuperar la señal, el sistema retoma de fondo la sincronización de archivos cartográficos modificados sin requerir que el usuario reinicie la app.
5. **Cumplimiento Estricto de UX**: Presentar el componente canónico **[`OfflineBanner`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/shared/widgets/network_state_widgets.dart)** cumpliendo la especificación **`UX-X-006`** de [`/docs/ux/10-transversales.md`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/docs/ux/10-transversales.md).

---

## 2. Diagrama de Arquitectura y Flujo Reactivo

```mermaid
flowchart TD
    subgraph OS["Sistema Operativo (Android / iOS / Desktop / Web)"]
        NetDriver["Driver de Red (Wi-Fi, Celular, Ethernet)"]
    end

    subgraph Plugin["connectivity_plus (v7.3.2)"]
        NativeChannel["Platform Channels / Method & Event Channels"]
    end

    subgraph Core["Capa Core de la Aplicación"]
        CS["ConnectivityService (Singleton)"]
        IsConn["Future&lt;bool&gt; isConnected"]
        ConnStream["Stream&lt;bool&gt; onConnectivityChanged (distinct)"]
        DescHelper["getConnectionTypeDescription()"]
    end

    subgraph FeatureMap["Módulo de Mapa Cartográfico"]
        MSS["MapSyncService (Cloudflare R2 Sync)"]
        CMS["CampusMapScreen (State & UI)"]
        OffBanner["OfflineBanner (UX-X-006)"]
        Repo["SupabaseCampusCommunityRepository"]
    end

    NetDriver --> NativeChannel
    NativeChannel --> CS
    CS --> IsConn
    CS --> ConnStream
    CS --> DescHelper

    MSS -->|1. Consulta isConnected previo a HTTP| IsConn
    CMS -->|2. Se suscribe en initState| ConnStream
    CMS -->|3. Si !_isOnline: renderiza| OffBanner
    OffBanner -->|4. Al pulsar 'Reintentar'| IsConn
    ConnStream -->|5. Si recupera red (wasOffline -> online)| MSS
    Repo -->|6. Fallback a caché local si offline| IsConn
```

---

## 3. Implementación del Servicio: `ConnectivityService`

El servicio reside en [`lib/core/services/connectivity_service.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/core/services/connectivity_service.dart) y sigue el patrón Singleton con soporte de inyección para pruebas unitarias:

```dart
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity;

  ConnectivityService._internal({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  @visibleForTesting
  factory ConnectivityService.custom({required Connectivity connectivity}) {
    return ConnectivityService._internal(connectivity: connectivity);
  }

  @visibleForTesting
  static bool? debugIsConnected;

  /// Retorna true si hay al menos una interfaz activa distinta a 'none'.
  Future<bool> get isConnected async {
    if (debugIsConnected != null) return debugIsConnected!;
    try {
      final results = await _connectivity.checkConnectivity();
      return isOnline(results);
    } catch (e) {
      // Fallback a online en caso de plataformas sin canal nativo registrado
      return true;
    }
  }

  /// Stream reactivo de booleanos con filtrado de duplicados consecutivos (.distinct())
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map(isOnline)
        .distinct();
  }

  /// Helper de validación de interfaces activas
  static bool isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Traducción semántica a español es-GT según lineamientos de UX
  static String getConnectionTypeDescription(List<ConnectivityResult> results) {
    if (!isOnline(results)) return 'Sin conexión';
    if (results.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.mobile)) return 'Datos móviles';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth Tethering';
    return 'Red activa';
  }
}
```

---

## 4. Integración en los Componentes del Mapa

### 4.1. `MapSyncService` (Sincronización R2 Inteligente)
En [`lib/features/map/services/map_sync_service.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/map/services/map_sync_service.dart), el método `syncMapAssetsIfNeeded` evalúa la conectividad antes de intentar cualquier llamada de red:

```dart
static Future<bool> syncMapAssetsIfNeeded({
  http.Client? httpClient,
  SharedPreferences? preferences,
  ConnectivityService? connectivityService,
}) async {
  final connectivity = connectivityService ?? ConnectivityService.instance;
  final isOnline = await connectivity.isConnected;
  if (!isOnline) {
    debugPrint('MapSyncService: Dispositivo sin conexión. Se omite comprobación con R2.');
    return false; // Salida inmediata sin socket ni timeout
  }

  // Si está online, procede a verificar map_version.json en Cloudflare R2...
}
```

### 4.2. `CampusMapScreen` (UI Reactiva y Auto-resincronización)
En [`lib/features/map/screens/campus_map_screen.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/map/screens/campus_map_screen.dart):
1. **Suscripción de Ciclo de Vida**:
   ```dart
   @override
   void initState() {
     super.initState();
     // ...
     _initConnectivity();
     _initMapData();
   }

   void _initConnectivity() async {
     _isOnline = await ConnectivityService.instance.isConnected;
     if (mounted) setState(() {});
     _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
       if (mounted) {
         final wasOffline = !_isOnline;
         setState(() => _isOnline = isOnline);
         if (wasOffline && isOnline) {
           // Al recuperar señal, sincroniza activos modificados con R2
           MapSyncService.syncMapAssetsIfNeeded();
         }
       }
     });
   }

   @override
   void dispose() {
     _connectivitySub?.cancel();
     // ...
     super.dispose();
   }
   ```

2. **Renderizado Condicional del `OfflineBanner`**:
   Cuando el dispositivo pierde conexión, se despliega el banner superior sin bloquear la interacción con el mapa ni con el directorio local:
   ```dart
   return Scaffold(
     backgroundColor: theme.scaffoldBackgroundColor,
     body: SafeArea(
       top: false,
       child: Column(
         children: [
           if (!_isOnline)
             OfflineBanner(
               onRetry: () async {
                 final online = await ConnectivityService.instance.isConnected;
                 if (mounted) setState(() => _isOnline = online);
                 if (online) MapSyncService.syncMapAssetsIfNeeded();
               },
             ),
           Expanded(
             child: isMobile
                 ? _buildMobileLayout(context, theme, isDark, mapTheme)
                 : _buildDesktopLayout(context, theme, isDark, mapTheme),
           ),
         ],
       ),
     ),
   );
   ```

---

## 5. Especificaciones Visuales y Accesibilidad (`UX-X-006`)

El widget [`OfflineBanner`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/lib/features/shared/widgets/network_state_widgets.dart) cumple al 100% las directrices de diseño sancarlista:

| Elemento | Tema Claro | Tema Oscuro | Estándar / Accesibilidad |
|---|---|---|---|
| **Fondo** | `#FEF3C7` (Ámbar suave) | `#451A03` (Ámbar muy oscuro) | Contraste adecuado para fondos de alerta |
| **Borde Inferior** | `#F59E0B` (1 px) | `#D97706` (1 px) | Separador visual nítido |
| **Icono** | `Icons.wifi_off` (`#B45309`, 16 px) | `Icons.wifi_off` (`#FBBF24`, 16 px) | Semántica de conectividad ausente |
| **Texto Informativo** | `"Sin conexión. Mostrando contenido en caché."` | `"Sin conexión. Mostrando contenido en caché."` | Fuente `w600` de 12 px (`#92400E` / `#FDE68A`) |
| **Botón 'Reintentar'** | Tamaño táctil mínimo 48×48 dp | Tamaño táctil mínimo 48×48 dp | WCAG 2.2 AA (Target Size) |

---

## 6. Cobertura de Pruebas Automatizadas

Se añadieron pruebas unitarias y de widgets especializadas para garantizar la confiabilidad del subsistema:

1. **[`test/core/services/connectivity_service_test.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/test/core/services/connectivity_service_test.dart)**:
   - Evaluación precisa de listas de `ConnectivityResult` (`wifi`, `mobile`, `ethernet`, `none`, vacía, combinadas).
   - Traducción de etiquetas en español (`Wi-Fi`, `Datos móviles`, `Sin conexión`).
   - Mocks de plataforma e inyección de dependencias.
   - Filtrado `.distinct()` en el stream reactivo (ignora duplicados consecutivos `[wifi] -> [mobile]`).

2. **[`test/features/map/map_sync_service_test.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/test/features/map/map_sync_service_test.dart)**:
   - Verifica que `syncMapAssetsIfNeeded` no intente conexiones HTTP cuando `ConnectivityService.debugIsConnected = false`.

3. **[`test/features/map/campus_map_screen_test.dart`](file:///C:/Users/HP/Documents/Programacion/Flutter/Comunidad_USAC/comunidad_universitaria/test/features/map/campus_map_screen_test.dart)**:
   - Comprueba que la pantalla del mapa dibuje de inmediato el `OfflineBanner` con el texto de advertencia y el botón *"Reintentar"* cuando se encuentra desconectada.
