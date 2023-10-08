import 'dart:io';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:playwave/model/models.dart';
import 'package:playwave/page/videoAlbumPage.dart';
import 'package:playwave/page/videoPlayerPage.dart';
import 'package:playwave/utils/components/shimmerComponent.dart';
import 'package:playwave/utils/constants/enumConstants.dart';
import '../utils/components/dividerComponents.dart';
import '../utils/components/videoFileComponent.dart';
import '../utils/repository/videoProvider.dart';
import '../utils/style.dart';

class RootPage extends ConsumerStatefulWidget {
  const RootPage({
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage>
    with SingleTickerProviderStateMixin {
  List<int> selectedFolders = [];
  List<VideoModel> videoList = [];
  List<Searchable> searchable = [];
  List<Searchable> results = [];
  bool searchPressed = false;
  late TextEditingController searchEditingController;

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

  @override
  void initState() {
    searchEditingController = TextEditingController();
    super.initState();
  }

  void searchableList(List<FolderModel> folders) {
    final List<Searchable> searchableItems = [];
    for (FolderModel folder in folders) {
      // Include the FolderModel itself as a searchable item
      searchableItems.add(folder);
      // Include all VideoModel instances within the FolderModel as searchable items
      searchableItems.addAll(folder.videoFiles);
    }
    setState(() {
      searchable = searchableItems;
    });
  }

  List<Searchable> _searchItems(String query) {
    final lowercaseQuery = query.toLowerCase();
    final List<Searchable> searchResults = searchable.where((item) {
      final lowercaseText = item.searchableText.toLowerCase();
      return lowercaseText.contains(lowercaseQuery);
    }).toList();
    return searchResults;
  }

  Future<void> sortList(SortBy sortBy, OrderBy orderBy) async{
    if (orderBy == OrderBy.ascending) {
      if (sortBy == SortBy.name) {
        videoList.sort((a, b) => basename(a.filePath).compareTo(basename(b.filePath)));
      }
      else if (sortBy == SortBy.duration) {
        videoList.sort((a, b) => a.duration.compareTo(b.duration));
      } else if (sortBy == SortBy.date) {
        videoList.sort((a, b) {
          final aDate = File(a.filePath).lastModifiedSync();
          final bDate = File(b.filePath).lastModifiedSync();
          return aDate.compareTo(bDate);
        });
      } else if (sortBy == SortBy.size) {
        videoList.sort((a, b) => a.fileSize.compareTo(b.fileSize));
      }
    }
    else if (orderBy == OrderBy.descending) {
      if (sortBy == SortBy.name) {
        videoList.sort((a, b) => basename(b.filePath).compareTo(basename(a.filePath)));
      }
      else if (sortBy == SortBy.duration) {
        videoList.sort((a, b) => b.duration.compareTo(a.duration));
      } else if (sortBy == SortBy.date) {
        videoList.sort((a, b) {
          final aDate = File(a.filePath).lastModifiedSync();
          final bDate = File(b.filePath).lastModifiedSync();
          return bDate.compareTo(aDate);
        });
      } else if (sortBy == SortBy.size) {
        videoList.sort((a, b) => b.fileSize.compareTo(a.fileSize));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final folder = ref.watch(videoProvider);
    final uiValue = ref.watch(uiValueProvider);
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: selectedFolders.isEmpty
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF646C57),
                      AppColors.black.withOpacity(0.9),
                      AppColors.black,
                    ],
                  )
                : const LinearGradient(
                    colors: [
                      AppColors.black,
                      AppColors.black,
                    ],
                  ),
          ),
          child: searchPressed
              ? AppBar(
                  automaticallyImplyLeading: false,
                  leadingWidth: 40,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  forceMaterialTransparency: true,
                  leading: IconButton(
                    onPressed: () {
                      setState(() {
                        searchPressed = false;
                        searchEditingController.text = "";
                        results.clear();
                      });
                    },
                    icon: Icon(
                      CupertinoIcons.arrow_left,
                      color: AppColors.white,
                      size: Theme.of(context).textTheme.headlineSmall!.fontSize,
                    ),
                  ),
                  title: TextField(
                    controller: searchEditingController,
                    decoration: InputDecoration(
                      hintText: 'Search files or folders',
                      hintStyle:
                          Theme.of(context).textTheme.titleMedium!.copyWith(
                                color: AppColors.white.withOpacity(0.4),
                                fontWeight: FontWeight.w400,
                              ),
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      suffix: IconButton(
                        onPressed: () {
                          setState(() {
                            searchEditingController.text = "";
                            results.clear();
                          });
                        },
                        icon: Icon(
                          CupertinoIcons.clear,
                          color: AppColors.white,
                          size:
                              Theme.of(context).textTheme.titleMedium!.fontSize,
                        ),
                      ),
                    ),
                    onChanged: (searchTerm) {
                      if (searchTerm.isNotEmpty) {
                        final result = _searchItems(searchTerm);
                        if (result.isNotEmpty) {
                          setState(() {
                            results = result;
                          });
                        }
                      } else {
                        setState(() {
                          results.clear();
                        });
                      }
                    },
                    onSubmitted: (searchTerm) {
                      if (searchTerm.isNotEmpty) {
                        final result = _searchItems(searchTerm);
                        if (result.isNotEmpty) {
                          setState(() {
                            results = result;
                          });
                        }
                      }
                    },
                    style: Theme.of(context).textTheme.titleMedium,
                    cursorColor: AppColors.accent,
                    autofocus: searchPressed,
                  ),
                )
              : AppBar(
                  automaticallyImplyLeading: false,
                  leadingWidth: 40,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  forceMaterialTransparency: true,
                  leading: selectedFolders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.only(left: 10),
                          child: Image(
                            image: AssetImage(
                              "assets/images/logo.png",
                            ),
                            height: 50,
                            width: 40,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
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
                            size: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .fontSize,
                          ),
                        ),
                  title: selectedFolders.isEmpty
                      ? Text(
                          "Playwave",
                          style: Theme.of(context).textTheme.titleLarge,
                        )
                      : Text(
                          "${selectedFolders.length}/${folder.value!.length}",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                  actions: [
                    if (folder.isLoading)
                      const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      ),
                    selectedFolders.isEmpty
                        ? Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: AppColors.black,
                                    isScrollControlled: true,
                                    builder: (context) {
                                      bool isGrid = uiValue.viewType == ViewType.gridView;
                                      bool isFolder = uiValue.layoutType == LayoutType.folderView;
                                      SortBy sortBy = uiValue.sortBy;
                                      OrderBy orderBy = uiValue.orderBy;
                                      return StatefulBuilder(
                                        builder: (context, setState) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 30,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  children: [
                                                    Column(
                                                      children: [
                                                        Text(
                                                          "View Mode",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceAround,
                                                          children: [
                                                            Column(
                                                              children: [
                                                                IconButton(
                                                                  onPressed:
                                                                      () {
                                                                    if (isFolder) {
                                                                      setState(
                                                                          () {
                                                                        isFolder =
                                                                            false;
                                                                      });
                                                                    } else {
                                                                      setState(
                                                                          () {
                                                                        isFolder =
                                                                            true;
                                                                      });
                                                                    }
                                                                  },
                                                                  icon: Icon(
                                                                    Icons
                                                                        .folder,
                                                                    color: isFolder
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white
                                                                            .withOpacity(0.6),
                                                                    size: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .headlineSmall!
                                                                        .fontSize,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "Folders",
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodySmall!
                                                                      .copyWith(
                                                                        color: isFolder
                                                                            ? AppColors.accent
                                                                            : AppColors.white.withOpacity(0.6),
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              width: 10,
                                                            ),
                                                            Column(
                                                              children: [
                                                                IconButton(
                                                                  onPressed:
                                                                      () {
                                                                    if (isFolder) {
                                                                      setState(
                                                                          () {
                                                                        isFolder =
                                                                            false;
                                                                      });
                                                                    } else {
                                                                      setState(
                                                                          () {
                                                                        isFolder =
                                                                            true;
                                                                      });
                                                                    }
                                                                  },
                                                                  icon: Icon(
                                                                    Icons
                                                                        .video_library,
                                                                    color: isFolder
                                                                        ? AppColors
                                                                            .white
                                                                            .withOpacity(
                                                                                0.6)
                                                                        : AppColors
                                                                            .accent,
                                                                    size: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .headlineSmall!
                                                                        .fontSize,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "Videos",
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodySmall!
                                                                      .copyWith(
                                                                        color: isFolder
                                                                            ? AppColors.white.withOpacity(0.6)
                                                                            : AppColors.accent,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      width: 0.3,
                                                      color: AppColors.accent
                                                          .withOpacity(0.6),
                                                      height: 100,
                                                    ),
                                                    Column(
                                                      children: [
                                                        Text(
                                                          "Layout Mode",
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceAround,
                                                          children: [
                                                            Column(
                                                              children: [
                                                                IconButton(
                                                                  onPressed:
                                                                      () {
                                                                    if (isGrid) {
                                                                      setState(
                                                                          () {
                                                                        isGrid =
                                                                            false;
                                                                      });
                                                                    } else {
                                                                      setState(
                                                                          () {
                                                                        isGrid =
                                                                            true;
                                                                      });
                                                                    }
                                                                  },
                                                                  icon: Icon(
                                                                    CupertinoIcons
                                                                        .list_bullet,
                                                                    color: isGrid
                                                                        ? AppColors
                                                                            .white
                                                                        : AppColors
                                                                            .accent,
                                                                    size: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .headlineSmall!
                                                                        .fontSize,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "List",
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .titleSmall!
                                                                      .copyWith(
                                                                        color: isGrid
                                                                            ? AppColors.white
                                                                            : AppColors.accent,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            Column(
                                                              children: [
                                                                IconButton(
                                                                  onPressed:
                                                                      () {
                                                                    if (isGrid) {
                                                                      setState(
                                                                          () {
                                                                        isGrid =
                                                                            false;
                                                                      });
                                                                    } else {
                                                                      setState(
                                                                          () {
                                                                        isGrid =
                                                                            true;
                                                                      });
                                                                    }
                                                                  },
                                                                  icon: Icon(
                                                                    Icons
                                                                        .grid_view_rounded,
                                                                    color: isGrid
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white,
                                                                    size: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .headlineSmall!
                                                                        .fontSize,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "Grid",
                                                                  style: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .titleSmall!
                                                                      .copyWith(
                                                                        color: isGrid
                                                                            ? AppColors.accent
                                                                            : AppColors.white,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 20,
                                                  ),
                                                  child: Divider(
                                                    height: 0.3,
                                                    thickness: 0.3,
                                                    color: AppColors.accent
                                                        .withOpacity(0.6),
                                                  ),
                                                ),
                                                Column(
                                                  children: [
                                                    Text(
                                                      "Sort",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium,
                                                    ),
                                                    const SizedBox(
                                                      height: 10,
                                                    ),
                                                    isFolder
                                                        ? Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceAround,
                                                      children: [
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.name;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                Icons
                                                                    .sort_by_alpha,
                                                                color: sortBy ==
                                                                        SortBy.name
                                                                    ? AppColors
                                                                        .accent
                                                                    : AppColors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.6),
                                                                size: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Title",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                    color: sortBy ==
                                                                        SortBy.name
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white
                                                                            .withOpacity(0.6),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.noOfFiles;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                CupertinoIcons.cube_box_fill,
                                                                color: sortBy == SortBy.noOfFiles
                                                                    ? AppColors
                                                                        .accent
                                                                    : AppColors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.6),
                                                                size: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Videos Files",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                    color: sortBy == SortBy.noOfFiles
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white
                                                                            .withOpacity(0.6),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.size;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                Icons.scale,
                                                                color: sortBy == SortBy.size
                                                                    ? AppColors
                                                                        .accent
                                                                    : AppColors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.6),
                                                                size: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Size",
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                    color: sortBy == SortBy.size
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white
                                                                            .withOpacity(0.6),
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    )
                                                        : Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                      children: [
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.name;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                Icons
                                                                    .sort_by_alpha,
                                                                color: sortBy ==
                                                                    SortBy.name
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(
                                                                    0.6),
                                                                size: Theme.of(
                                                                    context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Title",
                                                              style: Theme.of(
                                                                  context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                color: sortBy ==
                                                                    SortBy.name
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(0.6),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.date;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                Icons
                                                                    .calendar_month,
                                                                color: sortBy == SortBy.date
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(
                                                                    0.6),
                                                                size: Theme.of(
                                                                    context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Date",
                                                              style: Theme.of(
                                                                  context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                color: sortBy == SortBy.date
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(0.6),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.duration;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                Icons
                                                                    .timer_sharp,
                                                                color: sortBy == SortBy.duration
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(
                                                                    0.6),
                                                                size: Theme.of(
                                                                    context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Duration",
                                                              style: Theme.of(
                                                                  context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                color: sortBy == SortBy.duration
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(0.6),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          children: [
                                                            IconButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  sortBy = SortBy.size;
                                                                });
                                                              },
                                                              icon: Icon(
                                                                Icons.scale,
                                                                color: sortBy == SortBy.size
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(
                                                                    0.6),
                                                                size: Theme.of(
                                                                    context)
                                                                    .textTheme
                                                                    .headlineSmall!
                                                                    .fontSize,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Size",
                                                              style: Theme.of(
                                                                  context)
                                                                  .textTheme
                                                                  .bodySmall!
                                                                  .copyWith(
                                                                color: sortBy == SortBy.size
                                                                    ? AppColors
                                                                    .accent
                                                                    : AppColors
                                                                    .white
                                                                    .withOpacity(0.6),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 20,
                                                      ),
                                                      child: Divider(
                                                        height: 0.3,
                                                        thickness: 0.3,
                                                        color: AppColors.accent
                                                            .withOpacity(0.6),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              orderBy = OrderBy.ascending;
                                                            });
                                                          },
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                width: 0.5,
                                                                color: orderBy == OrderBy.ascending
                                                                    ? AppColors
                                                                        .accent
                                                                    : AppColors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.6),
                                                              ),
                                                              color: orderBy == OrderBy.ascending
                                                                  ? AppColors
                                                                      .accent
                                                                      .withOpacity(
                                                                          0.1)
                                                                  : AppColors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.1),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 20,
                                                                vertical: 10,
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    CupertinoIcons
                                                                        .arrow_up,
                                                                    color: orderBy == OrderBy.ascending
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white
                                                                            .withOpacity(0.6),
                                                                    size: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyLarge!
                                                                        .fontSize,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Text(
                                                                    "Ascending",
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .titleSmall!
                                                                        .copyWith(
                                                                          color: orderBy == OrderBy.ascending
                                                                              ? AppColors.accent
                                                                              : AppColors.white.withOpacity(0.6),
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              orderBy = OrderBy.descending;
                                                            });
                                                          },
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              border:
                                                                  Border.all(
                                                                width: 0.5,
                                                                color: orderBy == OrderBy.descending
                                                                    ? AppColors
                                                                        .accent
                                                                    : AppColors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.6),
                                                              ),
                                                              color: orderBy == OrderBy.descending
                                                                  ? AppColors
                                                                      .accent
                                                                      .withOpacity(
                                                                          0.1)
                                                                  : AppColors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.1),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 20,
                                                                vertical: 10,
                                                              ),
                                                              child: Row(
                                                                children: [
                                                                  Icon(
                                                                    CupertinoIcons
                                                                        .arrow_down,
                                                                    color: orderBy == OrderBy.descending
                                                                        ? AppColors
                                                                            .accent
                                                                        : AppColors
                                                                            .white
                                                                            .withOpacity(0.6),
                                                                    size: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyLarge!
                                                                        .fontSize,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Text(
                                                                    "Descending",
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .titleSmall!
                                                                        .copyWith(
                                                                          color: orderBy == OrderBy.descending
                                                                              ? AppColors.accent
                                                                              : AppColors.white.withOpacity(0.6),
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(
                                                  height: 40,
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
                                                        Navigator.pop(context);
                                                      },
                                                      child: Text(
                                                        "Cancel",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium!
                                                            .copyWith(
                                                              color: AppColors
                                                                  .white
                                                                  .withOpacity(
                                                                      0.6),
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 20,
                                                    ),
                                                    InkWell(
                                                      onTap: () async {
                                                        await ref
                                                            .read(
                                                                uiValueProvider
                                                                    .notifier)
                                                            .toggleView(
                                                          isFolder == true ? LayoutType.folderView : LayoutType.fileView,
                                                          isGrid == true ? ViewType.gridView : ViewType.listView,
                                                          sortBy,
                                                          orderBy,
                                                          ).then((value) async {
                                                            if(isFolder){
                                                              await ref.read(videoProvider.notifier).sortList(sortBy, orderBy).then((value){
                                                                Navigator.pop(
                                                                    context);
                                                              });
                                                            }else{
                                                              sortList(sortBy, orderBy).then((value){
                                                                Navigator.pop(
                                                                    context);
                                                              });
                                                            }
                                                        });
                                                      },
                                                      child: Text(
                                                        "Done",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleMedium!
                                                            .copyWith(
                                                              color: AppColors
                                                                  .accent,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 30,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                                icon: Icon(
                                  uiValue.viewType == ViewType.gridView
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
                                onPressed: () {
                                  if (folder.value!.isNotEmpty &&
                                      !folder.isLoading) {
                                    searchableList(folder.value!);
                                    setState(() {
                                      searchPressed = true;
                                    });
                                  }
                                },
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
                                      folder.value!.length) {
                                    for (int i = 0;
                                        i < folder.value!.length;
                                        i++) {
                                      if (!selectedFolders.contains(i)) {
                                        setState(() {
                                          selectedFolders.add(i);
                                        });
                                      }
                                    }
                                  } else if (selectedFolders.length ==
                                      folder.value!.length) {
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
                                      List<String> dirList = [];
                                      for (int e in selectedFolders) {
                                        dirList.add(folder.value!
                                            .elementAt(e)
                                            .folderName);
                                      }
                                      return StatefulBuilder(
                                          builder: (context, setState) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(5),
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
                                                  padding: const EdgeInsets.all(
                                                      10.0),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        selectedFolders.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return Row(
                                                        children: [
                                                          Text(
                                                            "${index + 1}",
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .titleSmall,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          Text(
                                                            basename(
                                                                dirList[index]),
                                                            style: Theme.of(
                                                                    context)
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
                                                    ref
                                                        .read(videoProvider.notifier)
                                                        .deleteVideosInDirectory(
                                                            dirList)
                                                        .then((value) {
                                                      if (value == true) {
                                                        Navigator.pop(context);
                                                        return true;
                                                      }
                                                    }).then((value) {
                                                      Navigator.pop(context);
                                                    });
                                                  },
                                                  child: Container(
                                                    width: size.width,
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
                                                          "Delete Permanently",
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
                                                    width: size.width,
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
                                        );
                                      });
                                    },
                                  ).then((value) {
                                    selectedFolders = [];
                                    setState(() {});
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
      body: Stack(
        children: [
          folder.when(
            data: (folders) {
              if (folders.isNotEmpty) {
                videoList =
                    folders.expand((element) => element.videoFiles).toList();
                setState(() {});
                if (uiValue.layoutType == LayoutType.folderView) {
                  if (uiValue.viewType == ViewType.gridView) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                      ),
                      shrinkWrap: true,
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        FolderModel model = folders[index];
                        return InkWell(
                          onTap: () {
                            if (selectedFolders.isEmpty) {
                              if (!model.isOpened) {
                                ref.read(utilProvider).onFolderOpen(model);
                                setState(() {});
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return VideoAlbumPage(
                                      selectedDirectory: model,
                                    );
                                  },
                                ),
                              );
                            } else {
                              toggleSelection(index);
                            }
                          },
                          onLongPress: () {
                            toggleSelection(index);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: selectedFolders.contains(index)
                                  ? AppColors.primarySwatch.shade800
                                      .withOpacity(0.3)
                                  : AppColors.black,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                model.isOpened
                                    ? Stack(
                                        children: [
                                          Icon(
                                            Icons.folder,
                                            color: AppColors.primary,
                                            size: Theme.of(context)
                                                .textTheme
                                                .displayLarge!
                                                .fontSize,
                                          ),
                                          if (selectedFolders.contains(index))
                                            Positioned.fill(
                                              top: 0,
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Icon(
                                                Icons.check_circle_rounded,
                                                color: AppColors.black
                                                    .withOpacity(0.4),
                                                size: Theme.of(context)
                                                    .textTheme
                                                    .headlineSmall!
                                                    .fontSize,
                                              ),
                                            ),
                                        ],
                                      )
                                    : badges.Badge(
                                        badgeContent: Text(
                                          "${model.videoFiles.map((e) => e.isOpened == false).toList().length}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                fontSize: 9,
                                                color: AppColors.black,
                                              ),
                                        ),
                                        badgeStyle: const badges.BadgeStyle(
                                          shape: badges.BadgeShape.circle,
                                          padding: EdgeInsets.all(5),
                                          badgeColor: AppColors.accent,
                                          elevation: 10,
                                        ),
                                        position: badges.BadgePosition.custom(
                                          top: 2,
                                          end: 0,
                                        ),
                                        child: Stack(
                                          children: [
                                            Icon(
                                              Icons.folder,
                                              color: AppColors.primary,
                                              size: Theme.of(context)
                                                  .textTheme
                                                  .displayLarge!
                                                  .fontSize,
                                            ),
                                            if (selectedFolders.contains(index))
                                              Positioned.fill(
                                                top: 0,
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Icon(
                                                  Icons.check_circle_rounded,
                                                  color: AppColors.black
                                                      .withOpacity(0.4),
                                                  size: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall!
                                                      .fontSize,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                Text(
                                  basename(model.folderName),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall!
                                      .copyWith(
                                        color: AppColors.white,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  model.videoFiles.length > 1
                                      ? "${model.videoFiles.length} videos"
                                      : "${model.videoFiles.length} video",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                        color: AppColors.white.withOpacity(0.6),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  else {
                    return ListView.separated(
                      itemBuilder: (context, index) {
                        FolderModel model = folders[index];
                        return ListTile(
                          selected: selectedFolders.contains(index),
                          onLongPress: () {
                            toggleSelection(index);
                          },
                          selectedTileColor:
                              AppColors.primarySwatch.shade800.withOpacity(0.3),
                          leading: model.isOpened
                              ? Stack(
                                  children: [
                                    Icon(
                                      Icons.folder,
                                      color: AppColors.primary,
                                      size: Theme.of(context)
                                          .textTheme
                                          .displayLarge!
                                          .fontSize,
                                    ),
                                    if (selectedFolders.contains(index))
                                      Positioned.fill(
                                        top: 0,
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color:
                                              AppColors.black.withOpacity(0.4),
                                          size: Theme.of(context)
                                              .textTheme
                                              .headlineSmall!
                                              .fontSize,
                                        ),
                                      ),
                                  ],
                                )
                              : badges.Badge(
                                  badgeContent: Text(
                                    "${model.videoFiles.map((e) => e.isOpened == false).toList().length}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          fontSize: 8,
                                          color: AppColors.black,
                                        ),
                                  ),
                                  badgeStyle: const badges.BadgeStyle(
                                    shape: badges.BadgeShape.circle,
                                    padding: EdgeInsets.all(5),
                                    badgeColor: AppColors.accent,
                                    elevation: 10,
                                  ),
                                  position: badges.BadgePosition.custom(
                                    top: 2,
                                    end: 0,
                                  ),
                                  child: Stack(
                                    children: [
                                      Icon(
                                        Icons.folder,
                                        color: AppColors.primary,
                                        size: Theme.of(context)
                                            .textTheme
                                            .displayLarge!
                                            .fontSize,
                                      ),
                                      if (selectedFolders.contains(index))
                                        Positioned.fill(
                                          top: 0,
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.black
                                                .withOpacity(0.4),
                                            size: Theme.of(context)
                                                .textTheme
                                                .headlineSmall!
                                                .fontSize,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                          title: Text(
                            basename(model.folderName),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                  color: AppColors.white,
                                ),
                          ),
                          subtitle: Text(
                            model.videoFiles.length > 1
                                ? "${model.videoFiles.length} videos"
                                : "${model.videoFiles.length} video",
                            style:
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                      color: AppColors.white.withOpacity(0.6),
                                    ),
                          ),
                          onTap: () async {
                            if (selectedFolders.isEmpty) {
                              await ref
                                  .read(utilProvider)
                                  .onFolderOpen(model)
                                  .then((value) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return VideoAlbumPage(
                                        selectedDirectory: model,
                                      );
                                    },
                                  ),
                                );
                                setState(() {});
                              });
                            } else {
                              toggleSelection(index);
                            }
                          },
                        );
                      },
                      shrinkWrap: true,
                      separatorBuilder: (context, index) {
                        return const DividerComponent();
                      },
                      itemCount: folders.length,
                    );
                  }
                }
                else {
                  if (uiValue.viewType == ViewType.gridView) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      shrinkWrap: true,
                      itemCount: videoList.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            if (selectedFolders.isEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerPage(
                                    videoFiles: videoList,
                                    selectedIndex: index,
                                  ),
                                ),
                              );
                            } else {
                              toggleSelection(index);
                            }
                          },
                          onLongPress: () {
                            toggleSelection(index);
                          },
                          child: VideoFileComponent(
                            videoModel: videoList[index],
                            onDelete: () async {
                              await ref.read(videoProvider.notifier).deleteFile(
                                [videoList[index]],
                              ).then((value) {
                                Navigator.pop(context);
                                setState(() {
                                  videoList.removeAt(index);
                                });
                              });
                            },
                            isGrid: uiValue.viewType == ViewType.gridView,
                            isSelected: selectedFolders.isNotEmpty
                                ? selectedFolders.contains(index)
                                : false,
                          ),
                        );
                      },
                    );
                  }
                  else {
                    return ListView.separated(
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () {
                            if (selectedFolders.isEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerPage(
                                    videoFiles: videoList,
                                    selectedIndex: index,
                                  ),
                                ),
                              );
                            } else {
                              toggleSelection(index);
                            }
                          },
                          onLongPress: () {
                            toggleSelection(index);
                          },
                          child: VideoFileComponent(
                            videoModel: videoList[index],
                            onDelete: () async {
                              await ref.read(videoProvider.notifier).deleteFile(
                                [videoList[index]],
                              ).then((value) {
                                Navigator.pop(context);
                                setState(() {
                                  videoList.removeAt(index);
                                });
                              });
                            },
                            isGrid: uiValue.viewType == ViewType.gridView,
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
                      itemCount: videoList.length,
                    );
                  }
                }
              } else {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
            error: (e, _) => const Center(
              child: Text("No data\ne"),
            ),
            loading: () => ListView.separated(
              itemBuilder: (context, index) {
                return ListTile(
                  leading: ShimmerComponent(
                    child: Icon(
                      Icons.folder,
                      color: AppColors.white,
                      size: Theme.of(context).textTheme.displayMedium!.fontSize,
                    ),
                  ),
                  title: ShimmerComponent(
                    child: Text(
                      "What do you call fake spaghetti? An 'impasta'!",
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            color: AppColors.white,
                          ),
                    ),
                  ),
                  subtitle: ShimmerComponent(
                    child: Text(
                      "20 videos",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: AppColors.white.withOpacity(0.6),
                          ),
                    ),
                  ),
                );
              },
              shrinkWrap: true,
              separatorBuilder: (context, index) {
                return const SizedBox(
                  height: 1,
                );
              },
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
            ),
          ),
          results.isNotEmpty
              ? Container(
                  color: AppColors.black,
                  width: size.width,
                  height: size.height,
                  child: ListView.separated(
                    itemBuilder: (context, index) {
                      final item = results[index];
                      if (item is VideoModel) {
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerPage(
                                  videoFiles: [item],
                                  selectedIndex: index,
                                ),
                              ),
                            );
                          },
                          child: VideoFileComponent(
                            videoModel: item,
                            onDelete: () async {
                              await ref.read(videoProvider.notifier).deleteFile(
                                [item],
                              ).then((value) {
                                Navigator.pop(context);
                                setState(() {
                                  videoList.remove(item);
                                  results.removeAt(index);
                                });
                              });
                            },
                            isGrid: false,
                            isSelected: false,
                          ),
                        );
                      } else if (item is FolderModel) {
                        return ListTile(
                          leading: Stack(
                            children: [
                              Icon(
                                Icons.folder,
                                color: AppColors.primary,
                                size: Theme.of(context)
                                    .textTheme
                                    .displayLarge!
                                    .fontSize,
                              ),
                              if (selectedFolders.contains(index))
                                Positioned.fill(
                                  top: 0,
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.black.withOpacity(0.4),
                                    size: Theme.of(context)
                                        .textTheme
                                        .headlineSmall!
                                        .fontSize,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            basename(item.folderName),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                  color: AppColors.white,
                                ),
                          ),
                          subtitle: Text(
                            item.videoFiles.length > 1
                                ? "${item.videoFiles.length} videos"
                                : "${item.videoFiles.length} video",
                            style:
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                      color: AppColors.white.withOpacity(0.6),
                                    ),
                          ),
                          onTap: () async {
                            await ref
                                .read(utilProvider)
                                .onFolderOpen(item)
                                .then((value) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) {
                                    return VideoAlbumPage(
                                      selectedDirectory: item,
                                    );
                                  },
                                ),
                              );
                            });
                          },
                        );
                      } else {
                        return const SizedBox
                            .shrink(); // Return an empty widget if the item type is unknown
                      }
                    },
                    shrinkWrap: true,
                    separatorBuilder: (context, index) {
                      return const DividerComponent();
                    },
                    itemCount: results.length,
                  ),
                )
              : Container(),
        ],
      ),
    );
  }
}
