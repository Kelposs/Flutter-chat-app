import 'dart:async';

import 'package:atc_chat_3ver/src/add_occupant_screen.dart';
import 'package:atc_chat_3ver/src/utils/api_utils.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/widgets/common.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class ChatDetailsScreen extends StatelessWidget {
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  const ChatDetailsScreen(this._cubeUser, this._cubeDialog);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _cubeDialog.type == CubeDialogType.PRIVATE ? "連絡先の詳細" : "グループの詳細",
          ),
          centerTitle: false,
          actions: const <Widget>[],
        ),
        body: DetailScreen(_cubeUser, _cubeDialog),
      ),
    );
  }

  Future<bool> _onBackPressed(BuildContext context) {
    Navigator.pop(context);
    return Future.value(false);
  }
}

class DetailScreen extends StatefulWidget {
  static const String TAG = "DetailScreen";
  final CubeUser _cubeUser;
  final CubeDialog _cubeDialog;

  const DetailScreen(this._cubeUser, this._cubeDialog);

  @override
  State createState() => _cubeDialog.type == CubeDialogType.PRIVATE
      ? ContactScreenState(_cubeUser, _cubeDialog)
      : GroupScreenState(_cubeUser, _cubeDialog);
}

abstract class ScreenState extends State<DetailScreen> {
  final CubeUser _cubeUser;
  CubeDialog _cubeDialog;
  final Map<int, CubeUser> _occupants = {};
  var _isProgressContinues = false;
  final Map<int, CubeUser> result2 = {};

  ScreenState(this._cubeUser, this._cubeDialog);

  @override
  void initState() {
    super.initState();
    if (_occupants.isEmpty) {
      initUsers();
    }
  }

  initUsers() async {
    _isProgressContinues = true;
    if (_cubeDialog.occupantsIds == null || _cubeDialog.occupantsIds!.isEmpty) {
      setState(() {
        _isProgressContinues = false;
      });
      return;
    }
    final temp = [...?_cubeDialog.occupantsIds];
    final int number = _cubeDialog.occupantsIds!.length;

    print("xxx${await getUsersByIds(temp.toSet())}");

    // for (var i = 0; i < number; i++) {
    //   /////////////////////////////tutaj zmienc
    //   var result = await getUsersByIds(temp.toSet());
    //   result2.addAll(result);
    //   temp.removeAt(0);
    // }
    var result = await getUsersByIds(temp.toSet());
    result2.addAll(result);
    _occupants.clear();
    _occupants.addAll(result2);
    _occupants.remove(_cubeUser.id);
    setState(() {
      _isProgressContinues = false;
    });
  }
}

class ContactScreenState extends ScreenState {
  CubeUser? contactUser;

  initUser() {
    contactUser = _occupants.values.isNotEmpty
        ? _occupants.values.first
        : CubeUser(fullName: "Absent");
  }

  ContactScreenState(_cubeUser, _cubeDialog) : super(_cubeUser, _cubeDialog);

