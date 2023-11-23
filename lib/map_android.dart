import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import 'main.dart';
import 'output.dart';
import 'product.dart';
import 'server_api.dart';

void main() {
  runApp(MyApp());
}

class MapAndroidScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<MapAndroidScreen> {
  CameraController? controller;
  late FlutterTts flutterTts;

  String _message = "모바일 기기를 턱에 가까이 대고 사용해 주세요."; // 초기 메시지

  int _captureCount = 0; // 촬영 횟수

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    flutterTts.setLanguage("ko-KR");
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.7);

    flutterTts.speak("세션모드 ${_message}");

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
        flutterTts.speak("카메라 권한이 거부되었습니다. 앱 설정에서 권한을 허용해주세요."); // TTS로 읽기

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
          if (details.primaryVelocity! < 0) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => ProductScreen()));
          }
          if (details.primaryVelocity! > 0) {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => MainScreen()));
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
    flutterTts.stop();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndSaveImage() async {
    try {
      final image = await controller?.takePicture();
      if (image == null) return;

      final File newImage = File(image.path);

      // 서버에 이미지 전송
      await sendImageData(newImage); // server_api.dart 파일의 함수 호출

      setState(() {
        _captureCount++; // 촬영횟수 업데이트
        setMapCaptureCount(_captureCount);

        _message =
            "좌측에 ${session_left}, 우측에 ${session_right}, 정면에 ${session_front}";

        flutterTts.speak(_message);
      });

      final message =
          "좌측에 ${session_left}, 우측에 ${session_right}, 정면에 ${session_front}, 촬영 횟수: ${map_captureCount}";
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
        flutterTts.speak(_message); // TTS로 메시지 읽기
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
