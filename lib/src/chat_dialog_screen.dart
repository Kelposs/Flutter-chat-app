import 'dart:async';
import 'dart:typed_data';

import 'package:atc_chat_3ver/src/chat_details_screen.dart';
import 'package:atc_chat_3ver/src/managers/call_manager.dart';
import 'package:atc_chat_3ver/src/managers/firebase_api.dart';
import 'package:atc_chat_3ver/src/utils/api_utils.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/widgets/common.dart';
import 'package:atc_chat_3ver/src/widgets/full_photo.dart';
import 'package:atc_chat_3ver/src/widgets/loading.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:connectycube_sdk/connectycube_sdk.dart';
// import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class ChatDialogScreen extends StatefulWidget {
  static var iconClick = false;
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  const ChatDialogScreen(this._cubeUser, this._cubeDialog);

  @override
  State<ChatDialogScreen> createState() => _ChatDialogScreenState();
}

class _ChatDialogScreenState extends State<ChatDialogScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget._cubeDialog.name != null ? widget._cubeDialog.name! : '',
        ),
        centerTitle: false,
        actions: <Widget>[
          IconButton(
              onPressed: () => {
                    CallManager.instance.startNewCall(context,
                        CallType.VIDEO_CALL, ChatScreenState._selectedUsers),
                    ChatScreenState(widget._cubeUser, widget._cubeDialog)
                        .onSendChatMessage("${widget._cubeUser.fullName}は電話した。")
                  },
              icon: const Icon(Icons.videocam)),
          IconButton(
              onPressed: () => {
                    CallManager.instance.startNewCall(context,
                        CallType.AUDIO_CALL, ChatScreenState._selectedUsers),
                    ChatScreenState(widget._cubeUser, widget._cubeDialog)
                        .onSendChatMessage("${widget._cubeUser.fullName}は電話した。")
                  },
              // onPressed: () => CallManager.instance.startNewCall(
              //     context, CallType.AUDIO_CALL, ChatScreenState._selectedUsers),
              icon: const Icon(Icons.call)), //tu je problem
          IconButton(
            onPressed: () => _chatDetails(context),
            icon: const Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: ChatScreen(widget._cubeUser, widget._cubeDialog),
    );
  }

  _chatDetails(BuildContext context) async {
    print("_chatDetails= ${widget._cubeDialog}");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatDetailsScreen(widget._cubeUser, widget._cubeDialog),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  static const String TAG = "_CreateChatScreenState";
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  const ChatScreen(this._cubeUser, this._cubeDialog);

  @override
  State createState() => ChatScreenState(_cubeUser, _cubeDialog);
}

class ChatScreenState extends State<ChatScreen> {
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;
  final Map<int?, CubeUser?> _occupants = {};
  static late Set<int> _selectedUsers;
  static late String nameToShow;

  late bool isLoading;
  String? imageUrl;
  List<CubeMessage>? listMessage = [];
  Timer? typingTimer;
  UploadTask? task;
  bool isTyping = false;
  String userStatus = '';
  String urlD = "";
  String destination = "";

  final TextEditingController textEditingController = TextEditingController();
  final ScrollController listScrollController = ScrollController();

  StreamSubscription<CubeMessage>? msgSubscription;
  StreamSubscription<MessageStatus>? deliveredSubscription;
  StreamSubscription<MessageStatus>? readSubscription;
  StreamSubscription<TypingStatus>? typingSubscription;

  late String savename;
  // late firebase_storage.FirebaseStorage storage;

  final List<CubeMessage> _unreadMessages = [];
  final List<CubeMessage> _unsentMessages = [];

