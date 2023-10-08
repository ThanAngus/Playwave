import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';

part 'models.g.dart';  // Hive generates code in a file named models.g.dart

@HiveType(typeId: 0)
class FolderModel implements Searchable{
  @HiveField(0)
  String folderName;

  @HiveField(1)
  List<VideoModel> videoFiles;

  @HiveField(2)
  bool isOpened;

  FolderModel({
    required this.folderName,
    required this.videoFiles,
    this.isOpened = false,
  });
  
  @override
  String get searchableText => basename(folderName);

  // Convert a FolderModel instance to a Map
  Map<String, dynamic> toJson() {
    return {
      'folderName': folderName,
      'videoFiles': videoFiles.map((video) => video.toJson()).toList(),
      'isOpened': isOpened,
    };
  }

  // Create a FolderModel instance from a Map
  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      folderName: json['folderName'],
      videoFiles: (json['videoFiles'] as List)
          .map((videoJson) => VideoModel.fromJson(videoJson))
          .toList(),
      isOpened: json['isOpened'],
    );
  }
}

@HiveType(typeId: 1)
class VideoModel implements Searchable{
  @HiveField(0)
  String filePath;

  @HiveField(1)
  String thumbnailPath;

  @HiveField(2)
  double duration;

  @HiveField(3)
  int fileSize;

  @HiveField(4)
  bool isOpened;

  VideoModel({
    required this.filePath,
    required this.thumbnailPath,
    required this.duration,
    required this.fileSize,
    this.isOpened = false,
  });

  @override
  String get searchableText => basename(filePath);

  // Convert a VideoModel instance to a Map
  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'thumbnailPath': thumbnailPath,
      'duration' : duration,
      'fileSize' : fileSize,
      'isOpened': isOpened,
    };
  }

  // Create a VideoModel instance from a Map
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      filePath: json['filePath'],
      thumbnailPath: json['thumbnailPath'],
      duration: json['duration'],
      fileSize: json['fileSize'],
      isOpened: json['isOpened'],
    );
  }
}

abstract class Searchable {
  String get searchableText;
}