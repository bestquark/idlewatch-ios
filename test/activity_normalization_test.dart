import 'package:flutter/material.dart';
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

  group('buildActivityBreakdownForTest', () {
    test('uses dedicated activity dataset beyond chart-sized 240 sample window', () {
      final now = DateTime.utc(2026, 2, 16, 23, 0);
      final entries = List.generate(300, (index) {
        return {
          'ts': now.subtract(Duration(minutes: index * 4)).millisecondsSinceEpoch,
          'activitySource': 'cronjob',
          'activitySeconds': 60,
        };
      });

      final breakdown = DashboardPage.buildActivityBreakdownForTest(
        entries,
        now: now,
      );

      expect(breakdown['cronjobSeconds'], closeTo(18000, 0.001));
      expect(breakdown['subagentSeconds'], closeTo(0, 0.001));
      expect(breakdown['idleSeconds'], closeTo(68400, 0.001));
      expect(breakdown['totalSeconds'], closeTo(86400, 0.001));
    });
  });

  group('shouldContinueActivityWindowPagination', () {
    test('continues when page is full and oldest sample is still inside 24h window', () {
      final now = DateTime.utc(2026, 2, 16, 23, 0);
      final pageEntries = List.generate(500, (index) {
        return {
          'ts': now.subtract(Duration(minutes: index)).millisecondsSinceEpoch,
        };
      });

      final shouldContinue = DashboardPage.shouldContinueActivityWindowPagination(
        pageEntries: pageEntries,
        now: now,
        pageSize: 500,
      );

      expect(shouldContinue, isTrue);
    });

    test('stops when page is full but already crosses 24h boundary', () {
      final now = DateTime.utc(2026, 2, 16, 23, 0);
      final pageEntries = List.generate(500, (index) {
        return {
          'ts': now.subtract(Duration(minutes: index * 3)).millisecondsSinceEpoch,
        };
      });

      final shouldContinue = DashboardPage.shouldContinueActivityWindowPagination(
        pageEntries: pageEntries,
        now: now,
        pageSize: 500,
      );

      expect(shouldContinue, isFalse);
    });

    test('stops when page is not full', () {
      final now = DateTime.utc(2026, 2, 16, 23, 0);
      final pageEntries = List.generate(37, (index) {
        return {
          'ts': now.subtract(Duration(minutes: index)).millisecondsSinceEpoch,
        };
      });

      final shouldContinue = DashboardPage.shouldContinueActivityWindowPagination(
        pageEntries: pageEntries,
        now: now,
        pageSize: 500,
      );

      expect(shouldContinue, isFalse);
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

  group('decideHostSelection', () {
    test('does not persist fallback during bootstrap race before prefs load', () {
      final decision = DashboardPage.decideHostSelection(
        hosts: const ['host-a', 'host-b'],
        latestHost: 'host-b',
        selectedHost: null,
        hostSelectionReady: false,
      );

      expect(decision.activeHost, 'host-b');
      expect(decision.fallbackHostToPersist, isNull);
    });

    test('keeps persisted host when ready even if latest host differs', () {
      final decision = DashboardPage.decideHostSelection(
        hosts: const ['host-a', 'host-b'],
        latestHost: 'host-b',
        selectedHost: 'host-a',
        hostSelectionReady: true,
      );

      expect(decision.activeHost, 'host-a');
      expect(decision.fallbackHostToPersist, isNull);
    });

    test('uses temporary fallback without overwriting persisted host when missing from window', () {
      final decision = DashboardPage.decideHostSelection(
        hosts: const ['host-a', 'host-b'],
        latestHost: 'host-b',
        selectedHost: 'removed-host',
        hostSelectionReady: true,
      );

      expect(decision.activeHost, 'host-b');
      expect(decision.fallbackHostToPersist, isNull);
    });
  });

  group('loading and recovery widget states', () {
    testWidgets('loading helper appears around 10 seconds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPage.buildLoadingStateForTest(elapsedSeconds: 10),
          ),
        ),
      );

      expect(find.text('Connecting to metrics stream…'), findsOneWidget);
      expect(
        find.text('Still connecting. This can happen on slow or waking networks.'),
        findsOneWidget,
      );
      expect(find.text('Retry connection'), findsNothing);
    });

    testWidgets('retry CTA appears around 30 seconds and fires callback', (
      tester,
    ) async {
      var retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPage.buildLoadingStateForTest(
              elapsedSeconds: 30,
              onRetry: () {
                retryTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Retry connection'), findsOneWidget);
      await tester.tap(find.text('Retry connection'));
      await tester.pumpAndSettle();
      expect(retryTapped, isTrue);
    });

    testWidgets('no valid series state exposes host selector and supports switching', (
      tester,
    ) async {
      String? changedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPage.buildNoValidSeriesStateForTest(
              host: 'host-a',
              availableHosts: const ['host-a', 'host-b'],
              selectedHost: 'host-a',
              onHostChanged: (value) {
                changedTo = value;
              },
            ),
          ),
        ),
      );

      expect(
        find.text('Host "host-a" has samples, but no valid CPU/Memory numeric points to plot.'),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('host-b').last);
      await tester.pumpAndSettle();

      expect(changedTo, 'host-b');
    });
  });
}
