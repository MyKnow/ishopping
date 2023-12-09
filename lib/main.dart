import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'map_platform.dart';
import 'product_platform.dart';
import 'shopping_bag.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late FlutterTts flutterTts;
  int _currentMode = 0; // 0: 세션모드, 1: 제품모드, 2: 결제모드

  @override
  void initState() {
    super.initState();
    initializeTts();
  }

  void initializeTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.8);
    await flutterTts.speak("세션 모드. 제품 모드. 결제 모드. ");
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
        child: GestureDetector(
          onVerticalDragEnd: (details) => _handleSwipe(details),
          onHorizontalDragEnd: (details) => _handleSwipe(details),
          onTap: () => _navigateToCurrentMode(context),
          child: OrientationBuilder(
            builder: (context, orientation) =>
                orientation == Orientation.portrait
                    ? buildVerticalLayout()
                    : buildHorizontalLayout(),
          ),
        ),
      ),
    );
  }

  void _handleSwipe(DragEndDetails details) {
    heavyVibration(1);
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! > 0 && _currentMode < 2) {
        setState(() {
          _currentMode++;
          speakCurrentMode(); // 모드가 변경될 때 TTS로 읽어줍니다.
        });
      } else if (details.primaryVelocity! < 0 && _currentMode > 0) {
        setState(() {
          _currentMode--;
          speakCurrentMode(); // 모드가 변경될 때 TTS로 읽어줍니다.
        });
      }
    }
  }

  // 모드가 변경될 때 TTS로 읽어주는 함수
  void speakCurrentMode() async {
    String modeText = "";
    switch (_currentMode) {
      case 0:
        modeText = "세션 모드";
        break;
      case 1:
        modeText = "제품 모드";
        break;
      case 2:
        modeText = "결제 모드";
        break;
    }

    await flutterTts.speak(modeText);
  }

  void _navigateToCurrentMode(BuildContext context) {
    switch (_currentMode) {
      case 0:
        navigateToSessionMode(context);
        break;
      case 1:
        navigateToProductMode(context);
        break;
      case 2:
        navigateToShoppingBagMode(context);
        break;
    }
  }

  Widget buildVerticalLayout() {
    double screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: <Widget>[
        buildModeButton(
            "세션 모드", "assets/images/public/maps.png", 0, screenHeight),
        buildModeButton(
            "제품 모드", "assets/images/public/coke.png", 1, screenHeight),
        buildModeButton(
            "결제 모드", "assets/images/public/coins.png", 2, screenHeight),
      ],
    );
  }

  Widget buildHorizontalLayout() {
    double screenHeight = MediaQuery.of(context).size.height;

    return Row(
      children: <Widget>[
        buildModeButton(
            "세션 모드", "assets/images/public/maps.png", 0, screenHeight),
        buildModeButton(
            "제품 모드", "assets/images/public/coke.png", 1, screenHeight),
        buildModeButton(
            "결제 모드", "assets/images/public/coins.png", 2, screenHeight),
      ],
    );
  }

  Widget buildModeButton(
      String text, String imagePath, int modeIndex, double buttonHeight) {
    double screenWidth = MediaQuery.of(context).size.width;
    double imageSize = min(screenWidth, buttonHeight) * 0.15;
    double fontSize = min(screenWidth, buttonHeight) * 0.1;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(10),
        child: ElevatedButton(
          onPressed: () {
            // 클릭 이벤트 처리
            _navigateToCurrentMode(context);
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor:
                _currentMode == modeIndex ? Colors.yellow : Colors.white,
            shadowColor: Colors.grey,
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            // 높이를 화면 높이로 설정
            minimumSize: Size(double.infinity, buttonHeight),
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
      ),
    );
  }

  // Navigation functions for each mode
  void navigateToSessionMode(BuildContext context) {
    heavyVibration(2);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const PlatformSpecificMapScreen()));
  }

  void navigateToProductMode(BuildContext context) {
    heavyVibration(3);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const PlatformSpecificProductScreen()));
  }

  void navigateToShoppingBagMode(BuildContext context) {
    heavyVibration(4);
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ShoppingBagScreen()));
  }

  // Haptic feedback functions
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
