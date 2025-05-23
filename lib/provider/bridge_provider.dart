import 'dart:async';
import 'dart:convert';

import 'package:darttonconnect_plus/crypto/session_crypto.dart';
import 'package:darttonconnect_plus/exceptions.dart';
import 'package:darttonconnect_plus/logger.dart';
import 'package:darttonconnect_plus/models/wallet_app.dart';
import 'package:darttonconnect_plus/provider/bridge_gateway.dart';
import 'package:darttonconnect_plus/provider/bridge_session.dart';
import 'package:darttonconnect_plus/provider/provider.dart';
import 'package:darttonconnect_plus/storage/interface.dart';

class BridgeProvider extends BaseProvider {
  static const int disconnectTimeout = 600;
  static const String standartUniversalUrl = 'tc://';

  late IStorage _storage;
  WalletApp? _wallet;

  late BridgeSession _session;
  BridgeGateway? _gateway;
  late Map<String, Completer<Map<String, dynamic>>> _pendingRequests;
  late List<dynamic> _listeners;

  BridgeProvider(IStorage storage, {WalletApp? wallet}) {
    _storage = storage;
    _wallet = wallet;

    _session = BridgeSession();
    _gateway = null;
    _pendingRequests = {};
    _listeners = [];
  }

  Future<String> connect(Map<String, dynamic> request) async {
    _closeGateways();
    final sessionCrypto = SessionCrypto();

    String bridgeUrl = _wallet?.bridgeUrl ?? '';
    String universalUrl =
        _wallet?.universalUrl ?? BridgeProvider.standartUniversalUrl;

    _gateway = BridgeGateway(
      _storage,
      bridgeUrl,
      sessionCrypto.sessionId,
      _gatewayListener,
      _gatewayErrorsListener,
    );

    await _gateway!.registerSession();

    _session.sessionCrypto = sessionCrypto;
    _session.bridgeUrl = bridgeUrl;

    return _generateUniversalUrl(universalUrl, request);
  }

  @override
  Future<bool> restoreConnection() async {
    _closeGateways();

    var connection = await _storage.getItem(key: IStorage.keyConnection);
    if (connection == null) {
      return false;
    }
    final decodeConnection = jsonDecode(connection) as Map<String, dynamic>;

    if (!decodeConnection.containsKey('session')) {
      return false;
    }
    _session = BridgeSession(stored: decodeConnection['session']);

    _gateway = BridgeGateway(
      _storage,
      _session.bridgeUrl!,
      _session.sessionCrypto.sessionId,
      _gatewayListener,
      _gatewayErrorsListener,
    );

    await _gateway!.registerSession();

    for (final listener in _listeners) {
      listener(decodeConnection['connect_event']);
    }

    return true;
  }

  @override
  void closeConnection() {
    _closeGateways();
    _session = BridgeSession();
    _gateway = null;
    _pendingRequests = {};
    _listeners = [];
  }

  @override
  Future<void> disconnect() async {
    final completer = Completer<void>();

    try {
      await Future.any([
        sendRequest({'method': 'disconnect', 'params': []}),
        Future.delayed(const Duration(seconds: disconnectTimeout)),
      ]);
    } catch (e) {
      logger.e('Provider disconnect', error: e);
    } finally {
      if (!completer.isCompleted) {
        await _removeSession();
        completer.complete();
      }
    }

    return completer.future;
  }

  void pause() {
    _gateway?.pause();
  }

  Future<void> unpause() async {
    await _gateway?.unpause();
  }

  @override
  Future<Map<String, dynamic>> sendRequest(dynamic request) async {
    if (_gateway == null || _session.walletPublicKey == null) {
      throw TonConnectError('Trying to send bridge request without session.');
    }
    final keyConnection =
        await _storage.getItem(key: IStorage.keyConnection, defaultValue: '{}');
    var connection = jsonDecode(keyConnection!) as Map<String, dynamic>;
    var id = connection['next_rpc_request_id'] != null
        ? connection['next_rpc_request_id'].toString()
        : '0';

    connection['next_rpc_request_id'] = (int.parse(id) + 1).toString();
    await _storage.setItem(
        key: IStorage.keyConnection, value: jsonEncode(connection));

    request['id'] = id;
    logger.d('Provider send http-bridge request: $request');

    final encodedRequest = _session.sessionCrypto.encrypt(
      jsonEncode(request),
      _session.walletPublicKey!,
    );

    await _gateway!
        .send(encodedRequest, _session.walletPublicKey!, request['method']);

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;
    return _pendingRequests;
  }

