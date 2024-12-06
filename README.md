# Dart SDK for TON Connect

Improved Dart SDK for TON Connect 2.0

Here is the for of [DartTonConnect](https://github.com/romanovichim/dartTonconnect) package.


## Install

With Dart:

	 $ dart pub add darttonconnect_plus
This will add a line like this to your package's pubspec.yaml (and run an implicit `dart pub get`):

	dependencies:
	  darttonconnect_plus: ^1.0.1
Alternatively, your editor might support `dart pub get`. Check the docs for your editor to learn more.


##### Configure

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

# Handle events

Next events may be in the stream:

### Wallets_loaded

`TonConnectManager` loaded supported TON wallets list. Now you are able to offer them to connect.

### UniversalLink_generated

User picked up specific wallet. Link for connection is generated.

### TonPaymentStatus.Connected

Selected wallet is connected to the app

### TonPaymentStatus.Transaction_prepaired

Transanction request is sent through TON HTTP bridge. User should open the wallet and confirm the transaction

### TonPaymentStatus.Transaction_sent

The payment is successfully sent to the blockchain

### TonPaymentStatus.Transaction_error_or_rejected

 User declined the transaction or something went wrong with the connection

### TonPaymentStatus.Disconnected

Wallet is disconnected from your app


# Send TON coins




### UI Part

If user connected his wallet before, connector will restore the connection.Use the `connector.restoreConnection()` method to be called when the application or page is reloaded, for example:

```
import 'package:darttonconnect_plus/ton_connect.dart';

@override
void initState() {
  // Override default initState method to call restoreConnection
  // method after screen reloading.
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!connector.connected) {
      restoreConnection();
    }
  });
}


/// Restore connection from memory.
void restoreConnection() {
  connector.restoreConnection();
}
```

## Fetch wallets list

You can fetch all supported wallets list

```
import 'package:darttonconnect_plus/ton_connect.dart';

Future<void> main() async {
  final connector = TonConnect('https://raw.githubusercontent.com/XaBbl4/pytonconnect/main/pytonconnect-manifest.json');
  final List<WalletApp> wallets = await connector.getWallets();
  print('Wallets: $wallets');
}
```

## Subscribe to the connection status changes

```
/// Update state/reactive variables to show updates in the ui.
void statusChanged(dynamic walletInfo) {
  print('Wallet info: $ walletInfo');
}

connector.onStatusChange(statusChanged);
```

## Initialize a wallet connection via universal link

```
import 'package:darttonconnect_plus/ton_connect.dart';

final generatedUrl = await connector.connect(wallets.first);
print('Generated url: $generatedUrl');
}
```

Then you have to show this link to user as QR-code, or use it as a deep_link. You will receive an update in console when user approves connection in the wallet.

## Send transaction

```
const transaction = {
  "validUntil": 1718097354,
  "messages": [
    {
      "address":
          "0:575af9fc97311a11f423a1926e7fa17a93565babfd65fe39d2e58b8ccb38c911",
      "amount": "20000000",
    }
  ]
};

try {
  await connector.sendTransaction(transaction);
} catch (e) {
  if (e is UserRejectsError) {
    logger.d(
        'You rejected the transaction. Please confirm it to send to the blockchain');
  } else {
    logger.d('Unknown error happened $e');
  }
}
```

## Disconnect

```
connector.disconnect();
```