  @override
  Widget build(BuildContext context) {
    initUser();
    return Scaffold(
      body: Container(
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
                  visible: _isProgressContinues,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ],
          )),
    );
  }

  Widget _buildAvatarFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: <Widget>[
        CircleAvatar(
          backgroundImage:
              contactUser!.avatar != null && contactUser!.avatar!.isNotEmpty
                  ? NetworkImage(contactUser!.avatar!)
                  : null,
          backgroundColor: greyColor2,
          radius: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(55),
            child: Text(
              contactUser!.fullName!.substring(0, 2).toUpperCase(),
              style: const TextStyle(fontSize: 40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.all(50),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(
              right: 10, left: 10,
              bottom: 3, // space between underline and text
            ),
            decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
              color: primaryColor, // Text colour here
              width: 1.0, // Underline width
            ))),
            child: Text(
              contactUser!.fullName!,
              style: const TextStyle(
                color: primaryColor,
                fontSize: 20, // Text colour here
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildButtons() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Container(
      child: Column(
        children: <Widget>[
          ElevatedButton(
            child: const Text(
              'チャット開始',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20, // Text colour here
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class GroupScreenState extends ScreenState {
  final TextEditingController _nameFilter = TextEditingController();
  String? _photoUrl = "";
  String _name = "";
  final Set<int?> _usersToRemove = {};
  List<int>? _usersToAdd;

  GroupScreenState(_cubeUser, _cubeDialog) : super(_cubeUser, _cubeDialog) {
    _nameFilter.addListener(_nameListen);
    _nameFilter.text = _cubeDialog.name;
    clearFields();
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
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                _buildPhotoFields(),
                _buildTextFields(),
                _buildGroupFields(),
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: Visibility(
                    maintainSize: false,
                    maintainAnimation: false,
                    maintainState: false,
                    visible: _isProgressContinues,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ],
            )),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "チャットアップデート",
        backgroundColor: Colors.blue,
        onPressed: () => _updateDialog(),
        child: const Icon(
          Icons.check,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPhotoFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    Widget avatarCircle = CircleAvatar(
      backgroundImage:
          _cubeDialog.photo != null && _cubeDialog.photo!.isNotEmpty
              ? NetworkImage(_cubeDialog.photo!)
              : null,
      backgroundColor: greyColor2,
      radius: 50,
      child: getAvatarTextWidget(
          _cubeDialog.photo != null && _cubeDialog.photo!.isNotEmpty,
          _cubeDialog.name!.substring(0, 2).toUpperCase()),
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
      _photoUrl = cubeFile.getPublicUrl();
      setState(() {
        _cubeDialog.photo = _photoUrl;
      });
    }).catchError((error) {
      _processUpdateError(error);
    });
  }

  Widget _buildTextFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Container(
            child: TextField(
              style: const TextStyle(color: primaryColor, fontSize: 20.0),
              controller: _nameFilter,
              decoration: const InputDecoration(labelText: 'グループ名変更'),
            ),
          ),
        ],
      ),
    );
  }

  _buildGroupFields() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        _addMemberBtn(),
        _removeMemberBtn(),
        _getUsersList(),
        _exitGroupBtn(),
      ],
    );
  }

  Widget _addMemberBtn() {
    return Container(
      padding: const EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: greyColor, // Text colour here
        width: 1.0, // Underline width
      ))),
      child: InkWell(
        splashColor: greyColor2,
        borderRadius: BorderRadius.circular(45),
        onTap: () => _addOpponent(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: const <Widget>[
            Icon(
              Icons.person_add,
              size: 35.0,
              color: blueColor,
            ),
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                'メンバー追加',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 20, // Text colour here
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _removeMemberBtn() {
    if (_usersToRemove.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: greyColor, // Text colour here
        width: 1.0, // Underline width
      ))),
      child: InkWell(
        splashColor: greyColor2,
        borderRadius: BorderRadius.circular(45),
        onTap: () => _removeOpponent(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: const <Widget>[
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.person_outline,
                size: 35.0,
                color: blueColor,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'メンバー削除',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 20, // Text colour here
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getUsersList() {
    if (_isProgressContinues) {
      return const SizedBox.shrink();
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      primary: false,
      itemCount: _occupants.length,
      itemBuilder: _getListItemTile,
      separatorBuilder: (context, index) {
        return const Divider(thickness: 2, indent: 20, endIndent: 20);
      },
    );
  }

  Widget _getListItemTile(BuildContext context, int index) {
    final user = _occupants.values.elementAt(index);
    Widget getUserAvatar() {
      if (user.avatar != null && user.avatar!.isNotEmpty) {
        return CircleAvatar(
          backgroundImage: NetworkImage(user.avatar!),
          backgroundColor: greyColor2,
          radius: 25.0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(55),
          ),
        );
      } else {
        return const Material(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
          clipBehavior: Clip.hardEdge,
          child: Icon(
            Icons.account_circle,
            size: 50.0,
            color: greyColor,
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      child: TextButton(
        child: Row(
          children: <Widget>[
            getUserAvatar(),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 20.0),
                child: Column(
                  children: <Widget>[
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.fromLTRB(10.0, 0.0, 0.0, 5.0),
                      child: Text(
                        '${user.fullName}',
                        style: const TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              child: Checkbox(
                value: _usersToRemove
                    .contains(_occupants.values.elementAt(index).id),
                onChanged: ((checked) {
                  setState(() {
                    if (checked!) {
                      _usersToRemove.add(_occupants.values.elementAt(index).id);
                    } else {
                      _usersToRemove
                          .remove(_occupants.values.elementAt(index).id);
                    }
                  });
                }),
              ),
            ),
          ],
        ),
        onPressed: () {
          log("user onPressed");
        },
      ),
    );
  }

  Widget _exitGroupBtn() {
    return Container(
      padding: const EdgeInsets.only(
        bottom: 3, // space between underline and text
      ),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(
        color: greyColor, // Text colour here
        width: 1.0, // Underline width
      ))),
      child: InkWell(
        splashColor: greyColor2,
        borderRadius: BorderRadius.circular(45),
        onTap: () => _exitDialog(),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: const <Widget>[
            Icon(
              Icons.exit_to_app,
              size: 35.0,
              color: blueColor,
            ),
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                'グループ退会',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 20, // Text colour here
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processUpdateError(exception) {
    log("_processUpdateUserError error $exception");
    setState(() {
      clearFields();
      _isProgressContinues = false;
    });
    showDialogError(exception, context);
  }

  _addOpponent() async {
    print('_addOpponent');
    _usersToAdd = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddOccupantScreen(_cubeUser),
      ),
    );
    if (_usersToAdd != null && _usersToAdd!.isNotEmpty) _updateDialog();
  }

  _removeOpponent() async {
    print('_removeOpponent');
    if (_usersToRemove.isNotEmpty) _updateDialog();
  }

  _exitDialog() {
    print('_exitDialog');
    deleteDialog(_cubeDialog.dialogId!).then((onValue) {
      Fluttertoast.showToast(msg: 'Success');
      Navigator.pushReplacementNamed(context, 'select_dialog',
          arguments: {USER_ARG_NAME: _cubeUser});
    }).catchError((error) {
      _processUpdateError(error);
    });
  }

  void _updateDialog() {
    print('_updateDialog $_name');
    if (_name.isEmpty &&
        _photoUrl!.isEmpty &&
        (_usersToAdd?.isEmpty ?? true) &&
        (_usersToRemove.isEmpty)) {
      Fluttertoast.showToast(msg: 'Nothing to save');
      return;
    }
    Map<String, dynamic> params = {};
    if (_name.isNotEmpty) params['name'] = _name;
    if (_photoUrl!.isNotEmpty) params['photo'] = _photoUrl;
    if (_usersToAdd?.isNotEmpty ?? false) {
      params['push_all'] = {'occupants_ids': List.of(_usersToAdd!)};
    }
    if (_usersToRemove.isNotEmpty) {
      params['pull_all'] = {'occupants_ids': List.of(_usersToRemove)};
    }

    setState(() {
      _isProgressContinues = true;
    });
    updateDialog(_cubeDialog.dialogId!, params).then((dialog) {
      _cubeDialog = dialog;
      Fluttertoast.showToast(msg: 'Success');
      setState(() {
        if ((_usersToAdd?.isNotEmpty ?? false) || (_usersToRemove.isNotEmpty)) {
          initUsers();
        }
        _isProgressContinues = false;
        clearFields();
      });
    }).catchError((error) {
      _processUpdateError(error);
    });
  }

  clearFields() {
    _name = '';
    _photoUrl = '';
    _usersToAdd = null;
    _usersToRemove.clear();
  }
}
