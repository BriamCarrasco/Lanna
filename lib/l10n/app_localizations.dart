import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @done.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get done;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @undo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get undo;

  /// No description provided for @open.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get open;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get delete;

  /// No description provided for @archive.
  ///
  /// In es, this message translates to:
  /// **'Archivar'**
  String get archive;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @rename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get rename;

  /// No description provided for @remove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get remove;

  /// No description provided for @move.
  ///
  /// In es, this message translates to:
  /// **'Mover'**
  String get move;

  /// No description provided for @name.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get name;

  /// No description provided for @search.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get search;

  /// No description provided for @refresh.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refresh;

  /// No description provided for @library.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get library;

  /// No description provided for @favorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritos'**
  String get favorites;

  /// No description provided for @folders.
  ///
  /// In es, this message translates to:
  /// **'Carpetas'**
  String get folders;

  /// No description provided for @collections.
  ///
  /// In es, this message translates to:
  /// **'Colecciones'**
  String get collections;

  /// No description provided for @authors.
  ///
  /// In es, this message translates to:
  /// **'Autores'**
  String get authors;

  /// No description provided for @stats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get stats;

  /// No description provided for @settings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settings;

  /// No description provided for @noAuthor.
  ///
  /// In es, this message translates to:
  /// **'Sin autor'**
  String get noAuthor;

  /// No description provided for @noBooksInLibrary.
  ///
  /// In es, this message translates to:
  /// **'No hay libros en la biblioteca'**
  String get noBooksInLibrary;

  /// No description provided for @newCollection.
  ///
  /// In es, this message translates to:
  /// **'Nueva colección'**
  String get newCollection;

  /// No description provided for @createCollectionHint.
  ///
  /// In es, this message translates to:
  /// **'Crea una colección para agrupar tus libros'**
  String get createCollectionHint;

  /// No description provided for @noCollectionMatches.
  ///
  /// In es, this message translates to:
  /// **'Ninguna colección coincide con la búsqueda'**
  String get noCollectionMatches;

  /// No description provided for @collection.
  ///
  /// In es, this message translates to:
  /// **'Colección'**
  String get collection;

  /// No description provided for @addBooks.
  ///
  /// In es, this message translates to:
  /// **'Añadir libros'**
  String get addBooks;

  /// No description provided for @renameCollection.
  ///
  /// In es, this message translates to:
  /// **'Renombrar colección'**
  String get renameCollection;

  /// No description provided for @deleteCollection.
  ///
  /// In es, this message translates to:
  /// **'Eliminar colección'**
  String get deleteCollection;

  /// No description provided for @emptyCollection.
  ///
  /// In es, this message translates to:
  /// **'Esta colección está vacía'**
  String get emptyCollection;

  /// No description provided for @booksInCollection.
  ///
  /// In es, this message translates to:
  /// **'Libros en la colección'**
  String get booksInCollection;

  /// No description provided for @libraryEmpty.
  ///
  /// In es, this message translates to:
  /// **'La biblioteca está vacía'**
  String get libraryEmpty;

  /// No description provided for @noFavoritesHint.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes favoritos. Abre el menú de un libro (clic derecho o mantener presionado) y elige «Añadir a favoritos».'**
  String get noFavoritesHint;

  /// No description provided for @noFavoritesResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados en tus favoritos'**
  String get noFavoritesResults;

  /// No description provided for @noFoldersChosen.
  ///
  /// In es, this message translates to:
  /// **'Todavía no elegiste ninguna carpeta'**
  String get noFoldersChosen;

  /// No description provided for @chooseFolder.
  ///
  /// In es, this message translates to:
  /// **'Elegir carpeta'**
  String get chooseFolder;

  /// No description provided for @chooseBooksFolder.
  ///
  /// In es, this message translates to:
  /// **'Elegir carpeta de libros'**
  String get chooseBooksFolder;

  /// No description provided for @folderNoBooks.
  ///
  /// In es, this message translates to:
  /// **'Esta carpeta no tiene libros'**
  String get folderNoBooks;

  /// No description provided for @noFolderResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados en esta carpeta'**
  String get noFolderResults;

  /// No description provided for @filterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get filterAll;

  /// No description provided for @filterComics.
  ///
  /// In es, this message translates to:
  /// **'Cómics'**
  String get filterComics;

  /// No description provided for @filterUnread.
  ///
  /// In es, this message translates to:
  /// **'Sin empezar'**
  String get filterUnread;

  /// No description provided for @filterReading.
  ///
  /// In es, this message translates to:
  /// **'Leyendo'**
  String get filterReading;

  /// No description provided for @filterFinished.
  ///
  /// In es, this message translates to:
  /// **'Terminados'**
  String get filterFinished;

  /// No description provided for @libraryUpToDate.
  ///
  /// In es, this message translates to:
  /// **'La biblioteca está al día'**
  String get libraryUpToDate;

  /// No description provided for @sortRecent.
  ///
  /// In es, this message translates to:
  /// **'Recientes'**
  String get sortRecent;

  /// No description provided for @sortTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get sortTitle;

  /// No description provided for @sortAuthor.
  ///
  /// In es, this message translates to:
  /// **'Autor'**
  String get sortAuthor;

  /// No description provided for @selectVolumes.
  ///
  /// In es, this message translates to:
  /// **'Selecciona tomos'**
  String get selectVolumes;

  /// No description provided for @clearSelection.
  ///
  /// In es, this message translates to:
  /// **'Quitar selección'**
  String get clearSelection;

  /// No description provided for @selectAll.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todo'**
  String get selectAll;

  /// No description provided for @moveToSeries.
  ///
  /// In es, this message translates to:
  /// **'Mover a serie'**
  String get moveToSeries;

  /// No description provided for @selectVolumesTooltip.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar tomos'**
  String get selectVolumesTooltip;

  /// No description provided for @sort.
  ///
  /// In es, this message translates to:
  /// **'Ordenar'**
  String get sort;

  /// No description provided for @addFolder.
  ///
  /// In es, this message translates to:
  /// **'Añadir carpeta'**
  String get addFolder;

  /// No description provided for @refreshLibrary.
  ///
  /// In es, this message translates to:
  /// **'Actualizar biblioteca'**
  String get refreshLibrary;

  /// No description provided for @scanning.
  ///
  /// In es, this message translates to:
  /// **'Revisando tus carpetas…'**
  String get scanning;

  /// No description provided for @continueReading.
  ///
  /// In es, this message translates to:
  /// **'Seguir leyendo'**
  String get continueReading;

  /// No description provided for @results.
  ///
  /// In es, this message translates to:
  /// **'Resultados'**
  String get results;

  /// No description provided for @allBooks.
  ///
  /// In es, this message translates to:
  /// **'Todos los libros'**
  String get allBooks;

  /// No description provided for @noFilterMatches.
  ///
  /// In es, this message translates to:
  /// **'Ningún libro coincide con los filtros'**
  String get noFilterMatches;

  /// No description provided for @clearFilters.
  ///
  /// In es, this message translates to:
  /// **'Quitar filtros'**
  String get clearFilters;

  /// No description provided for @details.
  ///
  /// In es, this message translates to:
  /// **'Detalles'**
  String get details;

  /// No description provided for @removeFavorite.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritos'**
  String get removeFavorite;

  /// No description provided for @addFavorite.
  ///
  /// In es, this message translates to:
  /// **'Añadir a favoritos'**
  String get addFavorite;

  /// No description provided for @markUnfinished.
  ///
  /// In es, this message translates to:
  /// **'Marcar como no terminado'**
  String get markUnfinished;

  /// No description provided for @markFinished.
  ///
  /// In es, this message translates to:
  /// **'Marcar como terminado'**
  String get markFinished;

  /// No description provided for @addToCollection.
  ///
  /// In es, this message translates to:
  /// **'Añadir a colección'**
  String get addToCollection;

  /// No description provided for @seriesEllipsis.
  ///
  /// In es, this message translates to:
  /// **'Serie…'**
  String get seriesEllipsis;

  /// No description provided for @select.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar'**
  String get select;

  /// No description provided for @noCollectionsYet.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes colecciones'**
  String get noCollectionsYet;

  /// No description provided for @archiveBookBody.
  ///
  /// In es, this message translates to:
  /// **'Dejará de aparecer en la biblioteca, pero conserva su progreso, marcadores y subrayados. El archivo se queda en su carpeta. Puedes recuperarlo desde Ajustes → Libros archivados.'**
  String get archiveBookBody;

  /// No description provided for @deleteBookBody.
  ///
  /// In es, this message translates to:
  /// **'Se quitará de la biblioteca y se borrará el archivo importado, junto con su progreso y marcadores. No se puede deshacer.'**
  String get deleteBookBody;

  /// No description provided for @notStarted.
  ///
  /// In es, this message translates to:
  /// **'Sin empezar'**
  String get notStarted;

  /// No description provided for @read.
  ///
  /// In es, this message translates to:
  /// **'Leer'**
  String get read;

  /// No description provided for @unavailable.
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get unavailable;

  /// No description provided for @pageShort.
  ///
  /// In es, this message translates to:
  /// **'Pág.'**
  String get pageShort;

  /// No description provided for @noBooksInFolders.
  ///
  /// In es, this message translates to:
  /// **'No encontramos libros en tus carpetas'**
  String get noBooksInFolders;

  /// No description provided for @yourLibraryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Tu biblioteca está vacía'**
  String get yourLibraryEmpty;

  /// No description provided for @emptyLibraryHintFolders.
  ///
  /// In es, this message translates to:
  /// **'Lanna lee EPUB, PDF, CBZ y CBR. Copia tus libros a la carpeta y actualiza la biblioteca.'**
  String get emptyLibraryHintFolders;

  /// No description provided for @emptyLibraryHint.
  ///
  /// In es, this message translates to:
  /// **'Elige la carpeta donde guardas tus libros. Lanna los lee desde ahí, sin copiarlos.'**
  String get emptyLibraryHint;

  /// No description provided for @closeFilters.
  ///
  /// In es, this message translates to:
  /// **'Cerrar filtros'**
  String get closeFilters;

  /// No description provided for @filters.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get filters;

  /// No description provided for @format.
  ///
  /// In es, this message translates to:
  /// **'Formato'**
  String get format;

  /// No description provided for @status.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get status;

  /// No description provided for @searchLibrary.
  ///
  /// In es, this message translates to:
  /// **'Buscar en la biblioteca'**
  String get searchLibrary;

  /// No description provided for @driveDisconnected.
  ///
  /// In es, this message translates to:
  /// **'Google Drive · Sin conectar'**
  String get driveDisconnected;

  /// No description provided for @renameSeries.
  ///
  /// In es, this message translates to:
  /// **'Renombrar serie'**
  String get renameSeries;

  /// No description provided for @moveToASeries.
  ///
  /// In es, this message translates to:
  /// **'Mover a una serie'**
  String get moveToASeries;

  /// No description provided for @seriesName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la serie'**
  String get seriesName;

  /// No description provided for @removeFromSeries.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la serie'**
  String get removeFromSeries;

  /// No description provided for @split.
  ///
  /// In es, this message translates to:
  /// **'Separar'**
  String get split;

  /// No description provided for @seriesOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones de la serie'**
  String get seriesOptions;

  /// No description provided for @splitVolumes.
  ///
  /// In es, this message translates to:
  /// **'Separar tomos'**
  String get splitVolumes;

  /// No description provided for @archiveSeries.
  ///
  /// In es, this message translates to:
  /// **'Archivar serie'**
  String get archiveSeries;

  /// No description provided for @seriesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Esta serie ya no tiene tomos'**
  String get seriesEmpty;

  /// No description provided for @bookNotInLibrary.
  ///
  /// In es, this message translates to:
  /// **'El libro no está en la biblioteca'**
  String get bookNotInLibrary;

  /// No description provided for @bookFileNotFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontró el archivo del libro'**
  String get bookFileNotFound;

  /// No description provided for @bookStructureError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la estructura del libro'**
  String get bookStructureError;

  /// No description provided for @pdfPasswordProtected.
  ///
  /// In es, this message translates to:
  /// **'PDF protegido con contraseña'**
  String get pdfPasswordProtected;

  /// No description provided for @pdfOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el PDF'**
  String get pdfOpenError;

  /// No description provided for @pdfProtected.
  ///
  /// In es, this message translates to:
  /// **'PDF protegido'**
  String get pdfProtected;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @bookmarkRemoved.
  ///
  /// In es, this message translates to:
  /// **'Marcador quitado'**
  String get bookmarkRemoved;

  /// No description provided for @bookmarkAdded.
  ///
  /// In es, this message translates to:
  /// **'Marcador añadido'**
  String get bookmarkAdded;

  /// No description provided for @editNote.
  ///
  /// In es, this message translates to:
  /// **'Editar nota'**
  String get editNote;

  /// No description provided for @addNote.
  ///
  /// In es, this message translates to:
  /// **'Añadir nota'**
  String get addNote;

  /// No description provided for @note.
  ///
  /// In es, this message translates to:
  /// **'Nota'**
  String get note;

  /// No description provided for @writeNote.
  ///
  /// In es, this message translates to:
  /// **'Escribe una nota'**
  String get writeNote;

  /// No description provided for @textCopied.
  ///
  /// In es, this message translates to:
  /// **'Texto copiado'**
  String get textCopied;

  /// No description provided for @tableOfContents.
  ///
  /// In es, this message translates to:
  /// **'Índice'**
  String get tableOfContents;

  /// No description provided for @appearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearance;

  /// No description provided for @bookmark.
  ///
  /// In es, this message translates to:
  /// **'Marcador'**
  String get bookmark;

  /// No description provided for @bookNoPages.
  ///
  /// In es, this message translates to:
  /// **'El libro no tiene páginas'**
  String get bookNoPages;

  /// No description provided for @bookNoChapters.
  ///
  /// In es, this message translates to:
  /// **'El libro no tiene capítulos legibles'**
  String get bookNoChapters;

  /// No description provided for @theme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @font.
  ///
  /// In es, this message translates to:
  /// **'Fuente'**
  String get font;

  /// No description provided for @fontBook.
  ///
  /// In es, this message translates to:
  /// **'Libro'**
  String get fontBook;

  /// No description provided for @woff2Unsupported.
  ///
  /// In es, this message translates to:
  /// **'Este libro trae su fuente en un formato que Lanna todavía no puede abrir (WOFF2).'**
  String get woff2Unsupported;

  /// No description provided for @size.
  ///
  /// In es, this message translates to:
  /// **'Tamaño'**
  String get size;

  /// No description provided for @lineSpacing.
  ///
  /// In es, this message translates to:
  /// **'Interlínea'**
  String get lineSpacing;

  /// No description provided for @pages.
  ///
  /// In es, this message translates to:
  /// **'Páginas'**
  String get pages;

  /// No description provided for @columnsAuto.
  ///
  /// In es, this message translates to:
  /// **'Auto'**
  String get columnsAuto;

  /// No description provided for @pageNumbers.
  ///
  /// In es, this message translates to:
  /// **'N.º pág.'**
  String get pageNumbers;

  /// No description provided for @show.
  ///
  /// In es, this message translates to:
  /// **'Mostrar'**
  String get show;

  /// No description provided for @hide.
  ///
  /// In es, this message translates to:
  /// **'Ocultar'**
  String get hide;

  /// No description provided for @reading.
  ///
  /// In es, this message translates to:
  /// **'Lectura'**
  String get reading;

  /// No description provided for @leftToRight.
  ///
  /// In es, this message translates to:
  /// **'Izq → Der'**
  String get leftToRight;

  /// No description provided for @rightToLeft.
  ///
  /// In es, this message translates to:
  /// **'Der → Izq'**
  String get rightToLeft;

  /// No description provided for @searchInBook.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el libro'**
  String get searchInBook;

  /// No description provided for @wordOrPhrase.
  ///
  /// In es, this message translates to:
  /// **'Palabra o frase'**
  String get wordOrPhrase;

  /// No description provided for @searching.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get searching;

  /// No description provided for @typeAndEnter.
  ///
  /// In es, this message translates to:
  /// **'Escribe y pulsa Enter'**
  String get typeAndEnter;

  /// No description provided for @noMatches.
  ///
  /// In es, this message translates to:
  /// **'Sin coincidencias'**
  String get noMatches;

  /// No description provided for @noToc.
  ///
  /// In es, this message translates to:
  /// **'Este libro no trae índice'**
  String get noToc;

  /// No description provided for @noBookmarks.
  ///
  /// In es, this message translates to:
  /// **'Sin marcadores todavía'**
  String get noBookmarks;

  /// No description provided for @noNotes.
  ///
  /// In es, this message translates to:
  /// **'Sin notas todavía'**
  String get noNotes;

  /// No description provided for @chapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos'**
  String get chapters;

  /// No description provided for @bookmarks.
  ///
  /// In es, this message translates to:
  /// **'Marcadores'**
  String get bookmarks;

  /// No description provided for @notes.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get notes;

  /// No description provided for @archivedBooks.
  ///
  /// In es, this message translates to:
  /// **'Libros archivados'**
  String get archivedBooks;

  /// No description provided for @archivedBooksHint.
  ///
  /// In es, this message translates to:
  /// **'No aparecen en la biblioteca. Al restaurarlos vuelven con su progreso, marcadores y subrayados. También puedes eliminarlos del dispositivo.'**
  String get archivedBooksHint;

  /// No description provided for @noArchivedBooks.
  ///
  /// In es, this message translates to:
  /// **'No hay libros archivados'**
  String get noArchivedBooks;

  /// No description provided for @restore.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get restore;

  /// No description provided for @deleteFromDevice.
  ///
  /// In es, this message translates to:
  /// **'Eliminar del dispositivo'**
  String get deleteFromDevice;

  /// No description provided for @exportProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar progreso de lectura'**
  String get exportProgressTitle;

  /// No description provided for @progressExported.
  ///
  /// In es, this message translates to:
  /// **'Progreso de lectura exportado'**
  String get progressExported;

  /// No description provided for @exportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar el progreso. Inténtalo de nuevo.'**
  String get exportFailed;

  /// No description provided for @importProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar progreso de lectura'**
  String get importProgressTitle;

  /// No description provided for @importFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar el progreso. Inténtalo de nuevo.'**
  String get importFailed;

  /// No description provided for @backupNoProgress.
  ///
  /// In es, this message translates to:
  /// **'El respaldo no tiene progreso para importar'**
  String get backupNoProgress;

  /// No description provided for @noNewProgress.
  ///
  /// In es, this message translates to:
  /// **'No había progreso nuevo que importar'**
  String get noNewProgress;

  /// No description provided for @backupTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El archivo es demasiado grande'**
  String get backupTooLarge;

  /// No description provided for @backupInvalid.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es un respaldo válido'**
  String get backupInvalid;

  /// No description provided for @backupNotLanna.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es un respaldo de progreso de Lanna'**
  String get backupNotLanna;

  /// No description provided for @backupNoBooks.
  ///
  /// In es, this message translates to:
  /// **'El respaldo no contiene libros'**
  String get backupNoBooks;

  /// No description provided for @linkOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el enlace'**
  String get linkOpenFailed;

  /// No description provided for @pageAnimation.
  ///
  /// In es, this message translates to:
  /// **'Animación de paso de página'**
  String get pageAnimation;

  /// No description provided for @pageAnimationHint.
  ///
  /// In es, this message translates to:
  /// **'Efecto al avanzar entre páginas'**
  String get pageAnimationHint;

  /// No description provided for @animationCurl.
  ///
  /// In es, this message translates to:
  /// **'Pasar hoja'**
  String get animationCurl;

  /// No description provided for @animationSlide.
  ///
  /// In es, this message translates to:
  /// **'Deslizar'**
  String get animationSlide;

  /// No description provided for @animationFade.
  ///
  /// In es, this message translates to:
  /// **'Desvanecer'**
  String get animationFade;

  /// No description provided for @animationNone.
  ///
  /// In es, this message translates to:
  /// **'Ninguna'**
  String get animationNone;

  /// No description provided for @edgeTaps.
  ///
  /// In es, this message translates to:
  /// **'Tocar los bordes para pasar página'**
  String get edgeTaps;

  /// No description provided for @keepAwake.
  ///
  /// In es, this message translates to:
  /// **'Mantener la pantalla encendida al leer'**
  String get keepAwake;

  /// No description provided for @dailyGoalSetting.
  ///
  /// In es, this message translates to:
  /// **'Meta diaria de lectura'**
  String get dailyGoalSetting;

  /// No description provided for @dailyGoalHint.
  ///
  /// In es, this message translates to:
  /// **'La racha cuenta los días en que la cumples'**
  String get dailyGoalHint;

  /// No description provided for @syncDrive.
  ///
  /// In es, this message translates to:
  /// **'Sincronización · Google Drive'**
  String get syncDrive;

  /// No description provided for @notConnected.
  ///
  /// In es, this message translates to:
  /// **'Sin conectar'**
  String get notConnected;

  /// No description provided for @driveSoon.
  ///
  /// In es, this message translates to:
  /// **'Sincronización con Drive: próximamente'**
  String get driveSoon;

  /// No description provided for @connect.
  ///
  /// In es, this message translates to:
  /// **'Conectar'**
  String get connect;

  /// No description provided for @readingProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso de lectura'**
  String get readingProgress;

  /// No description provided for @exportProgress.
  ///
  /// In es, this message translates to:
  /// **'Exportar progreso'**
  String get exportProgress;

  /// No description provided for @exportProgressHint.
  ///
  /// In es, this message translates to:
  /// **'Guarda un respaldo para llevarlo a otro dispositivo'**
  String get exportProgressHint;

  /// No description provided for @export.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get export;

  /// No description provided for @importProgress.
  ///
  /// In es, this message translates to:
  /// **'Importar progreso'**
  String get importProgress;

  /// No description provided for @importProgressHint.
  ///
  /// In es, this message translates to:
  /// **'Los libros se reconocen por su contenido; se conserva siempre la lectura más reciente'**
  String get importProgressHint;

  /// No description provided for @import.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get import;

  /// No description provided for @libraryFolders.
  ///
  /// In es, this message translates to:
  /// **'Carpetas de la biblioteca'**
  String get libraryFolders;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @removeFolderBody.
  ///
  /// In es, this message translates to:
  /// **'Sus libros dejarán de aparecer en la biblioteca, junto con su progreso, marcadores y subrayados. Los archivos no se tocan.'**
  String get removeFolderBody;

  /// No description provided for @noFolderHint.
  ///
  /// In es, this message translates to:
  /// **'Todavía no elegiste ninguna carpeta. Lanna lee los libros desde ahí, sin copiarlos.'**
  String get noFolderHint;

  /// No description provided for @foldersHint.
  ///
  /// In es, this message translates to:
  /// **'Lanna lee los libros desde estas carpetas, sin copiarlos.'**
  String get foldersHint;

  /// No description provided for @removeFolder.
  ///
  /// In es, this message translates to:
  /// **'Quitar carpeta'**
  String get removeFolder;

  /// No description provided for @sourceCode.
  ///
  /// In es, this message translates to:
  /// **'Código fuente'**
  String get sourceCode;

  /// No description provided for @checkUpdates.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualizaciones'**
  String get checkUpdates;

  /// No description provided for @licenses.
  ///
  /// In es, this message translates to:
  /// **'Licencias'**
  String get licenses;

  /// No description provided for @legalNotice.
  ///
  /// In es, this message translates to:
  /// **'Copyright © 2026 Lanna contributors.\nSoftware libre bajo la licencia GPL-3.0-or-later. Se distribuye SIN NINGUNA GARANTÍA.'**
  String get legalNotice;

  /// No description provided for @originTitle.
  ///
  /// In es, this message translates to:
  /// **'De dónde viene Lanna'**
  String get originTitle;

  /// No description provided for @originNameTitle.
  ///
  /// In es, this message translates to:
  /// **'El nombre'**
  String get originNameTitle;

  /// No description provided for @originNameText.
  ///
  /// In es, this message translates to:
  /// **'Cuando leo, Lanna suele estar ahí: sobre mis piernas o en algún lugar cerca. Su compañía se volvió parte de la lectura, así que la aplicación lleva su nombre.'**
  String get originNameText;

  /// No description provided for @originNamePhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto de Lanna'**
  String get originNamePhoto;

  /// No description provided for @originLogoTitle.
  ///
  /// In es, this message translates to:
  /// **'El logo'**
  String get originLogoTitle;

  /// No description provided for @originLogoText.
  ///
  /// In es, this message translates to:
  /// **'Zoe, mi otra gata, también es negra. Aparece de vez en cuando mientras leo o trabajo en la aplicación, y en ella se inspira el logo.'**
  String get originLogoText;

  /// No description provided for @originLogoPhoto.
  ///
  /// In es, this message translates to:
  /// **'Foto de Zoe'**
  String get originLogoPhoto;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @appLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la aplicación'**
  String get appLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get languageSystem;

  /// No description provided for @today.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get today;

  /// No description provided for @dailyGoal.
  ///
  /// In es, this message translates to:
  /// **'Meta diaria'**
  String get dailyGoal;

  /// No description provided for @statsEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Lanna empieza a medir desde ahora. Cada vez que leas se suma el tiempo, y deja de contar tras 5 minutos sin pasar página ni tocar la pantalla.'**
  String get statsEmptyHint;

  /// No description provided for @goalMet.
  ///
  /// In es, this message translates to:
  /// **'Meta cumplida'**
  String get goalMet;

  /// No description provided for @streak.
  ///
  /// In es, this message translates to:
  /// **'Racha'**
  String get streak;

  /// No description provided for @noStreak.
  ///
  /// In es, this message translates to:
  /// **'Sin racha'**
  String get noStreak;

  /// No description provided for @streakHint.
  ///
  /// In es, this message translates to:
  /// **'Cumple la meta para empezar una'**
  String get streakHint;

  /// No description provided for @thisWeek.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get thisWeek;

  /// No description provided for @sinceMonday.
  ///
  /// In es, this message translates to:
  /// **'Desde el lunes'**
  String get sinceMonday;

  /// No description provided for @thisYear.
  ///
  /// In es, this message translates to:
  /// **'Este año'**
  String get thisYear;

  /// No description provided for @lastMonths.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{ÚLTIMO MES} other{ÚLTIMOS {count} MESES}}'**
  String lastMonths(int count);

  /// No description provided for @noReading.
  ///
  /// In es, this message translates to:
  /// **'Sin lectura'**
  String get noReading;

  /// No description provided for @timePerMonth.
  ///
  /// In es, this message translates to:
  /// **'Tiempo por mes'**
  String get timePerMonth;

  /// No description provided for @daysWithReading.
  ///
  /// In es, this message translates to:
  /// **'Días con lectura'**
  String get daysWithReading;

  /// No description provided for @less.
  ///
  /// In es, this message translates to:
  /// **'Menos'**
  String get less;

  /// No description provided for @more.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get more;

  /// No description provided for @comicCbrFromFolder.
  ///
  /// In es, this message translates to:
  /// **'Este dispositivo no puede leer CBR desde una carpeta'**
  String get comicCbrFromFolder;

  /// No description provided for @comicInvalid.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es un CBZ ni un CBR válido'**
  String get comicInvalid;

  /// No description provided for @comicStopped.
  ///
  /// In es, this message translates to:
  /// **'El lector de cómics se detuvo'**
  String get comicStopped;

  /// No description provided for @comicNoPages.
  ///
  /// In es, this message translates to:
  /// **'El cómic no tiene páginas'**
  String get comicNoPages;

  /// No description provided for @comicClosed.
  ///
  /// In es, this message translates to:
  /// **'El cómic está cerrado'**
  String get comicClosed;

  /// No description provided for @comicDamaged.
  ///
  /// In es, this message translates to:
  /// **'El CBZ está dañado'**
  String get comicDamaged;

  /// No description provided for @dateShortPattern.
  ///
  /// In es, this message translates to:
  /// **'dd/MM/yyyy'**
  String get dateShortPattern;

  /// No description provided for @dayPattern.
  ///
  /// In es, this message translates to:
  /// **'EEEE d \'de\' MMMM'**
  String get dayPattern;

  /// No description provided for @authorsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 autor} other{{count} autores}}'**
  String authorsCount(int count);

  /// No description provided for @booksCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 libro} other{{count} libros}}'**
  String booksCount(int count);

  /// No description provided for @volumesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 tomo} other{{count} tomos}}'**
  String volumesCount(int count);

  /// No description provided for @collectionsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 colección} other{{count} colecciones}}'**
  String collectionsCount(int count);

  /// No description provided for @foldersCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 carpeta} other{{count} carpetas}}'**
  String foldersCount(int count);

  /// No description provided for @selectedCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 seleccionado} other{{count} seleccionados}}'**
  String selectedCount(int count);

  /// No description provided for @scanNewBooks.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 libro nuevo} other{{count} libros nuevos}}'**
  String scanNewBooks(int count);

  /// No description provided for @scanMoved.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 movido} other{{count} movidos}}'**
  String scanMoved(int count);

  /// No description provided for @scanMissing.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 no encontrado} other{{count} no encontrados}}'**
  String scanMissing(int count);

  /// No description provided for @scanFailed.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 no se pudo leer} other{{count} no se pudieron leer}}'**
  String scanFailed(int count);

  /// No description provided for @matchesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 coincidencia} other{{count} coincidencias}}'**
  String matchesCount(int count);

  /// No description provided for @daysCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 día} other{{count} días}}'**
  String daysCount(int count);

  /// No description provided for @finishedBooksCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 libro terminado} other{{count} libros terminados}}'**
  String finishedBooksCount(int count);

  /// No description provided for @backupUpToDate.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 libro ya al día} other{{count} libros ya al día}}'**
  String backupUpToDate(int count);

  /// No description provided for @backupCollections.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 colección actualizada} other{{count} colecciones actualizadas}}'**
  String backupCollections(int count);

  /// No description provided for @backupUnmatched.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 libro no está en esta biblioteca} other{{count} libros no están en esta biblioteca}}'**
  String backupUnmatched(int count);

  /// No description provided for @backupInvalidEntries.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 entrada no válida} other{{count} entradas no válidas}}'**
  String backupInvalidEntries(int count);

  /// No description provided for @progressImportedIn.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Progreso importado en 1 libro} other{Progreso importado en {count} libros}}'**
  String progressImportedIn(int count);

  /// No description provided for @chaptersCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 capítulo} other{{count} capítulos}}'**
  String chaptersCount(int count);

  /// No description provided for @pagesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 página} other{{count} páginas}}'**
  String pagesCount(int count);

  /// No description provided for @seriesReadCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 leído} other{{count} leídos}}'**
  String seriesReadCount(int count);

  /// No description provided for @scanNoAccess.
  ///
  /// In es, this message translates to:
  /// **'sin acceso a «{name}»'**
  String scanNoAccess(String name);

  /// No description provided for @scanFolderFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo revisar la carpeta: {error}'**
  String scanFolderFailed(String error);

  /// No description provided for @volumesOutOfSeries.
  ///
  /// In es, this message translates to:
  /// **'{volumes} fuera de su serie'**
  String volumesOutOfSeries(String volumes);

  /// No description provided for @volumesInSeries.
  ///
  /// In es, this message translates to:
  /// **'{volumes} en «{name}»'**
  String volumesInSeries(String volumes, String name);

  /// No description provided for @scanningProgress.
  ///
  /// In es, this message translates to:
  /// **'Revisando tus carpetas… {count} de {total}'**
  String scanningProgress(int count, int total);

  /// No description provided for @errorDetail.
  ///
  /// In es, this message translates to:
  /// **'Error: {error}'**
  String errorDetail(String error);

  /// No description provided for @noResultsFor.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados para «{query}»'**
  String noResultsFor(String query);

  /// No description provided for @bookMissingInFolder.
  ///
  /// In es, this message translates to:
  /// **'No se encuentra «{title}» en su carpeta. Revisa la carpeta y actualiza la biblioteca.'**
  String bookMissingInFolder(String title);

  /// No description provided for @bookArchived.
  ///
  /// In es, this message translates to:
  /// **'«{title}» archivado'**
  String bookArchived(String title);

  /// No description provided for @bookDeleted.
  ///
  /// In es, this message translates to:
  /// **'«{title}» eliminado'**
  String bookDeleted(String title);

  /// No description provided for @archiveBookTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Archivar «{title}»?'**
  String archiveBookTitle(String title);

  /// No description provided for @deleteBookTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{title}»?'**
  String deleteBookTitle(String title);

  /// No description provided for @addedOn.
  ///
  /// In es, this message translates to:
  /// **'Añadido {date}'**
  String addedOn(String date);

  /// No description provided for @finishedOn.
  ///
  /// In es, this message translates to:
  /// **'Terminado {date}'**
  String finishedOn(String date);

  /// No description provided for @readingProgressPercent.
  ///
  /// In es, this message translates to:
  /// **'Progreso de lectura: {percent} %'**
  String readingProgressPercent(int percent);

  /// No description provided for @timeRead.
  ///
  /// In es, this message translates to:
  /// **'Tiempo leído: {time}'**
  String timeRead(String time);

  /// No description provided for @timeReadRemaining.
  ///
  /// In es, this message translates to:
  /// **'{read} · faltan ~{time}'**
  String timeReadRemaining(String read, String time);

  /// No description provided for @seriesOf.
  ///
  /// In es, this message translates to:
  /// **'Serie de «{title}»'**
  String seriesOf(String title);

  /// No description provided for @moveVolumesToSeries.
  ///
  /// In es, this message translates to:
  /// **'Mover {count} tomos a una serie'**
  String moveVolumesToSeries(int count);

  /// No description provided for @archiveSeriesTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Archivar «{name}»?'**
  String archiveSeriesTitle(String name);

  /// No description provided for @archiveSeriesBody.
  ///
  /// In es, this message translates to:
  /// **'Los {count} tomos dejarán de aparecer en la biblioteca, pero conservan su progreso, marcadores y subrayados. Los archivos se quedan en su carpeta. Puedes recuperarlos desde Ajustes → Libros archivados.'**
  String archiveSeriesBody(int count);

  /// No description provided for @splitSeriesTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Separar «{name}»?'**
  String splitSeriesTitle(String name);

  /// No description provided for @splitSeriesBody.
  ///
  /// In es, this message translates to:
  /// **'Los {count} tomos volverán a aparecer como libros sueltos en la biblioteca. No se borra ningún archivo ni progreso de lectura.'**
  String splitSeriesBody(int count);

  /// No description provided for @seriesSplit.
  ///
  /// In es, this message translates to:
  /// **'«{name}» separada en {count} tomos'**
  String seriesSplit(String name, int count);

  /// No description provided for @seriesArchived.
  ///
  /// In es, this message translates to:
  /// **'«{name}» archivada · {count} tomos'**
  String seriesArchived(String name, int count);

  /// No description provided for @bookOpenError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el libro\n{error}'**
  String bookOpenError(String error);

  /// No description provided for @pageRange.
  ///
  /// In es, this message translates to:
  /// **'Páginas {first}–{last} de {total}'**
  String pageRange(int first, int last, int total);

  /// No description provided for @pageOf.
  ///
  /// In es, this message translates to:
  /// **'Página {page} de {total}'**
  String pageOf(int page, int total);

  /// No description provided for @pageShortOf.
  ///
  /// In es, this message translates to:
  /// **'Pág. {page} de {total}'**
  String pageShortOf(int page, int total);

  /// No description provided for @chapterReadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el capítulo {chapter}'**
  String chapterReadError(int chapter);

  /// No description provided for @minutesLeft.
  ///
  /// In es, this message translates to:
  /// **'quedan ~{mins} min'**
  String minutesLeft(int mins);

  /// No description provided for @bookDeletedFromDevice.
  ///
  /// In es, this message translates to:
  /// **'«{title}» eliminado del dispositivo'**
  String bookDeletedFromDevice(String title);

  /// No description provided for @deleteDeniedFolder.
  ///
  /// In es, this message translates to:
  /// **'Lanna no tiene permiso para borrar en «{folder}». Vuelve a añadir la carpeta desde la Biblioteca para concederlo.'**
  String deleteDeniedFolder(String folder);

  /// No description provided for @deleteDenied.
  ///
  /// In es, this message translates to:
  /// **'Lanna no tiene permiso para borrar en esa carpeta. Vuelve a añadir la carpeta desde la Biblioteca para concederlo.'**
  String get deleteDenied;

  /// No description provided for @deleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar «{title}». Inténtalo de nuevo.'**
  String deleteFailed(String title);

  /// No description provided for @deleteFromDeviceTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{title}» del dispositivo?'**
  String deleteFromDeviceTitle(String title);

  /// No description provided for @deleteFromDeviceBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará el archivo «{file}» y se quitará de Lanna junto con su progreso, marcadores, subrayados y tiempo de lectura. No se puede deshacer.'**
  String deleteFromDeviceBody(String file);

  /// No description provided for @deleteFromFolderBody.
  ///
  /// In es, this message translates to:
  /// **'Se borrará el archivo «{file}» de la carpeta «{folder}» y se quitará de Lanna junto con su progreso, marcadores, subrayados y tiempo de lectura. No se puede deshacer.'**
  String deleteFromFolderBody(String file, String folder);

  /// No description provided for @removeFolderTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar «{name}»?'**
  String removeFolderTitle(String name);

  /// No description provided for @archivedBooksCount.
  ///
  /// In es, this message translates to:
  /// **'Libros archivados · {count}'**
  String archivedBooksCount(int count);

  /// No description provided for @minutesPerDay.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min al día'**
  String minutesPerDay(int minutes);

  /// No description provided for @goalMinutes.
  ///
  /// In es, this message translates to:
  /// **'Meta: {goal} min'**
  String goalMinutes(int goal);

  /// No description provided for @timeMissing.
  ///
  /// In es, this message translates to:
  /// **'Faltan {time}'**
  String timeMissing(String time);

  /// No description provided for @bestStreak.
  ///
  /// In es, this message translates to:
  /// **'Mejor: {days}'**
  String bestStreak(String days);

  /// No description provided for @comicExtractFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo extraer el CBR: {detail}'**
  String comicExtractFailed(String detail);

  /// No description provided for @comicReadFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el cómic: {detail}'**
  String comicReadFailed(String detail);

  /// No description provided for @weekdayFirst.
  ///
  /// In es, this message translates to:
  /// **'L'**
  String get weekdayFirst;

  /// No description provided for @weekdayThird.
  ///
  /// In es, this message translates to:
  /// **'X'**
  String get weekdayThird;

  /// No description provided for @weekdayFifth.
  ///
  /// In es, this message translates to:
  /// **'V'**
  String get weekdayFifth;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
