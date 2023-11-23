import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'map_android.dart';
import 'product.dart';
import 'splash_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(),
      //home: MainScreen(),
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

    _speakText("메인 화면");
    _speakText("상. 세션모드. 하. 제품모드");
  }

  Future<void> _speakText(String text) async {
    var sentences = text.split(". ");
    for (var sentence in sentences) {
      if (sentence.isNotEmpty) {
        await flutterTts.speak(sentence);
        await Future.delayed(Duration(milliseconds: 500));
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
        child: Stack(
          children: <Widget>[
            CustomPaint(
              painter: BackgroundPainter(),
              size: const Size(double.infinity, double.infinity),
            ),
            Column(
              children: <Widget>[
                Expanded(
                  child: _buildButton(
                    context,
                    "세션 모드",
                    "assets/images/public/maps.png",
                    const EdgeInsets.fromLTRB(10, 30, 10, 10),
                    () => navigateToSessionMode(context),
                  ),
                ),
                Expanded(
                  child: _buildButton(
                    context,
                    "제품 모드",
                    "assets/images/public/coke.png",
                    const EdgeInsets.fromLTRB(10, 10, 10, 30),
                    () => navigateToProductMode(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void navigateToSessionMode(BuildContext context) {
    flutterTts.speak("세션 모드");
    heavyVibration(3);
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => MapAndroidScreen()));
  }

  void navigateToProductMode(BuildContext context) {
    flutterTts.speak("제품 모드");
    heavyVibration(3);
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ProductScreen()));
  }

  Widget _buildButton(BuildContext context, String text, String imagePath,
      EdgeInsets margin, VoidCallback onPressed) {
    return Container(
      margin: margin,
      width: double.infinity,
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
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double imageSize = constraints.maxWidth * 0.25;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(imagePath, width: imageSize),
                const SizedBox(width: 15),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'CustomFont',
                    fontSize: 52,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
