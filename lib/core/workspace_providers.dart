import 'package:flutter_riverpod/legacy.dart';

import 'workspace_controller.dart';

final workspaceProvider = ChangeNotifierProvider<AppWorkspaceController>(
  (ref) => AppWorkspaceController(),
);
