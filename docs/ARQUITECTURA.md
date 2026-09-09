# Arquitectura de `flips_app` y plan de proyecto base

> **Propósito de este documento**
>
> Tiene dos lectores:
>
> 1. Quien entra a mantener **esta** app (Diario Tiempo HN) y necesita entender cómo está armada.
> 2. Quien va a levantar el **repo base white-label** para otros medios y necesita saber qué copiar,
>    qué generalizar y qué no repetir.
>
> Las secciones **A** describen lo que existe hoy. Las secciones **B** son el plano de construcción
> del proyecto base. Si vas a arrancar el repo nuevo, leé A para entender las decisiones y ejecutá B.

**Estado del análisis:** repo `flips_app`, versión `1.1.1+7`, rama `main`.
Medición sobre 106 archivos Dart / 17,236 LOC en `lib/`.

---

## Índice

- [A. Arquitectura actual](#a-arquitectura-actual)
  - [A.1 Stack y versiones](#a1-stack-y-versiones)
  - [A.2 Modelo de capas](#a2-modelo-de-capas)
  - [A.3 Convenciones](#a3-convenciones)
  - [A.4 Estructura de carpetas](#a4-estructura-de-carpetas)
  - [A.5 Capa de modelos](#a5-capa-de-modelos)
  - [A.6 Capa de servicios](#a6-capa-de-servicios)
  - [A.7 Providers y controllers](#a7-providers-y-controllers)
  - [A.8 Pantallas y navegación](#a8-pantallas-y-navegación)
  - [A.9 Design system y globals](#a9-design-system-y-globals)
  - [A.10 Utils](#a10-utils)
  - [A.11 Flujos críticos](#a11-flujos-críticos)
  - [A.12 Capa de plataforma](#a12-capa-de-plataforma)
  - [A.13 Pruebas](#a13-pruebas)
  - [A.14 Deuda técnica](#a14-deuda-técnica)
- [B. Proyecto base white-label](#b-proyecto-base-white-label)
  - [B.1 Puntos de acoplamiento a la marca](#b1-puntos-de-acoplamiento-a-la-marca)
  - [B.2 Diseño de `BrandConfig`](#b2-diseño-de-brandconfig)
  - [B.3 Feature flags](#b3-feature-flags)
  - [B.4 Flavors de build](#b4-flavors-de-build)
  - [B.5 Estructura propuesta del repo nuevo](#b5-estructura-propuesta-del-repo-nuevo)
  - [B.6 Contrato de backend](#b6-contrato-de-backend)
  - [B.7 Orden de construcción](#b7-orden-de-construcción)
  - [B.8 Checklist de alta de un medio](#b8-checklist-de-alta-de-un-medio)
  - [B.9 Riesgos a resolver antes de escalar](#b9-riesgos-a-resolver-antes-de-escalar)

---

# A. Arquitectura actual

## A.1 Stack y versiones

| Concepto | Valor |
|---|---|
| Framework | Flutter `3.35.5` (fijado en `.fvmrc` **y** en `codemagic.yaml`) |
| Dart SDK | `^3.7.0` |
| Gestión de estado | `provider` (ChangeNotifier) |
| HTTP | `http` (cliente propio en `lib/services/http.service.dart`) |
| Almacenamiento seguro | `flutter_secure_storage` (tokens) |
| Almacenamiento simple | `shared_preferences` (preferencias, caché, banderas) |
| Push | `firebase_messaging` + `flutter_local_notifications` |
| Analítica | `firebase_analytics` |
| Publicidad | `google_mobile_ads` (Google Ad Manager, no AdMob directo) |
| PDF | `syncfusion_flutter_pdfviewer` |
| Voz | `flutter_tts` |
| OTA | Shorebird |
| CI/CD | Codemagic (workflow iOS → TestFlight) |
| Plataformas activas | Android, iOS |

> Las carpetas `web/`, `windows/`, `linux/`, `macos/` existen por el scaffold de Flutter
> pero **no están soportadas**: no hay configuración de Firebase ni de OAuth para ellas.

**Idioma y locale:** la app fuerza `Locale('es','ES')` como único locale soportado
(`lib/main.dart`), y los formatos de moneda usan `es_HN` (`lib/utils/formatters.dart`).
Son dos lugares distintos — ver [B.1](#b1-puntos-de-acoplamiento-a-la-marca).

---

## A.2 Modelo de capas

El proyecto usa un **MVC con Provider**: cuatro capas más un contenedor de estado.

```
   ┌──────────────┐   acción del usuario   ┌────────────────┐
   │    SCREEN    │ ─────────────────────► │   CONTROLLER   │
   │   (Widget)   │                        │  (orquesta)    │
   └──────┬───────┘                        └────────┬───────┘
          │                                         │ llama
          │ context.watch<XProvider>()              ▼
          │                                ┌────────────────┐    HTTP     ┌──────────┐
          │                                │    SERVICE     │ ──────────► │ Backend  │
          │                                │     (I/O)      │ ◄────────── │ Next.js  │
          │                                └────────┬───────┘             └──────────┘
          │                                         │ fromJson
          │                                         ▼
          │                                ┌────────────────┐
          │                                │     MODEL      │
          │                                │     (DTO)      │
          │                                └────────┬───────┘
          │                                         │
          │        notifyListeners()       ┌────────▼───────┐
          └────────────────────────────────│    PROVIDER    │
                                           │    (estado)    │
                                           └────────────────┘
```

### Responsabilidad de cada capa

| Capa | Hace | **No** hace |
|---|---|---|
| **Model** | Parsear JSON (`fromJson`), exponer datos inmutables, `copyWith` | Llamadas de red, lógica de UI |
| **Service** | HTTP, SDKs nativos, disco, SharedPreferences. Devuelve modelo o `null` | Tocar `BuildContext`, atrapar errores para mostrarlos |
| **Provider** | Guardar `loading`, `errorMessage` y los datos. Notificar | Lógica de negocio, llamar servicios |
| **Controller** | `try/catch`, traducir excepciones a mensajes, prender/apagar `loading` | Parsear JSON, construir widgets |
| **Screen** | Pintar, leer del provider, disparar controllers | Llamar servicios directamente |

### Reglas del proyecto

1. **El Service nunca conoce `BuildContext`.** Si un service necesitara navegar, se
   resuelve con el `navigatorKey` global de `lib/constants.dart`
   (así lo hace `SessionService.expireAndRedirect`).
2. **Los `try/catch` viven en el Controller.** El Service deja que la excepción suba.
3. **`SocketException` y `TimeoutException` se propagan sin envolver**, para que la pantalla
   pueda diferenciar "sin internet" de "error del servidor" y mostrar caché.
4. **El dinero se maneja en centavos enteros** (`priceCents`, `montoCentavos`, `totalCentavos`).
   El formateo ocurre solo al pintar, en `AppFormatters.moneyFromCentavos`.
5. **Un servicio, un dominio.** Si un service pasa de ~300 líneas, se parte.

### Ejemplo canónico — copiá este patrón para toda feature nueva

Feature `paquetes`, cuatro archivos:

```dart
// lib/models/paquetes.model.dart
class PaquetesResponse {
  final List<PaqueteModel> data;
  factory PaquetesResponse.fromJson(Map<String, dynamic> json) { ... }
}

// lib/services/paquetes.service.dart
class PaquetesService {
  final HttpService _httpService = HttpService();

  Future<List<PaqueteModel>?> obtenerPaquetes() async {
    final response = await _httpService.get('${apiUrl}paquetes');
    if (response.statusCode != 200) return null;          // null = falla controlada
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PaquetesResponse.fromJson(body).data;
  }
}

// lib/providers/paquetes.provider.dart
class PaquetesProvider with ChangeNotifier {
  bool _loading = false;
  String _errorMessage = '';
  List<PaqueteModel> _paquetes = [];
  // getters + setters que llaman notifyListeners()
}

// lib/controllers/paquetes.controller.dart
class PaquetesController {
  final PaquetesService _service = PaquetesService();

  Future<void> cargarPaquetes(BuildContext context) async {
    final provider = Provider.of<PaquetesProvider>(context, listen: false);
    provider.loading = true;
    provider.setError('');
    try {
      final paquetes = await _service.obtenerPaquetes();
      if (paquetes == null) {
        provider.setError('No se pudo obtener tus paquetes.');
      } else {
        provider.setPaquetes(paquetes);
      }
    } on SocketException {
      provider.setError('Sin conexión. Verifica tu internet e intenta nuevamente.');
    } catch (_) {
      provider.setError('Ocurrió un error al cargar los paquetes.');
    }
    provider.loading = false;
  }
}
```

---

## A.3 Convenciones

### Nombres de archivo

| Sufijo | Ejemplo | Capa |
|---|---|---|
| `.model.dart` | `noticias.model.dart` | DTO |
| `.service.dart` | `auth.service.dart` | I/O |
| `.provider.dart` | `noticias.provider.dart` | Estado |
| `.controller.dart` | `noticias.controller.dart` | Orquestación |
| `.screen.dart` | `home.screen.dart` | Pantalla completa |
| `.widget.dart` | `ad_banner.widget.dart` | Componente reutilizable |
| `.util.dart` | `noticia_link.util.dart` | Función pura |
| `.config.dart` | `google_sign_in.config.dart` | Configuración |

Archivos en `snake_case`, clases en `PascalCase`, todo el dominio en **español**
(`obtenerPaquetes`, `cargarNoticias`, `AccesoUsuario`). Mantené el idioma consistente:
mezclar `getPackages` con `obtenerPaquetes` en el mismo repo hace que nadie encuentre nada.

### Organización de pantallas

Una carpeta por feature. Si la feature tiene componentes propios, subcarpeta `widgets/`:

```
screens/noticias/
├── noticias.screen.dart
├── noticia_detalle.screen.dart
├── categoria_noticias.screen.dart
├── noticias_offline.screen.dart
├── noticia_desde_push.screen.dart
└── widgets/
    ├── news_cards.dart
    ├── noticias_header.dart
    ├── category_widgets.dart
    ├── search_bar.dart
    └── shared_widgets.dart
```

Los componentes usados por **más de una** feature suben a `lib/globals/widgets/`
y se exportan desde el barrel `widgets.dart`.

---

## A.4 Estructura de carpetas

```
flips_app/
├── lib/                                17,236 LOC · 106 archivos
│   ├── main.dart                       219 LOC — bootstrap + tema + MultiProvider
│   ├── constants.dart                   71 LOC — urlBase, apiUrl, GlobalKeys, AppAssets
│   ├── config/                           1 archivo ·    71 LOC
│   │   └── google_sign_in.config.dart      client IDs OAuth
│   ├── models/                          10 archivos · 1,728 LOC
│   ├── services/                        19 archivos · 3,681 LOC
│   ├── providers/                        9 archivos ·   542 LOC
│   ├── controllers/                      9 archivos ·   622 LOC
│   │   └── login/login_flows.controller.dart
│   ├── screens/                         27 archivos · 8,874 LOC
│   │   ├── home/            noticias/          diarios_digitales/
│   │   ├── login/           notificaciones/    onboarding/
│   │   ├── mi_perfil/       paquetes/          mis_facturas/
│   │   ├── mis_pagos/       mis_suscripcion/   sitio_web/
│   │   └── shared/          componentes compartidos entre features
│   ├── globals/
│   │   ├── widgets/                     20 archivos · 1,031 LOC — design system
│   │   └── functions/                    5 archivos ·    97 LOC — helpers
│   └── utils/                            4 archivos ·   371 LOC
│
├── android/
│   ├── app/build.gradle.kts             namespace + applicationId
│   ├── app/google-services.json         config Firebase Android
│   └── app/src/main/AndroidManifest.xml permisos, canal de push, App ID de Ads
├── ios/
│   ├── Runner/Info.plist                CFBundleDisplayName, esquemas OAuth
│   ├── Runner/Runner.entitlements       push
│   ├── Runner/GoogleService-Info.plist  config Firebase iOS
│   └── Runner.xcodeproj/                PRODUCT_BUNDLE_IDENTIFIER
│
├── assets/images/logo.png
├── test/                                 9 archivos
├── docs/
│   ├── ARQUITECTURA.md                  (este archivo)
│   └── google_sign_in_setup.md
├── codemagic.yaml                       CI/CD iOS → Shorebird → TestFlight
├── shorebird.yaml                       app_id de OTA
├── .fvmrc                               Flutter 3.35.5
├── analysis_options.yaml                flutter_lints 5
└── pubspec.yaml
```

---

## A.5 Capa de modelos

10 archivos, 1,728 LOC. Todos exponen `fromJson`; los que se mutan exponen `copyWith`.

| Archivo | Clases | Campos clave |
|---|---|---|
| `login_response.model.dart` | `LoginResponseModel`, `LoginUserData` | `token`, `refreshToken`, `expiresAt`, `refreshExpiresAt`, `sessionCookie`, `tieneRefreshToken` |
| `mi_perfil.model.dart` | `MiPerfilModel`, `RolModel`, `SuscripcionActivaModel` | `id`, `nombre`, `email`, `fotoUrl`, `rol`, `suscripcionActiva` |
| `noticias.model.dart` | `NoticiaModel`, `NoticiaContentBlock`, `NoticiaGalleryItem`, `CategoriaNoticiaModel` | El más complejo del proyecto — ver abajo |
| `diarios_digitales.model.dart` | `DiariosDigitalesResponse`, `DiarioDigitalModel`, `PdfAccessModel` | `pdfSignedUrl` + `pdfSignedUrlExpiresAt`, `coverUrl`, `anio`, `mes` |
| `paquetes.model.dart` | `PaquetesResponse`, `PaqueteModel` | `priceCents`, `currency`, `interval`, `intervalCount`, `metadata` |
| `mis_suscripcion.model.dart` | `SuscripcionModel`, `SuscripcionUsuarioModel`, `SuscripcionPlanModel` | `estado`, `precioCentavos`, `inicioPeriodoActual`, `finPeriodoActual` |
| `mis_pagos.model.dart` | `PagoModel`, `PagoUsuarioModel`, `PagoMetodoModel`, `PagoSuscripcionModel` | `montoCentavos`, `idPagoPasarela`, `claveIdempotencia`, `liquidadoEn` |
| `mis_facturas.model.dart` | `MisFacturasResponse`, `FacturaModel` | `totalCentavos`, `emitidaEn`, `estado`, `pdfUrl` |
| `suscripcion_checkout.model.dart` | `WebCheckoutSessionResponse`, `ContratarSuscripcionResponse` | `url`, `expiresInSeconds`, `paymentUrl`, `completeUrl` |
| `usuario.model.dart` | `Usuario` | **Sin referencias — código muerto** |

### `NoticiaModel` en detalle

Es el modelo central del producto y el que más piensa:

```dart
class NoticiaModel {
  final int id;
  final String link;                            // URL canónica en el sitio
  final String slug;                            // clave para deep links de push
  final DateTime? date;
  final String title;
  final String excerpt;
  final String content;                         // HTML crudo (compatibilidad)
  final List<NoticiaContentBlock> contentBlocks; // representación tipada
  final String imageUrl;
  final String imageAlt;
  final String localImagePath;                  // solo poblado en modo offline
  final List<int> categories;

  bool get hasImage;
  bool get tieneContenido;   // el listado NO trae contenido; el detalle sí
  NoticiaModel copyWith({...});
  NoticiaModel mergeDetalle(NoticiaModel detalle);
}
```

**`NoticiaContentBlock`** es un bloque tipado con enum `NoticiaContentBlockType`:
`text` · `image` · `link` · `gallery` · `video`. Cada uno guarda `sourceHtml` por si hay
que caer al render crudo.

**Por qué existe `mergeDetalle`:** la tarjeta del listado y el detalle vienen de endpoints
distintos. Al abrir una nota se fusiona el detalle sobre la tarjeta **sin pisar** lo que solo
existe en local (`localImagePath` de la copia offline). Reemplazar el objeto entero perdía
la imagen descargada.

---

## A.6 Capa de servicios

19 archivos, 3,681 LOC. Es donde vive toda la complejidad real.

### Infraestructura

#### `http.service.dart` (5.5 KB)

Cliente base de toda la app. Métodos `get`, `post`, `put`, `patch`, `delete`.

Responsabilidades:
- Arma cabeceras: `Accept`, `Content-Type`, `Authorization: Bearer <jwt>`, `Cookie`.
- Ante un `401`: llama a `SessionService.renovarSesion()` y **reintenta una sola vez**.
- Si el reintento vuelve a dar `401`, dispara `expireAndRedirect` y lanza `SessionExpiredException`.
- **Si no hay token pero sí sesión guardada**, lanza `SocketException` en vez de cerrar sesión.

> Ese último punto es una decisión deliberada y vale la pena conservarla: cerrar sesión ahí
> echaba del sistema a quien solo se había quedado sin señal. Tratarlo como falta de conexión
> permite que las pantallas con caché sigan mostrando contenido.

El reintento es **único** a propósito: si con un token recién emitido el servidor sigue
rechazando, el problema no es el token y reintentar solo alarga la espera.

#### `session.service.dart` (15 KB)

Toda la vida de la sesión. API estática.

| Método | Función |
|---|---|
| `getValidToken()` | Devuelve un access token vigente, renovando si hace falta |
| `renovarSesion()` | Usa el refresh token; **deduplicada** para que N peticiones en paralelo disparen un solo refresh |
| `guardarTokens(LoginResponseModel)` | Persiste en `flutter_secure_storage` |
| `hasValidSession()` / `hasStoredSession()` | Distingue "token vigente" de "hay algo guardado" |
| `expireAndRedirect({message})` | Limpia y navega a login vía `navigatorKey` global |
| `cerrarSesionEnServidor()` | Logout remoto |
| `isJwtExpired()`, `fotoUrlFromToken()` | Decodifica el payload del JWT |
| `_venceEnBreve()` | Renueva **antes** de que expire, no cuando ya expiró |

El access token dura una hora, así que expirar es rutina y no excepción. Toda la estrategia
está construida sobre esa premisa.

### Autenticación

#### `auth.service.dart` (7.9 KB)

Cinco flujos de entrada:

| Método | Endpoint |
|---|---|
| `login(email, password)` | credenciales clásicas |
| `requestEmailOtp(email)` → `verifyEmailOtp(email, otp)` → `completeRegister(...)` | alta por código |
| `requestResetOtp(email)` → `confirmPasswordReset(...)` | recuperar contraseña |
| `loginWithGoogle({idToken})` | Google Sign-In |
| `obtenerSuscripcionActiva()` | consulta con caché local |

#### `acceso_usuario.service.dart` (5.5 KB)

**Puerta única de permisos.** Expone un objeto inmutable `AccesoUsuario`:

```dart
class AccesoUsuario {
  final bool esAdmin;
  final bool tieneSuscripcionActiva;
  final bool resuelto;                // false mientras la consulta va en vuelo

  bool get ocultarAnuncios  => esAdmin || tieneSuscripcionActiva;
  bool get mostrarAnuncios  => resuelto && !ocultarAnuncios;
  bool get puedeLeerOffline => esAdmin || tieneSuscripcionActiva;
}
```

Dos decisiones que hay que preservar al templatizar:

1. **Guarda los hechos crudos y deriva cada política.** Antes un único `hideAds` decidía
   anuncios *y* guardado offline: coincidían por casualidad, y tocar una regla arrastraba la
   otra sin que nadie se enterara.
2. **El estado `sinResolver` existe para no parpadear.** Mientras no se sabe quién es el
   usuario no se pide ningún anuncio; si no, un suscriptor alcanzaba a ver el banner en el
   primer frame.

### Contenido

#### `noticias.service.dart` (18 KB)

| Grupo | Métodos |
|---|---|
| Consulta | `obtenerNoticias({page, perPage, categoria, busqueda, fechaDesde, fechaHasta})`, `obtenerNoticiaPorLink`, `obtenerNoticiaPorSlug`, `obtenerNoticiaCompleta`, `obtenerCategorias` |
| Caché | `_desdeCache`, `_guardarCache` — claves `noticias_cache_v1` / `noticias_cache_at_v1` en SharedPreferences |
| Offline | `guardarNoticiaOffline`, `obtenerNoticiasOffline`, `eliminarNoticiaOffline`, `_guardarImagenLocal`, `_guardarContenidoMultimediaLocal` |

El guardado offline **descarga las imágenes y el multimedia a disco** (`path_provider`) y
reescribe los bloques del contenido apuntando a las rutas locales. No es un simple dump de JSON.

#### `lectura_voz.service.dart` (8.7 KB)

Lectura por voz. Más sofisticado de lo que parece:

- `_elegirMotor()` — selecciona el engine TTS del dispositivo.
- `_buscarIdioma()` — resuelve la variante de español disponible.
- `_vocesEnEspanol()` + `_puntaje()` + `_puntosPorCalidad()` — **rankea las voces instaladas**
  y elige la mejor, porque el default del sistema suele ser la peor.
- `aplicarVelocidad(factor)`, `hablar(texto)`, `detener()`.

Trabaja junto a `utils/lectura_noticia.util.dart`, que convierte la nota en un guion
locutable (ver [A.10](#a10-utils)).

### Notificaciones

#### `push_notifications.service.dart` (28 KB — el archivo más grande)

Es un `ChangeNotifier` singleton (`PushNotificationsService.instance`) que además observa
el ciclo de vida de la app.

| Bloque | Métodos |
|---|---|
| Arranque | `init()`, `_initializeLocalNotifications()`, `firebaseMessagingBackgroundHandler` (top-level, obligatorio por FCM) |
| Permisos | `requestNotificationPermission()`, `isNotificationPermissionGranted()` |
| Token | `_syncCurrentToken()`, `syncTokenForLoggedInUser()`, `isDeviceRegistered()`, `unregisterTokenOnLogout()` |
| Preferencia de alertas | `setNewsAlertsEnabled(bool)`, `_subscribeToFlipsTopic()`, `_unsubscribeFromFlipsTopic()`, `_retryPendingAlertsSync()` |
| Bandeja | `_loadNotifications()`, `_saveNotifications()`, `markAllAsRead()`, `deleteNotification(id)`, `deleteNotifications(ids)`, `unreadCount` |
| Contenido del aviso | `_tituloDeMensaje`, `_cuerpoDeMensaje`, `_imagenDeMensaje`, `_descargarImagenDeAviso`, `_mensajeTieneContenido` |
| Deep link | `_esTipoNoticia`, `_slugDeNoticia`, `_noticiaAbreEnLaApp` |

El push trae `data.type` y `data.slug`. Si el tipo es noticia y el dominio es propio, abre
`NoticiaDesdePushScreen` dentro de la app; si no, abre el navegador. La imagen del aviso se
**descarga antes** de mostrar la notificación local, porque FCM no la renderiza solo en todos
los casos.

`_retryPendingAlertsSync()` existe porque activar/desactivar alertas puede fallar sin red:
la preferencia se guarda local y se reintenta luego.

### Monetización y medición

| Servicio | Detalle |
|---|---|
| `ads_consent.service.dart` | UMP (consentimiento). `solicitarSiHaceFalta()` corre **antes** de `MobileAds.initialize()`, que es el orden que documenta Google. Fuera del EEE/UK no muestra nada. |
| `ad_banner.widget.dart` *(en globals)* | `AdManagerBannerView`. Mide con `getPlatformAdSize()` dentro de `onAdLoaded` — no con la lista solicitada — y **reserva el alto desde el principio** para no sacudir el scroll. |
| `interstitial_ads.service.dart` | Precarga, reintento a 8 s, **cooldown de 1 minuto** entre impresiones. `registrarAperturaYContinuar`, `mostrarPorAccion`, `liberar`, `liberarTodo`. |
| `analytics.service.dart` | `logNoteView`, `logNewsSearch`, `logCategorySearch`, `logNewsScreen`, `logRouteScreen`, `logNoteShare`, `logNoteListen`. `_sanitize` y `_normalizeNewsTitle` limpian los valores antes de enviarlos. |
| `app_analytics_route_observer.dart` | `NavigatorObserver` que reporta `screen_view` automático en cada push/pop. |

### Suscripción

#### `suscripcion_checkout.service.dart` (4.8 KB)

| Método | Uso |
|---|---|
| `crearSesionWebCheckout({redirect})` | `POST /mobile/web-session` → URL de un solo uso con expiración corta |
| `iniciarCheckout(...)` | Alta de suscripción |
| `consultarEstado({pagoId})` | Polling del pago |
| `actualizarEstadoPago(...)` | Confirmación |

> **Por qué el checkout es web y no in-app:** las políticas de App Store y Play prohíben
> abrir pasarelas de pago embebidas para contenido digital, y el IAP nativo cobra 15–30 %.
> La app detecta que no hay suscripción activa, pide una sesión web al backend, y abre esa
> URL en el **navegador externo** del dispositivo. Next.js valida el handoff, crea la cookie
> y redirige a `/checkout` ya autenticado. Ver `README.md` para el detalle del flujo.

### Onboarding

#### `onboarding.service.dart` (5.6 KB)

Tours **versionados**: `tourVersion` y `articleTourVersion` son constantes; subir el número
vuelve a mostrar el tour a todos. Útil cuando cambia la UI.

El priming de notificaciones está limitado: `_maxNotificationPrompts = 3` con
`_promptCooldown = 7 días`. Pedir permiso sin parar es la vía rápida a que lo nieguen para siempre.

### Servicios CRUD simples

`mi_perfil` · `mis_facturas` · `mis_pagos` · `mis_suscripcion` · `paquetes` ·
`diarios_digitales` — menos de 2 KB cada uno, todos siguen el patrón del ejemplo canónico.

---

## A.7 Providers y controllers

Nueve pares, uno por dominio, registrados en el `MultiProvider` de `main.dart`:

```
AuthProvider · MiPerfilProvider · MisFacturasProvider · DiariosDigitalesProvider
NoticiasProvider · LectorProvider · PaquetesProvider · MisPagosProvider
MisSuscripcionProvider
```

Todos los providers exponen la misma tríada mínima: `loading`, `errorMessage`, y la colección
o entidad del dominio.

Dos providers salen del molde:

- **`NoticiasProvider`** — además del listado guarda `noticiasOffline`, que se consulta desde
  el menú "Más opciones" para mostrar el contador.
- **`LectorProvider`** — estado de la lectura por voz (reproduciendo, párrafo actual, velocidad).
  Es el único provider que no tiene un service CRUD detrás.

`controllers/login/login_flows.controller.dart` está aparte porque el login tiene cinco
flujos distintos y meterlos en `auth.controller.dart` lo volvía ilegible.

---

## A.8 Pantallas y navegación

### Shell de navegación

`HomeScreen` es el contenedor: `AnimatedBottomNavigationBar` de 4 pestañas.

| # | Pestaña | Pantalla |
|---|---|---|
| 0 | Noticias | `NoticiasScreen` |
| 1 | Diarios | `DiariosDigitalesScreen` |
| 2 | Perfil | `MiPerfilScreen` |
| 3 | Más opciones | `_MasOpcionesScreen` (privada, dentro de `home.screen.dart`) |

El banner fijo se dibuja **encima** de la barra, dentro de la misma `Column`, y solo si
`_acceso.mostrarAnuncios`.

`_MasOpcionesScreen` agrupa: noticias sin conexión, sitio web, switch de alertas, bandeja de
notificaciones, mi suscripción, mis pagos, mis facturas, paquetes, ver tutorial, privacidad,
cerrar sesión.

### Rutas

Solo existe **una ruta nombrada**: `/login`. Todo lo demás es `MaterialPageRoute` imperativo.

> Para el repo base conviene revisar esto: con deep links de push y checkout web volviendo del
> navegador, un router declarativo (`go_router`) simplifica bastante. No es bloqueante, pero
> es la decisión arquitectónica más discutible del proyecto actual.

### Arranque

`main.dart` decide la pantalla inicial con un `FutureBuilder<bool>` sobre
`_resolveInitialSession()`: si hay sesión válida → `HomeScreen`, si no → `LoginScreen`.
El future tiene timeout de 4 s y cae a `hasStoredSession()` como respaldo.

### Inventario por tamaño

| Pantalla | LOC | Nota |
|---|---|---|
| `noticias/noticia_detalle.screen.dart` | **1,643** | Render de bloques, TTS, compartir, guardar offline, ads, tour de artículo. **Demasiado grande — partir antes de templatizar.** |
| `home/home.screen.dart` | 785 | Shell + diálogo de suscripción + menú |
| `notificaciones/notificaciones.screen.dart` | 733 | Bandeja con selección múltiple |
| `noticias/noticias.screen.dart` | 619 | Portada: paginación, búsqueda, categorías, ads intercalados |
| `diarios_digitales/diarios_digitales.screen.dart` | 610 | Visor PDF + gating |
| `onboarding/widgets/coach_mark.widget.dart` | 457 | Overlay del tour |
| `noticias/widgets/shared_widgets.dart` | 415 | |
| `login/login.screen.dart` | 391 | + `auth_flow_sheet.widget.dart` (45) para OTP/registro/reset |
| `noticias/noticias_offline.screen.dart` | 349 | |
| `noticias/widgets/noticias_header.dart` | 315 | |
| `onboarding/onboarding_flow.dart` | 311 | `runIfNeeded()` y `replayTour()` |
| `mi_perfil/mi_perfil.screen.dart` | 293 | |
| `noticias/widgets/category_widgets.dart` | 252 | |
| `notificaciones/notificacion_detalle.screen.dart` | 237 | |
| `noticias/widgets/news_cards.dart` | 207 | |
| `noticias/noticia_desde_push.screen.dart` | 189 | Destino de los deep links |
| `shared/section_card.widget.dart` | 168 | |
| `onboarding/widgets/notifications_priming.sheet.dart` | 168 | |
| `noticias/categoria_noticias.screen.dart` | 167 | |
| `paquetes/paquetes.screen.dart` | 131 | |
| `mis_facturas` · `mis_suscripcion` · `mis_pagos` | 86 · 82 · 78 | Listados simples |
| `sitio_web/sitio_web.screen.dart` | 58 | WebView |
| `noticias/widgets/search_bar.dart` | 52 | |
| `shared/async_list_state.widget.dart` | 34 | Estados loading/error/vacío reutilizables |

---

## A.9 Design system y globals

### `lib/globals/widgets/` (20 archivos, 1,031 LOC)

Barrel en `widgets.dart` — un solo import da acceso a todo.

| Widget | Uso |
|---|---|
| `AdManagerBannerView` + `AdUnits` | Banners de Ad Manager |
| `AlertError` | Alerta de error |
| `ButtonXXL` | Botón principal a ancho completo |
| `Cargando` | Spinner estándar |
| `CustomAppBar` | AppBar del proyecto |
| `DialogDecision` / `DialogText` | Diálogos sí/no y de texto |
| `EnableGPS` | Solicitud de ubicación |
| `GlobalSnackbar` + `snackbarglobal.helper.global.dart` | Snackbars desde cualquier lado vía `snackbarKey` |
| `GridItem` | Ítem de menú con icono, texto, subtítulo y trailing |
| `MantenimientoAlert` | Aviso de mantenimiento |
| `MyPainter` | Formas del fondo |
| `NoData` | Estado vacío |
| `ParteAbajo` | Pie de pantalla |
| `Skeleton` | Placeholder de carga |
| `TextoPrincipal` / `TextSecundario` / `TextParrafo` | Escala tipográfica |

### Tema

**El tema completo está inline en `main.dart`, líneas 66–172.** Define:

```dart
ColorScheme.fromSeed(
  seedColor:  Color(0xFF0A3D91),   // azul Diario Tiempo
  primary:    Color(0xFF0A3D91),
  secondary:  Color(0xFF0ABAB5),
  error:      Color(0xFFD72638),
  surface:    Color(0xFFF6F8FC),
  brightness: Brightness.light,
)
```

más `appBarTheme`, `cardTheme`, `elevatedButtonTheme`, `inputDecorationTheme` y `textTheme`.

> **Para el repo base esto sale de `main.dart` a `lib/theme/app_theme.dart`,
> como una función `ThemeData buildTheme(BrandColors colors)`.** Es el cambio
> de mayor impacto y menor riesgo de todo el plan B.

Solo hay **tema claro**. No existe modo oscuro.

### `lib/globals/functions/`

| Archivo | Estado |
|---|---|
| `functions.dart` | Barrel |
| `cuerpocontroller.dart` | `CuerpoDeController.cuerpoNormal(...)` — usado en 2 lugares |
| `resetprovider.function.dart` | Usado en 4 lugares |
| `traertoken.function.dart` | **Muerto** — reemplazado por `SessionService` |
| `permisos.dart` | **Muerto** — `requestStoragePermission()` sin llamadas |

---

## A.10 Utils

| Archivo | Contenido |
|---|---|
| `formatters.dart` | `AppFormatters.moneyFromCentavos(int)` con `NumberFormat('#,##0.00','es_HN')` y `dateFromIso(String?)` |
| `html_texto.util.dart` | `limpiarHtml(value, {preservarParrafos, quitarPrefijoRedaccion})`, `decodificarEntidadesHtml`, `quitarPrefijoDeRedaccion` |
| `noticia_link.util.dart` | `NoticiaLinkUtil.normalizar`, `.esDominioPropio`, `.slugDesdeEnlace` sobre el set `_dominiosPropios` |
| `lectura_noticia.util.dart` | Lo más interesante — ver abajo |

### `lectura_noticia.util.dart`

Convierte una noticia en un guion locutable (`GuionNoticia`):

- `_valeLaPenaLeer(parrafo)` — descarta pies de foto, créditos y ruido.
- `normalizarParaVoz(texto)` — aplica `_ReglaDeVoz` en cascada: expande abreviaturas,
  convierte `L 1,500` a "mil quinientos lempiras" (`_conMoneda`), normaliza siglas y números.
- `_trocear(parrafo)` / `_trocearPorPalabras(oracion)` — parte en fragmentos que el motor TTS
  pueda pronunciar sin cortarse a mitad de frase.

> La regla de moneda está atada a lempiras. Para otro país hay que parametrizarla —
> es parte de `BrandConfig` en el plan B.

---

## A.11 Flujos críticos

### 1. Sesión y renovación

```
Petición ──► HttpService._enviar()
              │
              ├─► SessionService.getValidToken()
              │     ├─ token vigente? ──► lo devuelve
              │     ├─ vence en breve? ──► renovarSesion() y devuelve el nuevo
              │     └─ sin token pero hay sesión guardada? ──► lanza SocketException
              │
              ├─► request con Bearer + Cookie
              │
              └─► 401?
                    ├─ renovarSesion() ok ──► reintenta UNA vez
                    │     └─ 401 otra vez ──► expireAndRedirect + SessionExpiredException
                    └─ refresh falla ──────► expireAndRedirect
```

### 2. Push → deep link

```
FCM message
   ├─ app en background ──► firebaseMessagingBackgroundHandler (top-level)
   └─ app en foreground ──► onMessage
          │
          ├─ _mensajeTieneContenido()? ──► no: se descarta
          ├─ _descargarImagenDeAviso(url)  (si trae imagen)
          ├─ muestra notificación local
          └─ _persistMessageToStorage()  → alimenta la bandeja
                 │
          usuario toca
                 │
          ├─ _esTipoNoticia(data.type) && _noticiaAbreEnLaApp(data)
          │     └─► NoticiaDesdePushScreen(slug: _slugDeNoticia(data))
          └─ si no ──► url_launcher al navegador externo
```

### 3. Guardado offline

```
usuario toca "Guardar"
   ├─ AccesoUsuario.puedeLeerOffline? ──► no: muestra paywall
   └─ sí
       ├─ obtenerNoticiaCompleta()      (asegura contenido, no solo tarjeta)
       ├─ _guardarImagenLocal()          → descarga portada a disco
       ├─ _guardarContenidoMultimediaLocal() → descarga media de los bloques
       ├─ reescribe los bloques a rutas locales
       └─ persiste en SharedPreferences  → NoticiasProvider.noticiasOffline
```

### 4. Paywall y checkout

```
HomeScreen.initState
   ├─ OnboardingFlow.runIfNeeded()     ← el tour tiene prioridad
   │     └─ si se mostró, se pospone el resto
   └─ _validarSuscripcionActiva()
         ├─ AuthService.obtenerSuscripcionActiva()
         ├─ ¿ya se mostró hoy? (SharedPreferences, clave por fecha UTC)
         └─ diálogo → PaquetesScreen
                        └─ SuscripcionCheckoutService.crearSesionWebCheckout()
                              └─ url_launcher → NAVEGADOR EXTERNO
```

### 5. Anuncios

```
main()
  ├─ AdsConsentService.solicitarSiHaceFalta()   ← ANTES de initialize()
  └─ MobileAds.instance.initialize()
        │
        └─ en cada pantalla: AccesoUsuario.mostrarAnuncios
              ├─ resuelto == false ──► no se pide nada (evita el parpadeo)
              ├─ esAdmin || suscrito ──► sin anuncios
              └─ resto ──► banner fijo + rectángulos en lista + intersticiales con cooldown
```

---

## A.12 Capa de plataforma

### Android

| Archivo | Contenido relevante |
|---|---|
| `android/app/build.gradle.kts` | `namespace` y `applicationId` = `com.diariotiempohn.app` |
| `AndroidManifest.xml` | Permisos `INTERNET`, `POST_NOTIFICATIONS`; App ID de Ads; canal por defecto de FCM; `google_analytics_automatic_screen_reporting_enabled`; intents `PROCESS_TEXT` y `TTS_SERVICE`; `android:label="Diario Tiempo"` con `tools:replace` |
| `google-services.json` | Versionado en el repo |

### iOS

| Archivo | Contenido relevante |
|---|---|
| `Info.plist` | `CFBundleDisplayName` / `CFBundleName` = `Diario Tiempo`; esquemas de URL para OAuth |
| `Runner.entitlements` | Push |
| `GoogleService-Info.plist` | Versionado |
| `project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER = com.diariotiempohn.app` |

### CI/CD — `codemagic.yaml`

Un solo workflow: `ios-release`.

```
mac_mini_m2
  ├─ instala Shorebird
  ├─ flutter pub get
  ├─ pod install
  ├─ xcode-project use-profiles
  ├─ shorebird release ios --flutter-version=3.35.5
  └─ publica a TestFlight (submit_to_app_store: false)
```

Dos notas del propio archivo que conviene no perder:

- Se usa `shorebird release` y **no** `flutter build ipa`: un IPA construido con `flutter build`
  no queda parcheable con `shorebird patch`.
- Los client IDs de Google **no** van por `--dart-define` en CI, porque pasarlos vacíos los
  sobreescribía con `""` y rompía el login. Están como `defaultValue` en el config.
- El `SHOREBIRD_TOKEN` es una API key de `console.shorebird.dev` que **expira al año**.
  Si el build falla por autenticación, revisá eso primero.

**No hay workflow de Android en Codemagic.** Se construye a mano.

### OTA — `shorebird.yaml`

`app_id: 7498ccbf-8497-4c2c-a180-b1ecbab475c0`, con `auto_update` activo (por defecto).
Permite parchear Dart sin pasar por revisión de tienda. No sirve para cambios nativos
ni de dependencias.

---

## A.13 Pruebas

9 archivos en `test/`. La cobertura es baja pero está bien enfocada: cubre lo que más duele.

| Archivo | Qué cubre |
|---|---|
| `session_refresh_test.dart` | Renovación de sesión |
| `push_notifications_service_test.dart` | Parseo de mensajes y deep links |
| `noticia_desde_push_test.dart` | Pantalla destino del push |
| `acceso_usuario_test.dart` | Políticas de `AccesoUsuario` |
| `onboarding_service_test.dart` | Versionado de tours y cooldown de prompts |
| `lectura_noticia_util_test.dart` | Normalización para voz |
| `lector_provider_test.dart` | Estado del lector |
| `coach_mark_test.dart` | Overlay del tour |
| `google_sign_in_config_test.dart` | Resolución de client IDs por plataforma |

**No hay tests de:** `HttpService`, servicios CRUD, providers de listado, ni widget tests
de las pantallas grandes.

---

## A.14 Deuda técnica

### Dependencias declaradas y no usadas

Ocho paquetes en `pubspec.yaml` con **cero** referencias en `lib/`:

| Paquete | Comentario |
|---|---|
| `dio` | Todo el HTTP va por `http` |
| `localstorage` | Se usa `shared_preferences` |
| `board_datetime_picker` | — |
| `persistent_bottom_nav_bar` | Se usa `animated_bottom_navigation_bar` |
| `pdf` | Solo se *lee* PDF (`syncfusion_flutter_pdfviewer`), no se genera |
| `animate_do` | — |
| `syncfusion_flutter_datepicker` | **Quitarlo reduce la superficie de licenciamiento Syncfusion** |
| `android_id` | — |

### Código muerto

- `lib/models/usuario.model.dart` — 0 referencias.
- `lib/globals/functions/traertoken.function.dart` — reemplazado por `SessionService`.
- `lib/globals/functions/permisos.dart` — `requestStoragePermission()` sin llamadas.

### Otros

| Punto | Detalle |
|---|---|
| `noticia_detalle.screen.dart` | 1,643 LOC en un archivo. Partir en: shell, render de bloques, controles de TTS, barra de acciones. |
| Tema inline en `main.dart` | ~110 líneas que deberían vivir en `lib/theme/`. |
| Navegación imperativa | Una sola ruta nombrada; deep links resueltos a mano. |
| Sin modo oscuro | El `ColorScheme` es solo claro. |
| `// ignore_for_file:` amplios | `main.dart` y `home.screen.dart` silencian lints en todo el archivo. |
| `withOpacity` | Deprecado en Flutter reciente; usado en el tema. |

---

# B. Proyecto base white-label

Todo lo anterior es sólido y vale la pena conservarlo. Lo que **no** está resuelto es que la
marca está esparcida por 20 lugares. Esta sección es el plan para arreglarlo.

## B.1 Puntos de acoplamiento a la marca

Inventario exacto de lo que hoy obliga a hacer *find & replace* por cada medio nuevo:

| # | Ubicación | Qué está quemado | Destino |
|---|---|---|---|
| 1 | `lib/constants.dart:3` | `urlBase = 'https://www.diariotiempo.hn/api/'` | `BrandConfig.apiBaseUrl` |
| 2 | `lib/main.dart:176` | `title: 'Diario Tiempo HN'` | `BrandConfig.appName` |
| 3 | `lib/main.dart:66-71` | Paleta `0xFF0A3D91` / `0xFF0ABAB5` / `0xFFD72638` / `0xFFF6F8FC` | `BrandColors` |
| 4 | `lib/utils/noticia_link.util.dart:7` | `_dominiosPropios = {'tiempo.hn','diariotiempo.hn'}` | `BrandConfig.ownDomains` |
| 5 | `lib/models/noticias.model.dart:555-579` | `_normalizeTiempoLink()` con `https://tiempo.hn` | `BrandConfig.siteUrl` |
| 6 | `lib/screens/noticias/noticia_detalle.screen.dart:654,759,771` | `'Leer en tiempo.hn'` + normalización de URLs | `BrandCopy` + `siteUrl` |
| 7 | `lib/globals/widgets/ad_banner.widget.dart:13-16` | `/170101793/APP/320x50_fijo`, `/box_1` | `AdUnitIds` |
| 8 | `lib/services/interstitial_ads.service.dart:44` | `/170101793/APP/Interstitial` | `AdUnitIds` |
| 9 | `lib/screens/home/home.screen.dart:104` | *"Los anuarios desde 2008 a la fecha…"* | `BrandCopy.paywall` |
| 10 | `lib/screens/home/home.screen.dart:448` | URL de política de privacidad | `BrandConfig.privacyUrl` |
| 11 | `lib/screens/sitio_web/sitio_web.screen.dart:7` | `url = 'https://tiempo.hn'` | `BrandConfig.siteUrl` |
| 12 | `lib/screens/onboarding/onboarding_flow.dart:150` | *"Anuarios desde 2008 hasta hoy"* | `BrandCopy.onboarding` |
| 13 | `lib/services/analytics.service.dart:211-212` | Sufijos `" | Diario Tiempo de Honduras"` a recortar | `BrandConfig.titleSuffixesToStrip` |
| 14 | `lib/services/app_analytics_route_observer.dart:69` | Título de portada literal | `BrandCopy.homeTitle` |
| 15 | `lib/config/google_sign_in.config.dart` | Client IDs con `defaultValue` | `BrandConfig.oauth` |
| 16 | `lib/screens/noticias/widgets/noticias_header.dart:244` | `'Diario Tiempo HN'` | `BrandConfig.appName` |
| 17 | `lib/utils/formatters.dart:4` | Locale `es_HN` fijo | `BrandConfig.locale` + `currency` |
| 18 | `lib/utils/lectura_noticia.util.dart` | Regla de moneda en lempiras | `BrandConfig.currencySpoken` |
| 19 | Android / iOS | `com.diariotiempohn.app`, label, Firebase configs, entitlements | Flavors |
| 20 | `shorebird.yaml` / `codemagic.yaml` / `assets/images/logo.png` | app_id, bundle ID, ASC key, logo | Por flavor |

## B.2 Diseño de `BrandConfig`

Un solo objeto inmutable con **todo** lo que cambia entre medios.

```
lib/branding/
├── brand.dart               // resuelve el brand activo
├── brand_config.dart        // la clase
├── brand_colors.dart
├── brand_assets.dart
├── brand_copy.dart
├── brand_features.dart
├── ad_unit_ids.dart
├── google_oauth.dart
└── brands/
    ├── diario_tiempo.dart
    ├── medio_b.dart
    └── medio_c.dart
```

```dart
// lib/branding/brand_config.dart
@immutable
class BrandConfig {
  const BrandConfig({
    required this.id,
    required this.appName,
    required this.apiBaseUrl,
    required this.siteUrl,
    required this.ownDomains,
    required this.privacyUrl,
    required this.termsUrl,
    required this.locale,
    required this.currencyCode,
    required this.currencySpoken,
    required this.titleSuffixesToStrip,
    required this.colors,
    required this.assets,
    required this.ads,
    required this.oauth,
    required this.copy,
    required this.features,
  });

  final String id;                       // 'diario_tiempo'
  final String appName;                  // 'Diario Tiempo HN'
  final String apiBaseUrl;               // 'https://www.diariotiempo.hn/api/'
  final String siteUrl;                  // 'https://tiempo.hn'
  final Set<String> ownDomains;          // {'tiempo.hn','diariotiempo.hn'}
  final String privacyUrl;
  final String termsUrl;
  final Locale locale;                   // Locale('es','HN')
  final String currencyCode;             // 'HNL'
  final String currencySpoken;           // 'lempiras'  → para el TTS
  final List<String> titleSuffixesToStrip;

  final BrandColors   colors;
  final BrandAssets   assets;
  final AdUnitIds     ads;
  final GoogleOAuth   oauth;
  final BrandCopy     copy;
  final BrandFeatures features;
}
```

```dart
// lib/branding/brand_colors.dart
@immutable
class BrandColors {
  const BrandColors({
    required this.seed,
    required this.primary,
    required this.secondary,
    required this.error,
    required this.surface,
  });
  final Color seed, primary, secondary, error, surface;
}
```

```dart
// lib/branding/brand.dart
import 'brands/diario_tiempo.dart';
import 'brands/medio_b.dart';

const _brandId = String.fromEnvironment('BRAND', defaultValue: 'diario_tiempo');

const Map<String, BrandConfig> _registry = {
  'diario_tiempo': diarioTiempoBrand,
  'medio_b': medioBBrand,
};

/// Punto de acceso único. Todo el código lee de acá.
const BrandConfig brand = ...; // resuelto desde _registry[_brandId]
```

> **Regla:** después de esta refactorización, buscar el nombre de cualquier medio con
> `grep -ri "tiempo" lib/` debe devolver resultados **solo** dentro de
> `lib/branding/brands/`. Ese grep es tu prueba de aceptación.

## B.3 Feature flags

No todo medio quiere todo. Un flag por módulo evita borrar código para cada cliente:

```dart
// lib/branding/brand_features.dart
@immutable
class BrandFeatures {
  const BrandFeatures({
    this.ediciones      = true,   // visor de PDF / flips
    this.suscripciones  = true,   // paywall, paquetes, facturas, pagos
    this.ads            = true,   // Ad Manager
    this.tts            = true,   // lectura por voz
    this.offline        = true,   // guardar noticias
    this.googleSignIn   = true,
    this.notificaciones = true,
    this.sitioWeb       = true,   // pestaña de WebView
  });

  final bool ediciones, suscripciones, ads, tts, offline;
  final bool googleSignIn, notificaciones, sitioWeb;
}
```

Impacto por flag:

| Flag en `false` | Qué desaparece |
|---|---|
| `ediciones` | Pestaña 1 del bottom nav, `DiariosDigitalesScreen`, su service/provider/controller |
| `suscripciones` | Paywall, `PaquetesScreen`, mis pagos/facturas/suscripción, checkout web. `AccesoUsuario` pasa a mirar solo `esAdmin` |
| `ads` | Banner del shell, rectángulos del listado, intersticiales, consentimiento UMP |
| `tts` | Botón de escuchar, `LectorProvider`, `LecturaVozService` |
| `offline` | Botón guardar, `NoticiasOfflineScreen`, ítem del menú |
| `googleSignIn` | Botón de Google en login |

Con `ediciones=false`, `suscripciones=false` y `ads=true` tenés un medio 100 % gratuito
financiado por publicidad — configurado en minutos, sin tocar una línea de lógica.

> El bottom nav debe construirse a partir de una **lista filtrada por flags**, no con
> índices fijos. Es el único punto donde los flags obligan a un refactor real de la UI actual.

## B.4 Flavors de build

### Android

```
android/app/src/
├── diarioTiempo/google-services.json
├── medioB/google-services.json
└── main/...
```

```kotlin
// android/app/build.gradle.kts
flavorDimensions += "brand"
productFlavors {
    create("diarioTiempo") {
        dimension = "brand"
        applicationId = "com.diariotiempohn.app"
        resValue("string", "app_name", "Diario Tiempo")
    }
    create("medioB") {
        dimension = "brand"
        applicationId = "com.mediob.app"
        resValue("string", "app_name", "Medio B")
    }
}
```

El manifest pasa a usar `android:label="@string/app_name"`.

### iOS

Un **scheme** y una **configuration** por marca, con su `GoogleService-Info.plist` copiado
por un Run Script según la configuration activa.

### Comando de build

```bash
flutter build appbundle --flavor diarioTiempo --dart-define=BRAND=diario_tiempo
```

> `--flavor` (nativo) y `--dart-define=BRAND` (Dart) tienen que coincidir siempre.
> Vale la pena un script `tool/build.sh <brand>` que derive uno del otro y evite el
> desalineo silencioso.

## B.5 Estructura propuesta del repo nuevo

```
media_app_base/
├── lib/
│   ├── main.dart                   ← delgado: bootstrap + App()
│   ├── app.dart                    ← MaterialApp, providers, tema, router
│   ├── branding/                   ← ★ NUEVO — toda la marca acá
│   │   ├── brand.dart
│   │   ├── brand_config.dart
│   │   ├── brand_colors.dart · brand_assets.dart · brand_copy.dart
│   │   ├── brand_features.dart · ad_unit_ids.dart · google_oauth.dart
│   │   └── brands/
│   │       └── <un archivo por medio>
│   ├── theme/                      ← ★ NUEVO — sale de main.dart
│   │   ├── app_theme.dart          ← buildTheme(BrandColors)
│   │   └── app_text_styles.dart
│   ├── core/                       ← ★ NUEVO — infraestructura sin dominio
│   │   ├── http/http.service.dart
│   │   ├── session/session.service.dart
│   │   ├── storage/
│   │   └── errors/
│   ├── models/
│   ├── services/
│   ├── providers/
│   ├── controllers/
│   ├── screens/
│   ├── globals/widgets/
│   └── utils/
├── tool/
│   ├── new_brand.dart              ← ★ generador de marca
│   └── build.sh
├── android/  ios/  assets/  test/
├── docs/
│   ├── ARQUITECTURA.md
│   ├── BACKEND_CONTRACT.md
│   ├── openapi.yaml
│   └── ALTA_DE_MEDIO.md
└── codemagic.yaml                  ← workflow por flavor
```

Cambios respecto al repo actual:

1. **`branding/`** — nuevo, concentra los 20 puntos.
2. **`theme/`** — el tema sale de `main.dart`.
3. **`core/`** — `HttpService` y `SessionService` dejan de estar mezclados con los servicios
   de dominio. Son infraestructura y no cambian nunca entre medios.
4. **`app.dart`** — `main.dart` queda solo con el bootstrap asíncrono.
5. **`tool/`** — automatización del alta de marcas.

## B.6 Contrato de backend

Esto es lo que más valor comercial te da: cualquier medio que exponga estos endpoints
funciona con la app **sin tocar Dart**. Documentalo como OpenAPI en `docs/openapi.yaml`.

Todas las llamadas autenticadas van con `Authorization: Bearer <jwt>` y
`Content-Type: application/json` cuando aplica.

### Autenticación

| Endpoint | Método | Devuelve |
|---|---|---|
| `/auth/login` | POST | `token`, `refreshToken`, `expiresAt`, `refreshExpiresAt`, `data.usuario` |
| `/auth/refresh` | POST | mismo shape que login |
| `/auth/logout` | POST | `{ ok }` |
| `/auth/email/otp` | POST | envía código |
| `/auth/email/verify` | POST | valida código |
| `/auth/email/register` | POST | completa alta |
| `/auth/email/reset` | POST | OTP de recuperación |
| `/auth/email/reset/confirm` | POST | nueva contraseña |
| `/auth/google` | POST | `idToken` → sesión |

### Contenido

| Endpoint | Método | Parámetros |
|---|---|---|
| `/noticias` | GET | `page`, `perPage`, `categoria`, `busqueda`, `fechaDesde`, `fechaHasta` (ISO 8601 UTC) |
| `/noticias/by-link` | GET | `link` (URL codificada) **o** `slug` |
| `/noticias/categorias` | GET | `perPage` |
| `/diarios-digitales` | GET | `anio`, `mes` → incluye `pdfSignedUrl` con expiración |

Los endpoints de noticias son **públicos**: la app no exige sesión, pero manda el Bearer
cuando la hay (para personalizar y para saltarse anuncios en suscriptores).

> El backend es quien habla con WordPress y normaliza la respuesta. La app **no** consume
> WordPress directamente — así, un medio con otro CMS solo cambia su backend.

### Cuenta y monetización

| Endpoint | Método | Uso |
|---|---|---|
| `/usuario` | GET | perfil + `rol` + `suscripcionActiva` |
| `/paquetes` | GET | planes disponibles |
| `/suscripcion` | GET | suscripciones del usuario |
| `/pagos` | GET | historial |
| `/facturas` | GET | facturas con `pdfUrl` |
| `/mobile/web-session?redirect=/checkout` | POST | `{ ok, url, expiresInSeconds }` — handoff al navegador |

### Push

| Endpoint | Método | Uso |
|---|---|---|
| registro de token | POST | asocia token FCM ↔ usuario ↔ dispositivo |
| baja de token | POST/DELETE | al cerrar sesión |

**Payload de push esperado:**

```json
{
  "notification": { "title": "...", "body": "..." },
  "data": {
    "type": "noticia",
    "slug": "titulo-de-la-nota",
    "url": "https://midominio.com/...",
    "image": "https://..."
  }
}
```

`type: "noticia"` + dominio propio → abre dentro de la app. Cualquier otra cosa → navegador.

### Convenciones transversales

- Respuestas envueltas en `{ data: [...] }` para colecciones.
- Errores con `{ ok: false, message: "texto para el usuario" }` — la app muestra `message`.
- **Todo importe en centavos enteros** (`priceCents`, `montoCentavos`, `totalCentavos`).
- Fechas en ISO 8601 UTC.

## B.7 Orden de construcción

Para levantar el repo base, en este orden. Cada paso deja el proyecto compilando.

| # | Paso | Días | Por qué en este orden |
|---|---|---|---|
| 1 | Limpieza: 8 deps muertas + código huérfano | 1 | Menos superficie que migrar después |
| 2 | Extraer `theme/` desde `main.dart` | 1 | Aislado, sin riesgo, alto impacto visual |
| 3 | Crear `branding/` con `BrandConfig` y migrar los 20 puntos | 5 – 7 | El corazón del plan |
| 4 | Mover `HttpService`/`SessionService` a `core/` | 1 | Separa infraestructura de dominio |
| 5 | Partir `noticia_detalle.screen.dart` (1,643 → ~4 archivos) | 3 – 4 | Antes de que se multiplique por N medios |
| 6 | Implementar `BrandFeatures` + bottom nav dinámico | 3 – 4 | Depende del paso 3 |
| 7 | Flavors Android + schemes iOS + script de Firebase configs | 3 – 5 | Ya con el Dart resuelto |
| 8 | `tool/new_brand.dart` + `tool/build.sh` | 2 – 3 | Automatiza lo anterior |
| 9 | `docs/openapi.yaml` + `BACKEND_CONTRACT.md` + `ALTA_DE_MEDIO.md` | 2 – 3 | Es el entregable de venta |
| 10 | Tests de `core/`, `branding/` y flujos de sesión → ~40 % | 4 – 5 | Protege la base que van a usar todos |
| | **Total** | **25 – 34 días** | ≈ 1 – 1.5 meses |

**Retorno esperado:** cada medio nuevo pasa de ~120 días de implementación a **10 – 20 días**
(branding, Firebase, tiendas, ajustes de contenido). A partir del segundo cliente, la
inversión está amortizada.

## B.8 Checklist de alta de un medio

Guardar como `docs/ALTA_DE_MEDIO.md` en el repo base.

### Backend
- [ ] Endpoints del contrato ([B.6](#b6-contrato-de-backend)) implementados y en producción
- [ ] HTTPS con certificado válido
- [ ] Sesión web de handoff funcionando (si hay suscripciones)

### Dart
- [ ] `lib/branding/brands/<medio>.dart` creado (o generado con `tool/new_brand.dart`)
- [ ] Registrado en `_registry` de `brand.dart`
- [ ] `grep -ri "<nombre-del-medio>" lib/ --exclude-dir=branding` devuelve **cero** resultados

### Firebase
- [ ] Proyecto creado
- [ ] App Android registrada con el `applicationId` del flavor + SHA-1 y SHA-256
- [ ] App iOS registrada con el bundle ID
- [ ] `google-services.json` y `GoogleService-Info.plist` en la carpeta del flavor
- [ ] Cloud Messaging habilitado; APNs key subida
- [ ] Analytics habilitado

### Google Sign-In
- [ ] OAuth client **Web** creado → `oauth.webClientId`
- [ ] OAuth client **iOS** creado → `oauth.iosClientId`
- [ ] SHA-1 y SHA-256 de debug **y** release cargados en Firebase
- [ ] Esquema de URL inverso agregado al `Info.plist`

### Publicidad (si `features.ads`)
- [ ] Cuenta de Ad Manager / AdMob
- [ ] Tres unidades creadas: banner fijo, rectángulo, intersticial
- [ ] App ID en `AndroidManifest.xml` y en `Info.plist`

### Assets
- [ ] `logo.png`, ícono de app, splash
- [ ] Íconos generados con `flutter_launcher_icons`

### Build y publicación
- [ ] Flavor Android en `build.gradle.kts`
- [ ] Scheme y configuration iOS
- [ ] App creada en Shorebird → `app_id`
- [ ] Workflow de Codemagic para el flavor
- [ ] App Store Connect: ficha, privacidad, capturas
- [ ] Play Console: ficha, Data Safety, capturas
- [ ] URL de política de privacidad publicada y accesible

### Verificación final
- [ ] Login con email, con OTP y con Google
- [ ] Push recibido en foreground y en background, con imagen
- [ ] Deep link de push abre la nota correcta dentro de la app
- [ ] Renovación de sesión tras 1 hora
- [ ] Paywall aparece y el checkout web abre en navegador externo
- [ ] Anuncios visibles para anónimo, ocultos para suscriptor y admin
- [ ] Guardado offline con imágenes
- [ ] TTS lee con voz en español
- [ ] Modo avión: la app muestra caché en vez de cerrar sesión

## B.9 Riesgos a resolver antes de escalar

### 1. Licenciamiento Syncfusion — el más urgente

`syncfusion_flutter_pdfviewer` es hoy el visor de ediciones. La Community License es
gratuita solo bajo umbrales de facturación y tamaño de equipo; vendiendo la app a varios
medios se sale de ese rango rápido.

Dos caminos:

| Opción | Esfuerzo | Consecuencia |
|---|---|---|
| Licencia comercial | 0 días | Costo anual recurrente por desarrollador, a presupuestar dentro del precio de cada medio |
| Migrar a `pdfrx` o `pdfx` (open source) | 3 – 5 días | Sin costo recurrente; hay que reverificar zoom, cache y firma de URLs |

En cualquier caso: **eliminá ya `syncfusion_flutter_datepicker`**, que está declarado y sin usar.

### 2. Navegación imperativa

Con deep links de push, retorno del checkout web y N configuraciones de bottom nav según
flags, la navegación imperativa actual va a costar. Evaluar `go_router` en el repo base
(~3 días) antes de que haya tres medios en producción.

### 3. Firebase configs versionados

`google-services.json` y `GoogleService-Info.plist` están en el repo. Con un solo medio es
manejable; con varios conviene moverlos a variables de entorno de CI o a un repo privado de
configuración, y dejar solo plantillas versionadas.

### 4. Sin modo oscuro

Cada medio nuevo va a pedirlo. Definirlo **una vez** en `theme/` sale barato; hacerlo después,
pantalla por pantalla y por marca, no.

### 5. Cobertura de pruebas

40 % en `core/` y `branding/` no es un lujo: es lo que evita que un bug de sesión o de
resolución de marca se replique en todos los clientes a la vez.

---

## Apéndice — comandos útiles

```bash
# Análisis y pruebas
fvm flutter analyze
fvm flutter test

# Build por marca (repo base)
flutter build appbundle --flavor diarioTiempo --dart-define=BRAND=diario_tiempo
flutter build ipa       --flavor diarioTiempo --dart-define=BRAND=diario_tiempo

# Verificar que no quedó marca fuera de branding/
grep -ri "tiempo" lib/ --include=*.dart --exclude-dir=branding

# Detectar dependencias sin usar
flutter pub deps --style=compact

# Parche OTA
shorebird patch android
shorebird patch ios
```

---

**Última actualización:** 2026-08-25 · basado en `flips_app` `1.1.1+7`
