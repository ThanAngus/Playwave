import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> getVideoFolder() async {
  Directory? directory;

  if (Platform.isAndroid) {
    directory = await getExternalStorageDirectory();
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  }

  if (directory != null) {
    String videosPath = directory.path;
    Directory videosDirectory = Directory(videosPath);
    if (await videosDirectory.exists()) {
      return videosPath;
    }
  }

  return '';
}
