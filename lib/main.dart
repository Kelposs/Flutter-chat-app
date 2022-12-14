import 'dart:async';
import 'package:atc_chat_3ver/firebase_options.dart';
import 'package:atc_chat_3ver/src/chat_details_screen.dart';
import 'package:atc_chat_3ver/src/chat_dialog_screen.dart';
import 'package:atc_chat_3ver/src/login_screen.dart';
import 'package:atc_chat_3ver/src/managers/call_manager.dart';
import 'package:atc_chat_3ver/src/push_notifications_manager.dart';
import 'package:atc_chat_3ver/src/select_dialog_screen.dart';
import 'package:atc_chat_3ver/src/settings_screen.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/utils/pref_util.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:atc_chat_3ver/src/utils/configs.dart' as config;

import 'package:connectycube_sdk/connectycube_sdk.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _AppState();
  }
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late StreamSubscription<ConnectivityResult> connectivityStateSubscription;
  AppLifecycleState? appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: Builder(builder: (context) {
        CallManager.instance.init(context);
        return LoginScreen();
      }),
      //LoginScreen(),
      onGenerateRoute: (settings) {
        String? name = settings.name;
        Map<String, dynamic>? args =
            settings.arguments as Map<String, dynamic>?;

        MaterialPageRoute pageRout;

        switch (name) {
          case 'chat_dialog':
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDialogScreen(
                    args![USER_ARG_NAME], args[DIALOG_ARG_NAME]));
            break;
          case 'chat_details':
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                    args![USER_ARG_NAME], args[DIALOG_ARG_NAME]));
            break;

          case 'select_dialog':
            pageRout = MaterialPageRoute<bool>(
                builder: (context) => SelectDialogScreen(args![USER_ARG_NAME]));

            break;

          case 'login':
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());
            break;

          case 'settings':
            pageRout = MaterialPageRoute(
                builder: (context) => SettingsScreen(args![USER_ARG_NAME]));
            break;

          default:
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());

            break;
        }

        PushNotificationsManager.instance.onNotificationClicked = (payload) {
          return onNotificationSelected(payload, pageRout.subtreeContext);
        };

        return pageRout;
      },
    );
  }

  @override
  void initState() {
    super.initState();

    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    init(config.APP_ID, config.AUTH_KEY, config.AUTH_SECRET,
        onSessionRestore: () async {
      SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
      CubeUser? user = sharedPrefs.getUser();

      return createSession(user);
    });

    connectivityStateSubscription =
        Connectivity().onConnectivityChanged.listen((connectivityType) {
      if (AppLifecycleState.resumed != appState) return;

      if (connectivityType != ConnectivityResult.none) {
        log("chatConnectionState = ${CubeChatConnection.instance.chatConnectionState}");
        bool isChatDisconnected =
            CubeChatConnection.instance.chatConnectionState ==
                    CubeChatConnectionState.Closed ||
                CubeChatConnection.instance.chatConnectionState ==
                    CubeChatConnectionState.ForceClosed;

        if (isChatDisconnected &&
            CubeChatConnection.instance.currentUser != null) {
          CubeChatConnection.instance.relogin();
        }
      }
    });

    appState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  // @override
  // void dispose() {
  //   connectivityStateSubscription.cancel();
  //
  //   WidgetsBinding.instance!.removeObserver(this);
  //   super.dispose();
  // }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("Current app state: $state");
    appState = state;

    if (AppLifecycleState.paused == state) {
      if (CubeChatConnection.instance.isAuthenticated()) {
        CubeChatConnection.instance.logout();
      }
    } else if (AppLifecycleState.resumed == state) {
      SharedPrefs.instance.init().then((sharedPrefs) {
        CubeUser? user = sharedPrefs.getUser();

        if (user != null && !CubeChatConnection.instance.isAuthenticated()) {
          CubeChatConnection.instance.login(user);
        }
      });
    }
  }
}

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
