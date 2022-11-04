import 'package:atc_chat_3ver/src/push_notifications_manager.dart';
import 'package:atc_chat_3ver/src/utils/api_utils.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/utils/pref_util.dart';
import 'package:atc_chat_3ver/src/widgets/common.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class SettingsScreen extends StatelessWidget {
  final CubeUser? currentUser;

  const SettingsScreen(this.currentUser);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            '設定',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
        ),
        body: BodyLayout(currentUser),
        resizeToAvoidBottomInset: false);
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser? currentUser;

  const BodyLayout(this.currentUser);

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(currentUser);
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String TAG = "_BodyLayoutState";

  final CubeUser? currentUser;
  var _isUsersContinues = false;
  String? _avatarUrl = "";
  final TextEditingController _loginFilter = TextEditingController();
  final TextEditingController _nameFilter = TextEditingController();
  String _login = "";
  String _name = "";

  _BodyLayoutState(this.currentUser) {
    _loginFilter.addListener(_loginListen);
    _nameFilter.addListener(_nameListen);
    _nameFilter.text = currentUser!.fullName!;
    _loginFilter.text = currentUser!.login!;
  }

  _searchUser(value) {
    log("searchUser _user= $value");
    if (value != null) {
      setState(() {
        _isUsersContinues = true;
      });
    }
  }

  void _loginListen() {
    if (_loginFilter.text.isEmpty) {
      _login = "";
    } else {
      _login = _loginFilter.text.trim();
    }
  }

  void _nameListen() {
    if (_nameFilter.text.isEmpty) {
      _name = "";
    } else {
      _name = _nameFilter.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(60),
            child: Column(
              children: [
                _buildAvatarFields(),
                _buildTextFields(),
                _buildButtons(),
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Visibility(
                    maintainSize: false,
                    maintainAnimation: false,
                    maintainState: false,
                    visible: _isUsersContinues,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  Widget _buildAvatarFields() {
    Widget avatarCircle = CircleAvatar(
      backgroundImage:
          currentUser!.avatar != null && currentUser!.avatar!.isNotEmpty
              ? NetworkImage(currentUser!.avatar!)
              : null,
      backgroundColor: greyColor2,
      radius: 50,
      child: getAvatarTextWidget(
        currentUser!.avatar != null && currentUser!.avatar!.isNotEmpty,
        currentUser!.fullName!.substring(0, 2).toUpperCase(),
      ),
    );

    return Stack(
      children: <Widget>[
        InkWell(
          splashColor: greyColor2,
          borderRadius: BorderRadius.circular(45),
          onTap: () => _chooseUserImage(),
          child: avatarCircle,
        ),
        Positioned(
          top: 55.0,
          right: 35.0,
          child: RawMaterialButton(
            onPressed: () {
              _chooseUserImage();
            },
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(5.0),
            shape: const CircleBorder(),
            child: const Icon(
              Icons.mode_edit,
              size: 20.0,
            ),
          ),
        ),
      ],
    );
  }

  _chooseUserImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null) return;

    var uploadImageFuture = getUploadingImageFuture(result);

    uploadImageFuture.then((cubeFile) {
      _avatarUrl = cubeFile.getPublicUrl();
      setState(() {
        currentUser!.avatar = _avatarUrl;
      });
    }).catchError((exception) {
      _processUpdateUserError(exception);
    });
  }

  Widget _buildTextFields() {
    return Container(
      child: Column(
        children: <Widget>[
          Container(
            child: TextField(
              controller: _nameFilter,
              decoration: const InputDecoration(labelText: '名前変更'),
            ),
          ),
          Container(
            child: TextField(
              controller: _loginFilter,
              decoration: const InputDecoration(labelText: 'ログイン変更'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Container(
      child: Column(
        children: <Widget>[
          TextButton(
            onPressed: _updateUser,
            child: const Text('保存'),
          ),
          TextButton(
            onPressed: _logout,
            child: const Text('ログアウト'),
          )
        ],
      ),
    );
  }

  void _updateUser() {
    print('_updateUser user with $_login and $_name');
    if (_login.isEmpty && _name.isEmpty && _avatarUrl!.isEmpty) {
      Fluttertoast.showToast(msg: 'Nothing to save');
      return;
    }
    var userToUpdate = CubeUser()..id = currentUser!.id;

    if (_name.isNotEmpty) userToUpdate.fullName = _name;
    if (_login.isNotEmpty) userToUpdate.login = _login;
    if (_avatarUrl!.isNotEmpty) userToUpdate.avatar = _avatarUrl;
    setState(() {
      _isUsersContinues = true;
    });
    updateUser(userToUpdate).then((user) {
      SharedPrefs.instance.updateUser(user);
      Fluttertoast.showToast(msg: 'Success');
      setState(() {
        _isUsersContinues = false;
      });
    }).catchError((exception) {
      _processUpdateUserError(exception);
    });
  }

  void _logout() {
    print('_logout $_login and $_name');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("ログアウト"),
          content: const Text("現在のユーザーをログアウトしてもよろしいですか？"),
          actions: <Widget>[
            TextButton(
              child: const Text("キャンセル"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                signOut().then(
                  (voidValue) {
                    Navigator.pop(context); // cancel current Dialog
                  },
                ).catchError(
                  (onError) {
                    Navigator.pop(context); // cancel current Dialog
                  },
                ).whenComplete(() {
                  CubeChatConnection.instance.destroy();
                  PushNotificationsManager.instance.unsubscribe();
                  SharedPrefs.instance.deleteUser();
                  Navigator.pop(context); // cancel current screen
                  _navigateToLoginScreen(context);
                });
              },
            ),
          ],
        );
      },
    );
  }

  _navigateToLoginScreen(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, 'login', (route) => false);
  }

  void _processUpdateUserError(exception) {
    log("_processUpdateUserError error $exception", TAG);
    setState(() {
      _isUsersContinues = false;
    });
    showDialogError(exception, context);
  }
}
