import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'map_android.dart';
import 'product.dart';
import 'shopping_bag.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ShoppingBagScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    initializeTts();
  }

  void initializeTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.7);

    await _speakText("세션모드. 제품모드. 결제모드. ");
  }

  Future<void> _speakText(String text) async {
    var sentences = text.split(". ");
    for (var sentence in sentences) {
      if (sentence.isNotEmpty) {
        await flutterTts.speak(sentence);
        await Future.delayed(Duration(milliseconds: 700));
      }
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return Stack(
              children: <Widget>[
                CustomPaint(
                  painter: BackgroundPainter(),
                  size: const Size(double.infinity, double.infinity),
                ),
                orientation == Orientation.portrait
                    ? buildVerticalLayout()
                    : buildHorizontalLayout(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildVerticalLayout() {
    return Column(
      children: <Widget>[
        Expanded(
          child: buildButton(
            context,
            "세션 모드",
            "assets/images/public/maps.png",
            EdgeInsets.fromLTRB(10, 30, 10, 5),
            () => navigateToSessionMode(context),
          ),
        ),
        Expanded(
          child: buildButton(
            context,
            "제품 모드",
            "assets/images/public/coke.png",
            EdgeInsets.fromLTRB(10, 5, 10, 5),
            () => navigateToProductMode(context),
          ),
        ),
        Expanded(
          child: buildButton(
            context,
            "결제 모드",
            "assets/images/public/coins.png",
            EdgeInsets.fromLTRB(10, 5, 10, 30),
            () => navigateToShoppingBagMode(context),
          ),
        ),
      ],
    );
  }

  Widget buildHorizontalLayout() {
    double screenHeight = MediaQuery.of(context).size.height;

    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: screenHeight,
            child: buildButton(
              context,
              "세션 모드",
              "assets/images/public/maps.png",
              EdgeInsets.fromLTRB(10, 10, 5, 10),
              () => navigateToSessionMode(context),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: screenHeight,
            child: buildButton(
              context,
              "제품 모드",
              "assets/images/public/coke.png",
              EdgeInsets.fromLTRB(5, 10, 5, 10),
              () => navigateToProductMode(context),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: screenHeight,
            child: buildButton(
              context,
              "결제 모드",
              "assets/images/public/coins.png",
              EdgeInsets.fromLTRB(5, 10, 10, 10),
              () => navigateToShoppingBagMode(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildButton(BuildContext context, String text, String imagePath,
      EdgeInsets margin, VoidCallback onPressed) {
    // 화면의 너비와 높이를 가져옵니다.
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // 화면 크기에 따라 동적으로 크기를 조정합니다.
    double imageSize =
        min(screenWidth, screenHeight) * 0.15; // 이미지 크기를 화면의 10%로 설정
    double fontSize =
        min(screenWidth, screenHeight) * 0.1; // 텍스트 크기를 화면의 5%로 설정

    return Container(
      margin: margin,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          primary: Colors.white,
          onPrimary: Colors.black,
          shadowColor: Colors.grey,
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: EdgeInsets.symmetric(vertical: 20),
          minimumSize: Size(double.infinity, 100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(imagePath, width: imageSize),
            const SizedBox(width: 15),
            Text(
              text,
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontFamily: 'CustomFont',
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void navigateToSessionMode(BuildContext context) async {
    heavyVibration(3);
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => MapAndroidScreen()));
  }

  void navigateToProductMode(BuildContext context) async {
    heavyVibration(3);
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ProductScreen()));
  }

  void navigateToShoppingBagMode(BuildContext context) async {
    heavyVibration(3);
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ShoppingBagScreen()));
  }

  Future<void> heavyVibration(int rep) async {
    if (await Haptics.canVibrate()) {
      for (int i = 0; i < rep; i++) {
        await Haptics.vibrate(HapticsType.heavy);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  Future<void> rigidVibration(int rep) async {
    if (await Haptics.canVibrate()) {
      for (int i = 0; i < rep; i++) {
        await Haptics.vibrate(HapticsType.rigid);
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paintSmall = Paint()..color = const Color(0xFFFFF2CC);
    var paintLarge = Paint()..color = const Color(0xFFFFF2CC);

    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.1), 100, paintSmall);
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.7), 200, paintLarge);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
