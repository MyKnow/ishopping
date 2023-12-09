import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

Future<List<Map<String, dynamic>>> findNearbyGS25(
    double lat, double lon) async {
  String apiKey = "AIzaSyCo53euhUWqaUQtNUnWrOAippT9dkUFdmM";
  String url =
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lon&radius=1000&language=ko&keyword=GS25&key=$apiKey";

  List<Map<String, dynamic>> stores = [];

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].length > 0) {
        for (var store in data['results']) {
          var storeName = store['name'];
          var storeLat = store['geometry']['location']['lat'];
          var storeLon = store['geometry']['location']['lng'];
          var distance =
              Geolocator.distanceBetween(lat, lon, storeLat, storeLon).round();

          stores.add({
            'name': storeName,
            'address': store['vicinity'],
            'distance': distance, // 거리 값을 숫자로 저장
            'distanceString': "${distance}M" // 문자열 형식으로도 저장
          });
        }

        // 거리가 짧은 순으로 정렬
        stores.sort((a, b) => a['distance'].compareTo(b['distance']));
      }
    }
  } catch (e) {
    print("오류 발생: $e");
  }

  return stores;
}
