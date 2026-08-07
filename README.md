# flips_app
Aplicación móvil de los flips digitales de Diario Tiempo.

## Flujo de suscripción web

Por políticas de las tiendas digitales, Flutter no procesa compras internas ni abre checkouts de pago embebidos. Cuando la app detecta que la cuenta no tiene una suscripción activa, delega la gestión al sitio web:

1. Flutter muestra el mensaje `Tu cuenta no tiene una suscripción activa. Puedes gestionar tu cuenta desde nuestro sitio web.`
2. Al tocar el botón, Flutter solicita una sesión web con `POST /api/mobile/web-session?redirect=/checkout`.
3. El backend responde con `{ "ok": true, "url": "...", "expiresInSeconds": 90 }`.
4. Flutter abre esa `url` en el navegador externo del dispositivo.
5. Next.js valida el handoff, crea la cookie web y redirige al usuario a `/checkout` autenticado.

Todas las llamadas al backend se hacen con `Authorization: Bearer <jwt>` y `Content-Type: application/json` cuando aplica.

## Noticias de WordPress

La pantalla de noticias consume `https://tiempo.hn/wp-json/wp/v2/posts`. Si el sitio responde `401`, compila o ejecuta la app con credenciales de una contraseña de aplicación de WordPress mediante `--dart-define`; no guardes esa contraseña en el repositorio.

Ejemplo:

```bash
flutter run \
  --dart-define=WORDPRESS_API_USERNAME=<usuario-o-correo-wordpress> \
  --dart-define=WORDPRESS_API_APP_PASSWORD=<contraseña-de-aplicación>
```
