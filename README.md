# flips_app
Aplicacion movil de los flips digitales de diario tiempo

## Configuración de PixelPay

La app lee las credenciales públicas de PixelPay desde variables inyectadas por Flutter con `--dart-define` al ejecutar o compilar. Aunque los nombres empiezan con `NEXT_PUBLIC_`, en Flutter no se cargan automáticamente desde `.env`; hay que pasarlas en el comando o configurarlas en el pipeline de build.

Variables soportadas:

- `NEXT_PUBLIC_PIXELPAY_ENDPOINT`: endpoint de PixelPay. Si no se envía, la app usa `https://hn.ficoposonline.com`.
- `NEXT_PUBLIC_PIXELPAY_KEY_ID`: llave pública/key id de PixelPay.
- `NEXT_PUBLIC_PIXELPAY_KEY_HASH`: hash/secret requerido por el SDK de PixelPay.

Ejemplo para desarrollo:

```bash
flutter run \
  --dart-define=NEXT_PUBLIC_PIXELPAY_ENDPOINT=https://hn.ficoposonline.com \
  --dart-define=NEXT_PUBLIC_PIXELPAY_KEY_ID=TU_KEY_ID \
  --dart-define=NEXT_PUBLIC_PIXELPAY_KEY_HASH=TU_KEY_HASH
```

Ejemplo para compilar:

```bash
flutter build apk --release \
  --dart-define=NEXT_PUBLIC_PIXELPAY_ENDPOINT=https://hn.ficoposonline.com \
  --dart-define=NEXT_PUBLIC_PIXELPAY_KEY_ID=TU_KEY_ID \
  --dart-define=NEXT_PUBLIC_PIXELPAY_KEY_HASH=TU_KEY_HASH
```

> Nota: cualquier valor usado por el SDK en una app cliente puede inspeccionarse en el binario o en la app web. No subas credenciales reales al repositorio; para producción, lo ideal es que el backend entregue la configuración necesaria del checkout o que las credenciales se inyecten desde variables seguras del CI/CD.
