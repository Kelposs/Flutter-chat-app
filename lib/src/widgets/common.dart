import 'package:connectycube_sdk/connectycube_core.dart';
import 'package:flutter/cupertino.dart';

Widget getAvatarTextWidget(bool condition, String? text) {
  if (condition) {
    return const SizedBox.shrink();
  } else {
    return ClipRRect(
      borderRadius: BorderRadius.circular(55),
      child: Text(
        isEmpty(text) ? '?' : text!,
        style: const TextStyle(fontSize: 30),
      ),
    );
  }
}
