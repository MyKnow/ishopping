import 'dart:convert';

import 'package:http/http.dart' as http;

Future<List<Map<String, dynamic>>> findNearbyGS25(
    double latitude, double longitude) async {
  final String serverEndpoint =
      'http://ec2-3-36-61-193.ap-northeast-2.compute.amazonaws.com/api-corner/get-location/';
  try {
    // 서버에 POST 요청 보내기
    final response = await http.post(
      Uri.parse(serverEndpoint),
      body: jsonEncode({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      }),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    // 응답 데이터 확인
    if (response.statusCode == 200 || response.statusCode == 201) {
      // "store_list" 키의 값을 문자열에서 JSON 배열로 디코딩
      List<dynamic> serializedData =
          json.decode(json.decode(response.body)['store_list']);

      // 필요한 형식으로 데이터 가공
      List<Map<String, dynamic>> stores = [];
      serializedData.forEach((store) {
        String storeName = store[0];
        double distance = store[1].toDouble();
        String address = store[2];

        // 형식에 맞게 저장
        stores.add({
          'name': storeName,
          'address': address,
          'distance': distance.toInt(),
          'distanceString': "${distance}M",
        });
      });

      return stores;
    } else {
      // 에러 처리
      print('2002 Failed to load data: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    // 예외 처리
    print('2002 Error: $e');
    return [];
  }
}
