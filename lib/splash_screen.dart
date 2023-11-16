import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();

    // 이미지 애니메이션 컨트롤러
    _imageAnimationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 2500));
    _imageAnimation = Tween<double>(begin: 0, end: 40)
        .animate(_imageAnimationController)
      ..addListener(() => setState(() {}));
    _imageAnimationController.forward();

    // 텍스트 애니메이션 컨트롤러
    _textAnimationController =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    _textOpacity =
        Tween<double>(begin: 0.0, end: 1.0).animate(_textAnimationController);

    // 이미지 애니메이션이 완료된 후 텍스트 애니메이션 시작
    _imageAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _textAnimationController.forward();
      }
    });

    // 스플래시 스크린 지속 시간 후 메인 스크린으로 전환
    Timer(Duration(seconds: 5), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => MainScreen()));
    });
  }

  @override
  void dispose() {
    _imageAnimationController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double logoTop = MediaQuery.of(context).size.height * 0.43;
    double logoHeight = MediaQuery.of(context).size.width * 0.51;
    double textsTop = logoTop + logoHeight - 30;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            _buildImages(context),
            Positioned(
              top: textsTop,
              child: _buildTexts(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImages(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        _buildImage('assets/images/public/logo3.png', 0.4, 0.5),
        _buildAnimatedImage('assets/images/public/logo2.png', 0.3, 0.5),
        _buildImage('assets/images/public/logo1.png', 0.43, 0.51),
      ],
    );
  }

  Positioned _buildImage(String assetPath, double top, double widthFactor) {
    return Positioned(
      top: MediaQuery.of(context).size.height * top,
      width: MediaQuery.of(context).size.width * widthFactor,
      child: Image.asset(assetPath),
    );
  }

  Positioned _buildAnimatedImage(
      String assetPath, double top, double widthFactor) {
    return Positioned(
      top: MediaQuery.of(context).size.height * top + _imageAnimation.value,
      width: MediaQuery.of(context).size.width * widthFactor,
      child: Image.asset(assetPath),
    );
  }

  Widget _buildTexts(BuildContext context) {
    return FadeTransition(
      opacity: _textOpacity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildSpacedText('시각보조쇼핑서비스', 26, Colors.red, 0.8, FontWeight.bold),
          _buildSpacedText('아이쇼핑', 50, Colors.red, 0.9, FontWeight.bold),
        ],
      ),
    );
  }

  Container _buildSpacedText(String text, double fontSize, Color color,
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
                        fontSize: fontSize,
                        color: color,
                        fontFamily: 'CustomFont',
                        fontWeight: fontWeight),
                    textAlign: TextAlign.center,
                  ),
                ))
            .toList(),
      ),
    );
  }
}
