import 'package:darttonconnect/models/wallet_app.dart';
import 'package:flutter/material.dart';

import '../ton_connect.dart';

class TonPayScreen extends StatefulWidget {
  final String email;
  final String payload;
  final String amount;

  const TonPayScreen(
      {required this.email, required this.payload, required this.amount});

  @override
  _State createState() => _State();
}

class _State extends State<TonPayScreen> {
  List<WalletApp> walletsList = [];
  Map<String, String>? walletConnectionSource;
  var tonManager = TonConnectManager(
      'https://gist.githubusercontent.com/romanovichim/e81d599a6f3798bb9f74ab1970a8b376/raw/43e00b0abc824ef272ac6d0f8083d21456602adf/gistfiletest.txt');

  @override
  void initState() {
    super.initState();
    tonManager.messagesStream.listen((TonPaymentStatus status) {
      debugPrint("got message ${status}");
      setState(() {
        switch (status) {
          case TonPaymentStatus.Wallets_loaded:
            walletsList = TonConnectManager.wallets;
            break;
          case TonPaymentStatus.UniversalLink_generated:
            if (TonConnectManager.currentUniversalLink != null) {
              WidgetsBinding.instance.addPostFrameCallback((val) {
                _showLink(TonConnectManager.currentUniversalLink!);
              });
            }
            break;
          case TonPaymentStatus.Disconnected:
            break;
          case TonPaymentStatus.Connected:
            break;
          case TonPaymentStatus.Transaction_pending:
            WidgetsBinding.instance.addPostFrameCallback((val) {
              _showPayPopUp();
            });
            break;
          case TonPaymentStatus.Transaction_sent:
            //do smth
            break;
          default:
            break;
        }
      });
    });
  }

  void _showLink(String link) {}

  Widget _screen() {
    if (!tonManager.isConnected) {
      return _blueButton();
    }
    return Center(
        child: InkWell(
            onTap: () {
              tonManager.sendTrx(
                  address:
                      '0:d096ce8cbf04fe065cc0986f36a323545a406f8b0b020d05210f52081609af7b',
                  amount: 123,
                  comment: "no comment at all 31337");
            },
            child: Text("pay here")));
  }

  Widget _blueButton() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text("User ${widget.email}, amount to pay ${widget.amount}"),
      SizedBox(height: 12),
      ElevatedButton(
          onPressed: () {
            _showConnectTON();
          },
          child: const Text('connect ton'))
    ]);
  }

  /// Restore connection from memory.
  void restoreConnection() {
    //connector.restoreConnection();
  }

  void _showConnectTON() {}

  void _showPayPopUp() {}

  @override
  Widget build(BuildContext context) {
    return _screen();
  }
}
