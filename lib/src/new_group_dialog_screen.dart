import 'dart:typed_data';

import 'package:atc_chat_3ver/src/chat_dialog_screen.dart';
import 'package:atc_chat_3ver/src/utils/api_utils.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/widgets/common.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class NewGroupDialogScreen extends StatelessWidget {
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser> users;

  const NewGroupDialogScreen(this.currentUser, this._cubeDialog, this.users);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'New Group',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: NewChatScreen(currentUser, _cubeDialog, users),
        resizeToAvoidBottomInset: false);
  }
}

class NewChatScreen extends StatefulWidget {
  static const String TAG = "_CreateChatScreenState";
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser?> users;

  const NewChatScreen(this.currentUser, this._cubeDialog, this.users);

  @override
  State createState() => NewChatScreenState(currentUser, _cubeDialog, users);
}

class NewChatScreenState extends State<NewChatScreen> {
  static const String TAG = "NewChatScreenState";
  final CubeUser currentUser;
  final CubeDialog _cubeDialog;
  final List<CubeUser?> users;
  final TextEditingController _nameFilter = TextEditingController();

  Uint8List? _image;

  NewChatScreenState(this.currentUser, this._cubeDialog, this.users);

  @override
  void initState() {
    super.initState();
    _nameFilter.addListener(_nameListener);
  }

  void _nameListener() {
    if (_nameFilter.text.length > 4) {
      log("_createDialogImage text= ${_nameFilter.text.trim()}");
      _cubeDialog.name = _nameFilter.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGroupFields(),
                _buildDialogOccupants(),
              ],
            )),
        floatingActionButton: FloatingActionButton(
          heroTag: "新しいチャット",
          backgroundColor: Colors.blue,
          onPressed: () => _createDialog(),
          child: const Icon(
            Icons.check,
            color: Colors.white,
          ),
        ),
        resizeToAvoidBottomInset: false);
  }

  _buildGroupFields() {
    getIcon() {
      if (_image == null) {
        return const Icon(
          Icons.photo_camera,
          size: 45.0,
          color: blueColor,
        );
      } else {
        return Image.memory(_image!, width: 45.0, height: 45.0);
      }
    }

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            RawMaterialButton(
              onPressed: () => _createDialogImage(),
              elevation: 2.0,
              fillColor: Colors.white,
              padding: const EdgeInsets.all(10.0),
              shape: const CircleBorder(),
              child: getIcon(),
            ),
            Flexible(
              child: TextField(
                controller: _nameFilter,
                decoration: const InputDecoration(labelText: 'グループ名...'),
              ),
            )
          ],
        ),
        Container(
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.all(16.0),
          child: const Text(
            'グループ名を書いてください',
            style: TextStyle(color: primaryColor),
          ),
        ),
      ],
    );
  }

  _createDialogImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null) return;

    Uint8List? image;

    if (kIsWeb) {
      image = result.files.single.bytes;
    } else {
      image = File(result.files.single.path!).readAsBytesSync();
    }

    var uploadImageFuture = getUploadingImageFuture(result);

    uploadImageFuture.then((cubeFile) {
      _image = image;
      var url = cubeFile.getPublicUrl();
      log("_createDialogImage url= $url");
      setState(() {
        _cubeDialog.photo = url;
      });
    }).catchError((exception) {
      _processDialogError(exception);
    });
  }

  _buildDialogOccupants() {
    _getListItemTile(BuildContext context, int index) {
      return Container(
        child: Column(
          children: <Widget>[
            Material(
              borderRadius: const BorderRadius.all(Radius.circular(25.0)),
              clipBehavior: Clip.hardEdge,
              child: CircleAvatar(
                backgroundImage: users[index]!.avatar != null &&
                        users[index]!.avatar!.isNotEmpty
                    ? NetworkImage(users[index]!.avatar!)
                    : null,
                radius: 25,
                child: getAvatarTextWidget(
                    users[index]!.avatar != null &&
                        users[index]!.avatar!.isNotEmpty,
                    users[index]!.fullName!.substring(0, 2).toUpperCase()),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(0.0, 10.0, 0.0, 10.0),
              child: Column(
                children: <Widget>[
                  Container(
                    width: MediaQuery.of(context).size.width / 4,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 5.0),
                    child: Text(
                      users[index]!.fullName!,
                      style: const TextStyle(color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    _getOccupants() {
      return ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        scrollDirection: Axis.horizontal,
        itemCount: _cubeDialog.occupantsIds!.length,
        itemBuilder: _getListItemTile,
      );
    }

    return Container(
      child: Expanded(
        child: _getOccupants(),
      ),
    );
  }

  void _processDialogError(exception) {
    log("error $exception", TAG);
    showDialogError(exception, context);
  }

  Future<bool> onBackPress() {
    Navigator.pop(context);
    return Future.value(false);
  }

  _createDialog() {
    log("_createDialog _cubeDialog= $_cubeDialog");
    if (_cubeDialog.name == null || _cubeDialog.name!.length < 5) {
      showDialogMsg("Enter more than 4 character", context);
    } else {
      createDialog(_cubeDialog).then((createdDialog) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDialogScreen(currentUser, createdDialog),
          ),
        );
      }).catchError((exception) {
        _processDialogError(exception);
      });
    }
  }
}
