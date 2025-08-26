import 'package:cupertino_table_view/delegate/cupertino_table_view_delegate.dart';
import 'package:cupertino_table_view/index_path/index_path.dart';
import 'package:cupertino_table_view/index_path/index_path_generator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndexPathGenerator', () {
    final delegate = CupertinoTableViewDelegate(
      numberOfSectionsInTableView: () => 0,
      numberOfRowsInSection: (section) => 0,
      cellForRowAtIndexPath: (context, indexPath) => Container(),
    );

    test('Case 1: Empty Table View', () {
      final generator = IndexPathGenerator(delegate);
      expect(generator.generate(enableDivider: true), []);
    });

    test('Case 2: Single Section with One Row', () {
      delegate.numberOfSectionsInTableView = () => 1;
      delegate.numberOfRowsInSection = (section) => 1;
      final generator = IndexPathGenerator(delegate);
      final indexPaths = generator.generate(enableDivider: true);
      expect(indexPaths.length, 3);
      expect(indexPaths[0].isHeader, true);
      expect(indexPaths[1].isCell, true);
      expect(indexPaths[2].isFooter, true);
    });

    test('Case 3: Single Section with Multiple Rows', () {
      delegate.numberOfSectionsInTableView = () => 1;
      delegate.numberOfRowsInSection = (section) => 3;
      final generator = IndexPathGenerator(delegate);
      final indexPaths = generator.generate(enableDivider: true);
      expect(indexPaths.length, 7);
      expect(indexPaths[0].isHeader, true);
      expect(indexPaths[1].isCell, true);
      expect(indexPaths[2].isDivider, true);
      expect(indexPaths[3].isCell, true);
      expect(indexPaths[4].isDivider, true);
      expect(indexPaths[5].isCell, true);
      expect(indexPaths[6].isFooter, true);
    });

    test('Case 4: Multiple Sections with Different Row Counts', () {
      delegate.numberOfSectionsInTableView = () => 2;
      delegate.numberOfRowsInSection = (section) => section == 0 ? 3 : 1;
      final generator = IndexPathGenerator(delegate);
      final indexPaths = generator.generate(enableDivider: true);
      expect(indexPaths.length, 10);
      // Section 0
      expect(indexPaths[0].isHeader, true);
      expect(indexPaths[1].isCell, true);
      expect(indexPaths[2].isDivider, true);
      expect(indexPaths[3].isCell, true);
      expect(indexPaths[4].isDivider, true);
      expect(indexPaths[5].isCell, true);
      expect(indexPaths[6].isFooter, true);
      // Section 1
      expect(indexPaths[7].isHeader, true);
      expect(indexPaths[8].isCell, true);
      expect(indexPaths[9].isFooter, true);
    });

    test('Case 5: Multiple Sections with Different Row Counts (No Dividers)', () {
      delegate.numberOfSectionsInTableView = () => 2;
      delegate.numberOfRowsInSection = (section) => section == 0 ? 3 : 1;
      final generator = IndexPathGenerator(delegate);
      final indexPaths = generator.generate(enableDivider: false);
      expect(indexPaths.length, 8);
      // Section 0
      expect(indexPaths[0].isHeader, true);
      expect(indexPaths[1].isCell, true);
      expect(indexPaths[2].isCell, true);
      expect(indexPaths[3].isCell, true);
      expect(indexPaths[4].isFooter, true);
      // Section 1
      expect(indexPaths[5].isHeader, true);
      expect(indexPaths[6].isCell, true);
      expect(indexPaths[7].isFooter, true);
    });

    test('Case 6: Single Section with No Rows', () {
      delegate.numberOfSectionsInTableView = () => 1;
      delegate.numberOfRowsInSection = (section) => 0;
      final generator = IndexPathGenerator(delegate);
      final indexPaths = generator.generate(enableDivider: true);
      expect(indexPaths.length, 2);
      expect(indexPaths[0].isHeader, true);
      expect(indexPaths[1].isFooter, true);
    });
  });
}
