# Configuración recomendada para Google Sign-In

Sí: antes de que el botón de Google funcione en una app real, se debe crear y configurar el proyecto en Google Cloud Console o Firebase Console. La app Flutter solo inicia el flujo; Google valida que el paquete/bundle, las huellas de firma y los OAuth Client IDs coincidan con lo registrado.

## 1. Google Cloud Console

1. Crear o seleccionar un proyecto en Google Cloud Console.
2. Configurar la pantalla de consentimiento OAuth.
3. Crear un OAuth Client ID de tipo **Web application**. Este es el `GOOGLE_WEB_CLIENT_ID` que se pasa al backend y al plugin como `serverClientId`.
4. Crear un OAuth Client ID de tipo **Android** con:
   - Package name: debe coincidir con `applicationId` en `android/app/build.gradle.kts`.
   - SHA-1 y SHA-256 de cada firma que uses: debug, release y Play App Signing si publicas en Google Play.
5. Si compilas iOS, crear un OAuth Client ID de tipo **iOS** con el bundle id de la app y configurar el URL scheme reverso en Xcode/Info.plist.

## 2. Variables de compilación Flutter

La implementación lee los Client IDs por `--dart-define` para no quemar credenciales/configuración de ambiente en el repositorio:

```bash
flutter run \
  --dart-define=GOOGLE_WEB_CLIENT_ID="TU_WEB_CLIENT_ID.apps.googleusercontent.com" \
  --dart-define=GOOGLE_IOS_CLIENT_ID="TU_IOS_CLIENT_ID.apps.googleusercontent.com"
```

Para Android, `GOOGLE_WEB_CLIENT_ID` es obligatorio en esta implementación porque se usa para solicitar un ID token verificable por el backend. `GOOGLE_IOS_CLIENT_ID` solo aplica si compilas iOS/macOS.

## 3. Backend

El endpoint público que llama Flutter es `POST /api/auth/google`, con `Content-Type: application/json`. La app debe mandar únicamente el ID token de Google en la propiedad `idToken`; el backend también acepta los alias `credential` o `token`, pero `idToken` es la opción recomendada:

```json
{
  "idToken": "GOOGLE_ID_TOKEN"
}
```

La implementación obtiene el token con `GoogleSignIn(serverClientId: GOOGLE_WEB_CLIENT_ID).signIn()`, lee `googleUser.authentication.idToken` y envía solo `{ "idToken": idToken }` al backend. No se envían email, nombre ni datos del perfil porque el servidor debe derivar la identidad desde el token validado.

El backend debe validar el `idToken` del lado del servidor antes de crear la sesión propia de la app. Validaciones mínimas recomendadas:

- Firma del token contra las llaves públicas de Google.
- `iss` igual a `https://accounts.google.com` o `accounts.google.com`.
- `aud` igual al Web Client ID configurado para la app/backend.
- `exp` no vencido.
- Usar el `sub` de Google como identificador estable; no confiar en el email/nombre enviado por el cliente como fuente de verdad.

## 4. Errores comunes

- `clientConfigurationError`, `ApiException: 10`, `12500` o cancelación después de elegir cuenta: suele ser package name, SHA-1/SHA-256 o Web Client ID incorrecto.
- `idToken` vacío: falta `serverClientId`/`GOOGLE_WEB_CLIENT_ID` o el cliente OAuth no corresponde al proyecto/app.
- Funciona en debug pero falla en release: falta registrar la huella SHA de release o la de Play App Signing.


## Referencias oficiales

- Google OpenID Connect: https://developers.google.com/identity/openid-connect/openid-connect
- Plugin Flutter `google_sign_in`: https://pub.dev/packages/google_sign_in
- Configuración Android del plugin: https://pub.dev/packages/google_sign_in_android
