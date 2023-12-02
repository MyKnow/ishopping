import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'product_iOS.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const platformChannel = MethodChannel('flutter/native_views');
  UniqueKey viewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    platformChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == "predictionValue") {
      String predictionValue = call.arguments;
      _callProductFLNativeView(predictionValue);
    }
  }

  void _callProductFLNativeView(String predictionValue) {
    // ProductiOSScreen으로 전환하고 예측값을 전달
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ProductiOSScreen(predictionValue: predictionValue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String viewType = 'section_view'; // 기본적으로 'section_view' 호출
    final Map<String, dynamic> creationParams = <String, dynamic>{};

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
}
