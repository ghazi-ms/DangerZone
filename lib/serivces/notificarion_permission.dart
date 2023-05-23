import 'package:permission_handler/permission_handler.dart';

Future<void> requestPermission() async {
  final status = await Permission.notification.request();

  if (status.isDenied) {
    openAppSettings();
  }
}
