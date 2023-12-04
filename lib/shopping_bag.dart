import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
// import 'cart_items.dart'; // 상품 데이터를 가져오는 파일

class ShoppingBagScreen extends StatefulWidget {
  final Map<String, int>? shoppingbag;
  const ShoppingBagScreen({super.key, this.shoppingbag});

  @override
  _ShoppingBagScreenState createState() => _ShoppingBagScreenState();
}

class _ShoppingBagScreenState extends State<ShoppingBagScreen> {
  //List<CartItem> cartItems = [];
  int totalPrice = 0;

  @override
  void initState() {
    super.initState();
    widget.shoppingbag?.forEach((name, quantity) {
      cartItems.add(CartItem(
          name: name,
          quantity: quantity,
          price: 1000)); // 가격을 1000원으로 고정, 나중에 DB걸로 바꿀 거임.
    });
  }

  Future<bool> authenticateWithFingerprint() async {
    final LocalAuthentication auth = LocalAuthentication();
    bool authenticated = false;
    try {
      authenticated =
          await auth.authenticate(localizedReason: '지문을 사용하여 인증해주세요.');
    } catch (e) {
      print(e);
    }
    return authenticated;
  }

  void showPurchasingPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("구매 중", style: TextStyle(color: Colors.red)),
          content: SizedBox(
            height: 50.0,
            width: 50.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        );
      },
    );
  }

  void showPurchaseCompletePopup() {
    Navigator.pop(context); // 이전 팝업 닫기
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
            child: ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return item.quantity > 0
                    ? Column(
                        children: [
                          ListTile(
                            title: Text('${item.name} ${item.quantity}개',
                                style: TextStyle(
                                    fontFamily: 'CustomFont',
                                    color: Colors.red,
                                    fontSize: 20)),
                            trailing: Text('${item.price * item.quantity}원',
                                style: TextStyle(
                                    fontFamily: 'CustomFont',
                                    color: Colors.red,
                                    fontSize: 20)),
                            leading: IconButton(
                              icon: Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  item.quantity = 0;
                                });
                              },
                            ),
                          ),
                          Divider(color: Colors.grey),
                        ],
                      )
                    : Container();
              },
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
                    if (await authenticateWithFingerprint()) {
                      showPurchasingPopup();
                      await Future.delayed(
                          Duration(seconds: 2)); // '결제 중' 상태를 가정하는 시간
                      Navigator.pop(context); // '결제 중' 팝업 닫기
                      showPurchaseCompletePopup();
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
}

class CartItem {
  final String name;
  final int price;
  int quantity;

  CartItem({required this.name, this.quantity = 0, required this.price});
}

// 장바구니에 담긴 상품 목록 (예시 데이터)
List<CartItem> cartItems = [
  CartItem(name: '까르보불닭', quantity: 2, price: 1500),
  CartItem(name: '짜파게티', quantity: 1, price: 1200),
  // ... 추가 상품
  CartItem(name: '까르보불닭', price: 1500),
  CartItem(name: '짜파게티', price: 1200),
  CartItem(name: '진라면매운맛', price: 3500),
  CartItem(name: '불닭볶음면', price: 5000),
  CartItem(name: '김치사발면', price: 3000),
  CartItem(name: '육개장', price: 4000),
  CartItem(name: '신라면', price: 4500),
  CartItem(name: '튀김우동', price: 4300),
  CartItem(name: '너구리', price: 4500),
];
