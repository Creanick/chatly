import 'package:flutter/foundation.dart';

enum ViewState { initial, initialLoading, executing, idle }

class ViewStateProvider with ChangeNotifier {
  ViewState state = ViewState.initial;
  void setState(ViewState s) {
    state = s;
    notifyListeners();
  }

  void startInitialLoader() => setState(ViewState.initialLoading);
  void startExecuting() => setState(ViewState.executing);
  void stopExecuting() => setState(ViewState.idle);
}
