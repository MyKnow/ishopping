import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'output.dart';

String productInfo = '-1';

Future<void> sendImageData(File imageFile) async {
  // 프로세스 시작 시간
  var processStartTime = DateTime.now();

  // 현재 시간과 랜덤 값을 이용한 picture_id 생성
  String pictureId = generatePictureId();

  // 이미지 파일을 읽는 시간 측정 시작
  var imageReadStartTime = DateTime.now();

  // 이미지 파일을 읽어서 바이트로 변환
  List<int> imageBytes = await imageFile.readAsBytes();

  // 이미지 파일을 읽는 데 걸린 시간
  var imageReadDuration =
      DateTime.now().difference(imageReadStartTime).inMilliseconds;
  print('2002 Image read time: ${imageReadDuration}ms');

  // 서버 엔드포인트
  Uri uri = Uri.parse(
      'http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com/api-corner/corner_detect/');

  // HTTP 클라이언트 생성
  var request = http.MultipartRequest('POST', uri);

  // 이미지 데이터 추가
  request.files.add(http.MultipartFile.fromBytes(
    'picture',
    imageBytes,
    filename: 'picture.jpg',
    contentType: MediaType('image', 'jpeg'),
  ));

  // picture_id 데이터 추가
  request.fields['picture_id'] = pictureId;

  // 서버 전송 시간 측정 시작
  var uploadStartTime = DateTime.now();

  // 요청 보내기
  var response = await request.send();

  // 서버 전송 시간
  var uploadDuration =
      DateTime.now().difference(uploadStartTime).inMilliseconds;
  print('2002 Upload time: ${uploadDuration}ms');

  // 응답 스트림을 String으로 변환
  String responseData = await response.stream.bytesToString();

  if (response.statusCode == 200 || response.statusCode == 201) {
    print('2002 Data sent successfully!');

    // JSON 파싱
    var decodedResponse = json.decode(responseData);
    // 'info' 필드 추출
    productInfo = decodedResponse['info'];
    setProductName(productInfo);
  } else {
    print('2002 Failed to send data. Status code: ${response.statusCode}');
  }

  // 전체 프로세스 시간
  var totalDuration =
      DateTime.now().difference(processStartTime).inMilliseconds;
  print('2002 Total process time: ${totalDuration}ms');
}

String generatePictureId() {
  int currentTimeInSeconds =
      (DateTime.now().millisecondsSinceEpoch / 1000).round();
  int randomValue = Random().nextInt(1000);
  return "$currentTimeInSeconds.$randomValue";
}

// 텐서플로우 라이트
class ServerAPI {
  static const String _serverEndpoint =
      'http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com/api-corner/corner_detect/';

  static Future<void> sendResultToServer(String result) async {
    try {
      Uri uri = Uri.parse(_serverEndpoint);
      var response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'result': result}));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("2002 Data sent successfully");

        // 서버로부터의 응답을 JSON 형태로 파싱
        var decodedResponse = json.decode(response.body);

        // 'info' 필드 추출 및 반환
        productInfo = decodedResponse['info'];

        setProductName(productInfo);
      } else {
        print("2002 Failed to send data. Status code: ${response.statusCode}");
      }
    } catch (e) {
      print("2002 Error sending data to server: $e");
    }
  }
}
