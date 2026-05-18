# flips_app
Aplicación móvil de los flips digitales de Diario Tiempo.

## Flujo de pago PixelPay hosted checkout

La app ya no usa el SDK de PixelPay ni captura datos de tarjeta en Flutter. El pago se delega al backend y a la URL segura de PixelPay:

1. Flutter solicita al backend un checkout con `POST /api/mobile/pixelpay/hosted/checkout`.
2. El backend responde con `pagoId` y `paymentUrl`.
3. Flutter abre `paymentUrl` en una WebView.
4. La WebView se cierra cuando PixelPay redirige a `completeUrl` o `cancelUrl`.
5. Flutter consulta el resultado final con `GET /api/mobile/pixelpay/hosted/status?pagoId=...`.
6. Si el backend responde un pago exitoso, la app continúa el flujo de membresía.

Todas las llamadas al backend se hacen con `Authorization: Bearer <jwt>` y `Content-Type: application/json` cuando aplica.

## Noticias de WordPress

La pantalla de noticias consume `https://tiempo.hn/wp-json/wp/v2/posts`. Si el sitio responde `401`, compila o ejecuta la app con credenciales de una contraseña de aplicación de WordPress mediante `--dart-define`; no guardes esa contraseña en el repositorio.

Ejemplo:

```bash
flutter run \
  --dart-define=WORDPRESS_API_USERNAME=<usuario-o-correo-wordpress> \
  --dart-define=WORDPRESS_API_APP_PASSWORD=<contraseña-de-aplicación>
```
