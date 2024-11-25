import 'dart:async';
import 'dart:convert';

import 'package:darttonconnect/storage/interface.dart';
import 'package:darttonconnect/ton_connect.dart';
import 'package:flutter/foundation.dart';
import 'package:tonutils/dataformat.dart';

import 'exceptions.dart';
import 'logger.dart';
import 'models/wallet_app.dart';

enum TonPaymentStatus {
  Wallets_loaded,
  UniversalLink_generated,
  Connected,
  Disconnected,
  Transaction_prepaired,
  Transaction_sent,
  Transaction_error_or_rejected,
}

class TonConnectManager {

  TonConnectManager(String manifestUrl,
      {IStorage? customStorage,
        String? walletsListSource,
        int? walletsListCacheTtl}) {
    _connector = TonConnect(manifestUrl,
        customStorage: customStorage,
        walletsListSource: walletsListSource,
        walletsListCacheTtl: walletsListCacheTtl);
    //messagesStream.asBroadcastStream();
    _connector.onStatusChange((status) {
      debugPrint("connector got status $status");
      if (status is Map<String, dynamic>) {
        if (status.containsKey('error')) {
          broadcastMessage(TonPaymentStatus.Transaction_error_or_rejected);
        } else if (status.containsKey('result')){
          broadcastMessage(TonPaymentStatus.Transaction_sent);
        }
        return;
      }
      broadcastMessage(_connector.connected
          ? TonPaymentStatus.Connected
          : TonPaymentStatus.Disconnected);
    });
    _connector.restoreConnection();
    loadWallets();
  }

  Future<void> disconnect() async {
    _connector.disconnect();
  }

  TonPaymentStatus status = TonPaymentStatus.Disconnected;

  bool get isConnected => _connector.connected;

  final StreamController<TonPaymentStatus> _clientsStreamController =
  StreamController<TonPaymentStatus>.broadcast();

  late TonConnect _connector;

  Stream<TonPaymentStatus> get messagesStream =>
      _clientsStreamController.stream;

  static List<WalletApp> wallets = [];

  static String? currentUniversalLink;

  void broadcastMessage(TonPaymentStatus updatedStatus) {
    status = updatedStatus;
    _clientsStreamController.add(updatedStatus);
  }

  void loadWallets() async {
    wallets = await _connector.getWallets();
    broadcastMessage(TonPaymentStatus.Wallets_loaded);
  }

  /// Send transaction with specified data.
  void sendTrx(
      {required String address,
        required int amount,
        String? comment,
        int? validUntill}) async {
    validUntill ??= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10000;
    if (!_connector.connected) {
      broadcastMessage(TonPaymentStatus.Disconnected);
    } else {
      Map<String, Object> message = {
        "address": address,
        "amount": amount.toString(),
      };
      if (comment != null) {
        var payload = ScString(comment);
        var cell = beginCell()
            .storeUint(BigInt.zero, 32)
            .storeStringTail(payload.value)
            .endCell();
        final base64Str = base64.encode(cell.toBoc());
        message['payload'] = base64Str;
      }
      var transaction = {
        "validUntil": validUntill,
        "messages": [message]
      };
      sendTrxRaw(transaction: transaction);
    }
  }

  sendTrxRaw({required Map<String, dynamic> transaction}) async {
    try {
      await _connector.sendTransaction(transaction);
      broadcastMessage(TonPaymentStatus.Transaction_prepaired);
    } catch (e) {
      if (e is UserRejectsError) {
        broadcastMessage(TonPaymentStatus.Transaction_error_or_rejected);
        logger.d(
            'You rejected the transaction. Please confirm it to send to the blockchain');
      } else {
        logger.d('Unknown error happened $e');
      }
    }
  }

  void generateWalletLink(WalletApp wallet) async {
    if (_connector.connected) {
      _connector.disconnect();
    }
    String universalLink = await _connector.connect(wallet);
    TonConnectManager.currentUniversalLink = universalLink;
    broadcastMessage(TonPaymentStatus.UniversalLink_generated);
  }
}
