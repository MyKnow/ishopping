// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';
import 'product_iOS.dart';
import 'shopping_bag.dart';

class MapScreen extends StatefulWidget {
  final Map<String, int> shoppingbag;
  final String predictionValue;
  const MapScreen(
      {super.key, required this.shoppingbag, required this.predictionValue});
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  UniqueKey viewKey = UniqueKey();

  final _platformChannel = const MethodChannel('flutter/PV2P');

  String _predictionValue = '';
  late Map<String, int> _shoppingbag;

  @override
  void initState() {
    super.initState();
    _platformChannel.setMethodCallHandler(_handleProductMethodCall);
  }

  Future<void> _handleProductMethodCall(MethodCall call) async {
    print("product 호출");
    if (call.method == 'sendData') {
      final data = Map<String, dynamic>.from(call.arguments);
      setState(() {
        _predictionValue = data['predictionValue'];
        _shoppingbag = Map<String, int>.from(data['shoppingbag']);
      });
      print(_shoppingbag);
      _callProductFLNativeView(_predictionValue, _shoppingbag);
    } else if (call.method == 'sendData2F') {
      final data = Map<String, dynamic>.from(call.arguments);
      setState(() {
        _shoppingbag = Map<String, int>.from(data['shoppingbag']);
      });
      print(_shoppingbag);
      _callSBFLNativeView(_shoppingbag);
    } else if (call.method == 'Section2Main') {
      _callMainView();
    }
  }

  void _callProductFLNativeView(
      String predictionValue, Map<String, int> shoppingbag) {
    // ProductiOSScreen으로 전환하고 예측값을 전달
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => ProductiOSScreen(
                predictionValue: predictionValue,
                shoppingbag: shoppingbag,
                callby: 'Map',
              )),
    );
  }

  void _callSBFLNativeView(Map<String, int> shoppingbag) {
    // ProductiOSScreen으로 전환하고 예측값을 전달
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => ShoppingBagScreen(shoppingbag: shoppingbag)),
    );
  }

  void _callMainView() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    const String viewType = 'section_view'; // 기본적으로 'section_view' 호출
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'shoppingbag': widget.shoppingbag,
      'predictionValue': widget.predictionValue
    };

    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return UiKitView(
            key: viewKey,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  // Dispose the view when the widget is removed from the widget tree
  @override
  void dispose() {
    // Replace the viewKey with a new key to ensure the old view is disposed
    viewKey = UniqueKey();
    super.dispose();
  }
}
