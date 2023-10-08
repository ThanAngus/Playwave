import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

Future<Map<Permission, PermissionStatus>> getPermissions() async {
  Map<Permission, PermissionStatus> statues = await [
    Permission.storage,
    Permission.manageExternalStorage,
    Permission.accessMediaLocation,
  ].request();
  return statues;
}

Future<String> gettingPermissions() async {
  DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  AndroidDeviceInfo androidDeviceInfo = await deviceInfoPlugin.androidInfo;
  if (androidDeviceInfo.version.sdkInt >= 33) {
    PermissionStatus videoPermission = await Permission.videos.request();
    PermissionStatus photosPermission = await Permission.photos.request();
    PermissionStatus accessMediaLocation = await Permission.accessMediaLocation.request();
    PermissionStatus manageExternalStoragePermission = await Permission.manageExternalStorage.request();

    if (videoPermission == PermissionStatus.granted &&
        photosPermission == PermissionStatus.granted &&
        accessMediaLocation == PermissionStatus.granted && manageExternalStoragePermission == PermissionStatus.granted) {
      return "Granted";
    }
    else if(videoPermission.isPermanentlyDenied || photosPermission.isPermanentlyDenied || accessMediaLocation.isPermanentlyDenied || manageExternalStoragePermission.isPermanentlyDenied){
      return "Permanent-Denied";
    }else{
      return "Denied";
    }
  } else {
    PermissionStatus storageStatus = await Permission.storage.request();
    PermissionStatus accessMediaLocationStatus = await Permission.accessMediaLocation.request();
    if(storageStatus == PermissionStatus.granted && accessMediaLocationStatus == PermissionStatus.granted){
      return "Granted";
    }else if(storageStatus == PermissionStatus.permanentlyDenied || accessMediaLocationStatus == PermissionStatus.permanentlyDenied){
      return "Permanent-Denied";
    }else{
      return "Denied";
    }
  }
}
