import 'dart:io' as io;

import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Las imágenes de los libros, para leerlos sin conexión.
///
/// Antes iban a la caché por defecto de `flutter_cache_manager`, que guarda
/// como mucho 200 archivos y borra lo que no se haya mirado en 30 días. El
/// libro 1 solo ya tiene 226 imágenes, y además compartían sitio con las
/// portadas y con las de los demás libros: unos segundos después de terminar
/// la descarga, la limpieza de la caché borraba las que sobraban y en el
/// lector salían en blanco sin conexión.
class BookImages {
  BookImages._();

  static final CacheManager cache = CacheManager(
    Config(
      'bookImages',
      stalePeriod: const Duration(days: 3650),
      maxNrOfCacheObjects: 100000,
      fileSystem: offlineFileSystem('bookImages'),
    ),
  );

  /// La caché de antes, para recuperar lo que siga ahí sin volver a bajarlo.
  static BaseCacheManager get legacy => DefaultCacheManager();
}

/// Sistema de archivos para una caché que tiene que sobrevivir: en la carpeta
/// de soporte de la app y no en la temporal, que Android o iOS vacían cuando
/// les falta espacio (y el usuario con «Borrar caché»). En web, la de
/// memoria de siempre: allí no hay carpetas.
FileSystem offlineFileSystem(String key) =>
    kIsWeb ? MemoryCacheSystem() : _SupportDirFileSystem(key);

class _SupportDirFileSystem implements FileSystem {
  _SupportDirFileSystem(this._key) : _dir = _createDirectory(_key);

  final String _key;
  final Future<Directory> _dir;

  static Future<Directory> _createDirectory(String key) async {
    const fs = LocalFileSystem();
    final target =
        fs.directory(p.join((await getApplicationSupportDirectory()).path, key));
    if (!await target.exists()) {
      // Lo que se bajó cuando esta caché vivía en la carpeta temporal se
      // trae entero: el índice guarda solo el nombre del archivo, así que
      // sigue valiendo y no hay que volver a descargar nada.
      final old = io.Directory(
        p.join((await getTemporaryDirectory()).path, key),
      );
      try {
        if (await old.exists()) await old.rename(target.path);
      } catch (_) {
        // Si no se puede mover, se vuelve a bajar lo que falte.
      }
    }
    await target.create(recursive: true);
    return target;
  }

  @override
  Future<File> createFile(String name) async {
    final dir = await _dir;
    if (!await dir.exists()) await _createDirectory(_key);
    return dir.childFile(name);
  }
}
