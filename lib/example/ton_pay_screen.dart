
import 'package:darttonconnect_plus/models/wallet_app.dart';
import 'package:darttonconnect_plus/ton_connect_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ton_buttons/flutter_ton_buttons.dart';
import 'package:url_launcher/url_launcher.dart';

class TonPayScreen extends StatefulWidget {

  const TonPayScreen();

  @override
  _State createState() => _State();
}

class _State extends State<TonPayScreen> {
  List<WalletApp> walletsList = [];
  Map<String, String>? walletConnectionSource;
  var tonManager = TonConnectManager(
      'https://raw.githubusercontent.com/aap17/dart_ton_plus/refs/heads/main/darttonconnect-manifest.json', logLevel: null);

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

            if (tonManager.walletConnectionLink != null) {
              launchUrl(Uri.parse(tonManager.walletConnectionLink!),
                  mode: LaunchMode.externalApplication);
              WidgetsBinding.instance.addPostFrameCallback((val) {

                _showLink(tonManager.selectedWallet!.name, tonManager.walletConnectionLink!);
              });
              debugPrint(tonManager.walletConnectionLink!);
            }
            break;
          case TonPaymentStatus.Disconnected:
            setState(() {

            });
            break;
          case TonPaymentStatus.Connected:
            setState(() {

            });
            break;
          case TonPaymentStatus.Transaction_prepaired:
              _showPayPendingPopUp();

            break;
          case TonPaymentStatus.Transaction_error_or_rejected:
            if (tonManager.isConnected){
              setState(() {
                debugPrint("payment error");
              });
            } else {
              _showConnectErrorPopUp(tonManager.selectedWallet!.name, tonManager.walletConnectionLink!);
            }
            break;
          case TonPaymentStatus.Transaction_sent:
            setState(() {
              debugPrint("payment sent!");
            });
            break;
          default:
            break;
        }
      });
    });
  }

  void _showLink(String name, String link) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return TonConnectionPendingWidget(
            walletName: name,
            onPop: () {
              Navigator.of(context).pop();
            },
            universalLink: link,
            qrCode: Container(
              height: 50,
              width: 50,
              color: Colors.blue,
            ),
          );
        });
  }

  void _showConnectErrorPopUp(String walletName, String link) {
    showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return TonConnectionPendingWidget(
            error: true,
            walletName: walletName,
            onPop: () {
              Navigator.of(context).pop();
            },
            universalLink: link,
            qrCode: Container(
              height: 50,
              width: 50,
              color: Colors.blue,
            ),
          );
        });
  }
  Widget _screen() {
    if (!tonManager.isConnected) {
      return _blueButton();
    }
    return Center(
        child: Column(children:[
          GestureDetector(
              onTap: (){
                tonManager.disconnect();
              },
              child: Text('logout')),
          SizedBox(height: 48),
          InkWell(
            onTap: () {
              tonManager.sendTrx(
                  address:
                      '0:d096ce8cbf04fe065cc0986f36a323545a406f8b0b020d05210f52081609af7b',
                  amount: 10123,
                  comment: "no comment at all 31337");
            },
            child: Text("pay here"))]));
  }

  Widget _showPayPopUp() {
    return InkWell(
        onTap: () {
          _showPayPendingPopUp();
        },
        child: TonConnectButton());
  }

  Widget _blueButton() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(height: 12),
      GestureDetector(
          onTap: () {
            _showConnectTON();
          },
          child: TonConnectButton())
    ]);
  }


  /// Restore connection from memory.
  void restoreConnection() {
    //connector.restoreConnection();
  }

  void _showConnectTON() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return TonOpenWalletWidget(
            wallets: walletsList,
            telegramWallet: walletsList.first,
            qrCode: SizedBox(),
            onTap: (WalletApp wallet) async {
              Navigator.of(context).pop();
              tonManager.generateWalletLink(wallet);
            });
      },
    );
  }

  void _showPayPendingPopUp() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return TonSendTrxWidget(
          walletName: tonManager.connectedWalletInfo?.device?.appName,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _screen();
  }
}
