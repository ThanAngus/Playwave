import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:playwave/model/models.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_watcher/volume_watcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../utils/repository/videoProvider.dart';
import '../utils/style.dart';

class VideoPlayerPage extends ConsumerStatefulWidget {
  final List<VideoModel> videoFiles;
  final int selectedIndex;

  const VideoPlayerPage({
    super.key,
    required this.videoFiles,
    required this.selectedIndex,
  });

  @override
  ConsumerState<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends ConsumerState<VideoPlayerPage> {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  List<VideoModel>? videoFiles = [];
  int currentIndex = 0;
  double dragOffset = 0;
  double? initialX;
  late VideoPlayerController controller;
  bool controlVisible = true,
      isPlaying = false,
      fullScreen = false,
      isLandscape = true,
      showVolume = false,
      showBrightness = false,
      portraitUp = true,
      landscapeUp = true;
  late Timer timer;
  IconData? repeatIcon = Icons.repeat;
  String repeatMode = "Off";
  BoxFit screenFit = BoxFit.cover;
  double _currentVolume = 0.5, _currentBrightness = 0.5;
  final double _maxVolume = 10, _maxBrightness = 10;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    currentIndex = widget.selectedIndex;
    videoFiles = widget.videoFiles;
    initializeVideoPlayer(currentIndex);
    _streamSubscriptions.add(
      //Accelerometer to detect the screen rotation
      accelerometerEvents.listen(
        (event) {
          if (event.x > 7.0) {
            setState(() {
              landscapeUp = true;
            });
          } else if (event.x < -7.0) {
            setState(() {
              landscapeUp = false;
            });
          }
          if (event.y > 10) {
            setState(() {
              portraitUp = true;
            });
          } else if (event.y < -10) {
            setState(() {
              portraitUp = false;
            });
          }
          setOrientation();
        },
        cancelOnError: true,
      ),
    );
    super.initState();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void initializeVideoPlayer(int currentIndex) {
    controller = VideoPlayerController.file(File(videoFiles![currentIndex].filePath))
      ..addListener(() {
        if (controller.value.position == controller.value.duration &&
            currentIndex < videoFiles!.length) {
          if (currentIndex + 1 > videoFiles!.length && repeatMode == 'All') {
            initializeVideoPlayer(0);
          } else {
            playNext();
          }
        }
      })
      ..initialize().then((value) {
        setState(() {});
        _initializeVolumeListener();
      }).whenComplete((){
        if(!videoFiles![currentIndex].isOpened){
          ref.read(utilProvider).onVideoOpened(videoFiles![currentIndex]);
        }
        controller.play();
      });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    _initializeBrightness();
  }

  Future<void> _initializeVolumeListener() async {
    double initVolume = 0.5;
    try {
      initVolume = await VolumeWatcher.getCurrentVolume;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error initializing volume listener: $e');
      }
    }
    if (!mounted) return;

    setState(() {
      _currentVolume = initVolume;
      controller.setVolume(_currentVolume);
    });
  }

  Future<void> _initializeBrightness() async {
    double currentBright = 0.5;
    try {
      currentBright = await ScreenBrightness().current;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error initializing brightness listener: $e');
      }
    }
    setState(() {
      _currentBrightness = currentBright;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel().whenComplete((){
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      });
    }
    turnScreen();
    super.dispose();

  }

  void setRepeat(VideoPlayerController controller) {
    if (repeatMode == "Off") {
      setState(() {
        repeatMode = 'Only';
        repeatIcon = Icons.repeat_one;
        controller.setLooping(true);
      });
    } else if (repeatMode == 'Only') {
      setState(() {
        repeatMode = 'All';
        repeatIcon = Icons.repeat;
        controller.setLooping(false);
      });
    } else {
      setState(() {
        repeatMode = 'Off';
        repeatIcon = Icons.repeat;
        controller.setLooping(false);
      });
    }
  }

