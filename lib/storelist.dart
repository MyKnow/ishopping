import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import 'find.dart';
import 'main.dart';
import 'map_platform.dart';
import 'product_platform.dart';
import 'store_server_api.dart';

class StoreListScreen extends StatefulWidget {
  final int currentMode;

  const StoreListScreen({Key? key, required this.currentMode})
      : super(key: key);

  @override
  _StoreListScreenState createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  List<Map<String, dynamic>> stores = [];
  int _selectedIndex = 0;
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    initializeTts();
  }

  void initializeTts() async {
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.7);
    flutterTts.speak("가까운 GS25 매장. 현재 위치에 알맞는 편의점을 선택하세요.");
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
      print("2002 ${position.latitude}, ${position.longitude}");
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
      body: GestureDetector(
        onTap: () {
          if (widget.currentMode == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlatformSpecificMapScreen(),
              ),
            );
          } else if (widget.currentMode == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FindScreen(),
              ),
            );
          } else if (widget.currentMode == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlatformSpecificProductScreen(),
              ),
            );
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0 &&
              _selectedIndex < stores.length - 1) {
            setState(() {
              _selectedIndex++;
            });
          } else if (details.primaryVelocity! < 0 && _selectedIndex > 0) {
            setState(() {
              _selectedIndex--;
            });
          }
          flutterTts.speak(stores[_selectedIndex]['name']);
        },
        child: ListView.separated(
          itemCount: stores.length,
          separatorBuilder: (context, index) => Divider(color: Colors.grey),
          physics: NeverScrollableScrollPhysics(), // 스크롤 비활성화
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
                            color: _selectedIndex == index
                                ? Colors.red
                                : Colors.black,
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
                      color:
                          _selectedIndex == index ? Colors.red : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
