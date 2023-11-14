import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'section.dart';
import 'product.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.blue),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SectionPage()),
                    );
                    heavy_vibration(1);
                  },
                  child: null, // 버튼 1의 텍스트나 아이콘을 추가하려면 이곳에 작성
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(primary: Colors.red),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductPage()),
                    );
                    heavy_vibration(2);
                  },
                  child: null, // 버튼 2의 텍스트나 아이콘을 추가하려면 이곳에 작성
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  heavy_vibration(int rep) async {
    final canVibrate = await Haptics.canVibrate();

    for (int i = 0; i < rep; i++) {
      await Haptics.vibrate(HapticsType.heavy);
      await Future.delayed(const Duration(milliseconds: 300));
      
    }
  }
  rigid_vibration(int rep) async {
    final canVibrate = await Haptics.canVibrate();

    for (int i = 0; i < rep; i++) {
      await Haptics.vibrate(HapticsType.rigid);
      await Future.delayed(const Duration(milliseconds: 300));
      
    }
  }
}
