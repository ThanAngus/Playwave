import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../model/models.dart';
import '../../model/uiStateModel.dart';
import '../constants/enumConstants.dart';

void thumbnailGenerator(Map<String, dynamic> message) async {
  final String videoPath = message['videoPath'];
  final String tempDirPath = message['tempDir'];
  final replyPort = message['replyPort'] as SendPort;
  final String? thumbnailPath = await _thumbnailWorker(videoPath, tempDirPath);

  replyPort.send(thumbnailPath);
}

Future<String?> _thumbnailWorker(String videoPath, String tempPath) async {
  String? thumbnail;
  try {
    thumbnail = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      thumbnailPath: tempPath,
      imageFormat: ImageFormat.JPEG,
    );
  } catch (e, stack) {
    if (kDebugMode) {
      print("error is $e");
      print(stack);
    }
  }
  return thumbnail;
}

final videoProvider = StateNotifierProvider<VideoNotifier, AsyncValue<List<FolderModel>>>(
  (ref) => VideoNotifier(),
);

class VideoNotifier extends StateNotifier<AsyncValue<List<FolderModel>>> {
  VideoNotifier() : super(const AsyncValue.loading()) {
    initializeHive();
  }

  Future<void> initializeHive() async {
    try {
      var dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(FolderModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(VideoModelAdapter());
      }
      var value = await Hive.openBox<FolderModel>('videoBox');
      state = AsyncValue.data(value.values.toList());
      sortList(SortBy.name, OrderBy.ascending);
      fetchVideos();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<List<Directory>> getExternalStorageDirectory() async {
    List<Directory> storages = (await getExternalStorageDirectories())!;
    storages = storages.map((Directory e) {
      final List<String> splitPathList = e.path.split("/");
      return Directory(splitPathList
          .sublist(
              0, splitPathList.indexWhere((element) => element == "Android"))
          .join("/"));
    }).toList();
    return storages;
  }

  Future<void> fetchVideos() async {
    try {
      List<Directory> storages = await getExternalStorageDirectory();
      for (var storage in storages) {
        await for (var folder in _fetchVideosRecursively(storage)) {
          await checkForUpdates(folder); // Call checkForUpdates here
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching videos: $e');
      }
    }
  }

  static Future<String?> _generateThumbnail(
      String videoPath, String tempDir) async {
    final thumbnailReceivePort = ReceivePort();
    final isolate = await FlutterIsolate.spawn(
      thumbnailGenerator,
      {
        'videoPath': videoPath,
        'tempDir': tempDir,
        'replyPort': thumbnailReceivePort.sendPort,
      },
    );
    final String? thumbnailPath = await thumbnailReceivePort.first;
    isolate.kill();
    return thumbnailPath;
  }

  Stream<FolderModel> _fetchVideosRecursively(Directory dir) async* {
    final appDocDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final receivePort = ReceivePort();
    final message = {
      'sendPort': receivePort.sendPort,
      'directory': dir.path,
      'appDocumentPath': appDocDir.path,
      'tempPath': tempDir.path,
    };
    final isolate = await FlutterIsolate.spawn(
      _fetchVideosWorker,
      message,
    );
    await for (final folderMap in receivePort) {
      final folder = FolderModel.fromJson(folderMap as Map<String, dynamic>);
      yield folder;
    }
    isolate.kill();
  }

  static void _fetchVideosWorker(Map<String, dynamic> message) async {
    final sendPort = message['sendPort'] as SendPort;
    final directory = Directory(message['directory']);
    final appDocumentPath = message['appDocumentPath'];
    final tempPath = message['tempPath'];
    await _processDirectory(sendPort, directory, appDocumentPath, tempPath);
  }

  static Future<void> _processDirectory(SendPort sendPort, Directory dir,
      String appDocumentsPath, String tempDir) async {
    Hive.init(appDocumentsPath);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FolderModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(VideoModelAdapter());
    }
    await Hive.openBox<FolderModel>('videoBox');
    final List<FileSystemEntity> entities = await dir.list().toList();
    final List<VideoModel> videos = [];


    bool isVideoFile(File file) {
      final List<String> videoExtensions = [
        '.mp4',
        '.avi',
        '.mkv',
        '.mov',
        '.wmv'
      ];
      return videoExtensions
          .any((ext) => file.path.toLowerCase().endsWith(ext));
    }

    bool isFileHidden(File file) {
      return file.path.split('/').last.startsWith('.');
    }

    var box = Hive.box<FolderModel>('videoBox');
    for (final entity in entities) {
      try {
        if (entity is File && isVideoFile(entity) && !isFileHidden(entity)) {
          if (entity.existsSync()) {
            final existingVideo = box.values
                .expand((folder) => folder.videoFiles)
                .firstWhereOrNull((video) => video.filePath == entity.path);
            VideoData? data = await UtilsRepository().getVideoData(entity.path);
            if (existingVideo == null) {
              // Thumbnail doesn't exist, create a new thumbnail
              videos.add(
                VideoModel(
                  filePath: entity.path,
                  thumbnailPath: "",
                  duration: data!.duration!,
                  fileSize: data.filesize!,
                ),
              );
            } else {
              videos.add(existingVideo);
            }
          }
        } else if (entity is Directory) {
          await _processDirectory(sendPort, entity, appDocumentsPath,
              tempDir); // Recursive call to process subdirectories
        }
      } catch (e, stack) {
        if (kDebugMode) {
          print('Error processing entity: $e');
          print(stack);
        }
      }
    }

    if (videos.isNotEmpty) {
      FolderModel folderModel = FolderModel(
        folderName: dir.path,
        videoFiles: videos,
      );
      final folderMap = folderModel.toJson();
      sendPort.send(folderMap);
    }
  }

  Future<void> generateThumbnailsForFolder(FolderModel folder) async {
    final tempDir = (await getTemporaryDirectory()).path;
    var box = Hive.box<FolderModel>('videoBox');
    for (var video in folder.videoFiles) {
      if (video.thumbnailPath.isEmpty || video.thumbnailPath == "") {
        // Only generate if there is no thumbnail yet
        video.thumbnailPath = (await _generateThumbnail(video.filePath, tempDir))!;
      }
    }
    // Update Hive and state here if necessary
    var existingFolder = box.values.firstWhereOrNull(
        (existingFolder) => existingFolder.folderName == folder.folderName);
    if (existingFolder != null) {
      var index = box.values.toList().indexOf(existingFolder);
      box.putAt(index, folder); // Update the folder in Hive
    }
    // Optionally, update the state to reflect the new thumbnails
    state = AsyncValue.data(box.values.toList());
  }

  Future<void> checkForUpdates(FolderModel newFolder) async {
    var box = Hive.box<FolderModel>('videoBox');
    var existingFolder = box.values.firstWhereOrNull(
        (folder) => folder.folderName == newFolder.folderName);
    if (existingFolder == null) {
      // New folder found, add to Hive
      box.add(newFolder).whenComplete(() {
        generateThumbnailsForFolder(newFolder);
      });
    } else {
      generateThumbnailsForFolder(existingFolder);
      if (newFolder.videoFiles.isNotEmpty) {
        // Existing folder found, check for new or missing videos
        Map<String, VideoModel> existingVideos = {
          for (var video in existingFolder.videoFiles) video.filePath: video
        };
        List<VideoModel> updatedVideos = List<VideoModel>.from(existingFolder.videoFiles);
        for (var newVideo in newFolder.videoFiles) {
          if (!existingVideos.containsKey(newVideo.filePath)) {
            // New video found, add to updated videos list
            updatedVideos.add(newVideo);
          }
        }

        // Remove missing videos from updated videos list
        updatedVideos.removeWhere((video) => !newFolder.videoFiles
            .any((newVideo) => newVideo.filePath == video.filePath));

        // Update folder in Hive if there are any changes
        if (updatedVideos.length != existingFolder.videoFiles.length) {
          var updatedFolder = FolderModel(
            folderName: existingFolder.folderName,
            videoFiles: updatedVideos,
          );

          box.putAt(box.values.toList().indexOf(existingFolder), updatedFolder);
        }
      } else {
        box.deleteAt(box.values.toList().indexOf(newFolder));
      }
    }
    // Update state with the updated data from Hive
    state = AsyncValue.data(box.values.toList());
  }

  Future<void> sortList(SortBy sortBy, OrderBy orderBy) async {
    if (orderBy == OrderBy.ascending) {
      if (sortBy == SortBy.name) {
        state.value!.sort((a, b) => basename(a.folderName).compareTo(basename(b.folderName)));
      }
      else if (sortBy == SortBy.noOfFiles) {
        state.value!.sort((a, b) => a.videoFiles.length.compareTo(b.videoFiles.length));
      } else if (sortBy == SortBy.date) {
        state.value!.sort((a, b) {
          final aDate = a.videoFiles.map((e) => File(e.filePath).lastModifiedSync()).first;
          final bDate = b.videoFiles.map((e) => File(e.filePath).lastModifiedSync()).first;
          return aDate.compareTo(bDate);
        });
      }
    }
    else if (orderBy == OrderBy.descending) {
      if (sortBy == SortBy.name) {
        state.value!.sort((a, b) => basename(b.folderName).compareTo(basename(a.folderName)));
      }
      else if (sortBy == SortBy.noOfFiles) {
        state.value!.sort((a, b) => b.videoFiles.length.compareTo(a.videoFiles.length));
      } else if (sortBy == SortBy.date) {
        state.value!.sort((a, b) {
          final aDate = a.videoFiles.map((e) => File(e.filePath).lastModifiedSync()).first;
          final bDate = b.videoFiles.map((e) => File(e.filePath).lastModifiedSync()).first;
          return bDate.compareTo(aDate);
        });
      }
    }
  }

  Future<bool> deleteVideosInDirectory(List<String> dirPath) async {
    var box = Hive.box<FolderModel>('videoBox');
    try {
      for (String e in dirPath) {
        var dir = Directory(e);
        if (await dir.exists()) {
          var files = dir.listSync();
          for (var file in files) {
            if (file is File && _isVideoFile(file)) {
              await file.delete();
              // Update Hive if necessary
            }
          }
        }
        var folder =
        box.values.firstWhereOrNull((folder) => folder.folderName == e);
        if (folder != null) {
          box.deleteAt(box.values.toList().indexOf(folder));
        }
      }
      // Update the state to reflect the changes
      state = AsyncValue.data(box.values.toList());
      return true;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return false;
  }

  Future<bool> deleteFile(List<VideoModel> videos) async {
    var box = Hive.box<FolderModel>('videoBox');
    for (var e in videos) {
      File videoFile = File(e.filePath);
      if (videoFile.existsSync()) {
        try {
          await videoFile.delete();
          var folderModel = box.values.firstWhere((folder) => folder.folderName == videoFile.parent.path);
          var updatedVideos = folderModel.videoFiles.where((element) => element.filePath != e.filePath).toList();
          var updatedFolder = FolderModel(
            folderName: folderModel.folderName,
            videoFiles: updatedVideos,
            isOpened: folderModel.isOpened,
          );
          box.putAt(
              box.values.toList().indexWhere((element) => element.folderName == videoFile.parent.path),
              updatedFolder);
          // Update the state after the deletion and Hive update
          state = AsyncValue.data(box.values.toList());
        } catch (e) {
          // Handle exceptions as needed
          return false;
        }
      }
    }
    return true;
  }

  bool _isVideoFile(File file) {
    final List<String> videoExtensions = [
      '.mp4',
      '.avi',
      '.mkv',
      '.mov',
      '.wmv'
    ];
    return videoExtensions.any((ext) => file.path.toLowerCase().endsWith(ext));
  }
}

final utilProvider = Provider((ref) => UtilsRepository());

class UtilsRepository {

  void shareFile(String path) {
    Share.shareFiles([path], text: 'Check out this video!');
  }

  Future<VideoData?> getVideoData(String filePath) async {
    final videoInfo = FlutterVideoInfo();
    var info = await videoInfo.getVideoInfo(filePath);
    return info;
  }

  Future<void> onVideoOpened(VideoModel videoModel) async {
    videoModel.isOpened = true;
    // Update the video in Hive
    var box = Hive.box<FolderModel>('videoBox');
    var folderModel = box.values.firstWhere(
        (folder) => folder.folderName == Directory(videoModel.filePath).path);
    int index = box.values.toList().indexOf(folderModel);
    folderModel.videoFiles[index].isOpened = true;
    box.putAt(index, folderModel);
  }

  Future<void> onFolderOpen(FolderModel folderModel) async {
    folderModel.isOpened = true;
    //Update the folder in Hive
    var box = Hive.box<FolderModel>('videoBox');
    var folder = box.values
        .firstWhere((element) => element.folderName == folderModel.folderName);
    folder.isOpened = true;
    box.putAt(
        box.values.toList().indexWhere((element) => element == folderModel),
        folder);
  }
}

final uiValueProvider =
    StateNotifierProvider<UIValueNotifier, UIState>(
  (ref) {
    return UIValueNotifier();
  },
);

class UIValueNotifier extends StateNotifier<UIState> {
  UIValueNotifier() : super(const UIState());

  Future<void> toggleView(LayoutType layoutType, ViewType viewType, SortBy sortBy, OrderBy orderBy) async {
    state = UIState(
      viewType: viewType,
      sortBy: sortBy,
      orderBy: orderBy,
      layoutType: layoutType,
    );
  }

  Future<void> toggleGridView(bool isGridView) async {
    state = UIState(
      viewType: isGridView ? ViewType.gridView : ViewType.listView,
      sortBy: state.sortBy,
      orderBy: state.orderBy,
    );
  }

  Future<void> updateSort(SortBy sortBy) async {
    state = UIState(
      viewType: state.viewType,
      sortBy: sortBy,
      orderBy: state.orderBy,
    );
  }
}
