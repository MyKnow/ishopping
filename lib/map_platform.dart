import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import "map_android.dart";
import "map.dart";

class PlatformSpecificMapScreen extends StatelessWidget {
  const PlatformSpecificMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      // Android용 화면 로딩
      return MapAndroidScreen();
    } else if (Platform.isIOS) {
      // iOS용 화면 로딩
      return MapScreen();
    } else {
      // 다른 플랫폼을 위한 대체 화면
      return const Center(child: Text('Unsupported platform'));
    }
  }
}
