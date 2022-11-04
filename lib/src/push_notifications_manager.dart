import 'dart:convert';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/utils/pref_util.dart';
import 'package:universal_io/io.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:platform_device_id/platform_device_id.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class PushNotificationsManager {
  static const TAG = "PushNotificationsManager";

  static final PushNotificationsManager _instance =
      PushNotificationsManager._internal();

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  PushNotificationsManager._internal() {
    Firebase.initializeApp();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  // BuildContext? applicationContext;

  static PushNotificationsManager get instance => _instance;

  Future<dynamic> Function(String? payload)? onNotificationClicked;

  init() async {
    FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

    print("everything ok");
    await FirebaseMessaging.instance.getToken();
    // vapidKey:
    //     "BNW_YNdZBsJrT8EaLJ1K2Q6buM7XRPCtYnS7SY0x0a3-p3rzU9TZ13cyvcrpIRR_ZJ5PwFRsYP5kZ_UHgtamFRc");
    await Firebase.initializeApp();

    await firebaseMessaging.requestPermission(
        alert: true, badge: true, sound: true);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher_foreground');
    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    String? token;
    if (Platform.isAndroid) {
      firebaseMessaging
          .getToken(
              vapidKey:
                  "BNW_YNdZBsJrT8EaLJ1K2Q6buM7XRPCtYnS7SY0x0a3-p3rzU9TZ13cyvcrpIRR_ZJ5PwFRsYP5kZ_UHgtamFRc")
          .then((token) {
        log('[getToken] token: $token', TAG);
        subscribe(token);
      }).catchError((onError) {
        log('[getToken] onError: $onError', TAG);
      });
    } else if (Platform.isIOS) {
      token = await firebaseMessaging.getAPNSToken();
    }

    if (!isEmpty(token)) {
      subscribe(token);
    }

    firebaseMessaging.onTokenRefresh.listen((newToken) {
      subscribe(newToken);
    });

    FirebaseMessaging.onMessage.listen((remoteMessage) {
      log('[onMessage] message: $remoteMessage', TAG);
      showNotification(remoteMessage);
    });

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

    // TODO test after fix https://github.com/FirebaseExtended/flutterfire/issues/4898
    FirebaseMessaging.onMessageOpenedApp.listen((remoteMessage) {
      log('[onMessageOpenedApp] remoteMessage: $remoteMessage', TAG);
      if (onNotificationClicked != null) {
        onNotificationClicked!.call(jsonEncode(remoteMessage.data));
      }
    });
  }

  subscribe(String? token) async {
    log('[subscribe] token: $token', PushNotificationsManager.TAG);

    SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
    if (sharedPrefs.getSubscriptionToken() == token) {
      log('[subscribe] skip subscription for same token',
          PushNotificationsManager.TAG);
      return;
    }

    bool isProduction = const bool.fromEnvironment('dart.vm.product');

    CreateSubscriptionParameters parameters = CreateSubscriptionParameters();
    ////////////////////////////////////////////////////////////////////////////////
    // CreateEventParams params = CreateEventParams();
    // params.parameters = {
    //   'message': "Some message in push", // 'message' field is required
    //   'custom_parameter1': "custom parameter value 1",
    //   'custom_parameter2': "custom parameter value 2",
    // };
    // params.notificationType = NotificationType.PUSH;
    // params.environment =
    //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
    // params.usersIds = [CubeChatConnection.instance.currentUser?.id];
    // print("Kacper ${CubeChatConnection.instance.currentUser?.id}");
    // createEvent(params.getEventForRequest())
    //     .then((cubeEvent) {})
    //     .catchError((error) {});
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    parameters.environment =
        isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;

    if (Platform.isAndroid) {
      parameters.channel = NotificationsChannels.GCM;
      parameters.platform = CubePlatform.ANDROID;
      parameters.bundleIdentifier = "com.connectycube.flutter.chat_sample";
    } else if (Platform.isIOS) {
      parameters.channel = NotificationsChannels.APNS;
      parameters.platform = CubePlatform.IOS;
      parameters.bundleIdentifier = "com.connectycube.flutter.chatSample.app";
    }

    String? deviceId = await PlatformDeviceId.getDeviceId;
    parameters.udid = deviceId;
    parameters.pushToken = token;

    createSubscription(parameters.getRequestParameters())
        .then((cubeSubscription) {
      log('[subscribe] subscription SUCCESS', PushNotificationsManager.TAG);
      sharedPrefs.saveSubscriptionToken(token!);
      for (var subscription in cubeSubscription) {
        if (subscription.device!.clientIdentificationSequence == token) {
          sharedPrefs.saveSubscriptionId(subscription.id!);
        }
      }
    }).catchError((error) {
      log('[subscribe] subscription ERROR: $error',
          PushNotificationsManager.TAG);
    });
  }

  unsubscribe() {
    SharedPrefs.instance.init().then((sharedPrefs) {
      int subscriptionId = sharedPrefs.getSubscriptionId();
      if (subscriptionId != 0) {
        deleteSubscription(subscriptionId).then((voidResult) {
          FirebaseMessaging.instance.deleteToken();
          sharedPrefs.saveSubscriptionId(0);
        });
      }
    }).catchError((onError) {
      log('[unsubscribe] ERROR: $onError', PushNotificationsManager.TAG);
    });
  }

  Future<dynamic> onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    log('[onDidReceiveLocalNotification] id: $id , title: $title, body: $body, payload: $payload',
        PushNotificationsManager.TAG);
    return Future.value();
  }

  Future<dynamic> onSelectNotification(String? payload) {
    log('[onSelectNotification] payload: $payload',
        PushNotificationsManager.TAG);
    if (onNotificationClicked != null) {
      onNotificationClicked!.call(payload);
    }
    return Future.value();
  }
}

