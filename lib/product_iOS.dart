import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProductiOSScreen extends StatefulWidget {
  const ProductiOSScreen({super.key});

  @override
  _ProductiOSScreenState createState() => _ProductiOSScreenState();
}

class _ProductiOSScreenState extends State<ProductiOSScreen> {
  // Unique key to control the lifecycle of UiKitView
  UniqueKey viewKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    const String viewType = 'product_view';
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    return FutureBuilder(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // Return the UiKitView with a unique key
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
