import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/pos_menu_runtime_models.dart';
import 'pos_menu_sync_cache_models.dart';

PosMenuSyncCache createPosMenuSyncCache() => FilePosMenuSyncCache();

/// Stores only immutable static projection data. Runtime overlays are fetched
/// anew and intentionally cannot become a version identity.
class FilePosMenuSyncCache implements PosMenuSyncCache {
  FilePosMenuSyncCache({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}pos_menu_sync');
  }

  Future<File> _fileFor(PosMenuCacheScope scope) async {
    final Directory directory = await _directoryProvider();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}${scope.fileName}');
  }

  @override
  Future<PosCachedMenu?> read(PosMenuCacheScope scope) async {
    try {
      final File file = await _fileFor(scope);
      final File previous = File('${file.path}.previous');
      if (!await file.exists() && await previous.exists()) {
        await previous.rename(file.path);
      }
      if (!await file.exists()) return null;
      return PosCachedMenu.fromJson(
        jsonDecode(await file.readAsString()),
        expectedScope: scope,
      );
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on PosMenuContractException {
      return null;
    }
  }

  @override
  Future<void> write(PosCachedMenu menu) async {
    final File target = await _fileFor(menu.scope);
    final File temporary = File('${target.path}.next');
    final File previous = File('${target.path}.previous');
    await temporary.writeAsString(encodePosCachedMenu(menu), flush: true);
    if (await previous.exists()) await previous.delete();
    if (await target.exists()) await target.rename(previous.path);
    await temporary.rename(target.path);
    if (await previous.exists()) await previous.delete();
  }

  @override
  Future<void> clear(PosMenuCacheScope scope) async {
    final File target = await _fileFor(scope);
    if (await target.exists()) await target.delete();
    final File previous = File('${target.path}.previous');
    if (await previous.exists()) await previous.delete();
  }
}
