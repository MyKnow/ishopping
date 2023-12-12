// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'product_iOS.dart';
import 'shopping_bag.dart';

class FindScreen extends StatefulWidget {
  final Map<String, int> shoppingbag;
  const FindScreen({super.key, required this.shoppingbag});
  @override
  _FindScreenState createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
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
    }
  }

  void _callProductFLNativeView(
      String predictionValue, Map<String, int> shoppingbag) {
    // ProductiOSScreen으로 전환하고 예측값을 전달
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => ProductiOSScreen(
              predictionValue: predictionValue, shoppingbag: shoppingbag)),
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

  @override
  Widget build(BuildContext context) {
    const String viewType = 'find_view'; // 기본적으로 'find_view' 호출
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'shoppingbag': widget.shoppingbag
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
