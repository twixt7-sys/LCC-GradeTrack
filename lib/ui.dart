// Single import point for Material widgets.
//
// Flutter 3.47 deprecated package:flutter/material.dart in favor of the
// decoupled package:material_ui. That package is a separate copy with its own
// Theme types, and go_router 18 / fl_chart 1.3 still build on flutter/material,
// so mixing the two would split theming. The app stays on flutter/material
// through this shim; when those packages migrate, change this one export to
// package:material_ui/material_ui.dart.
// ignore_for_file: deprecated_member_use
library;

export 'package:flutter/material.dart';
