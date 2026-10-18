// Portions derived from FlClash (https://github.com/chen08209/FlClash), Copyright (c) the FlClash authors, GPL-3.0-or-later.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

SingleActivator controlSingleActivator(LogicalKeyboardKey trigger) {
  final control = Platform.isMacOS ? false : true;
  return SingleActivator(trigger, control: control, meta: !control);
}
