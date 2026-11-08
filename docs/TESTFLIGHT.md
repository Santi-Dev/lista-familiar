# Subir a TestFlight desde Windows

El workflow `.github/workflows/testflight.yml` compila en un runner macOS de GitHub, firma con
firma automática (API key de App Store Connect) y sube la build a TestFlight.

## Lo que tienes que hacer tú (una sola vez)

1. **Apple Developer Program** (99 USD/año): developer.apple.com/programs.
   Anota tu **Team ID** (developer.apple.com → Account → Membership details).
2. **Registrar el Bundle ID**: Certificates, Identifiers & Profiles → Identifiers → `+` → App IDs → App →
   Bundle ID (Explicit) `com.santidev.listafamiliar`.
3. **Crear la app**: appstoreconnect.apple.com → Apps → `+` → New App → iOS, nombre "Lista Familiar",
   idioma Spanish, bundle id `com.santidev.listafamiliar`, SKU libre (p. ej. `lista-familiar`).
4. **API key**: App Store Connect → Users and Access → Integrations → App Store Connect API → `+`,
   rol **Admin** (o App Manager con acceso a certificados). Descarga el `.p8` (solo se puede una vez)
   y anota **Key ID** e **Issuer ID**.
5. **Secrets en GitHub** (repo → Settings → Secrets and variables → Actions → New repository secret):
   | Secret | Valor |
   |---|---|
   | `APPLE_TEAM_ID` | tu Team ID |
   | `ASC_KEY_ID` | Key ID de la API key |
   | `ASC_ISSUER_ID` | Issuer ID |
   | `ASC_KEY_P8` | contenido completo del archivo `.p8` (con las líneas BEGIN/END) |
6. **Lanzar**: Actions → `testflight` → Run workflow. El número de build es el nº de ejecución.
7. En App Store Connect → TestFlight, la build tarda unos minutos en procesarse. Añade testers
   internos (tu Apple ID) e instala con la app TestFlight en el iPhone.

## Notas
- Nunca pegues el `.p8` ni los secrets en el chat ni los commitees.
- Para testers externos hace falta rellenar "Test Information" y pasar la revisión beta de Apple.
- Confirmación de correo: en Supabase está desactivada (Authentication → Providers → Email); si la activas,
  el registro pedirá confirmar el correo antes de entrar.
- La versión (`MARKETING_VERSION`) está en los ajustes del target `ListaFamiliar` (`ios/ListaFamiliar.xcodeproj`, General → Identity → Version).
