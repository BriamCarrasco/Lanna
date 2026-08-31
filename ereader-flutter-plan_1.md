# Lanna — plan de proyecto

> Inspirado en eReader Prestigio, pero open source, sin sus limitaciones, con sync propia vía Google Drive.

## Decisiones tomadas

- **Nombre**: la app se llama **Lanna**. Descriptor de acompañamiento (tiendas, sitio, README): "Lanna — eReader" / "Lanna: lector de EPUB y PDF". El binario, el título de ventana y `applicationName` usan solo "Lanna".
- **Bundle / application ID**: `com.lanna.reader` (ajustar si se consigue un dominio propio).
- **Logo**: cabeza de gato negro de frente, ojos ámbar/dorados, bigotes blancos y bandana/collar rojo con hebilla y anilla. Silueta casi negra (`#23212c`), acentos rojo/granate, ojos dorados. Archivos fuente: `assets/logo/lanna.svg` y `assets/logo/lanna.png`. Color semilla del tema: rojo del collar `#B52A33`. Sin parecido con eReader Prestigio.
- **Licencia**: **GPLv3** (copyleft — cualquier derivado distribuido debe publicarse también bajo GPL). Añadir archivo `LICENSE` con el texto completo y cabeceras de licencia en los fuentes.
- **Nota histórica**: "Lanna" es también un reino histórico del norte de Tailandia (Chiang Mai); no hay conflicto de marca, se menciona solo como contexto para el branding.

## Idea del proyecto

Lector de libros electrónicos open source, multiplataforma (Windows, macOS, Linux, Android), con foco en:

- Fidelidad de renderizado de EPUB (tipografía, layout, notas al pie, etc.)
- Animaciones de paso de página cuidadas (tipo curl/slide), al nivel de las que le gustan al usuario en eReader Prestigio
- Backup y sincronización de biblioteca + progreso de lectura entre dispositivos vía Google Drive

**Nota:** nombre y branding propios ya definidos (ver "Decisiones tomadas") — sin parecido con "eReader Prestigio".

## Alcance v1 (MVP)

- **Formatos soportados**: EPUB (prioridad), PDF
- **Formatos futuros (v2+)**: MOBI, FB2, CBZ/CBR
- **Funcionalidades core**:
  - Biblioteca local (importar, organizar, buscar)
  - Lectura paginada con animación de transición custom
  - Progreso de lectura, marcadores, anotaciones básicas
  - Temas claro/oscuro, ajuste de fuente y tamaño
  - Backup y sync de biblioteca + progreso vía Google Drive

## Stack elegido y por qué

### Framework de la app: Flutter (Dart)
Cubre las 4 plataformas objetivo desde un solo codebase. Su motor de renderizado (Skia/Impeller) está pensado para animaciones custom, ideal para el efecto de paso de página que buscas. Dart tiene sintaxis cercana a Java, lo que aprovecha tu experiencia previa. Ecosistema maduro tanto en mobile como en desktop.

### Motor de renderizado de contenido: WebView + epub.js (vía `flutter_epub_viewer`)
Un EPUB es esencialmente HTML/CSS/XHTML empaquetado con reglas de paginación propias. Reimplementar ese motor desde cero es un proyecto en sí mismo. `epub.js` es la librería más madura para esto (la usan lectores serios como Thorium Reader). Flutter se encarga del chrome de la app y de las animaciones por encima del WebView, así se obtiene fidelidad real al estándar EPUB sin renunciar a animaciones nativas.

### PDF: `pdfx` o `syncfusion_flutter_pdfviewer`
Soporte multiplataforma ya resuelto, evita reinventar un renderer de PDF desde cero.

### Almacenamiento local: SQLite vía `sqflite` o `drift`
Biblioteca, progreso de lectura, marcadores y anotaciones necesitan persistencia estructurada y consultas — SQLite es el estándar multiplataforma en Flutter.

### Gestión de estado: Riverpod
Testeable, sin dependencia de `BuildContext`, buen soporte para flujos async (carga de libros, sync con Drive).

### Sync: Google Drive API (`googleapis`) + `google_sign_in`
Acceso oficial a Drive, con soporte de OAuth multiplataforma vía `google_sign_in`.

### Animaciones de paso de página
Capa nativa en Flutter (no CSS del WebView) usando `CustomPainter` o paquetes como `page_flip`, para lograr el efecto curl/slide sobre el contenido ya renderizado.

## Arquitectura (capas)

1. **UI y animaciones** — Flutter / Dart
2. **Motor de lectura** — EPUB: WebView + epub.js · PDF: pdfx / syncfusion
3. **Almacenamiento local** — SQLite (sqflite / drift)
4. **Sincronización** — Google Drive API + OAuth

## Qué instalar / configurar

### 1. Flutter SDK
- Instalar Flutter SDK (incluye Dart) desde flutter.dev
- Correr `flutter doctor` y resolver cualquier dependencia faltante
- Habilitar soporte desktop:
  ```bash
  flutter config --enable-windows-desktop
  flutter config --enable-macos-desktop
  flutter config --enable-linux-desktop
  ```

### 2. Requisitos por plataforma
- **Windows**: Visual Studio 2022 (Community) con el workload "Desktop development with C++"
- **macOS**: Xcode completo + Xcode Command Line Tools + CocoaPods (`sudo gem install cocoapods`)
- **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- **Android**: Android Studio + Android SDK + JDK 17+

