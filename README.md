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

## Noticias

La pantalla de noticias ya no consume WordPress directamente: usa el mismo backend que el resto de las APIs (`apiUrl` en `lib/constants.dart`), que se encarga de hablar con WordPress y devuelve las mismas respuestas.

Endpoints:

- Listado: `/api/noticias?page=1&perPage=10`
- Filtros opcionales: `categoria`, `busqueda`, `fechaDesde`, `fechaHasta` (fechas en ISO 8601 UTC).
- Noticia por link: `/api/noticias/by-link?link=<url-codificada>`
- Noticia por slug: `/api/noticias/by-link?slug=<slug>`
- Categorías: `/api/noticias/categorias?perPage=100`

Son endpoints públicos: la app no exige sesión para consultarlos, pero envía `Authorization: Bearer <jwt>` cuando ya hay una sesión válida. Ya no se necesitan las credenciales de WordPress (`--dart-define=WP_USER/WP_PASS`).
