import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'googleAPI.dart';
import 'main.dart';

class StoreListScreen extends StatefulWidget {
  @override
  _StoreListScreenState createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  List<Map<String, dynamic>> stores = [];
  String locationMessage = "";
  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("권한 거부됨"),
          content: Text("위치 권한이 거부되었습니다. 앱 설정에서 권한을 허용해주세요."),
          actions: <Widget>[
            TextButton(
              child: Text("확인", style: TextStyle(color: Colors.red)),
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

  Future<void> getCurrentLocation() async {
    // 위치 권한 확인 및 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      var storesList =
          await findNearbyGS25(position.latitude, position.longitude);
      setState(() {
        stores = storesList;
      });
    } catch (e) {
      print("위치 정보를 가져오는데 실패했습니다: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth * 0.05; // 화면 너비의 5%

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '가까운 GS25 매장',
          style: TextStyle(fontSize: fontSize * 1.2, color: Colors.red),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.separated(
        itemCount: stores.length,
        itemBuilder: (context, index) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stores[index]['name'],
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        stores[index]['address'],
                        style:
                            TextStyle(fontSize: fontSize, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  stores[index]['distanceString'],
                  style: TextStyle(
                    fontSize: fontSize,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (context, index) => Divider(color: Colors.grey[300]),
      ),
    );
  }
}