  ChatScreenState(this._cubeUser, this._cubeDialog);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ja');
    _initCubeChat();
    // storage = firebase_storage.FirebaseStorage.instance;
    isLoading = false;
    nameToShow = _cubeDialog.name!;
    imageUrl = '';
    _selectedUsers = {};
    _cubeDialog.occupantsIds?.removeWhere((element) => element == _cubeUser.id);
    for (var i = 0; i < _cubeDialog.occupantsIds!.length; i++) {
      _selectedUsers.add(_cubeDialog.occupantsIds![i]);
    }
    savename = "";
    // //////////////////////
    // // /
    // bool isProduction = bool.fromEnvironment('dart.vm.product');
    // CreateEventParams params = CreateEventParams();
    // params.parameters = {
    //   'message': "aaaaa", // 'message' field is required
    //   'custom_parameter1': "custom parameter value 1",
    //   'custom_parameter2': "custom parameter value 2",
    // };
    // params.notificationType = NotificationType.PUSH;
    // params.eventType = params.environment =
    //     isProduction ? CubeEnvironment.PRODUCTION : CubeEnvironment.DEVELOPMENT;
    // params.usersIds = [5498363];
    // print("Kacper ${CubeChatConnection.instance.currentUser?.id}");
    // createEvent(params.getEventForRequest())
    //     .then((cubeEvent) {})
    //     .catchError((error) {});
  }

  @override
  void dispose() {
    msgSubscription?.cancel();
    deliveredSubscription?.cancel();
    readSubscription?.cancel();
    typingSubscription?.cancel();
    textEditingController.dispose();
    super.dispose();
  }

  void openGallery() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null) return;

    setState(() {
      isLoading = true;
    });

    var uploadImageFuture = getUploadingImageFuture(result);
    Uint8List imageData;
    File file;

    if (kIsWeb) {
      imageData = result.files.single.bytes!;
    } else {
      imageData = File(result.files.single.path!).readAsBytesSync();
    }
    try {
      var decodedImage = await decodeImageFromList(imageData);

      uploadImageFile(uploadImageFuture, decodedImage);
    } catch (e) {
      if (kIsWeb) {
        final fileBytes = result.files.first.bytes;
        final fileName = result.files.first.name;
        // var attachment = CubeAttachment();
        //         final attachment = CubeAttachment();
        // attachment.id = cubeFile.uid;
        // attachment.url = getPrivateUrlForUid(cubeFile.uid);
        // attachment.name = cubeFile.name;
        // attachment.uid = cubeFile.uid;
        // final message = createCubeMsg();
        // message.body = "Attachment";
        // message.attachments = [attachment];
        var link;
        await FirebaseStorage.instance
            .ref('uploads/$fileName')
            .putData(fileBytes!)
            .then(
              (p0) => {
                setState(() {
                  isLoading = false;
                }),
              },
            );
        link = await FirebaseStorage.instance
            .ref('uploads/$fileName')
            .getDownloadURL();

        final attachment = CubeAttachment();
        attachment.url = link.toString();
        attachment.name = fileName;

        final message = createCubeMsg();
        message.body = "Attachment";
        message.attachments = [attachment];
        onSendMessage(message);
      } else {
        file = File(result.files.single.path!);
        uploadNonImageFile(file);
      }
    }
  }

  Future uploadImageFile(Future<CubeFile> uploadAction, imageData) async {
    uploadAction.then((cubeFile) {
      onSendChatAttachment(cubeFile, imageData);
    }).catchError((ex) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'This file is not an image');
    });
  }

  Future uploadNonImageFile(fileData) async {
    destination = "file/${fileData.path.split('/').last}";
    // task = FirebaseApi.uploadFile(destination, fileData);
    // if (task == null) return;
    // urlD = await (await task)!.ref.getDownloadURL();
    uploadFile(fileData).then((cubeFile) {
      final attachment = CubeAttachment();
      attachment.id = cubeFile.uid;
      attachment.url = getPrivateUrlForUid(cubeFile.uid);
      attachment.name = cubeFile.name;
      attachment.uid = cubeFile.uid;
      final message = createCubeMsg();
      message.body = "Attachment";
      message.attachments = [attachment];
      /////////////////////////////////////
      //////////////////////////////////////////////

      onSendMessage(message);
    }).catchError((ex) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'Thisaaaaa file is not an image');
    });
  }

  Future getLink(fileData) async {
    destination = "file/${fileData.path.split('/').last}";
  }

  void onReceiveMessage(CubeMessage message) {
    log("onReceiveMessage message= $message");
    if (message.dialogId != _cubeDialog.dialogId ||
        message.senderId == _cubeUser.id) return;

    _cubeDialog.deliverMessage(message);
    addMessageToListView(message);
  }

  void onDeliveredMessage(MessageStatus status) {
    log("onDeliveredMessage message= $status");
    updateReadDeliveredStatusMessage(status, false);
  }

  void onReadMessage(MessageStatus status) {
    log("onReadMessage message= ${status.messageId}");
    updateReadDeliveredStatusMessage(status, true);
  }

  void onTypingMessage(TypingStatus status) {
    log("TypingStatus message= ${status.userId}");
    if (status.userId == _cubeUser.id ||
        (status.dialogId != null && status.dialogId != _cubeDialog.dialogId)) {
      return;
    }
    userStatus = _occupants[status.userId]?.fullName ??
        _occupants[status.userId]?.login ??
        '';
    if (userStatus.isEmpty) return;
    userStatus = "$userStatus is typing ...";

    if (isTyping != true) {
      setState(() {
        isTyping = true;
      });
    }
    startTypingTimer();
  }

  startTypingTimer() {
    typingTimer?.cancel();
    typingTimer = Timer(const Duration(milliseconds: 900), () {
      setState(() {
        isTyping = false;
      });
    });
  }

  void onSendChatMessage(String content) {
    if (content.trim() != '') {
      final message = createCubeMsg();
      message.body = content.trim();
      onSendMessage(message);
      bool isProduction = const bool.fromEnvironment('dart.vm.product');
      CreateEventParams params = CreateEventParams();

      if (content.contains("はあなたに電話をします。")) {
        params.parameters = {
          'message':
              "${_cubeUser.fullName}はあなたに電話をします。", // 'message' field is required
          'title': "Kacper",
          'custom_parameter2': "custom parameter value 2",
        };
      } else {
        params.parameters = {
          'message':
              "${_cubeUser.fullName} send you a message", // 'message' field is required
          'title': "Kacper",
          'custom_parameter2': "custom parameter value 2",
        };
      }
      params.notificationType = NotificationType.PUSH;
      params.environment = isProduction
          ? CubeEnvironment.PRODUCTION
          : CubeEnvironment.DEVELOPMENT;
      params.usersIds = _cubeDialog.occupantsIds!;
      createEvent(params.getEventForRequest())
          .then((cubeEvent) {})
          .catchError((error) {});
    } else {
      Fluttertoast.showToast(msg: 'Nothing to send');
    }
  }

  void onSendChatAttachment(CubeFile cubeFile, imageData) async {
    final attachment = CubeAttachment();
    attachment.id = cubeFile.uid;
    attachment.type = CubeAttachmentType.IMAGE_TYPE;
    attachment.url = cubeFile.getPublicUrl();
    attachment.height = imageData.height;
    attachment.width = imageData.width;
    final message = createCubeMsg();
    message.body = "Attachment";
    message.attachments = [attachment];

    onSendMessage(message);
  }

  CubeMessage createCubeMsg() {
    var message = CubeMessage();
    message.dateSent = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    message.markable = true;
    message.saveToHistory = true;
    return message;
  }

  void onSendMessage(CubeMessage message) async {
    log("onSendMessage message= $message");
    textEditingController.clear();
    await _cubeDialog.sendMessage(message);
    message.senderId = _cubeUser.id;
    if (!ChatDialogScreen.iconClick) {
      addMessageToListView(message);
      listScrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    ChatDialogScreen.iconClick = false;
  }

  updateReadDeliveredStatusMessage(MessageStatus status, bool isRead) {
    log('[updateReadDeliveredStatusMessage]');
    setState(() {
      CubeMessage? msg = listMessage!
          .firstWhereOrNull((msg) => msg.messageId == status.messageId);
      if (msg == null) return;
      if (isRead) {
        msg.readIds == null
            ? msg.readIds = [status.userId]
            : msg.readIds?.add(status.userId);
      } else {
        msg.deliveredIds == null
            ? msg.deliveredIds = [status.userId]
            : msg.deliveredIds?.add(status.userId);
      }

      log('[updateReadDeliveredStatusMessage] status updated for $msg');
    });
  }

  addMessageToListView(CubeMessage message) {
    setState(() {
      isLoading = false;
      int existMessageIndex = listMessage!.indexWhere((cubeMessage) {
        return cubeMessage.messageId == message.messageId;
      });

      if (existMessageIndex != -1) {
        listMessage!
            .replaceRange(existMessageIndex, existMessageIndex + 1, [message]);
      } else {
        listMessage!.insert(0, message);
      }
    });
    ChatDialogScreen.iconClick = false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onBackPress,
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // List of messages
              buildListMessage(),
              //Typing content
              buildTyping(),
              // Input content
              buildInput(),
            ],
          ),

          // Loading
          buildLoading()
        ],
      ),
    );
  }

  Widget buildItem(int index, CubeMessage message) {
    markAsReadIfNeed() {
      var isOpponentMsgRead =
          message.readIds != null && message.readIds!.contains(_cubeUser.id);
      print(
          "markAsReadIfNeed message= $message, isOpponentMsgRead= $isOpponentMsgRead");
      if (message.senderId != _cubeUser.id && !isOpponentMsgRead) {
        if (message.readIds == null) {
          message.readIds = [_cubeUser.id!];
        } else {
          message.readIds!.add(_cubeUser.id!);
        }

        if (CubeChatConnection.instance.chatConnectionState ==
            CubeChatConnectionState.Ready) {
          _cubeDialog.readMessage(message);
        } else {
          _unreadMessages.add(message);
        }
      }
    }

    Widget getReadDeliveredWidget() {
      log("[getReadDeliveredWidget]");
      bool messageIsRead() {
        log("[getReadDeliveredWidget] messageIsRead");
        if (_cubeDialog.type == CubeDialogType.PRIVATE) {
          return message.readIds != null &&
              (message.recipientId == null ||
                  message.readIds!.contains(message.recipientId));
        }
        return message.readIds != null &&
            message.readIds!.any(
                (int id) => id != _cubeUser.id && _occupants.keys.contains(id));
      }

      bool messageIsDelivered() {
        log("[getReadDeliveredWidget] messageIsDelivered");
        if (_cubeDialog.type == CubeDialogType.PRIVATE) {
          return message.deliveredIds?.contains(message.recipientId) ?? false;
        }
        return message.deliveredIds != null &&
            message.deliveredIds!.any(
                (int id) => id != _cubeUser.id && _occupants.keys.contains(id));
      }

      if (messageIsRead()) {
        log("[getReadDeliveredWidget] if messageIsRead");
        return Stack(children: const <Widget>[
          Icon(
            Icons.check,
            size: 15.0,
            color: blueColor,
          ),
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.check,
              size: 15.0,
              color: blueColor,
            ),
          )
        ]);
      } else if (messageIsDelivered()) {
        log("[getReadDeliveredWidget] if messageIsDelivered");
        return Stack(children: const <Widget>[
          Icon(
            Icons.check,
            size: 15.0,
            color: greyColor,
          ),
          Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.check,
              size: 15.0,
              color: greyColor,
            ),
          )
        ]);
      } else {
        log("[getReadDeliveredWidget] sent");
        return const Icon(
          Icons.check,
          size: 15.0,
          color: greyColor,
        );
      }
    }

    Widget getDateWidget() {
      return Text(
        DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(message.dateSent! * 1000)),
        style: const TextStyle(
            color: greyColor, fontSize: 12.0, fontStyle: FontStyle.italic),
      );
    }

    Widget getHeaderDateWidget() {
      return Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(10.0),
        child: Text(
          DateFormat.MMMEd("ja").format(
              DateTime.fromMillisecondsSinceEpoch(message.dateSent! * 1000)),
          style: const TextStyle(
              color: primaryColor, fontSize: 20.0, fontStyle: FontStyle.italic),
        ),
      );
    }

    bool isHeaderView() {
      int headerId = int.parse(DateFormat('ddMMyyyy').format(
          DateTime.fromMillisecondsSinceEpoch(message.dateSent! * 1000)));
      if (index >= listMessage!.length - 1) {
        return false;
      }
      var msgPrev = listMessage![index + 1];
      int nextItemHeaderId = int.parse(DateFormat('ddMMyyyy').format(
          DateTime.fromMillisecondsSinceEpoch(msgPrev.dateSent! * 1000)));
      var result = headerId != nextItemHeaderId;
      return result;
    }

    if (message.senderId == _cubeUser.id) {
      // Right (own message)
      return Column(
        children: <Widget>[
          isHeaderView() ? getHeaderDateWidget() : const SizedBox.shrink(),
          GestureDetector(
            onLongPress: () {
              List<String> ids = [message.messageId!];
              bool force =
                  true; // true - to delete everywhere, false - to delete for himself

              deleteMessages(ids, force).then((deleteItemsResult) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          ChatDialogScreen(this._cubeUser, this._cubeDialog)),
                  (Route<dynamic> route) => false,
                );
              }).catchError((error) {});
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                (message.attachments?.isNotEmpty == true)
                    // Image
                    ? Container(
                        decoration: BoxDecoration(
                            color: greyColor2,
                            borderRadius: BorderRadius.circular(8.0)),
                        margin: EdgeInsets.only(
                            bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                            right: 10.0),
                        child: message.attachments!.first.url != null &&
                                message.attachments!.first.height != null
                            ? TextButton(
                                child: Material(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8.0)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        CachedNetworkImage(
                                          placeholder: (context, url) =>
                                              Container(
                                            width: 200.0,
                                            height: 200.0,
                                            padding: const EdgeInsets.all(70.0),
                                            decoration: const BoxDecoration(
                                              color: greyColor2,
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(8.0),
                                              ),
                                            ),
                                            child:
                                                const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      themeColor),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Material(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(8.0),
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: Image.asset(
                                              'images/img_not_available.jpeg',
                                              width: 200.0,
                                              height: 200.0,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          imageUrl:
                                              message.attachments!.first.url!,
                                          width: 200.0,
                                          height: 200.0,
                                          fit: BoxFit.cover,
                                        ),
                                        getDateWidget(),
                                        getReadDeliveredWidget(),
                                      ]),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FullPhoto(
                                              url: message
                                                  .attachments!.first.url!)));
                                },
                              )
                            : TextButton(
                                child: Material(
                                  color: greyColor2,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8.0)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 200, maxHeight: 1000),
                                          child: RichText(
                                            overflow: TextOverflow.ellipsis,
                                            text: TextSpan(
                                                text: message
                                                    .attachments!.first.name!,
                                                style: const TextStyle(
                                                    color: Colors.blue)),
                                          ),
                                        ),
                                        // Text(
                                        //   getPrivateUrlForUid(
                                        //       message.attachments!.first.uid)!,
                                        //   overflow: TextOverflow.clip,
                                        //   maxLines: 4,
                                        //   softWrap: false,
                                        //   style: TextStyle(color: primaryColor),
                                        // ),
                                        getDateWidget(),
                                        getReadDeliveredWidget(),
                                      ]),
                                ),
                                onPressed: () async => {
                                  print(message.attachments!.first.url!),
                                  launchUrl(Uri.parse(
                                      message.attachments!.first.url!))
                                },
                              ),
                        // {launch(message.attachments!.first.url!)}),
                      )
                    : (message.body != null && message.body!.isNotEmpty == true)
                        // Text
                        ? Flexible(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                  15.0, 10.0, 15.0, 10.0),
                              decoration: BoxDecoration(
                                  color: greyColor2,
                                  borderRadius: BorderRadius.circular(8.0)),
                              margin: EdgeInsets.only(
                                  bottom:
                                      isLastMessageRight(index) ? 20.0 : 10.0,
                                  right: 10.0),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      message.body!,
                                      style:
                                          const TextStyle(color: primaryColor),
                                    ),
                                    getDateWidget(),
                                    getReadDeliveredWidget(),
                                  ]),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.fromLTRB(
                                15.0, 10.0, 15.0, 10.0),
                            width: 200.0,
                            decoration: BoxDecoration(
                                color: greyColor2,
                                borderRadius: BorderRadius.circular(8.0)),
                            margin: EdgeInsets.only(
                                bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                                right: 10.0),
                            child: const Text(
                              "Empty",
                              style: TextStyle(color: primaryColor),
                            ),
                          )
              ],
            ),
          ),
        ],
      );
    } else {
      // Left (opponent message)
      markAsReadIfNeed();
      return Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            isHeaderView() ? getHeaderDateWidget() : const SizedBox.shrink(),
            Row(
              children: <Widget>[
                Material(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(18.0),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: CircleAvatar(
                    backgroundImage: _occupants[message.senderId]?.avatar !=
                                null &&
                            _occupants[message.senderId]!.avatar!.isNotEmpty
                        ? NetworkImage(_occupants[message.senderId]!.avatar!)
                        : null,
                    backgroundColor: greyColor2,
                    radius: 30,
                    child: getAvatarTextWidget(
                      _occupants[message.senderId]?.avatar != null &&
                          _occupants[message.senderId]!.avatar!.isNotEmpty,
                      _occupants[message.senderId]
                          ?.fullName
                          ?.substring(0, 2)
                          .toUpperCase(),
                    ),
                  ),
                ), /////////////////////////////////////////////////////
                message.attachments?.isNotEmpty ?? true
                    ? Container(
                        margin: const EdgeInsets.only(left: 10.0),
                        child: message.attachments!.first.url != null &&
                                message.attachments!.first.height != null
                            ? TextButton(
                                child: Material(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8.0)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CachedNetworkImage(
                                          placeholder: (context, url) =>
                                              Container(
                                            width: 200.0,
                                            height: 200.0,
                                            padding: const EdgeInsets.all(70.0),
                                            decoration: const BoxDecoration(
                                              color: greyColor2,
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(8.0),
                                              ),
                                            ),
                                            child:
                                                const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      themeColor),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Material(
                                            borderRadius:
                                                const BorderRadius.all(
                                              Radius.circular(8.0),
                                            ),
                                            clipBehavior: Clip.hardEdge,
                                            child: Image.asset(
                                              'images/img_not_available.jpeg',
                                              width: 200.0,
                                              height: 200.0,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          imageUrl:
                                              message.attachments!.first.url!,
                                          width: 200.0,
                                          height: 200.0,
                                          fit: BoxFit.cover,
                                        ),
                                        getDateWidget(),
                                      ]),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FullPhoto(
                                              url: message
                                                  .attachments!.first.url!)));
                                },
                              )
                            : TextButton(
                                child: Material(
                                  color: primaryColor,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8.0)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(
                                              15.0, 10.0, 15.0, 5.0),
                                          constraints: const BoxConstraints(
                                              maxWidth: 200, maxHeight: 1000),
                                          child: RichText(
                                            overflow: TextOverflow.ellipsis,
                                            text: TextSpan(
                                                text: message
                                                    .attachments!.first.name!,
                                                style: TextStyle(
                                                    color:
                                                        Colors.blue.shade300)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 15, bottom: 5),
                                          child: getDateWidget(),
                                        )
                                      ]),
                                ),
                                onPressed: () async => {
                                      print(message.attachments!.first.url!),
                                      launchUrl(Uri.parse(
                                          message.attachments!.first.url!))
                                    }),
                        // {launch(message.attachments!.first.url!)}),
                      )
                    : message.body != null && message.body!.isNotEmpty == true
                        ? Flexible(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                  15.0, 10.0, 15.0, 10.0),
                              decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(8.0)),
                              margin: const EdgeInsets.only(left: 10.0),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.body!,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    getDateWidget(),
                                  ]),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.fromLTRB(
                                15.0, 10.0, 15.0, 10.0),
                            width: 200.0,
                            decoration: BoxDecoration(
                                color: greyColor2,
                                borderRadius: BorderRadius.circular(8.0)),
                            margin: EdgeInsets.only(
                                bottom: isLastMessageRight(index) ? 20.0 : 10.0,
                                right: 10.0),
                            child: const Text(
                              "Empty",
                              style: TextStyle(color: primaryColor),
                            ),
                          ),
              ],
            ),
          ],
        ),
      );
    }
  }

  bool isLastMessageLeft(int index) {
    if ((index > 0 &&
            listMessage != null &&
            listMessage![index - 1].id == _cubeUser.id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool isLastMessageRight(int index) {
    if ((index > 0 &&
            listMessage != null &&
            listMessage![index - 1].id != _cubeUser.id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Widget buildLoading() {
    return Positioned(
      child: isLoading ? const Loading() : Container(),
    );
  }

  Widget buildTyping() {
    return Visibility(
      visible: isTyping,
      child: Container(
        alignment: Alignment.centerLeft,
        margin: const EdgeInsets.all(16.0),
        child: Text(
          userStatus,
          style: const TextStyle(color: primaryColor),
        ),
      ),
    );
  }

  Widget buildInput() {
    return Container(
      width: double.infinity,
      height: 50.0,
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: greyColor2, width: 0.5)),
          color: Colors.white),
      child: Row(
        children: <Widget>[
          // Button send image
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              child: IconButton(
                icon: const Icon(Icons.image),
                onPressed: () {
                  openGallery();
                },
                color: primaryColor,
              ),
            ),
          ),

          // Edit text
          Flexible(
            child: Container(
              child: TextField(
                style: const TextStyle(color: primaryColor, fontSize: 15.0),
                controller: textEditingController,
                decoration: const InputDecoration.collapsed(
                  hintText: 'メッセージを書いてください...',
                  hintStyle: TextStyle(color: greyColor),
                ),
                onChanged: (text) {
                  _cubeDialog.sendIsTypingStatus();
                },
              ),
            ),
          ),

          // Button send message
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => onSendChatMessage(textEditingController.text),
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildListMessage() {
    getWidgetMessages(listMessage) {
      return ListView.builder(
        padding: const EdgeInsets.all(10.0),
        itemBuilder: (context, index) => buildItem(index, listMessage[index]),
        itemCount: listMessage.length,
        reverse: true,
        controller: listScrollController,
      );
    }

    if (listMessage != null && listMessage!.isNotEmpty) {
      return Flexible(child: getWidgetMessages(listMessage));
    }

    return Flexible(
      child: StreamBuilder(
        stream: getAllItems().asStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor)));
          } else {
            listMessage = snapshot.data as List<CubeMessage>;
            return getWidgetMessages(listMessage);
          }
        },
      ),
    );
  }

  Future<List<CubeMessage>> getAllItems() async {
    Completer<List<CubeMessage>> completer = Completer();
    List<CubeMessage>? messages;
    var params = GetMessagesParameters();
    params.sorter = RequestSorter(SORT_DESC, '', 'date_sent');
    try {
      final int numberTest = _cubeDialog.occupantsIds!.length;
      List<int>? tempList = [...?_cubeDialog.occupantsIds];
      // for (var i = 0; i < numberTest; i++) {
      // await Future.wait<void>([

      //   getMessages(_cubeDialog.dialogId!, params.getRequestParameters())
      //       .then((result) => messages = result!.items),
      //   //   getAllUsersByIds(tempList.toSet()).then((result) => _occupants
      //   //       .addAll({for (var item in result!.items) item.id: item}))
      //   // ]);
      //   // tempList.removeAt(0);
      //   getAllUsersByIds(_cubeDialog.occupantsIds!.toSet()).then((result) =>
      //       _occupants.addAll(Map.fromIterable(result!.items,
      //           key: (item) => item.id, value: (item) => item)))
      // ]);
      // }
      await Future.wait<void>([
        getMessages(_cubeDialog.dialogId!, params.getRequestParameters())
            .then((result) => messages = result!.items),
        getAllUsersByIds(_cubeDialog.occupantsIds!.toSet()).then((result) =>
            _occupants.addAll(Map.fromIterable(result!.items,
                key: (item) => item.id, value: (item) => item)))
      ]);
      completer.complete(messages);
    } catch (error) {
      completer.completeError(error);
    }
    return completer.future;
  }

  Future<bool> onBackPress() {
    Navigator.pushNamedAndRemoveUntil(context, 'select_dialog', (r) => false,
        arguments: {USER_ARG_NAME: _cubeUser});

    return Future.value(false);
  }

  _initChatListeners() {
    msgSubscription = CubeChatConnection
        .instance.chatMessagesManager!.chatMessagesStream
        .listen(onReceiveMessage);
    deliveredSubscription = CubeChatConnection
        .instance.messagesStatusesManager!.deliveredStream
        .listen(onDeliveredMessage);
    readSubscription = CubeChatConnection
        .instance.messagesStatusesManager!.readStream
        .listen(onReadMessage);
    typingSubscription = CubeChatConnection
        .instance.typingStatusesManager!.isTypingStream
        .listen(onTypingMessage);
  }

  void _initCubeChat() {
    log("_initCubeChat");
    if (CubeChatConnection.instance.isAuthenticated()) {
      log("[_initCubeChat] isAuthenticated");
      _initChatListeners();
    } else {
      log("[_initCubeChat] not authenticated");
      CubeChatConnection.instance.connectionStateStream.listen((state) {
        log("[_initCubeChat] state $state");
        if (CubeChatConnectionState.Ready == state) {
          _initChatListeners();

          if (_unreadMessages.isNotEmpty) {
            for (var cubeMessage in _unreadMessages) {
              _cubeDialog.readMessage(cubeMessage);
            }
            _unreadMessages.clear();
          }

          if (_unsentMessages.isNotEmpty) {
            for (var cubeMessage in _unsentMessages) {
              _cubeDialog.sendMessage(cubeMessage);
            }

            _unsentMessages.clear();
          }
        }
      });
    }
  }

  void voiceCallFunc() {
    onSendChatMessage("");
  }

  // Future<void> _prepareSaveDir() async {
  //   _localPath = (await _findLocalPath())!;
  //   final savedDir = Directory(_localPath);
  //   bool hasExisted = await savedDir.exists();
  //   if (!hasExisted) {
  //     savedDir.create();
  //   }
  // }

  // Future<String?> _findLocalPath() async {
  //   var externalStorageDirPath;
  //   if (Platform.isAndroid) {
  //     try {
  //       externalStorageDirPath = await AndroidPathProvider.downloadsPath;
  //     } catch (e) {
  //       final directory = await getExternalStorageDirectory();
  //       externalStorageDirPath = directory?.path;
  //     }
  //   }
  //   return externalStorageDirPath;
  // }
}
