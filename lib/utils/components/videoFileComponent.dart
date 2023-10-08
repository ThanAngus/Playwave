import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:playwave/utils/components/shimmerComponent.dart';
import 'package:playwave/utils/repository/videoProvider.dart';
import 'package:playwave/utils/style.dart';
import '../../model/models.dart';

class VideoFileComponent extends ConsumerStatefulWidget {
  final VoidCallback onDelete;
  final VideoModel videoModel;
  final bool isGrid;
  final bool isSelected;

  const VideoFileComponent({
    super.key,
    required this.videoModel,
    required this.onDelete,
    required this.isGrid,
    required this.isSelected,
  });

  @override
  ConsumerState<VideoFileComponent> createState() => _VideoFileComponentState();
}

class _VideoFileComponentState extends ConsumerState<VideoFileComponent> {
  String? videoDuration = "";
  late TextEditingController renameController;
  late File video;
  late VideoModel videoModel;
  VideoData? data;
  bool loading = true;

  @override
  void initState() {
    video = File(widget.videoModel.filePath);
    videoModel = widget.videoModel;
    renameController = TextEditingController(
      text: basename(widget.videoModel.filePath),
    );
    videoDuration = formatDuration(widget.videoModel.duration);
    super.initState();
  }

  String formatDuration(double duration) {
    double milliseconds = duration; // your milliseconds value
    int totalSeconds = (milliseconds / 1000).truncate();
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    String hoursString = hours > 0 ? '$hours:' : '';
    String minutesString = '$minutes'.padLeft(2, '0');
    String secondsString = '$seconds'.padLeft(2, '0');
    return '$hoursString$minutesString:$secondsString';
  }

  Future<void> renameFile(BuildContext context) async {
    final newName = renameController.text.trim();
    if (newName.isNotEmpty) {
      final oldFile = File(widget.videoModel.filePath);
      if (oldFile.existsSync()) {
        File newFile = await oldFile.rename(
            '${dirname(widget.videoModel.filePath)}/$newName${extension(widget.videoModel.filePath)}');
        var box = Hive.box<FolderModel>('videoBox');
        var folderModel = box.values
            .firstWhere((folder) => folder.folderName == oldFile.parent.path);
        var updatedVideos = folderModel.videoFiles.map((video) {
          if (video.filePath == oldFile.path) {
            return VideoModel(
              filePath: newFile.path,
              thumbnailPath: video.thumbnailPath,
              duration: video.duration,
              fileSize: video.fileSize,
            );
          }
          return video;
        }).toList();

        var updatedFolder = FolderModel(
          folderName: folderModel.folderName,
          videoFiles: updatedVideos,
        );
        setState(() {
          video = newFile;
        });
        box
            .putAt(box.values.toList().indexOf(folderModel), updatedFolder)
            .then((value) {
          Navigator.pop(context);
        });
      }
    }
  }

