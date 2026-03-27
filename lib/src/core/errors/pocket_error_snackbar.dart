import 'package:flutter/material.dart';

import 'pocket_error.dart';

void showPocketErrorSnackBar(
  BuildContext context,
  PocketUserFacingError error,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.inlineMessage)));
}
