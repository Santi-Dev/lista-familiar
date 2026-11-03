# Publicar en la App Store

Camino: **cuenta de desarrollador → app en App Store Connect → build por TestFlight → ficha y revisión → publicar**.

## 0. Requisitos previos
- Apple Developer Program activo (99 USD/año) y los 4 secrets de GitHub de `docs/TESTFLIGHT.md`.
- Bundle ID `com.santidev.listafamiliar` registrado y la app creada en App Store Connect.
- Una build ya subida con el workflow `testflight` y probada en TestFlight.

## 1. Lo que Apple exige y hoy NOS FALTA
| Requisito | Estado | Qué hacer |
|---|---|---|
| **Borrar cuenta desde la app** (guideline 5.1.1(v)) | Falta | Añadir "Eliminar mi cuenta" en Ajustes + función SQL `delete_my_account()` en Supabase que borre el usuario. Sin esto Apple rechaza la app |
| **URL de política de privacidad** | Falta | Publicar una página (por ejemplo GitHub Pages) y poner la URL en App Store Connect |
| **Manifiesto de privacidad** (`PrivacyInfo.xcprivacy`) | Falta | Añadirlo al target declarando las APIs de "razón requerida" que use la app y sus dependencias |
| **Cuenta de demostración** para el revisor | Falta | Crear un usuario de prueba con un grupo y listas; darlo en "Información de revisión" |
| **Capturas** | Falta | iPhone 6,9" (1320×2868), de 3 a 10. Se pueden generar con `scripts/preview.sh` / los snapshots y reescalar |
| **URL de soporte** y correo de contacto | Falta | Una página o un correo de soporte |
| Icono 1024×1024 sin transparencia | Hecho (revisar que no tenga canal alfa) | `Assets.xcassets/AppIcon` |
| Cifrado de exportación | Hecho | `ITSAppUsesNonExemptEncryption = false` (solo HTTPS) |
| Sign in with Apple | No aplica | Solo es obligatorio si se ofrece login con Google/Facebook u otros terceros; aquí es correo y contraseña |

## 2. Ficha en App Store Connect
1. **Información de la app**: nombre (máx. 30 caracteres), subtítulo, categoría (Compras o Estilo de vida), idioma principal Español.
2. **Precio y disponibilidad**: gratis y países.
3. **Privacidad de la app** (etiquetas): se recopilan correo y nombre (cuenta) y contenido del usuario (listas), vinculados a la
   identidad, para el funcionamiento de la app. **Sin rastreo** (no hay SDK de analítica ni publicidad).
4. **Versión 1.0**: descripción, palabras clave, texto "Novedades", capturas, URL de soporte, URL de privacidad.
5. **Clasificación por edades**: cuestionario (sin contenido sensible, resultado 4+).
6. **Revisión de la app**: contacto, cuenta de demostración y notas ("el registro es por correo; un grupo familiar se crea o se une con un código").
7. **Build**: elige la build que subió el workflow `testflight`.

## 3. Enviar a revisión y publicar
1. Pulsa **Añadir para revisión** → **Enviar a revisión**. Suele tardar entre 24 y 48 h.
2. Si la rechazan, App Store Connect explica el motivo; se corrige, se sube otra build y se reenvía.
3. Elige **liberación manual o automática** al aprobarse.
4. Para versiones siguientes: sube `MARKETING_VERSION` en `swift_space/project.yml`, lanza `testflight` y crea la nueva versión en App Store Connect.

## 4. Antes de abrirla al público (Supabase)
- El plan gratuito **pausa los proyectos tras ~1 semana sin actividad**: para producción conviene el plan Pro.
- El correo integrado de Supabase tiene un límite muy bajo y no está pensado para producción: configura un **SMTP propio**
  si añades recuperación de contraseña o confirmación de correo.
- Revisa las políticas RLS cada vez que cambie el esquema (los snapshots no las cubren).
