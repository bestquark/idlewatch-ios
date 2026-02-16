import 'package:flutter_test/flutter_test.dart';
import 'package:idlewatch_ios/main.dart';

void main() {
  group('computeNormalizedActivitySeconds', () {
    test('keeps raw values when active total is <= 24h', () {
      final result = DashboardPage.computeNormalizedActivitySeconds(
        cronjobSeconds: 3 * 3600,
        subagentSeconds: 5 * 3600,
      );

      expect(result['cronjobSeconds'], closeTo(10800, 0.001));
      expect(result['subagentSeconds'], closeTo(18000, 0.001));
      expect(result['idleSeconds'], closeTo(57600, 0.001));
      expect(
        (result['cronjobSeconds']! +
                result['subagentSeconds']! +
                result['idleSeconds']!),
        closeTo(86400, 0.001),
      );
    });

    test('scales categories proportionally when active total exceeds 24h', () {
      final result = DashboardPage.computeNormalizedActivitySeconds(
        cronjobSeconds: 20 * 3600,
        subagentSeconds: 10 * 3600,
      );

      expect(result['cronjobSeconds'], closeTo(57600, 0.01)); // 16h
      expect(result['subagentSeconds'], closeTo(28800, 0.01)); // 8h
      expect(result['idleSeconds'], closeTo(0, 0.01));
      expect(
        (result['cronjobSeconds']! +
                result['subagentSeconds']! +
                result['idleSeconds']!),
        closeTo(86400, 0.01),
      );
    });
  });

  group('buildSeriesDataFromEntries', () {
    test('uses first valid timestamp baseline even when first doc ts is malformed', () {
      final series = DashboardPage.buildSeriesDataFromEntries([
        {
          'ts': 'bad-ts',
          'cpuPct': 22,
          'memPct': 33,
        },
        {
          'ts': 1700000000,
          'cpuPct': 25,
          'memPct': 40,
        },
        {
          'ts': 1700000060,
          'cpuPct': 35,
          'memPct': 50,
        },
      ]);

      expect(series.hasValidSeries, isTrue);
      expect(series.firstTimestamp, isNotNull);
      expect(series.cpuSpots.length, 2);
      expect(series.memSpots.length, 2);
      expect(series.cpuSpots.first.x, closeTo(0, 0.001));
      expect(series.cpuSpots.last.x, closeTo(1, 0.001));
      expect(series.droppedInvalidPoints, 1);
    });
  });
}
