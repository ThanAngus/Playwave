import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playwave/page/rootPage.dart';
import 'package:playwave/utils/style.dart';
import '../services/permissionHandling.dart';

class SlashPage extends StatefulWidget {
  const SlashPage({super.key});

  @override
  State<SlashPage> createState() => _SlashPageState();
}

class _SlashPageState extends State<SlashPage> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: gettingPermissions(),
        builder: (context, snapshot){
          if(snapshot.hasError){
            return const Center(
              child: Text(
                "Error getting app started",
              ),
            );
          }else{
            if(snapshot.connectionState == ConnectionState.waiting){
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Playwave",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const CircularProgressIndicator(
                      color: AppColors.accent,
                    ),
                  ],
                ),
              );
            }else{
              if (snapshot.data == "Granted") {
                return const RootPage();
              } else {
                if (snapshot.data == "Permanent-Denied") {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: Center(
                          child: Text(
                            "Permission required to continue using the app.",
                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              await openAppSettings();
                            },
                            child: Text(
                              "Open App Setting",
                              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              SystemNavigator.pop();
                            },
                            child: Text(
                              "Cancel",
                              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color: AppColors.errorColor,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
                else {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: Center(
                          child: Text(
                            "Permission required to continue using the app.",
                            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async{
                              getPermissions();
                            },
                            child: Text(
                              "Request Permission",
                              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              SystemNavigator.pop();
                            },
                            child: Text(
                              "Cancel",
                              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color: AppColors.errorColor,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              }
            }
          }
          return Container();
        },
      ),
    );
  }
}
