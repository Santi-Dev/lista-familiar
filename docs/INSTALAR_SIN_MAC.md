# Instalar la app en tu iPhone desde Windows (sin Apple Developer)

Sirve para probar rápido. La app firmada con un Apple ID gratuito **caduca a los 7 días**: hay que reinstalarla.
Para distribuirla a la familia sin caducidad, usa TestFlight (`docs/TESTFLIGHT.md`).

## 1. Obtener el .ipa
1. GitHub → pestaña **Actions** → workflow **build-ipa** → **Run workflow**.
2. Espera unos 10 minutos. Al terminar, abre la ejecución y descarga el artefacto **ListaFamiliar-ipa** (es un .zip
   con `ListaFamiliar.ipa` dentro). Descomprímelo.

(También con `gh run download <id> -n ListaFamiliar-ipa`.)

## 2. Instalar con Sideloadly (Windows)
1. Instala **iTunes** y **iCloud** desde la web de Apple (no las versiones de la Microsoft Store: Sideloadly lo exige).
2. Instala **Sideloadly** (sideloadly.io).
3. Conecta el iPhone por cable y pulsa *Confiar en este ordenador*.
4. En Sideloadly: arrastra el `.ipa`, escribe tu Apple ID y pulsa **Start**.
   - Recomendado: usa un Apple ID secundario solo para esto.
   - Si pide contraseña específica de app, créala en appleid.apple.com.
5. En el iPhone: Ajustes → General → **VPN y gestión de dispositivos** → tu Apple ID → **Confiar**.
6. En iPhone con iOS 16+, activa **Ajustes → Privacidad y seguridad → Modo desarrollador** y reinicia.
7. Abre **Lista Familiar**.

## Límites del Apple ID gratuito
- Caduca cada 7 días (reinstala con Sideloadly) y permite pocas apps activas.
- Solo funciona en dispositivos donde la instales tú.
- Es normal que la app tenga otro bundle id (Sideloadly lo ajusta al firmar).

## Qué probar primero
1. Registrarte (Supabase debe tener desactivado *Confirm email*).
2. Crear un grupo familiar y anotar el código.
3. Crear una lista, añadir y marcar artículos.
4. Instalar en otro móvil, unirse con el código y comprobar que los cambios llegan en tiempo real.