### 3. Editor
- Zed, con la extensión de Dart (Zed detecta y sugiere instalarla al abrir un archivo `.dart`; usa el Dart Analysis Server para autocompletado, diagnósticos y formateo)
- Claude Code corre desde terminal, así que funciona igual de bien dentro de la terminal integrada de Zed
- Para debugging visual de la UI (widget inspector, hot reload con inspección de árbol de widgets) puede ser útil tener Android Studio o VS Code instalado solo para eso, aunque no es obligatorio para el día a día

### 4. Google Cloud / Drive API
- Crear proyecto en Google Cloud Console
- Habilitar "Google Drive API"
- Configurar la pantalla de consentimiento OAuth
- Crear credenciales OAuth:
  - Client ID tipo "Desktop app" para Windows/macOS/Linux
  - Client ID tipo "Android" (requiere el SHA-1 del keystore de firma)
- Scopes recomendados: `drive.appdata` (metadata oculta al usuario) y, si vas a respaldar los archivos completos, `drive.file`

### 5. Paquetes Flutter principales (pubspec.yaml)
```yaml
dependencies:
  flutter_epub_viewer: ^latest
  pdfx: ^latest            # o syncfusion_flutter_pdfviewer
  sqflite: ^latest          # o drift
  path_provider: ^latest
  flutter_riverpod: ^latest
  google_sign_in: ^latest
  googleapis: ^latest
  googleapis_auth: ^latest
```
> Revisar versiones actuales en pub.dev antes de fijarlas — el ecosistema se mueve rápido.

## Estructura de proyecto sugerida

```
lib/
  core/           # utilidades, temas, constantes
  data/
    local/        # sqlite, DAOs
    drive/        # cliente Google Drive, lógica de sync
    models/       # Book, ReadingProgress, Bookmark, etc.
  features/
    library/      # pantalla de biblioteca
    reader/       # pantalla de lectura + animaciones
    settings/
  app.dart
  main.dart
```

## Roadmap sugerido

- **Fase 0** — Setup del proyecto, `flutter doctor` verde en Windows + Android (macOS/Linux se aplazan hasta tener ese hardware). Ver definición detallada abajo.
- **Fase 1** — Biblioteca local + importar EPUB + lectura básica (sin animación custom)
- **Fase 2** — Animaciones de paso de página propias
- **Fase 3** — Soporte PDF
- **Fase 4** — Integración Google Drive (auth + backup manual)
- **Fase 5** — Sync automática + resolución de conflictos (last-write-wins por timestamp)
- **Fase 6** — MOBI/FB2, anotaciones avanzadas, temas adicionales

## Fase 0 — definición detallada

**Objetivo:** proyecto Flutter que compila y corre en Windows y Android, con estructura, tooling, licencia y repo git listos. macOS/Linux quedan habilitados en el scaffold pero se prueban más adelante.

**Definition of Done:**
- `flutter doctor` sin errores para Windows + Android
- `flutter run -d windows` y `-d android` muestran una pantalla placeholder de "Biblioteca" con tema claro/oscuro
- `flutter analyze` limpio y `flutter test` (test de humo) pasa
- Repo git con `LICENSE` (GPLv3), `.gitignore`, `README.md` y primer commit
- Ícono de la app (el gato) configurado para Windows y Android

**Estado del entorno (verificado 2026-08-31):**
- Ya instalado: Git, Zed, Android Studio, Android SDK, JDK 21, **Visual Studio Build Tools 2019 16.11 + Windows 10 SDK** (Flutter lo acepta para compilar escritorio → no hace falta VS 2022)
- Instalado en esta sesión: **Flutter SDK 3.47.2** en `C:\dev\flutter` (añadido al PATH de usuario); Android **cmdline-tools** + licencias aceptadas
- `flutter doctor`: **sin errores** (Windows + Android + Chrome/web)

**Tareas — todas completadas:**
1. ✅ Flutter SDK 3.47.2 instalado, `flutter doctor` verde
2. ✅ Desktop ya habilitado por defecto en 3.47
3. ✅ `flutter create --org com.lanna --project-name lanna --platforms=android,windows,macos,linux .`
4. ✅ Estructura `lib/{core/{theme,router},data/{local,drive,models},features/{library,reader,settings}}` + `app.dart` + `main.dart`
5. ✅ Deps: `flutter_riverpod ^2.6.1`, `go_router ^18`, `path_provider`, `drift` + `drift_flutter`; dev: `drift_dev`, `build_runner`, `flutter_launcher_icons`, `flutter_lints ^6`
6. ✅ `analysis_options.yaml` con lints extra (single quotes, trailing commas, relative imports, etc.)
7. ✅ App shell: `ProviderScope` + `MaterialApp.router`, `AppTheme` claro/oscuro (semilla `#B52A33`), `go_router` `/` → `LibraryScreen` placeholder
8. ✅ Assets en `assets/logo/`; íconos generados con `flutter_launcher_icons` (Android adaptive + Windows `.ico`)
9. ✅ `LICENSE` (GPLv3 completo) + cabeceras SPDX en los fuentes Dart
10. ✅ `git init`, `.gitignore` de Flutter, `README.md`, primer commit
11. ⬜ (Opcional) CI GitHub Actions — pendiente
12. ✅ `flutter analyze` limpio, `flutter test` (smoke) pasa

**Decisiones cerradas para Fase 0:**
- Persistencia: **drift** (type-safe, migraciones)
- Router: **go_router**
- Nombre del paquete Dart: `lanna`
- Repo: local por ahora, GitHub cuando haya algo funcional

## Pendientes / decisiones abiertas

- Dominio propio para el bundle ID y el sitio
- Alcance real de "otros formatos" en v1
- Estrategia exacta de conflictos de sync (por ahora: timestamp + last-write-wins)
- GPLv3 vs AGPLv3 si en algún momento hay backend propio (por ahora GPLv3)
