import 'package:flutter/material.dart';

import 'app/app.dart';

void main() {
  // Firebase and the shared-preferences read behind the notification
  // permission flag both touch platform channels during startup, which needs
  // the binding up before `runApp`.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OneOrgStaffApp());
}