showNotification(RemoteMessage message) async {
  log('[showNotification] message: $message', PushNotificationsManager.TAG);
  Map<String, dynamic> data = message.data;

  const sounds = "ringring.wav";

  print("mmmm $data");
  print(data["message"].contains("Incoming"));

  if (data["message"].contains("Incoming")) {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'messagexaa',
      'Chat messages_1asdasd',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Colors.green,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sounds.split(".").first),
    );
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    FlutterLocalNotificationsPlugin().show(
      1,
      "Chat sample",
      data['message'].toString(),
      platformChannelSpecifics,
      payload: jsonEncode(data),
    );
  } else {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
      'messages_channel_id4',
      'Chat messages_5',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Colors.green,
      playSound: true,
    );
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    FlutterLocalNotificationsPlugin().show(
      3,
      "Chat sample",
      data['message'].toString(),
      platformChannelSpecifics,
      payload: jsonEncode(data),
    );
  }
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('[onBackgroundMessage] message: $message', PushNotificationsManager.TAG);
  showNotification(message);
  return Future.value();
}

Future<dynamic> onNotificationSelected(String? payload, BuildContext? context) {
  log('[onSelectNotification] payload: $payload', PushNotificationsManager.TAG);

  if (context == null) return Future.value();

  log('[onSelectNotification] context != null', PushNotificationsManager.TAG);

  ///xxxxxx
  if (payload != null) {
    return SharedPrefs.instance.init().then((sharedPrefs) {
      CubeUser? user = sharedPrefs.getUser();

      if (user != null && !CubeChatConnection.instance.isAuthenticated()) {
        Map<String, dynamic> payloadObject = jsonDecode(payload);
        String? dialogId = payloadObject['dialog_id'];

        log("getNotificationAppLaunchDetails, dialog_id: $dialogId",
            PushNotificationsManager.TAG);

        getDialogs({'id': dialogId}).then((dialogs) {
          if (dialogs?.items != null && dialogs!.items.isNotEmpty) {
            CubeDialog dialog = dialogs.items.first;

            Navigator.pushReplacementNamed(context, 'chat_dialog',
                arguments: {USER_ARG_NAME: user, DIALOG_ARG_NAME: dialog});
          }
        });
      }
    });
  } else {
    return Future.value();
  }
}
