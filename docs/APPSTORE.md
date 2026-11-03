# Publicar en la App Store

Camino: **cuenta de desarrollador → app en App Store Connect → build por TestFlight → ficha y revisión → publicar**.

## 0. Requisitos previos
- Apple Developer Program activo (99 USD/año) y los 4 secrets de GitHub de `docs/TESTFLIGHT.md`.
- Bundle ID `com.santidev.listafamiliar` registrado y la app creada en App Store Connect.
- Una build ya subida con el workflow `testflight` y probada en TestFlight.

## 1. Assets y datos que pide Apple (fuente: App Store Connect Help, consultada en noviembre de 2026)

### Imágenes
| Asset | Obligatorio | Especificación |
|---|---|---|
| **Icono de la app** | Sí | PNG de 1024×1024, **sin canal alfa** (si no, error ITMS-90717). Ya lo tenemos: RGB sin transparencia. Opcional: variantes oscura y tintada (iOS 18) o un `.icon` de Icon Composer (iOS 26, solo Mac) |
| **Capturas iPhone "Dynamic Island medio"** | **Sí** | 1206×2622 (o 1179×2556) |
| **Capturas iPhone "Dynamic Island grande"** (6,9") | **Sí** (o, en su lugar, Face ID grande 1284×2778) | 1320×2868 (o 1290×2796 / 1260×2736) |
| Resto de tamaños de iPhone | No | Apple los escala a partir de los anteriores |
| Capturas de iPad | No (la app es solo iPhone) | Solo harían falta con soporte de iPad: 13" = 2064×2752 |
| **Vista previa de la app** (vídeo) | No | 886×1920 vertical, 15 a 30 s, hasta 30 fps, H.264 (.mp4/.mov/.m4v), ≤ 500 MB, hasta 3 |

Reglas de las capturas: **mínimo 1 y máximo 10 por tamaño**, formato JPEG o PNG, **sin transparencias**.
Nota: a partir de abril de 2027 Apple pedirá también capturas "iPhone Duo" para apps compiladas con el SDK de iOS 27.1 o posterior.

### Textos y datos de la ficha
| Campo | Obligatorio | Límite / detalle |
|---|---|---|
| Nombre de la app | Sí | Máx. 30 caracteres |
| Subtítulo | No | Máx. 30 caracteres |
| Texto promocional | No | Máx. 170 caracteres; se puede cambiar sin nueva versión |
| Descripción | Sí | Máx. 4000 caracteres, texto plano |
| Palabras clave | Sí | Máx. 100 bytes, separadas por comas; sin repetir el nombre de la app |
| **URL de soporte** | **Sí** | Con `https://`; debe llevar a un contacto real (correo, dirección o teléfono) |
| URL de marketing | No | Con `https://` |
| **URL de política de privacidad** | **Sí** | Con `https://` |
| **Copyright** | **Sí** | Año y titular, por ejemplo `2026 Tu Nombre` |
| Categoría, precio y países | Sí | Compras o Estilo de vida; gratis |
| Clasificación por edades | Sí | Cuestionario |
| Etiquetas de privacidad | Sí | Correo y nombre (cuenta) y contenido del usuario (listas), vinculados al usuario, sin rastreo |
| Novedades de esta versión | Solo en actualizaciones | Máx. 4000 caracteres |

### Información de revisión (no visible al público)
- **Contacto**: nombre, correo y teléfono en formato internacional (`+34…`).
- **Cuenta de demostración** (obligatoria porque la app pide iniciar sesión): usuario y contraseña que no caduquen.
- **Notas** (máx. 4000 bytes): "El registro es por correo. Un grupo familiar se crea o se une con un código de 6 caracteres."

### Requisitos de la app que hoy nos faltan
| Requisito | Estado | Qué hacer |
|---|---|---|
| **Borrar la cuenta desde la app** (guideline 5.1.1(v)) | Falta | "Eliminar mi cuenta" en Ajustes + función SQL `delete_my_account()` en Supabase. Sin esto Apple rechaza la app |
| **Manifiesto de privacidad** (`PrivacyInfo.xcprivacy`) | Falta | Añadirlo al target con las APIs de "razón requerida" que usen la app y sus dependencias |
| Política de privacidad y URL de soporte | Faltan | Publicar dos páginas (por ejemplo con GitHub Pages) |
| Cifrado de exportación | Hecho | `ITSAppUsesNonExemptEncryption = false` |
| Sign in with Apple | No aplica | Solo es obligatorio si se ofrece login con terceros (Google, Facebook…) |

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

## 5. Generar las imágenes de la tienda (desde Windows)
1. **Capturar** en un iPhone 17 Pro Max (1320×2868). El compositor genera también el tamaño de 1206×2622 a partir de esas mismas capturas. Actions → `ios-preview` → Run workflow, con
   `device = iPhone 17 Pro Max` y `screens = welcome lists detail item-form settings`. Descarga el artefacto `ios-preview`
   y copia los `*-light.png` a `tools/store/raw/`.
   (Con `scripts/preview.sh` o `gh run download` también sirve.) En este modo las fechas de ejemplo son recientes ("hace 2 horas").
2. **Componer el carrusel**: `cd tools/store && npm install && node compose.mjs` (usa el Edge o Chrome instalado).
   Para la versión oscura: `node compose.mjs raw out-oscuro oscuro`.
3. Los textos de cada diapositiva están en `tools/store/store.json`. Salen en `tools/store/out/<tamaño>/*.jpg`, sin
   transparencia, en `out/iphone-6.9/` (1320×2868) y `out/iphone-6.3/` (1206×2622), listas para subir a App Store Connect.
