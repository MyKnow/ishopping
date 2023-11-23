import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'main.dart'; // 메인 스크린에 대한 참조

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _imageAnimationController;
  late Animation<double> _imageAnimation;
  late AnimationController _textAnimationController;
  late Animation<double> _textOpacity;
  late FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    initializeTtsAndAnimations();
    scheduleSplashScreenTransition();
  }

  void initializeTtsAndAnimations() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("ko-KR");
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.6);
    flutterTts.speak("시각보조쇼핑서비스 아이쇼핑 로딩중");

    _imageAnimationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 2500));
    _imageAnimation = Tween<double>(begin: 0, end: 40)
        .animate(_imageAnimationController)
      ..addListener(() => setState(() {}));
    _imageAnimationController.forward();

    _textAnimationController =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    _textOpacity =
        Tween<double>(begin: 0.0, end: 1.0).animate(_textAnimationController);

    _imageAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _textAnimationController.forward();
      }
    });
  }

  void scheduleSplashScreenTransition() {
    Timer(Duration(seconds: 5), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MainScreen()));
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    _imageAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            buildImages(context),
            buildTexts(context),
          ],
        ),
      ),
    );
  }

  Widget buildImages(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        buildImage('assets/images/public/logo3.png', 0.4, 0.5),
        buildAnimatedImage('assets/images/public/logo2.png', 0.3, 0.5),
        buildImage('assets/images/public/logo1.png', 0.43, 0.51),
      ],
    );
  }

  Positioned buildImage(String assetPath, double top, double widthFactor) {
    return Positioned(
      top: MediaQuery.of(context).size.height * top,
      width: MediaQuery.of(context).size.width * widthFactor,
      child: Image.asset(assetPath),
    );
  }

  Positioned buildAnimatedImage(
      String assetPath, double top, double widthFactor) {
    return Positioned(
      top: MediaQuery.of(context).size.height * top + _imageAnimation.value,
      width: MediaQuery.of(context).size.width * widthFactor,
      child: Image.asset(assetPath),
    );
  }

  Widget buildTexts(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.73,
      child: FadeTransition(
        opacity: _textOpacity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            buildSpacedText('시각보조쇼핑서비스', 26, Colors.red, 0.8, FontWeight.bold),
            buildSpacedText('아이쇼핑', 50, Colors.red, 0.9, FontWeight.bold),
          ],
        ),
      ),
    );
  }

  Container buildSpacedText(String text, double fontSize, Color color,
      double widthFactor, FontWeight fontWeight) {
    return Container(
      width: MediaQuery.of(context).size.width * widthFactor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: text
            .split('')
            .map((char) => Expanded(
                    child: Text(
                  char,
                  style: TextStyle(
                      fontSize: fontSize, color: color, fontWeight: fontWeight),
                  textAlign: TextAlign.center,
                )))
            .toList(),
      ),
    );
  }
}
