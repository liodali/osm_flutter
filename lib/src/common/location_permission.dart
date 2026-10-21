import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

export 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart'
    show Permission, PermissionStatus, PermissionStatusGetters;

// Import the platform-neutral contract so pub.dev can recognize macOS support.
// The permission_handler dependency still registers Android's native plugin.
// Apple location authorization belongs to the native map implementation.
Future<PermissionStatus> requestLocationPermission(
    Permission permission) async {
  final statuses =
      await PermissionHandlerPlatform.instance.requestPermissions([permission]);
  return statuses[permission] ?? PermissionStatus.denied;
}
