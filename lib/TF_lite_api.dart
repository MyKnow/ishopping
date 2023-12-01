import 'dart:io';

import 'package:tflite_flutter/tflite_flutter.dart';

// import 'server_api.dart';
import 'output.dart';

String result = '-1';

class TFLiteAPI {
  // 결과 라벨 배열
  static const List<String> labels = [
    '까르보불닭',
    '짜파게티',
    '진라면매운맛',
    '불닭볶음면',
    '김치사발면',
    '육개장',
    '신라면',
    '튀김우동',
    '너구리'
  ];

  static Future<void> processImage(File imageFile) async {
    // TensorFlow Lite 인터프리터 초기화
    var interpreter =
        await Interpreter.fromAsset('models/model_unquant.tflite');

    // 이미지를 모델에 맞게 변환 (여기서는 예시로만 제공됨)
    var inputImage = imageFile.readAsBytesSync(); // 이미지 파일을 바이트로 변환
    // 모델 실행 및 결과 처리
    var output = List.filled(1, 0).reshape([1, 1]);
    interpreter.run(inputImage, output);

    // 결과를 라벨로 변환
    result = labels[output[0]];
    setProductName(result);

    // 결과를 서버에 전송
    // await ServerAPI.sendResultToServer(result);

    // 인터프리터 자원 해제
    interpreter.close();
  }
}
