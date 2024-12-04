import 'dart:async';
import 'dart:convert';

import 'package:darttonconnect/parsers/connect_event.dart';
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
    connector = TonConnect(manifestUrl,
        customStorage: customStorage,
        walletsListSource: walletsListSource,
        walletsListCacheTtl: walletsListCacheTtl);
    connector.onStatusChange((status) {
      if (status is Map<String, dynamic>) {
        if (status.containsKey('error')) {
          broadcastMessage(TonPaymentStatus.Transaction_error_or_rejected);
        } else if (status.containsKey('result')){
          broadcastMessage(TonPaymentStatus.Transaction_sent);
        }
        return;
      }
      broadcastMessage(connector.connected
          ? TonPaymentStatus.Connected
          : TonPaymentStatus.Disconnected);
    });
    connector.restoreConnection();
    loadWallets();
  }

  Future<void> disconnect() async {
    connector.disconnect();
  }

  TonPaymentStatus status = TonPaymentStatus.Disconnected;

  bool get isConnected => connector.connected;

  final StreamController<TonPaymentStatus> _clientsStreamController =
  StreamController<TonPaymentStatus>.broadcast();

  late TonConnect connector;

  Stream<TonPaymentStatus> get messagesStream =>
      _clientsStreamController.stream;

  static List<WalletApp> wallets = [];

  String? walletConnectionLink;

  WalletInfo? get connectedWalletInfo => connector.wallet;

  WalletApp? selectedWallet;

  void broadcastMessage(TonPaymentStatus updatedStatus) {
    status = updatedStatus;
    _clientsStreamController.add(updatedStatus);
  }

  void loadWallets() async {
    wallets = await connector.getWallets();
    broadcastMessage(TonPaymentStatus.Wallets_loaded);
  }

  /// Send transaction with specified data.
  void sendTrx(
      {required String address,
        required int amount,
        String? comment,
        int? validUntill}) async {
    validUntill ??= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10000;
    if (!connector.connected) {
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
      await connector.sendTransaction(transaction);
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
    if (connector.connected) {
      connector.disconnect();
    }
    String universalLink = await connector.connect(wallet);
    walletConnectionLink = universalLink;
    selectedWallet = wallet;
    broadcastMessage(TonPaymentStatus.UniversalLink_generated);
  }
}
