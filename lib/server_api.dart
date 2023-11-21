import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

Future<void> sendImageData(File imageFile) async {
  // 현재 시간과 랜덤 값을 이용한 picture_id 생성
  String pictureId = generatePictureId();

  // 서버 엔드포인트
  Uri uri = Uri.parse(
      'http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com:8080/api-corner/corner_detect/');

  // 이미지 파일을 읽어서 바이트로 변환
  List<int> imageBytes = await imageFile.readAsBytes();

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

  // 요청 보내기
  var response = await request.send();

  // 응답 확인
  if (response.statusCode == 200) {
    print('Data sent successfully!');
  } else {
    print('Failed to send data. Status code: ${response.statusCode}');
  }
}

String generatePictureId() {
  int currentTimeInSeconds =
      (DateTime.now().millisecondsSinceEpoch / 1000).round();
  int randomValue = Random().nextInt(1000);
  return "$currentTimeInSeconds.$randomValue";
}
