import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_game/features/seerah_maze/ui/responsive/maze_breakpoints.dart';

void main() {
  group('MazeBreakpoints.sizeForWidth', () {
    test('below 600 is compact', () {
      expect(MazeBreakpoints.sizeForWidth(0), MazeScreenSize.compact);
      expect(MazeBreakpoints.sizeForWidth(599.9), MazeScreenSize.compact);
    });

    test('600 up to (not including) 1024 is medium', () {
      expect(MazeBreakpoints.sizeForWidth(600), MazeScreenSize.medium);
      expect(MazeBreakpoints.sizeForWidth(1023.9), MazeScreenSize.medium);
    });

    test('1024 and above is expanded', () {
      expect(MazeBreakpoints.sizeForWidth(1024), MazeScreenSize.expanded);
      expect(MazeBreakpoints.sizeForWidth(5000), MazeScreenSize.expanded);
    });
  });

  group('MazeBreakpoints.orientationFor', () {
    test('wider than tall is landscape', () {
      expect(MazeBreakpoints.orientationFor(const Size(1024, 768)), Orientation.landscape);
    });

    test('taller than wide is portrait', () {
      expect(MazeBreakpoints.orientationFor(const Size(412, 915)), Orientation.portrait);
    });

    test('a perfect square counts as landscape (width >= height)', () {
      expect(MazeBreakpoints.orientationFor(const Size(800, 800)), Orientation.landscape);
    });
  });
}
