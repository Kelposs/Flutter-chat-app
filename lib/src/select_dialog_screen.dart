import 'dart:async';
import 'dart:convert';

import 'package:atc_chat_3ver/src/new_dialog_screen.dart';
import 'package:atc_chat_3ver/src/push_notifications_manager.dart';
import 'package:atc_chat_3ver/src/utils/api_utils.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class SelectDialogScreen extends StatelessWidget {
  static const String TAG = "SelectDialogScreen";
  final CubeUser currentUser;

  const SelectDialogScreen(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'ユーザー名： ${currentUser.fullName}',
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () => _openSettings(context),
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: BodyLayout(currentUser),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return Future.value(false);
  }

  _openSettings(BuildContext context) {
    Navigator.pushNamed(context, 'settings',
        arguments: {USER_ARG_NAME: currentUser});
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;

  const BodyLayout(this.currentUser);

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(currentUser);
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String TAG = "_BodyLayoutState";

  final CubeUser currentUser;
  List<ListItem<CubeDialog>> dialogList = [];
  var _isDialogContinues = true;

  StreamSubscription<CubeMessage>? msgSubscription;
  final ChatMessagesManager? chatMessagesManager =
      CubeChatConnection.instance.chatMessagesManager;

  _BodyLayoutState(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(bottom: 16, top: 16),
        child: Column(
          children: [
            Visibility(
              visible: _isDialogContinues && dialogList.isEmpty,
              child: Container(
                margin: const EdgeInsets.all(40),
                alignment: FractionalOffset.center,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
            Expanded(
              child: _getDialogsList(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "新しいチャット",
        backgroundColor: Colors.blue,
        onPressed: () => _createNewDialog(context),
        child: const Icon(
          Icons.chat,
          color: Colors.white,
        ),
      ),
    );
  }

  void _createNewDialog(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateChatScreen(currentUser),
      ),
    ).then((value) => refresh());
  }

  void _processGetDialogError(exception) {
    log("GetDialog error $exception", TAG);
    setState(() {
      _isDialogContinues = false;
    });
    showDialogError(exception, context);
  }

  Widget _getDialogsList(BuildContext context) {
    if (_isDialogContinues) {
      getDialogs().then((dialogs) {
        _isDialogContinues = false;
        log("getDialogs: $dialogs", TAG);
        setState(() {
          dialogList.clear();
          dialogList.addAll(
              dialogs!.items.map((dialog) => ListItem(dialog)).toList());
        });
      }).catchError((exception) {
        _processGetDialogError(exception);
      });
    }
    if (_isDialogContinues && dialogList.isEmpty) {
      return const SizedBox.shrink();
    } else if (dialogList.isEmpty) {
      return const FittedBox(
        fit: BoxFit.contain,
        child: Text("No dialogs yet"),
      );
    } else {
      return ListView.separated(
        itemCount: dialogList.length,
        itemBuilder: _getListItemTile,
        separatorBuilder: (context, index) {
          return const Divider(thickness: 2, indent: 40, endIndent: 40);
        },
      );
    }
  }

  Widget _getListItemTile(BuildContext context, int index) {
    getDialogIcon() {
      var dialog = dialogList[index].data;
      if (dialog.type == CubeDialogType.PRIVATE) {
        return const Icon(
          Icons.person,
          size: 40.0,
          color: greyColor,
        );
      } else {
        return const Icon(
          Icons.group,
          size: 40.0,
          color: greyColor,
        );
      }
    }

    getDialogAvatarWidget() {
      var dialog = dialogList[index].data;
      if (dialog.photo == null) {
        return CircleAvatar(
            radius: 25, backgroundColor: greyColor3, child: getDialogIcon());
      } else {
        return CachedNetworkImage(
          placeholder: (context, url) => Container(
            width: 40.0,
            height: 40.0,
            padding: const EdgeInsets.all(70.0),
            decoration: const BoxDecoration(
              color: greyColor2,
              borderRadius: BorderRadius.all(
                Radius.circular(8.0),
              ),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(themeColor),
            ),
          ),
          imageUrl: dialogList[index].data.photo!,
          width: 45.0,
          height: 45.0,
          fit: BoxFit.cover,
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(left: 5.0, right: 5.0),
      child: TextButton(
        child: Row(
          children: <Widget>[
            Material(
              borderRadius: const BorderRadius.all(Radius.circular(25.0)),
              clipBehavior: Clip.hardEdge,
              child: getDialogAvatarWidget(),
            ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 20.0),
                child: Column(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                      child: Text(
                        dialogList[index].data.name ?? '利用不可',
                        style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0),
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 0.0),
                      child: Text(
                        dialogList[index].data.lastMessage ?? '利用不可',
                        style: const TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: dialogList[index].isSelected,
              child: IconButton(
                iconSize: 25.0,
                icon: const Icon(
                  Icons.delete,
                  color: themeColor,
                ),
                onPressed: () {
                  _deleteDialog(context, dialogList[index].data);
                },
              ),
            ),
            Container(
              child: Text(
                dialogList[index].data.lastMessageDateSent != null
                    ? DateFormat.MMMd("ja").format(
                        DateTime.fromMillisecondsSinceEpoch(
                            dialogList[index].data.lastMessageDateSent! * 1000))
                    : '利用不可',
                style: const TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
        onLongPress: () {
          setState(() {
            dialogList[index].isSelected = !dialogList[index].isSelected;
          });
        },
        onPressed: () {
          _openDialog(context, dialogList[index].data);
        },
      ),
    );
  }

  void _deleteDialog(BuildContext context, CubeDialog dialog) async {
    log("_deleteDialog= $dialog");
    Fluttertoast.showToast(msg: 'Coming soon');
  }

  void _openDialog(BuildContext context, CubeDialog dialog) async {
    Navigator.pushNamed(context, 'chat_dialog',
        arguments: {USER_ARG_NAME: currentUser, DIALOG_ARG_NAME: dialog});
  }

  void refresh() {
    setState(() {
      _isDialogContinues = true;
    });
  }

  @override
  void initState() {
    initializeDateFormatting('ja');
    msgSubscription =
        chatMessagesManager!.chatMessagesStream.listen(onReceiveMessage);
    bool isProduction = const bool.fromEnvironment('dart.vm.product');
    CreateEventParams params = CreateEventParams();
    params.parameters = {
      'message': "a send you a message", // 'message' field is required
      'title': "Kacper",
      'custom_parameter2': "custom parameter value 2",
    };

    params.notificationType = NotificationType.PUSH;
    params.environment =
        isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
    params.usersIds = [6010912];
    createEvent(params.getEventForRequest()).then((cubeEvent) {
      print("senda");
    }).catchError((error) {});
  }

  @override
  void dispose() {
    super.dispose();
    log("dispose", TAG);
    msgSubscription?.cancel();
  }

  void onReceiveMessage(CubeMessage message) {
    log("onReceiveMessage global message= $message");

    updateDialog(message);
  }

  updateDialog(CubeMessage msg) {
    ListItem<CubeDialog>? dialogItem =
        dialogList.firstWhereOrNull((dlg) => dlg.data.dialogId == msg.dialogId);
    if (dialogItem == null) return;
    dialogItem.data.lastMessage = msg.body;
    setState(() {
      dialogItem.data.lastMessage = msg.body;
    });
  }
}
