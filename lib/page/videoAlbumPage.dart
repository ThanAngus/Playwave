import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:playwave/page/videoPlayerPage.dart';
import 'package:playwave/utils/components/videoFileComponent.dart';
import 'package:playwave/utils/constants/enumConstants.dart';
import 'package:playwave/utils/repository/videoProvider.dart';
import '../model/models.dart';
import '../utils/components/dividerComponents.dart';
import '../utils/style.dart';

class VideoAlbumPage extends ConsumerStatefulWidget {
  final FolderModel selectedDirectory;

  const VideoAlbumPage({
    super.key,
    required this.selectedDirectory,
  });

  @override
  ConsumerState<VideoAlbumPage> createState() => _VideoAlbumPageState();
}

class _VideoAlbumPageState extends ConsumerState<VideoAlbumPage> {
  late FolderModel folderModel;
  List<int> selectedFolders = [];
  List<VideoModel> files = [];
  bool isGridView = false;

  @override
  void initState() {
    folderModel = widget.selectedDirectory;
    initData();
    super.initState();
  }

  void initData() async{
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final uiValue = ref.watch(uiValueProvider);
      setState(() {
        isGridView = uiValue.viewType == ViewType.gridView;
        folderModel.videoFiles.sort((a, b) => File(a.filePath)
            .lastModifiedSync()
            .compareTo(File(b.filePath).lastModifiedSync()));
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onTap(BuildContext context, int index) {
    if (selectedFolders.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(
            videoFiles: folderModel.videoFiles,
            selectedIndex: index,
          ),
        ),
      );
    } else {
      if (selectedFolders.contains(index)) {
        setState(() {
          selectedFolders.remove(index);
        });
      } else {
        setState(() {
          selectedFolders.add(index);
        });
      }
    }
  }

  void toggleSelection(int index) {
    if (selectedFolders.contains(index)) {
      setState(() {
        selectedFolders.remove(index);
      });
    } else {
      setState(() {
        selectedFolders.add(index);
      });
    }
  }

  Future<void> deleteFile(List<int> indexList) async {
    List<VideoModel> videoDeleteList = [];
    for(int e in indexList){
      videoDeleteList.add(folderModel.videoFiles[e]);
    }
    await ref.read(videoProvider.notifier).deleteFile(videoDeleteList,).then((value) {
      setState(() {
        folderModel.videoFiles.removeWhere((element) => videoDeleteList.contains(element));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF646C57),
                AppColors.black.withOpacity(0.9),
                AppColors.black,
              ],
            ),
          ),
          child: AppBar(
            elevation: 0,
            forceMaterialTransparency: true,
            leading: selectedFolders.isEmpty
                ? IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      CupertinoIcons.arrow_left,
                      color: AppColors.primary,
                    ),
                  )
                : IconButton(
                    onPressed: () {
                      setState(() {
                        selectedFolders = [];
                      });
                    },
                    icon: Icon(
                      CupertinoIcons.clear,
                      color: AppColors.white,
                      size: Theme.of(context).textTheme.headlineSmall!.fontSize,
                    ),
                  ),
            title: selectedFolders.isEmpty
                ? Text(
                    basename(folderModel.folderName),
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : Text(
                    "${selectedFolders.length}/${folderModel.videoFiles.length}",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
            actions: [
              selectedFolders.isEmpty
                  ? Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (isGridView) {
                              setState(() {
                                isGridView = false;
                              });
                            } else {
                              setState(() {
                                isGridView = true;
                              });
                            }
                            await ref.read(uiValueProvider.notifier).toggleGridView(isGridView);
                          },
                          icon: Icon(
                            isGridView
                                ? CupertinoIcons.list_bullet
                                : Icons.grid_view_rounded,
                            color: AppColors.white,
                            size: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .fontSize,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(
                            CupertinoIcons.search,
                            color: AppColors.white,
                            size: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .fontSize,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (selectedFolders.length <
                                folderModel.videoFiles.length) {
                              for (int i = 0;
                                  i < folderModel.videoFiles.length;
                                  i++) {
                                if (!selectedFolders.contains(i)) {
                                  setState(() {
                                    selectedFolders.add(i);
                                  });
                                }
                              }
                            } else if (selectedFolders.length ==
                                folderModel.videoFiles.length) {
                              setState(() {
                                selectedFolders = [];
                              });
                            }
                          },
                          icon: Icon(
                            Icons.select_all_outlined,
                            color: AppColors.white,
                            size: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .fontSize,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (context) {
                                List<VideoModel> dirList = [];
                                for (int e in selectedFolders) {
                                  dirList.add(folderModel.videoFiles.elementAt(e));
                                }
                                return StatefulBuilder(
                                    builder: (context, setState) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    backgroundColor:
                                        AppColors.black.withOpacity(0.9),
                                    title: Center(
                                      child: Text(
                                        "Are you sure?",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge!
                                            .copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          selectedFolders.length > 1
                                              ? "Are you sure you want to delete these items? This action cannot be undone."
                                              : "Are you sure you want to delete this item? This action cannot be undone.",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                          textAlign: TextAlign.center,
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            color: AppColors.black
                                                .withOpacity(0.5),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: selectedFolders.length,
                                              itemBuilder: (context, index) {
                                                return Row(
                                                  children: [
                                                    Text(
                                                      "${index + 1}",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall,
                                                    ),
                                                    const SizedBox(
                                                      width: 5,
                                                    ),
                                                    Text(
                                                      basename(dirList[index].filePath),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall,
                                                    )
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () async {
                                              await ref
                                                  .read(videoProvider.notifier)
                                                  .deleteFile(
                                                dirList,
                                              ).then((value) {
                                                setState((){
                                                  selectedFolders = [];
                                                });
                                                Navigator.pop(context, true);
                                              });
                                            },
                                            child: Container(
                                              width: size.width,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                color: AppColors.primary,
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 15,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    "Delete Permanently",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall!
                                                        .copyWith(
                                                          color:
                                                              AppColors.white,
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
                                              width: size.width,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: AppColors.primary,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 15,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    "Cancel",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall!
                                                        .copyWith(
                                                          color:
                                                              AppColors.white,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                });
                              },
                            ).then((value) {
                              if(value == true){
                                for(int e in selectedFolders){
                                  setState(() {
                                    folderModel.videoFiles.removeAt(e);
                                    widget.selectedDirectory.videoFiles.removeAt(e);
                                  });
                                }
                              }
                              setState(() {});
                              if (folderModel.videoFiles.isEmpty) {
                                Navigator.pop(context);
                              }
                            });
                          },
                          icon: Icon(
                            CupertinoIcons.delete,
                            color: AppColors.white,
                            size: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .fontSize,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
      body: isGridView
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              shrinkWrap: true,
              itemCount: folderModel.videoFiles.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    onTap(context, index);
                  },
                  onLongPress: () {
                    toggleSelection(index);
                  },
                  child: VideoFileComponent(
                    videoModel: folderModel.videoFiles[index],
                    onDelete: () async {
                      deleteFile([index]).whenComplete((){
                        setState(() {});
                        if(folderModel.videoFiles.isEmpty){
                          Navigator.pop(context);
                        }
                      });
                    },
                    isGrid: isGridView,
                    isSelected: selectedFolders.isNotEmpty
                        ? selectedFolders.contains(index)
                        : false,
                  ),
                );
              },
            )
          : ListView.separated(
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    onTap(context, index);
                  },
                  onLongPress: () {
                    toggleSelection(index);
                  },
                  child: VideoFileComponent(
                    videoModel: folderModel.videoFiles[index],
                    onDelete: () async {
                      deleteFile([index]).whenComplete((){
                        Navigator.pop(context);
                        if(folderModel.videoFiles.isEmpty){
                          Navigator.pop(context);
                        }
                        setState(() {});
                      });
                    },
                    isGrid: isGridView,
                    isSelected: selectedFolders.isNotEmpty
                        ? selectedFolders.contains(index)
                        : false,
                  ),
                );
              },
              shrinkWrap: true,
              separatorBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: DividerComponent(),
                );
              },
              itemCount: folderModel.videoFiles.length,
            ),
    );
  }
}
