import 'package:atc_chat_3ver/src/managers/call_manager.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class IncomingCallScreen extends StatefulWidget {
  static const String TAG = "IncomingCallScreen";
  final P2PSession _callSession;
  static late String name;
  const IncomingCallScreen(this._callSession);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  initState() {
    IncomingCallScreen.name =
        widget._callSession.cubeSdp.userInfo!.values.first;
  }

  @override
  Widget build(BuildContext context) {
    widget._callSession.onSessionClosed = (callSession) {
      log("_onSessionClosed", IncomingCallScreen.TAG);
      Navigator.pop(context);
    };

    return WillPopScope(
        onWillPop: () => _onBackPressed(context),
        child: Scaffold(
            body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(36),
                child:
                    Text(_getCallTitle(), style: const TextStyle(fontSize: 28)),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 36, bottom: 8),
                child: Text("メンバー:", style: TextStyle(fontSize: 20)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 86),
                //_callSession.opponentsIds.join(", ")
                child: Text(widget._callSession.cubeSdp.userInfo!.values.first,
                    style: const TextStyle(fontSize: 18)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: FloatingActionButton(
                      heroTag: "拒否する",
                      backgroundColor: Colors.red,
                      onPressed: () =>
                          _rejectCall(context, widget._callSession),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: FloatingActionButton(
                      heroTag: "応答する",
                      backgroundColor: Colors.green,
                      onPressed: () =>
                          _acceptCall(context, widget._callSession),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )));
  }

  _getCallTitle() {
    String callType;

    switch (widget._callSession.callType) {
      case CallType.VIDEO_CALL:
        callType = "Video";
        break;
      case CallType.AUDIO_CALL:
        callType = "Audio";
        break;
    }

    return "Incoming ${widget._callSession.callType} call";
  }

  void _acceptCall(BuildContext context, P2PSession callSession) {
    CallManager.instance.acceptCall(callSession.sessionId);
  }

  void _rejectCall(BuildContext context, P2PSession callSession) {
    CallManager.instance.reject(callSession.sessionId);
  }

  Future<bool> _onBackPressed(BuildContext context) {
    return Future.value(false);
  }
}
