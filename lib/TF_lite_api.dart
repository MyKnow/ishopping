import 'dart:io';

import 'package:tflite/tflite.dart';

import 'server_api.dart';

class TFLiteAPI {
  static Future<void> processImage(File imageFile) async {
    // TensorFlow Lite 모델 로드 및 실행
    await TFLite.loadModel(model: "assets/model.tflite");
    var recognitions = await TFLite.runModelOnImage(path: imageFile.path);

    // 결과 처리 (예시)
    String result = recognitions[0]["label"];
    await ServerAPI.sendResultToServer(result);
  }
}
