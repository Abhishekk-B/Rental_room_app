import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaStorageService {
  /// Saves a picked image file to persistent local app storage
  static Future<String> saveMediaLocally(File sourceFile, {required String subfolder}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docsDir.path, subfolder));

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final ext = p.extension(sourceFile.path);
    final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(targetDir.path, filename);

    final savedFile = await sourceFile.copy(targetPath);
    return savedFile.path;
  }
}
