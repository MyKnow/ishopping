import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:vibration/vibration.dart';

class ShoppingBagScreen extends StatefulWidget {
  final Map<String, int>? shoppingbag;

  const ShoppingBagScreen({super.key, this.shoppingbag});

  @override
  _ShoppingBagScreenState createState() => _ShoppingBagScreenState();
}

class _ShoppingBagScreenState extends State<ShoppingBagScreen> {
  int totalPrice = 0;
  int _selectedIndex = 0;
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    widget.shoppingbag?.forEach((name, quantity) {
      cartItems.add(CartItem(
          name: name,
          quantity: quantity,
          price: 1000)); // 가격을 1000원으로 고정, 나중에 DB로 바꿀 예정
    });
    initializeTts();
    readCartItems();
  }

  void initializeTts() async {
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.6);
  }

  void readCartItems() {
    String toRead = '장바구니에 있는 제품: ';
    totalPrice = 0;
    for (var item in cartItems) {
      totalPrice += item.price * item.quantity;
      toRead += '${item.name} ${item.quantity}개, ';
    }
    toRead += '총 금액은 ${totalPrice}원 입니다.';
    flutterTts.speak(toRead);
  }

  void readCurrentItem() {
    if (cartItems.isNotEmpty && _selectedIndex < cartItems.length) {
      var currentItem = cartItems[_selectedIndex];
      flutterTts.speak('${currentItem.name}, ${currentItem.quantity}개');
    }
  }

  void readCurrentQuantity() {
    if (cartItems.isNotEmpty && _selectedIndex < cartItems.length) {
      var currentItem = cartItems[_selectedIndex];
      flutterTts.speak('${currentItem.quantity}개');
    }
  }

  Future<bool> authenticateWithFingerprint() async {
    final LocalAuthentication auth = LocalAuthentication();
    bool authenticated = false;
    try {
      authenticated =
          await auth.authenticate(localizedReason: '생체 인식을 사용하여 인증해주세요.');
      flutterTts.speak('생체 인식을 사용하여 인증해주세요.');
    } catch (e) {
      print(e);
    }
    return authenticated;
  }

  void showPurchasingPopup() {
    flutterTts.speak('구매 중');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("구매 중", style: TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 50.0,
                width: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showPurchaseCompletePopup() {
    Navigator.pop(context); // 이전 팝업 닫기
    flutterTts.speak('구매 완료. 구매가 성공적으로 완료되었습니다.');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("구매 완료", style: TextStyle(color: Colors.red)),
          content:
              Text("구매가 성공적으로 완료되었습니다.", style: TextStyle(color: Colors.red)),
          actions: <Widget>[
            TextButton(
              child: Text("확인", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    totalPrice = 0;
    for (var item in cartItems) {
      totalPrice += item.price * item.quantity;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('장바구니',
            style: TextStyle(
                fontFamily: 'CustomFont', color: Colors.red, fontSize: 24)),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: () async {
                if (await authenticateWithFingerprint()) {
                  await Vibration.vibrate();
                  executePurchase();
                }
              },
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! > 0 &&
                    _selectedIndex < cartItems.length - 1) {
                  setState(() {
                    _selectedIndex++;
                    readCurrentItem();
                  });
                } else if (details.primaryVelocity! < 0 && _selectedIndex > 0) {
                  setState(() {
                    _selectedIndex--;
                    readCurrentItem();
                  });
                }
              },
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! > 0 &&
                    cartItems[_selectedIndex].quantity < 99) {
                  setState(() {
                    cartItems[_selectedIndex].quantity++;
                    readCurrentQuantity();
                  });
                } else if (details.primaryVelocity! < 0 &&
                    cartItems[_selectedIndex].quantity > 0) {
                  setState(() {
                    cartItems[_selectedIndex].quantity--;
                    readCurrentQuantity();
                  });
                }
              },
              child: ListView.builder(
                itemCount: cartItems.length,
                physics: NeverScrollableScrollPhysics(), // 스크롤 비활성화
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return item.quantity >= 0
                      ? Column(
                          children: [
                            ListTile(
                              title: Text('${item.name} ${item.quantity}개',
                                  style: TextStyle(
                                      color: _selectedIndex == index
                                          ? Colors.red
                                          : Color.fromARGB(255, 116, 116, 116),
                                      fontSize: 22)),
                              trailing: Text('${item.price * item.quantity}원',
                                  style: TextStyle(
                                      color: _selectedIndex == index
                                          ? Colors.red
                                          : Color.fromARGB(255, 116, 116, 116),
                                      fontSize: 22)),
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                            ),
                            Divider(),
                          ],
                        )
                      : SizedBox.shrink();
                },
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('총 금액: ${totalPrice}원',
                    style: TextStyle(
                        fontFamily: 'CustomFont',
                        color: Colors.red,
                        fontSize: 24)),
                SizedBox(height: 10),
                ElevatedButton(
                  child: Text('구매하기',
                      style: TextStyle(
                          fontFamily: 'CustomFont',
                          color: Colors.white,
                          fontSize: 20)),
                  style: ElevatedButton.styleFrom(primary: Colors.red),
                  onPressed: () async {
                    await Vibration.vibrate();
                    if (await authenticateWithFingerprint()) {
                      executePurchase();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void executePurchase() async {
    showPurchasingPopup();
    await Future.delayed(Duration(seconds: 2));
    Navigator.pop(context);
    showPurchaseCompletePopup();
  }
}

class CartItem {
  final String name;
  final int price;
  int quantity;

  CartItem({required this.name, this.quantity = 0, required this.price});
}

List<CartItem> cartItems = [
  CartItem(name: '까르보불닭', quantity: 2, price: 1500),
  CartItem(name: '짜파게티', quantity: 1, price: 1200),
  // ... 추가 상품 ...
];
