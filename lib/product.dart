import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import 'main.dart';
import 'map_android.dart';
import 'var_api.dart';

void main() {
  runApp(MyApp());
}

class ProductScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<ProductScreen> {
  CameraController? controller;
  String _message = "제품과 기기를 최대한 나란히 하고 촬영하세요."; // 초기 메시지

  int _captureCount = 0; // 촬영 횟수

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _changeMessage(); // 메시지 변경
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final status = await Permission.camera.request();

    if (status != PermissionStatus.granted) {
      _showPermissionDeniedDialog();
      return;
    }

    controller = CameraController(cameras.first, ResolutionPreset.max);
    controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("권한 거부됨"),
          content: Text("카메라 권한이 거부되었습니다. 앱 설정에서 권한을 허용해주세요."),
          actions: <Widget>[
            TextButton(
              child: Text("확인"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller?.value.isInitialized == true) {
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => MapAndroidScreen()));
          }
        },
        onLongPress: () async {
          await Vibration.vibrate();
          await _captureAndSaveImage();
        },
        child: Stack(
          children: <Widget>[
            Transform.scale(
              scale: 1 /
                  (controller!.value.aspectRatio *
                      MediaQuery.of(context).size.aspectRatio),
              alignment: Alignment.topCenter,
              child: CameraPreview(controller!),
            ),
            CustomPaint(
              size: Size.infinite,
              painter: GridPainter(),
            ),
            _buildInstructionBox(), // 안내 메시지 박스
          ],
        ),
      );
    } else {
      return Center(child: CircularProgressIndicator());
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSaveImage() async {
    try {
      final image = await controller?.takePicture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/${DateTime.now().toIso8601String()}.png';

      final File newImage = File(imagePath);
      await newImage.writeAsBytes(await image.readAsBytes());

      final result = await ImageGallerySaver.saveFile(newImage.path);
      print('Image saved to gallery: $result');

      setState(() {
        _captureCount++; // 촬영 횟수 업데이트
        setProductCaptureCount(_captureCount);

        _message = "해당 제품은 ${product_name}";
      });

      final message = "해당 제품은 ${product_name}, 촬영 횟수 : ${product_captureCount}";
      print(message);
    } catch (e) {
      print('Error capturing image: $e');
    }
  }

  Widget _buildInstructionBox() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _message,
          style: TextStyle(
            color: Colors.red,
            fontFamily: 'CustomFont',
            fontSize: 32,
          ),
        ),
      ),
    );
  }

  void _changeMessage() {
    Timer(Duration(seconds: 3), () {
      setState(() {
        _message = "화면을 길게 누르면 촬영이 됩니다.";
      });
    });
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(Offset(0, size.height * i / 3),
          Offset(size.width, size.height * i / 3), paint);
    }

    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0),
          Offset(size.width * i / 3, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
