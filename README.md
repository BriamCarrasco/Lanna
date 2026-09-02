<p align="center">
  <img src="assets/logo/lanna.png" width="140" alt="Lanna">
</p>

<h1 align="center">Lanna</h1>

<p align="center">
  Lector de EPUB y PDF de código abierto para Windows y Android.
</p>

<p align="center">
  <a href="LICENSE"><img alt="Licencia GPL-3.0-or-later" src="https://img.shields.io/badge/licencia-GPL--3.0--or--later-blue"></a>
  <img alt="Plataformas: Windows y Android" src="https://img.shields.io/badge/plataformas-Windows%20%7C%20Android-lightgrey">
  <img alt="Hecho con Flutter" src="https://img.shields.io/badge/hecho%20con-Flutter-02569B">
</p>

---

**Lanna** es un lector de libros electrónicos centrado en tres cosas: fidelidad
de renderizado, un paso de página que se siente bien, y que tu biblioteca y tu
progreso de lectura sean tuyos.

> **Estado del proyecto:** en desarrollo activo. Utilizable a diario, pero aún
> sin una versión estable publicada. Los formatos y la interfaz pueden cambiar.

## Características

**Biblioteca**
- Importación de EPUB y PDF desde el explorador de archivos o arrastrando y soltando (escritorio).
- Portadas extraídas del propio archivo, con carátula generada cuando el libro no trae ninguna.
- Búsqueda por título y autor, insensible a acentos y mayúsculas.
- Colecciones propias y agrupación automática por autor.
- Fila de «Seguir leyendo» con el progreso de cada libro.

**Lectura**
- EPUB paginado con renderizado fiel: tipografía, notas al pie, imágenes y una o dos páginas según el ancho disponible.
- PDF con render nativo, una o dos páginas por vista.
- Animaciones de paso de página: curl, deslizar, desvanecer o ninguna.
- Cuatro temas de lectura (claro, sepia, oscuro, negro), tamaño de fuente, interlínea y elección entre serif y sans.
- Índice del libro, marcadores y búsqueda dentro del texto.
- Resaltados en cuatro colores con notas, tanto en EPUB como en PDF.
- Barra de progreso arrastrable para saltar por el libro.
- Modo inmersivo a pantalla completa en móvil.
- El progreso de lectura se guarda solo y se restaura al reabrir.

**En camino**
- Sincronización de biblioteca y progreso vía Google Drive.
- Formatos MOBI, FB2 y CBZ.

## Stack

| Capa | Tecnología |
|---|---|
| Aplicación | Flutter (Dart) |
| Motor EPUB | `epub.js` sobre `flutter_inappwebview`, servido por un servidor HTTP local (`shelf`) en `127.0.0.1` |
| Motor PDF | `pdfrx` (PDFium) |
| Parseo EPUB | Implementación propia con `archive` + `xml` |
| Base de datos | SQLite mediante `drift` |
| Estado | Riverpod |
| Navegación | `go_router` |

El contenido del EPUB se sirve desde un servidor local en el bucle de retorno,
con cabeceras CSP que bloquean la ejecución de scripts y las conexiones de red
del propio libro.

## Requisitos de desarrollo

- **Flutter SDK 3.47 o superior**, con `flutter doctor` sin errores.
- **Windows**
  - Visual Studio Build Tools con el workload «Desktop development with C++».
  - WebView2 Runtime (viene preinstalado en Windows 11).
  - NuGet CLI accesible desde el `PATH`, que lo necesita `flutter_inappwebview_windows`.
- **Android**
  - Android SDK y JDK 17 o superior, con las licencias aceptadas.
  - El proyecto fija Android Gradle Plugin 8.11, Kotlin 2.2.20 y Gradle 8.14.3,
    porque `flutter_inappwebview` todavía no admite AGP 9. Flutter avisará de
    ello en cada compilación; es esperado y no impide compilar.

## Compilación

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # código generado de drift

flutter run -d windows
flutter run -d <id-del-dispositivo-android>
```

Comprobaciones antes de publicar cambios:

```bash
flutter analyze
flutter test
```

Regenerar los iconos de la aplicación tras cambiar el logotipo:

```bash
dart run flutter_launcher_icons
```

## Licencia

Distribuido bajo [GPL-3.0-or-later](LICENSE). Copyright © 2026 los
contribuidores de Lanna.

Cualquier versión modificada que se distribuya debe publicarse también bajo la
GPL.

### Componentes de terceros

| Componente | Licencia |
|---|---|
| [epub.js](https://github.com/futurepress/epub.js) | BSD-2-Clause |
| [JSZip](https://stuk.github.io/jszip/) | MIT |
| Tipografías Manrope y Newsreader | SIL Open Font License 1.1 |

Las tipografías se distribuyen en `assets/fonts/` junto a sus licencias
(`OFL-*.txt`); epub.js y JSZip, en `assets/reader/`.
