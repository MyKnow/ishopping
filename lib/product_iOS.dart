// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ishopping/map_iOS.dart';

import 'shopping_bag.dart';

class ProductiOSScreen extends StatefulWidget {
  final Map<String, int> shoppingbag;
  final String predictionValue;
  const ProductiOSScreen(
      {super.key, required this.predictionValue, required this.shoppingbag});
  @override
  _ProductiOSScreenState createState() => _ProductiOSScreenState();
}

class _ProductiOSScreenState extends State<ProductiOSScreen> {
  UniqueKey viewKey = UniqueKey();
  String _predictionValue = '';

  final _platformChannel = const MethodChannel('flutter/SB2S');
  late Map<String, int> _shoppingbag;

  @override
  void initState() {
    super.initState();
    _platformChannel.setMethodCallHandler(_handleSectionMethodCall);
  }

  Future<void> _handleSectionMethodCall(MethodCall call) async {
    print("section 호출");
    print(call.method);
    if (call.method == 'sendData2S') {
      final data = Map<String, dynamic>.from(call.arguments);
      setState(() {
        _predictionValue = data['predictionValue'];
        _shoppingbag = Map<String, int>.from(data['shoppingbag']);
      });
      print(_predictionValue);
      _callSectionFLNativeView(_predictionValue, _shoppingbag);
    } else if (call.method == 'sendData2F') {
      final data = Map<String, dynamic>.from(call.arguments);
      setState(() {
        _shoppingbag = Map<String, int>.from(data['shoppingbag']);
      });
      print(_shoppingbag);
      _callSBFLNativeView(_shoppingbag);
    }
  }

  void _callSectionFLNativeView(
      String predictionValue, Map<String, int> shoppingbag) {
    // ProductiOSScreen으로 전환하고 예측값을 전달
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => MapScreen(
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
    const String viewType = 'product_view';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'predictionValue': widget.predictionValue,
      'shoppingbag': widget.shoppingbag
    };

    return UiKitView(
      key: viewKey,
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
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
