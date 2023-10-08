import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:playwave/page/rootPage.dart';
import 'package:playwave/page/splashPage.dart';
import 'package:playwave/utils/style.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isFirstTime = prefs.getBool('first_launch') ?? true;
  FlutterNativeSplash.remove();
  runApp(
    ProviderScope(
      child: MyApp(
        isFirstLaunch: isFirstTime,
      ),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final bool isFirstLaunch;

  const MyApp({
    required this.isFirstLaunch,
    super.key,
  });

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      builder: (context, Widget? child) {
        return MaterialApp(
          title: 'Play Wave',
          theme: appTheme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return ScrollConfiguration(
              behavior: MyBehavior(),
              child: child!,
            );
          },
          home: widget.isFirstLaunch ? const SlashPage() : const RootPage(),
        );
      },
    );
  }
}