  void showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        backgroundColor: AppColors.black.withOpacity(0.9),
        title: Center(
          child: Text(
            'Video Info',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Text(
                  'File',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: AppColors.white,
                      ),
                ),
                RichText(
                  text: TextSpan(
                    text: "File:  ",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: AppColors.grey,
                        ),
                    children: [
                      TextSpan(
                        text: basename(widget.videoModel.filePath),
                        style:
                            Theme.of(context).textTheme.titleMedium!.copyWith(
                                  color: AppColors.white,
                                ),
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    text: "Location:  ",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: AppColors.grey,
                        ),
                    children: [
                      TextSpan(
                        text: widget.videoModel.filePath,
                        style:
                            Theme.of(context).textTheme.titleMedium!.copyWith(
                                  color: AppColors.white,
                                ),
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    text: "Size:  ",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: AppColors.grey,
                        ),
                    children: [
                      TextSpan(
                        text:
                            '${File(widget.videoModel.filePath).lengthSync()} bytes',
                        style:
                            Theme.of(context).textTheme.titleMedium!.copyWith(
                                  color: AppColors.white,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: AppColors.primary,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                child: Center(
                  child: Text(
                    "Close",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isGrid
        ? Container(
            color: widget.isSelected
                ? AppColors.white.withOpacity(0.2)
                : AppColors.black,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                widget.isSelected
                    ? Expanded(
                        child: Stack(
                          children: [
                            videoModel.thumbnailPath != "" ? Container(
                              height: 100,
                              width: ScreenUtil().screenWidth,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                image: DecorationImage(
                                  image: FileImage(
                                    File(videoModel.thumbnailPath),
                                  ),
                                  opacity: 0.8,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ) : ShimmerComponent(
                              child: Container(
                                height: 100,
                                width: ScreenUtil().screenWidth,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  image: DecorationImage(
                                    image: FileImage(
                                      File(videoModel.thumbnailPath),
                                    ),
                                    opacity: 0.8,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.white.withOpacity(0.4),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: Icon(
                                    Icons.check,
                                    color: AppColors.black.withOpacity(0.4),
                                    size: Theme.of(context)
                                        .textTheme
                                        .headlineMedium!
                                        .fontSize,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 100,
                              width: ScreenUtil().screenWidth,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                image: DecorationImage(
                                  image: FileImage(
                                    File(videoModel.thumbnailPath),
                                  ),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: videoDuration != null
                                    ? Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          color:
                                              AppColors.black.withOpacity(0.5),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(3.0),
                                          child: Text(
                                            videoDuration!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall!
                                                .copyWith(
                                                  fontSize: 12,
                                                  color: AppColors.white,
                                                ),
                                          ),
                                        ),
                                      )
                                    : Container(),
                              ),
                            ),
                            videoModel.isOpened
                                ? Container()
                                : Positioned(
                                    left: 5,
                                    top: 5,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: AppColors.accent,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        child: Text(
                                          "NEW",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                fontSize: 10,
                                                color: AppColors.white,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                const SizedBox(
                  height: 5,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        child: Text(
                          video.path.split('/').last,
                          style:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    color: AppColors.white,
                                  ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    IconButton(
                      onPressed: () {
                        if (!widget.isSelected) {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            backgroundColor: AppColors.black,
                            builder: (context) {
                              return Wrap(
                                children: [
                                  ListTile(
                                    onTap: () {
                                      ref
                                          .read(utilProvider)
                                          .shareFile(videoModel.filePath);
                                    },
                                    leading: Icon(
                                      Icons.share,
                                      size: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .fontSize,
                                      color: AppColors.white,
                                    ),
                                    title: Text(
                                      "Share",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: AppColors.white,
                                          ),
                                    ),
                                  ),
                                  ListTile(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          backgroundColor:
                                              AppColors.black.withOpacity(0.9),
                                          title: Text(
                                            'Rename File',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge!
                                                .copyWith(
                                                  color: AppColors.white,
                                                ),
                                          ),
                                          content: TextFormField(
                                            controller: renameController,
                                            autofocus: true,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          actions: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                InkWell(
                                                  onTap: () async {
                                                    await renameFile(context)
                                                        .then((value) {
                                                      Navigator.pop(context);
                                                      setState(() {});
                                                    }).then((value) {
                                                      setState(() {});
                                                    });
                                                  },
                                                  child: Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                      color: AppColors.primary,
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 15,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          "Rename",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleSmall!
                                                                  .copyWith(
                                                                    color: AppColors
                                                                        .white,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  height: 10,
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                      border: Border.all(
                                                        color:
                                                            AppColors.primary,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        vertical: 15,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          "Cancel",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleSmall!
                                                                  .copyWith(
                                                                    color: AppColors
                                                                        .white,
                                                                  ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    leading: Icon(
                                      Icons.edit,
                                      size: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .fontSize,
                                      color: AppColors.white,
                                    ),
                                    title: Text(
                                      "Rename",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: AppColors.white,
                                          ),
                                    ),
                                  ),
                                  ListTile(
                                    onTap: () {
                                      showInfo(context);
                                    },
                                    leading: Icon(
                                      Icons.info_outline,
                                      size: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .fontSize,
                                      color: AppColors.white,
                                    ),
                                    title: Text(
                                      "Properties",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: AppColors.white,
                                          ),
                                    ),
                                  ),
                                  ListTile(
                                    onTap: widget.onDelete,
                                    leading: Icon(
                                      Icons.delete_outline,
                                      size: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .fontSize,
                                      color: AppColors.white,
                                    ),
                                    title: Text(
                                      "Delete",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: AppColors.white,
                                          ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        : Container(
            color: widget.isSelected
                ? AppColors.white.withOpacity(0.2)
                : AppColors.black,
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 60,
              width: ScreenUtil().screenWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  widget.isSelected
                      ? Expanded(
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      image: DecorationImage(
                                        image: FileImage(
                                          File(videoModel.thumbnailPath),
                                        ),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    bottom: 10,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 30,
                                      width: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.white.withOpacity(0.4),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: AppColors.black.withOpacity(0.8),
                                        size: Theme.of(context)
                                            .textTheme
                                            .headlineSmall!
                                            .fontSize,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    video.path.split('/').last,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Expanded(
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      image: DecorationImage(
                                        image: FileImage(
                                          File(videoModel.thumbnailPath),
                                        ),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: videoDuration != null
                                          ? Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                color: AppColors.black
                                                    .withOpacity(0.5),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(3.0),
                                                child: Text(
                                                  videoDuration!,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .copyWith(
                                                        color: AppColors.white,
                                                        fontSize: ScreenUtil()
                                                            .setSp(11),
                                                      ),
                                                ),
                                              ),
                                            )
                                          : Container(),
                                    ),
                                  ),
                                  videoModel.isOpened
                                      ? Container()
                                      : Positioned(
                                          left: 3,
                                          top: 5,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              color: AppColors.accent,
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 3,
                                              ),
                                              child: Text(
                                                "NEW",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall!
                                                    .copyWith(
                                                      fontSize: 9,
                                                      color: AppColors.white,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    video.path.split('/').last,
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  IconButton(
                    onPressed: () {
                      if (!widget.isSelected) {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          backgroundColor: AppColors.black,
                          builder: (context) {
                            return Wrap(
                              children: [
                                ListTile(
                                  onTap: () {
                                    ref
                                        .read(utilProvider)
                                        .shareFile(videoModel.filePath);
                                  },
                                  leading: Icon(
                                    Icons.share,
                                    size: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .fontSize,
                                    color: AppColors.white,
                                  ),
                                  title: Text(
                                    "Share",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: AppColors.white,
                                        ),
                                  ),
                                ),
                                ListTile(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        backgroundColor:
                                            AppColors.black.withOpacity(0.9),
                                        title: Text(
                                          'Rename File',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge!
                                              .copyWith(
                                                color: AppColors.white,
                                              ),
                                        ),
                                        content: TextFormField(
                                          controller: renameController,
                                          autofocus: true,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        actions: [
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              InkWell(
                                                onTap: () async {
                                                  await renameFile(context)
                                                      .then((value) {
                                                    Navigator.pop(context);
                                                    setState(() {});
                                                  }).then((value) {
                                                    setState(() {});
                                                  });
                                                },
                                                child: Container(
                                                  width: MediaQuery.of(context)
                                                      .size
                                                      .width,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                    color: AppColors.primary,
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 15,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        "Rename",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall!
                                                            .copyWith(
                                                              color: AppColors
                                                                  .white,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Container(
                                                  width: MediaQuery.of(context)
                                                      .size
                                                      .width,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                    border: Border.all(
                                                      color: AppColors.primary,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 15,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        "Cancel",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall!
                                                            .copyWith(
                                                              color: AppColors
                                                                  .white,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  leading: Icon(
                                    Icons.edit,
                                    size: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .fontSize,
                                    color: AppColors.white,
                                  ),
                                  title: Text(
                                    "Rename",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: AppColors.white,
                                        ),
                                  ),
                                ),
                                ListTile(
                                  onTap: () {
                                    showInfo(context);
                                  },
                                  leading: Icon(
                                    Icons.info_outline,
                                    size: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .fontSize,
                                    color: AppColors.white,
                                  ),
                                  title: Text(
                                    "Properties",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: AppColors.white,
                                        ),
                                  ),
                                ),
                                ListTile(
                                  onTap: widget.onDelete,
                                  leading: Icon(
                                    Icons.delete_outline,
                                    size: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .fontSize,
                                    color: AppColors.white,
                                  ),
                                  title: Text(
                                    "Delete",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                          color: AppColors.white,
                                        ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
