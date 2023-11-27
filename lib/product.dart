import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import 'main.dart';
import 'map_android.dart';
import 'output.dart';
import 'server_api.dart';

void main() {
  runApp(MyApp());
}

class ProductScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<ProductScreen> {
  CameraController? controller;
  late FlutterTts flutterTts;
  String _message = "제품과 기기를 최대한 나란히 하고 촬영하세요.";
  int _captureCount = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    checkCameraPermission();
  }

  Future<void> checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (status == PermissionStatus.granted) {
      initializeCameraAndTts();
    } else {
      _showPermissionDeniedDialog();
    }
  }

  void initializeCameraAndTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.75);
    await flutterTts.speak("제품모드 시작. $_message");

    final cameras = await availableCameras();
    controller = CameraController(cameras.first, ResolutionPreset.max);
    await controller?.initialize();
    if (mounted) setState(() {});
    _changeMessage();
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
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => MainScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        flutterTts.stop(); // 뒤로 가기 시 TTS 중지
        Navigator.of(context).pop(); // 현재 화면을 닫음
        return false; // 뒤로 가기 동작을 수동으로 처리하기 때문에 false 반환
      },
      child: Scaffold(
        body: controller?.value.isInitialized == true
            ? GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MapAndroidScreen()));
                  }
                },
                onLongPress: () async {
                  await Vibration.vibrate();
                  await _captureAndSaveImage();
                },
                child: Stack(
                  children: <Widget>[
                    Transform.scale(
                      scale: _calculateCameraScale(),
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
              )
            : Center(child: CircularProgressIndicator()),
      ),
    );
  }

  double _calculateCameraScale() {
    double screenAspectRatio = MediaQuery.of(context).size.aspectRatio;
    double cameraAspectRatio = controller!.value.aspectRatio;

    // 화면이 세로 방향일 때 (화면 가로세로 비율이 1보다 작은 경우)
    if (screenAspectRatio < 1) {
      // 카메라 미리보기의 높이가 화면 높이에 맞도록 스케일링
      return 1 / (cameraAspectRatio * screenAspectRatio);
    } else {
      // 화면이 가로 방향일 때, 기존 로직 유지
      return screenAspectRatio / cameraAspectRatio;
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel(); // 타이머 취소
    flutterTts.stop();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSaveImage() async {
    try {
      final image = await controller?.takePicture();
      if (image == null) return;

      final File newImage = File(image.path);

      // 텐서플로우 라이트
      // await TFLiteAPI.processImage(imageFile);

      // 서버에 이미지 전송
      await sendImageData(newImage); // server_api.dart 파일의 함수 호출

      setState(() {
        _captureCount++; // 촬영 횟수 업데이트
        setProductCaptureCount(_captureCount);

        _message = "${product_name}";

        flutterTts.speak(_message);
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
    _messageTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _message = "화면을 길게 누르면 촬영이 됩니다.";
          flutterTts.speak(_message);
        });
      }
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
