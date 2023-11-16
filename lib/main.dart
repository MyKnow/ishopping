import 'package:flutter/material.dart';
import 'splash_screen.dart'; // 스플래쉬 스크린에 대한 참조
import 'map.dart';
import 'product.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(), // 스플래쉬 스크린을 초기 스크린으로 설정
    );
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF9E6),
      body: Stack(
        children: <Widget>[
          CustomPaint(
            painter: BackgroundPainter(),
            size: Size(double.infinity, double.infinity),
          ),
          Column(
            children: <Widget>[
              Expanded(
                child: _buildButton(
                  context,
                  "현재 위치",
                  "assets/images/public/maps.png",
                  EdgeInsets.fromLTRB(10, 30, 10, 10),
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => MapScreen())),
                ),
              ),
              Expanded(
                child: _buildButton(
                  context,
                  "제품 확인",
                  "assets/images/public/coke.png",
                  EdgeInsets.fromLTRB(10, 10, 10, 30),
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ProductScreen())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                SizedBox(width: 15),
                Text(
                  text,
                  style: TextStyle(
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
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paintSmall = Paint()..color = Color(0xFFFFF2CC);
    var paintLarge = Paint()..color = Color(0xFFFFF2CC);

    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.1), 100, paintSmall);
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.7), 200, paintLarge);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
