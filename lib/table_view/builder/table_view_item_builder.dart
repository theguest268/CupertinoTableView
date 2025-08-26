import 'package:flutter/widgets.dart';

import '../../delegate/cupertino_table_view_delegate.dart';
import '../../index_path/index_path.dart';

class TableViewItemBuilder {
  final CupertinoTableViewDelegate delegate;
  final CellBuilder cellBuilder;

  const TableViewItemBuilder({
    required this.delegate,
    required this.cellBuilder,
  });

  Widget buildItem(BuildContext context, IndexPath indexPath) {
    if (indexPath.isHeader) {
      return _buildHeader(context, indexPath.section);
    } else if (indexPath.isFooter) {
      return _buildFooter(context, indexPath.section);
    } else if (indexPath.isDivider) {
      return cellBuilder.buildDivider(indexPath.section);
    } else {
      return cellBuilder.buildCell(indexPath);
    }
  }

  Widget _buildHeader(BuildContext context, int section) {
    return delegate.headerInSection?.call(context, section) ?? const SizedBox.shrink();
  }

  Widget _buildFooter(BuildContext context, int section) {
    return delegate.footerInSection?.call(context, section) ?? const SizedBox.shrink();
  }
}

class CellBuilder {
  final Widget Function(IndexPath indexPath) buildCell;
  final Widget Function(int section) buildDivider;

  const CellBuilder({
    required this.buildCell,
    required this.buildDivider,
  });
}
