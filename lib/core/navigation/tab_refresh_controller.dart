import 'package:flutter/foundation.dart';

class TabRefreshController {
  TabRefreshController._();

  static final ValueNotifier<int> home = ValueNotifier<int>(0);
  static final ValueNotifier<int> social = ValueNotifier<int>(0);

  static void requestHomeRefresh() => home.value++;
  static void requestSocialRefresh() => social.value++;
}
