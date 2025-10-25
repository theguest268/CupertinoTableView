import '../cupertino_table_view.dart';
import '../table_view/cupertino_table_view_config.dart';

class IndexPathGenerator {
  final CupertinoTableViewDelegate delegate;

  const IndexPathGenerator(this.delegate);

  List<IndexPath> generate({required bool enableDivider}) {
    final result = <IndexPath>[];
    final sectionCount = delegate.numberOfSectionsInTableView();

    for (int section = 0; section < sectionCount; section++) {
      _addSectionItems(result, section, enableDivider);
    }

    return result;
  }

  void _addSectionItems(List<IndexPath> result, int section, bool enableDivider) {
    // Add section header
    result.add(IndexPath(section: section, row: TableViewConfig.headerRowIndex));

    // Add cells and dividers
    final rowCount = delegate.numberOfRowsInSection?.call(section) ?? 0;
    if (enableDivider && rowCount > 0) {
      _addCellsWithDividers(result, section, rowCount);
    } else {
      _addCellsOnly(result, section, rowCount);
    }

    // Add section footer
    result.add(IndexPath(section: section, row: TableViewConfig.footerRowIndex));
  }

  void _addCellsWithDividers(List<IndexPath> result, int section, int rowCount) {
    for (int row = 0; row < rowCount; row++) {
      result.add(IndexPath(section: section, row: row));
      if (row < rowCount - 1) {
        // Add divider with unique negative index
        result.add(IndexPath(section: section, row: TableViewConfig.dividerBaseIndex));
      }
    }
  }

  void _addCellsOnly(List<IndexPath> result, int section, int rowCount) {
    for (int row = 0; row < rowCount; row++) {
      result.add(IndexPath(section: section, row: row));
    }
  }
}
