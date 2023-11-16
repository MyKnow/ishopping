import 'package:flutter/material.dart';
import 'main.dart';

void main() {
  runApp(MyApp());
}

class ProductScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text("제품 스크린입니다")),
    );
  }
}
