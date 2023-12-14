import 'package:flutter/material.dart';
import 'package:ishopping/find_iOS.dart';
import 'package:ishopping/shopping_bag.dart';
import 'dart:io' show Platform;

class PlatformSpecificFindScreen extends StatelessWidget {
  const PlatformSpecificFindScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Map<String, int> initMap = {};
    if (Platform.isAndroid) {
      // Android용 화면 로딩
      return const ShoppingBagScreen();
    } else if (Platform.isIOS) {
      // iOS용 화면 로딩
      return FindScreen(shoppingbag: initMap);
    } else {
      // 다른 플랫폼을 위한 대체 화면
      return const Center(child: Text('Unsupported platform'));
    }
  }
}
