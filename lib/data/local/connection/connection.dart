// Picks the right database connection for the current platform at compile time:
// native SQLite on mobile/desktop, SQLite-on-WASM (IndexedDB) on the web.
//
// The rest of the app only ever calls [openConnection]; it doesn't know or care
// which implementation is in use.
export 'unsupported.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.html) 'web.dart';
