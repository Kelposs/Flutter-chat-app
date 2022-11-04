import 'package:atc_chat_3ver/src/chat_dialog_screen.dart';
import 'package:atc_chat_3ver/src/new_group_dialog_screen.dart';
import 'package:atc_chat_3ver/src/utils/api_utils.dart';
import 'package:atc_chat_3ver/src/utils/consts.dart';
import 'package:atc_chat_3ver/src/widgets/common.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_chat.dart';

class CreateChatScreen extends StatefulWidget {
  final CubeUser _cubeUser;

  @override
  State<StatefulWidget> createState() {
    return _CreateChatScreenState(_cubeUser);
  }

  const CreateChatScreen(this._cubeUser);
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  static const String TAG = "_CreateChatScreenState";
  final CubeUser currentUser;

  _CreateChatScreenState(this.currentUser);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(context),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text(
            'ユーザー名： ${currentUser.fullName}',
          ),
        ),
        body: BodyLayout(currentUser),
      ),
    );
  }

  Future<bool> _onBackPressed(BuildContext context) {
    Navigator.pop(context);
    return Future.value(false);
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
  List<CubeUser> userList = [];
  List<CubeUser> userSetList = []; //my app
  final Set<int> _selectedUsers = {};
  var _isUsersContinues = false;
  var _isPrivateDialog = true;
  String? userToSearch;
  String userMsg = " ";

  _BodyLayoutState(this.currentUser);

  _searchUser(value) {
    log("searchUser _user= $value");
    if (value != null) {
      setState(() {
        userToSearch = value;
        _isUsersContinues = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            children: [
              _buildTextFields(),
              _buildDialogButton(),
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
              Expanded(
                child: _getUsersList(context),
              ),
            ],
          )),
      floatingActionButton: Visibility(
        visible: !_isPrivateDialog,
        child: FloatingActionButton(
          heroTag: "新しいチャット",
          backgroundColor: Colors.blue,
          onPressed: () => _createDialog(context, _selectedUsers, true),
          child: const Icon(
            Icons.check,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTextFields() {
    return Container(
      child: Column(
        children: <Widget>[
          Container(
            child: TextField(
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(labelText: 'ユーザ検索'),
                onSubmitted: (value) {
                  _searchUser(value.trim());
                }),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogButton() {
    getIcon() {
      if (_isPrivateDialog) {
        return Icons.person;
      } else {
        return Icons.people;
      }
    }

    getDescription() {
      if (_isPrivateDialog) {
        return "グループチャット作成";
      } else {
        return "プライベートチャット作成";
      }
    }

    return Container(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: Icon(
          getIcon(),
          size: 25.0,
          color: themeColor,
        ),
        onPressed: () {
          setState(() {
            _isPrivateDialog = !_isPrivateDialog;
          });
        },
        label: Text(getDescription()),
      ),
    );
  }

  Widget _getUsersList(BuildContext context) {
    clearValues() {
      _isUsersContinues = false;
      userToSearch = null;
      userMsg = " ";
      userList.clear();
    }

    if (_isUsersContinues) {
      if (userToSearch != null && userToSearch!.isNotEmpty) {
        getUsersByFullName(userToSearch!).then((users) {
          log("getusers: $users", TAG);
          setState(() {
            clearValues();
            userList.addAll(users!.items);
            userSetList.addAll(users.items); //zmiana wykrzynik
            userSetList.toSet().toList(); //aaasaa
          });
        }).catchError((onError) {
          log("getusers catchError: $onError", TAG);
          setState(() {
            clearValues();
            userMsg = "Couldn't find user";
          });
        });
      }
    }
    if (userList.isEmpty) {
      return FittedBox(
        fit: BoxFit.contain,
        child: Text(userMsg),
      );
    } else {
      return ListView.builder(
        itemCount: userList.length,
        itemBuilder: _getListItemTile,
      );
    }
  }

  Widget _getListItemTile(BuildContext context, int index) {
    getPrivateWidget() {
      return Container(
        margin: const EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
        child: TextButton(
          child: Row(
            children: <Widget>[
              Material(
                borderRadius: const BorderRadius.all(
                  Radius.circular(40.0),
                ),
                clipBehavior: Clip.hardEdge,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    backgroundImage: userList[index].avatar != null &&
                            userList[index].avatar!.isNotEmpty
                        ? NetworkImage(userList[index].avatar!)
                        : null,
                    radius: 25,
                    child: getAvatarTextWidget(
                        userList[index].avatar != null &&
                            userList[index].avatar!.isNotEmpty,
                        userList[index]
                            .fullName!
                            .substring(0, 2)
                            .toUpperCase()),
                  ),
                ),
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
                          '${userList[index].fullName}',
                          style: const TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                child: const Icon(
                  Icons.arrow_forward,
                  size: 25.0,
                  color: themeColor,
                ),
              ),
            ],
          ),
          onPressed: () {
            _createDialog(context, {userList[index].id!}, false);
          },
        ),
      );
    }

    getGroupWidget() {
      return Container(
        margin: const EdgeInsets.only(bottom: 10.0, left: 5.0, right: 5.0),
        child: TextButton(
          child: Row(
            children: <Widget>[
              Material(
                borderRadius: const BorderRadius.all(
                  Radius.circular(40.0),
                ),
                clipBehavior: Clip.hardEdge,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    backgroundImage: userList[index].avatar != null &&
                            userList[index].avatar!.isNotEmpty
                        ? NetworkImage(userList[index].avatar!)
                        : null,
                    radius: 25,
                    child: getAvatarTextWidget(
                        userList[index].avatar != null &&
                            userList[index].avatar!.isNotEmpty,
                        userList[index]
                            .fullName!
                            .substring(0, 2)
                            .toUpperCase()),
                  ),
                ),
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
                          '${userList[index].fullName}',
                          style: const TextStyle(color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                child: Checkbox(
                  value: _selectedUsers.contains(userList[index].id),
                  onChanged: ((checked) {
                    setState(() {
                      if (checked!) {
                        _selectedUsers.add(userList[index].id!);
                      } else {
                        _selectedUsers.remove(userList[index].id);
                      }
                    });
                  }),
                ),
              ),
            ],
          ),
          onPressed: () {
            setState(() {
              if (_selectedUsers.contains(userList[index].id)) {
                _selectedUsers.remove(userList[index].id);
              } else {
                _selectedUsers.add(userList[index].id!);
              }
            });
          },
        ),
      );
    }

    getItemWidget() {
      if (_isPrivateDialog) {
        return getPrivateWidget();
      } else {
        return getGroupWidget();
      }
    }

    return getItemWidget();
  }

  void _createDialog(BuildContext context, Set<int> users, bool isGroup) async {
    log("_createDialog with users= $users");
    if (isGroup) {
      CubeDialog newDialog =
          CubeDialog(CubeDialogType.GROUP, occupantsIds: users.toList());
      List<CubeUser> usersToAdd = users
          .map((id) => userSetList.firstWhere((user) => user.id == id))
          .toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              NewGroupDialogScreen(currentUser, newDialog, usersToAdd),
        ),
      );
    } else {
      CubeDialog newDialog =
          CubeDialog(CubeDialogType.PRIVATE, occupantsIds: users.toList());
      createDialog(newDialog).then((createdDialog) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDialogScreen(currentUser, createdDialog),
          ),
        );
      }).catchError((error) {
        _processCreateDialogError(error);
      });
    }
  }

  void _processCreateDialogError(exception) {
    log("Login error $exception", TAG);
    showDialogError(exception, context);
  }

  @override
  void initState() {
    super.initState();
    log("initState");
  }
}