  @override
  void listen(Function eventsCallback) {
    _listeners.add(eventsCallback);
  }

  Future<void> _gatewayListener(
      Map<String, dynamic> bridgeIncomingMessage) async {
    final String decryptMessage = _session.sessionCrypto.decrypt(
        bridgeIncomingMessage['message'], bridgeIncomingMessage['from']);
    final walletMessage = jsonDecode(decryptMessage) as Map<String, dynamic>;

    logger.d('Wallet message received: $walletMessage');
    if (walletMessage.containsKey('error')) {
      for (final listener in _listeners) {
        listener(walletMessage);
      }
      return;
    }
    if (walletMessage.containsKey('result')){
      logger.d("bridge got result: $walletMessage");
      for (final listener in _listeners) {
        listener(walletMessage);
      }
      return;
    }
    if (!walletMessage.containsKey('event')) {
      if (walletMessage.containsKey('id')) {
        final id = walletMessage['id'].toString();
        if (!_pendingRequests.containsKey(id)) {
          logger.d("Response id $id doesn't match any request's id");
          return;
        }

        _pendingRequests[id]!.complete(walletMessage);
        _pendingRequests.remove(id);
      }
    }

    if (walletMessage.containsKey('id')) {
      final id = int.parse(walletMessage['id'].toString());
      final keyConnection = await _storage.getItem(
          key: IStorage.keyConnection, defaultValue: '{}');
      var connection = jsonDecode(keyConnection!) as Map<String, dynamic>;
      final lastId = connection.containsKey('last_wallet_event_id')
          ? connection['last_wallet_event_id']
          : 0;

      if (lastId != null && id <= lastId) {
        logger.e(
            'Received event id (=$id) must be greater than stored last wallet event id (=$lastId)');
        return;
      }

      if (walletMessage.containsKey('event') &&
          walletMessage['event'] != 'connect') {
        connection['last_wallet_event_id'] = id;
        await _storage.setItem(
            key: IStorage.keyConnection, value: jsonEncode(connection));
      }
    }

    final listeners = [..._listeners];

    if (walletMessage['event'] == 'connect') {
      await _updateSession(walletMessage, bridgeIncomingMessage['from']);
    } else if (walletMessage['event'] == 'disconnect') {
      await _removeSession();
    }

    for (final listener in listeners) {
      listener(walletMessage);
    }
  }

  void _gatewayErrorsListener() {
    throw TonConnectError('Bridge error');
  }

  Future<void> _updateSession(
      Map<String, dynamic> connectEvent, String walletPublicKey) async {
    _session.walletPublicKey = walletPublicKey;

    final connection = {
      'type': 'http',
      'session': _session.getMap(),
      'last_wallet_event_id':
          connectEvent.containsKey('id') ? connectEvent['id'] : null,
      'connect_event': connectEvent,
      'next_rpc_request_id': 0,
    };

    await _storage.setItem(
        key: IStorage.keyConnection, value: jsonEncode(connection));
  }

  Future<void> _removeSession() async {
    if (_gateway != null) {
      closeConnection();
      await _storage.removeItem(key: IStorage.keyConnection);
      await _storage.removeItem(key: IStorage.keyLastEventId);
    }
  }

  String _generateUniversalUrl(
      String universalUrl, Map<String, dynamic> request) {
    const version = 2;
    final sessionId = _session.sessionCrypto.sessionId;
    final requestSafe = Uri.encodeComponent(jsonEncode(request));

    final url = '$universalUrl?v=$version&id=$sessionId&r=$requestSafe';

    return url;
  }

  void _closeGateways() {
    _gateway?.close();
  }
}
