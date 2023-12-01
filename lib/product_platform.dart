import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import "product_android.dart";
import 'product_iOS.dart';

class PlatformSpecificProductScreen extends StatelessWidget {
  const PlatformSpecificProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      // Android용 화면 로딩
      return ProductAndroidScreen();
    } else if (Platform.isIOS) {
      // iOS용 화면 로딩
      return const ProductiOSScreen();
    } else {
      // 다른 플랫폼을 위한 대체 화면
      return const Center(child: Text('Unsupported platform'));
    }
  }
}