  void setVisibility() async {
    if (controlVisible == true) {
      timer = Timer(const Duration(seconds: 5), () {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersive,
        );
        setState(() {
          controlVisible = false;
        });
      });
    }
  }

  void playNext() {
    setState(() {
      currentIndex = currentIndex + 1;
      // Check if the index has reached the end of the list
      if (currentIndex == videoFiles!.length) {
        if (widget.selectedIndex == 0) {
          // Close the video player screen
          Navigator.pop(context);
          return;
        } else {
          currentIndex = 0;
        }
      }
      controller.dispose();
      initializeVideoPlayer(currentIndex);
    });
  }

  void playPrev() {
    setState(() {
      // Decrement the index and wrap around if needed
      currentIndex =
          (currentIndex - 1 + videoFiles!.length) % videoFiles!.length;
      // Dispose the old controller and create a new one with the previous video
      controller.dispose();
      initializeVideoPlayer(currentIndex);
    });
  }

  void seekVideo(double milliseconds) {
    setState(() {
      final Duration newPosition = Duration(milliseconds: milliseconds.toInt());
      controller.seekTo(newPosition);
    });
  }

  String formatDuration(Duration duration) {
    String hours = duration.inHours.toString().padLeft(0, '2');
    String minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  void setOrientation() async {
    if (controller.value.aspectRatio > 1) {
      // If the aspect ratio is greater than 1, set to landscape mode
      landscapeUp
          ? SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
            ])
          : SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeRight,
            ]);
      setState(() {
        isLandscape = true;
      });
    } else {
      portraitUp
          ? SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ])
          : SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitDown,
            ]);
      setState(() {
        isLandscape = false;
      });
    }
    await WakelockPlus.enable();
    setVisibility();
  }

  void turnScreen() async {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await ScreenBrightness().resetScreenBrightness();
    timer.cancel();
    await WakelockPlus.disable();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.black,
      endDrawer: Drawer(
        backgroundColor: AppColors.black.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Center(
                  child: Text(
                    "Playlist",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  itemCount: videoFiles!.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              currentIndex == index
                                  ? Icon(
                                      Icons.play_arrow,
                                      color: AppColors.white,
                                      size: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
                                          .fontSize,
                                    )
                                  : Text(
                                      "${index + 1}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  path.basename(videoFiles![index].filePath),
                                  style: Theme.of(context).textTheme.titleSmall,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        currentIndex == index
                            ? Container()
                            : IconButton(
                                onPressed: () {
                                  setState(() {
                                    videoFiles!.removeAt(index);
                                  });
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.white,
                                ),
                              ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          VolumeWatcher(onVolumeChangeListener: (double volume) {
            setState(() {
              _currentVolume = volume;
              controller.setVolume(_currentVolume);
            });
          }),
          controller.value.isInitialized
              ? Center(
                  child: AspectRatio(
                    aspectRatio: isLandscape
                        ? fullScreen
                            ? 21 / 9
                            : controller.value.aspectRatio
                        : fullScreen
                            ? 9 / 21
                            : controller.value.aspectRatio,
                    child: VideoPlayer(
                      controller,
                    ),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
          Positioned.fill(
            top: 0,
            right: 0,
            left: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Visibility(
                  visible: controlVisible,
                  child: AppBar(
                    backgroundColor: AppColors.black.withOpacity(0.2),
                    toolbarHeight: 60,
                    leading: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        turnScreen();
                      },
                      icon: Icon(
                        CupertinoIcons.arrow_left,
                        color: AppColors.white,
                        size: Theme.of(context).textTheme.titleLarge!.fontSize,
                      ),
                    ),
                    title: SizedBox(
                      width: ScreenUtil().screenWidth / 2,
                      child: Text(
                        path.basename(videoFiles![currentIndex].filePath),
                        style:
                            Theme.of(context).textTheme.titleMedium!.copyWith(
                                  color: AppColors.white,
                                ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    actions: [
                      IconButton(
                        onPressed: () {
                          scaffoldKey.currentState!.openEndDrawer();
                        },
                        icon: Icon(
                          Icons.playlist_play,
                          color: AppColors.white,
                          size: Theme.of(context)
                              .textTheme
                              .headlineMedium!
                              .fontSize,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (controlVisible == true) {
                        setState(() {
                          controlVisible = false;
                        });
                      } else if (controlVisible == false) {
                        setState(() {
                          controlVisible = true;
                        });
                        setVisibility();
                      }
                    },
                    onHorizontalDragUpdate: (details) {
                      // Update the drag offset when the user drags horizontally
                      setState(() {
                        dragOffset += details.primaryDelta!.toDouble();
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      // Calculate the number of milliseconds to seek based on the drag offset
                      final int milliseconds = (dragOffset /
                              size.width *
                              controller.value.duration.inMilliseconds)
                          .toInt();
                      seekVideo((controller.value.position.inMilliseconds +
                              milliseconds)
                          .roundToDouble());
                      setState(() {
                        dragOffset = 0;
                      });
                    },
                    onVerticalDragStart: (details) {
                      // Check the horizontal position of the swipe
                      if (details.localPosition.dx > size.width / 2) {
                        // Swipe on the right side
                        showBrightness = true;
                      } else {
                        // Swipe on the left side
                        showVolume = true;
                      }
                      // Update the UI based on the swipe position
                      setState(() {});
                    },
                    onVerticalDragUpdate: (details) async {
                      if (showVolume) {
                        double sensitivity = 0.01;
                        double verticalDragDelta = details.primaryDelta ?? 0;
                        if (verticalDragDelta > 0) {
                          setState(() {
                            _currentVolume =
                                (_currentVolume - sensitivity).clamp(0.0, 1.0);
                          });
                        } else if (verticalDragDelta < 0) {
                          setState(() {
                            _currentVolume =
                                (_currentVolume + sensitivity).clamp(0.0, 1.0);
                          });
                        }
                        await VolumeWatcher.setVolume(_currentVolume);
                        _initializeVolumeListener();
                      }
                      if (showBrightness) {
                        double sensitivity = 0.01;
                        double verticalDragDelta = details.primaryDelta ?? 0;
                        if (verticalDragDelta > 0) {
                          setState(() {
                            _currentBrightness =
                                (_currentBrightness - sensitivity)
                                    .clamp(0.0, 1.0);
                          });
                        } else if (verticalDragDelta < 0) {
                          setState(() {
                            _currentBrightness =
                                (_currentBrightness + sensitivity)
                                    .clamp(0.0, 1.0);
                          });
                        }
                        await ScreenBrightness()
                            .setScreenBrightness(_currentBrightness);
                        _initializeBrightness();
                      }
                    },
                    onVerticalDragEnd: (details) {
                      if (showVolume || showBrightness) {
                        if (mounted) {
                          timer = Timer(const Duration(seconds: 2), () {
                            setState(() {
                              showVolume = false;
                              showBrightness = false;
                            });
                          });
                        }
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Visibility(
                            visible: showBrightness,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(60),
                                  color: AppColors.black.withOpacity(0.5),
                                ),
                                height: isLandscape
                                    ? size.height / 2
                                    : size.height / 4,
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Text(
                                      "${(_currentBrightness * 10).toInt()}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Flexible(
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: SliderTheme(
                                          data: SliderThemeData(
                                            activeTrackColor: AppColors.white,
                                            inactiveTrackColor:
                                                Colors.grey.shade200,
                                            thumbColor: Colors.transparent,
                                            overlayColor: Colors.transparent,
                                            thumbSelector: (textDirection,
                                                    values,
                                                    tapValue,
                                                    thumbSize,
                                                    trackSize,
                                                    dx) =>
                                                Thumb.end,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                              enabledThumbRadius: 1,
                                              elevation: 0.0,
                                            ),
                                            trackHeight: 2,
                                            trackShape:
                                                const RoundedRectSliderTrackShape(),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                    overlayRadius: 1),
                                          ),
                                          child: Slider(
                                            max: _maxBrightness,
                                            min: 0,
                                            onChanged: (newBrightness) async {
                                              await ScreenBrightness()
                                                  .setScreenBrightness(
                                                      newBrightness)
                                                  .then((value) {
                                                _initializeBrightness();
                                              });
                                            },
                                            value: (_currentBrightness * 10)
                                                .roundToDouble(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Icon(
                                      Icons.brightness_4_sharp,
                                      color: AppColors.white,
                                      size: Theme.of(context)
                                          .textTheme
                                          .headlineSmall!
                                          .fontSize,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Visibility(
                            visible: showVolume,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 20,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(60),
                                  color: AppColors.black.withOpacity(0.5),
                                ),
                                height: isLandscape
                                    ? size.height / 2
                                    : size.height / 4,
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Text(
                                      "${(_currentVolume * 10).toInt()}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Flexible(
                                      child: RotatedBox(
                                        quarterTurns: 3,
                                        child: SliderTheme(
                                          data: SliderThemeData(
                                            activeTrackColor: AppColors.white,
                                            inactiveTrackColor:
                                                Colors.grey.shade200,
                                            thumbColor: Colors.transparent,
                                            overlayColor: Colors.transparent,
                                            thumbSelector: (textDirection,
                                                    values,
                                                    tapValue,
                                                    thumbSize,
                                                    trackSize,
                                                    dx) =>
                                                Thumb.end,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                              enabledThumbRadius: 1,
                                              elevation: 0.0,
                                            ),
                                            trackHeight: 2,
                                            trackShape:
                                                const RoundedRectSliderTrackShape(),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                    overlayRadius: 1),
                                          ),
                                          child: Slider(
                                            label: "${_currentVolume.round()}",
                                            max: _maxVolume,
                                            min: 0,
                                            onChanged: (newVolume) async {
                                              await VolumeWatcher.setVolume(
                                                  newVolume);
                                              setState(() {});
                                            },
                                            value: (_currentVolume * 10)
                                                .roundToDouble(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Icon(
                                      Icons.volume_up,
                                      color: AppColors.white,
                                      size: Theme.of(context)
                                          .textTheme
                                          .headlineSmall!
                                          .fontSize,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Visibility(
                  visible: controlVisible,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      return Container(
                        color: AppColors.black.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    color: AppColors.black.withOpacity(0.2),
                                    child: Text(
                                      formatDuration(value.position),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(
                                            color: AppColors.white,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: VideoProgressIndicator(
                                      controller,
                                      allowScrubbing: true,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    color: AppColors.black.withOpacity(0.2),
                                    child: Text(
                                      formatDuration(value.duration),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge!
                                          .copyWith(
                                            color: AppColors.white,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setRepeat(controller);
                                  },
                                  icon: Icon(
                                    repeatIcon,
                                    size: Theme.of(context)
                                        .textTheme
                                        .headlineMedium!
                                        .fontSize,
                                    color: repeatMode != "Off"
                                        ? AppColors.primary
                                        : AppColors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        playPrev();
                                      },
                                      icon: Icon(
                                        Icons.skip_previous_sharp,
                                        size: Theme.of(context)
                                            .textTheme
                                            .headlineMedium!
                                            .fontSize,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        if (value.isPlaying) {
                                          controller.pause();
                                          setState(() {
                                            isPlaying = false;
                                          });
                                        } else {
                                          controller.play();
                                          setState(() {
                                            isPlaying = true;
                                          });
                                        }
                                      },
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        size: Theme.of(context)
                                            .textTheme
                                            .displayLarge!
                                            .fontSize,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        playNext();
                                      },
                                      icon: Icon(
                                        Icons.skip_next_sharp,
                                        size: Theme.of(context)
                                            .textTheme
                                            .headlineMedium!
                                            .fontSize,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (fullScreen) {
                                      setState(() {
                                        fullScreen = false;
                                      });
                                    } else {
                                      setState(() {
                                        fullScreen = true;
                                      });
                                    }
                                    print(fullScreen);
                                  },
                                  icon: Icon(
                                    fullScreen
                                        ? Icons.fit_screen
                                        : Icons.fullscreen,
                                    size: Theme.of(context)
                                        .textTheme
                                        .headlineMedium!
                                        .fontSize,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
