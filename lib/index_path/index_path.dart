import 'package:flutter/foundation.dart';
import '../table_view/cupertino_table_view_config.dart';

/// tableView下标类
@immutable
class IndexPath {
  final int section;
  final int row;

  const IndexPath({required this.section, required this.row});

  @override
  bool operator ==(Object other) {
    if (other is! IndexPath) {
      return false;
    }
    return section == other.section && row == other.row;
  }

  @override
  int get hashCode => section.hashCode & row.hashCode;

  @override
  String toString() {
    return 'section:$section row:$row';
  }
}

extension IndexPathExtensions on IndexPath {
  bool get isHeader => row == TableViewConfig.headerRowIndex;
  bool get isFooter => row == TableViewConfig.footerRowIndex;
  bool get isDivider => row == TableViewConfig.dividerBaseIndex;
  bool get isCell => row >= 0;
}
