import 'dart:io';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'server_api.dart';

class TFLiteAPI {
  static Future<void> processImage(File imageFile) async {
    // TensorFlow Lite 인터프리터 초기화
    var interpreter = await Interpreter.fromAsset('model.tflite');

    // 이미지를 모델에 맞게 변환 (여기서는 예시로만 제공됨)
    var inputImage = imageFile.readAsBytesSync(); // 이미지 파일을 바이트로 변환
    // 모델 실행 및 결과 처리
    var output = List.filled(1, 0).reshape([1, 1]);
    interpreter.run(inputImage, output);

    // 결과를 String으로 변환
    String result = output[0].toString();

    // 결과를 서버에 전송
    await ServerAPI.sendResultToServer(result);

    // 인터프리터 자원 해제
    interpreter.close();
  }
}
