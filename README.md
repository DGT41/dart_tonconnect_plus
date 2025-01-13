# Dart SDK for TON Connect

Improved Dart SDK for TON Connect 2.0

Here is the fork of [DartTonConnect](https://github.com/romanovichim/dartTonconnect) package. Forked version advantages:
1. Stream with TON HTTP network events
2. Transaction sending interface with payload support
3. Bug fixes


## Install

With Dart:

	 $ dart pub add darttonconnect_plus
This will add a line like this to your package's pubspec.yaml (and run an implicit `dart pub get`):

	dependencies:
	  darttonconnect_plus: ^1.0.1
Alternatively, your editor might support `dart pub get`. Check the docs for your editor to learn more.


## Configure

Create JSON-manifest file with your app description. This info will be displayed inside the wallet during the connection procedure.

```json
{
  "url": "<app-url>",                        // required
  "name": "<app-name>",                      // required
  "iconUrl": "<app-icon-url>",               // required
  "termsOfUseUrl": "<terms-of-use-url>",     // optional
  "privacyPolicyUrl": "<privacy-policy-url>" // optional
}
```

This file must be available to GET by its URL.


## Init

Pass manifest to `TonConnectManager` 

```
var tonManager = TonConnectManager(
'https://gist.githubusercontent.com/romanovichim/e81d599a6f3798bb9f74ab1970a8b376/raw/43e00b0abc824ef272ac6d0f8083d21456602adf/gistfiletest.txt');
```

Subscribe to TON events stream messages

```
    tonManager.messagesStream.listen((TonPaymentStatus status) {
      
    });
```

## Handle events

Next events may be in the stream:

`TonPaymentStatus.Wallets_loaded`

Supported TON wallets list is loaded. Now you are able to offer them to connect.

`TonPaymentStatus.UniversalLink_generated`

User picked up specific wallet. Link for connection is generated.

`TonPaymentStatus.Connected`

Selected wallet is connected to the app. Now you are able to request the transaction.

`TonPaymentStatus.Transaction_prepaired`

Transanction request is sent through TON HTTP bridge. User should open the wallet and confirm the transaction

`TonPaymentStatus.Transaction_sent`

The transaction is successfully add to the blockchain

`TonPaymentStatus.Transaction_error_or_rejected`

User declined the transaction or something went wrong with the connection

`TonPaymentStatus.Disconnected`

The wallet is disconnected from your app


## Transaction

Simple interface, with `comment` that will be shown while confirmation inside the wallet

```
  void sendTrx(
      {required String address,
        required int amount,
        String? comment,
        int? validUntill})
```

Or create transaction by your own

```
sendTrxRaw({required Map<String, dynamic> transaction})
```


## Example

Full example please see [here](https://github.com/aap17/dart_ton_plus/blob/main/lib/example/ton_pay_screen.dart)


## UI Part

All nessesary Flutter widgets implemented in [Flutter_ton_buttons](https://pub.dev/packages/flutter_ton_buttons/versions) package
