import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
                    /*
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SectionPage()),
                    );
                    */
                    vibration(2);
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
                    /*
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProductPage()),
                    );
                    */
                    HapticFeedback.vibrate();
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

  vibration(int rep) async {
    for (int i = 0; i < rep; i++) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
