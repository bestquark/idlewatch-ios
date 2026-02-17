import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

class IdleWatchPerformancePolicy {
  static const int startupHelperSeconds = 10;
  static const int startupRetrySeconds = 30;
  static const int authHelperSeconds = 10;
  static const int authRetrySeconds = 30;
  static const int loadingHelperSeconds = 10;
  static const int loadingRetrySeconds = 30;
  static const int firstRenderBudgetMs = 3500;
  static const int retryRecoveryBudgetMs = 30000;

  static void logPerfSignal(String signal, int valueMs, {int? budgetMs}) {
    final guard = budgetMs == null ? 'n/a' : '$valueMs/$budgetMs';
    final status =
        budgetMs == null ? 'observed' : (valueMs <= budgetMs ? 'pass' : 'warn');
    // NOTE: logs intentionally lightweight so QA can scrape thresholds.
    debugPrint(
      '[idlewatch-perf] $signal=$valueMs status=$status'
      '${budgetMs == null ? '' : ' budget=$guard'}',
    );
  }
}

class _PerfTestHarnessConfig {
  static const String _bootstrapDelayMsRaw =
      String.fromEnvironment('IDLEWATCH_BOOTSTRAP_DELAY_MS', defaultValue: '0');
  static const String _authDelayMsRaw =
      String.fromEnvironment('IDLEWATCH_AUTH_DELAY_MS', defaultValue: '0');
  static const String _dashboardDelayMsRaw =
      String.fromEnvironment('IDLEWATCH_DASHBOARD_DELAY_MS', defaultValue: '0');

  static const bool enableDashboardAutoRetry = bool.fromEnvironment(
    'IDLEWATCH_DASHBOARD_AUTO_RETRY',
    defaultValue: false,
  );

  static final int bootstrapDelayMs = _parseMs(_bootstrapDelayMsRaw);
  static final int authDelayMs = _parseMs(_authDelayMsRaw);
  static final int dashboardDelayMs = _parseMs(_dashboardDelayMsRaw);

  static int _parseMs(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IdleWatchApp());
}

class IdleWatchApp extends StatelessWidget {
  const IdleWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IdleWatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AppBootstrapPage(),
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @visibleForTesting
  static Widget buildBootstrapLoadingStateForTest({
    required int elapsedSeconds,
    VoidCallback? onRetry,
  }) {
    return _BootstrapLoadingState(
      elapsedSeconds: elapsedSeconds,
      onRetry: onRetry,
    );
  }

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  bool _isInitializing = true;
  String? _startupError;
  Timer? _waitTicker;
  int _waitSeconds = 0;
  DateTime? _initializationStartAt;
  bool _loggedStartupHint = false;
  bool _loggedStartupRetryHint = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _startWaitTicker() {
    _waitTicker?.cancel();
    _waitTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isInitializing) return;
      setState(() {
        _waitSeconds += 1;
      });

      if (!_loggedStartupHint &&
          _waitSeconds == IdleWatchPerformancePolicy.startupHelperSeconds) {
        _loggedStartupHint = true;
        IdleWatchPerformancePolicy.logPerfSignal(
          'bootstrap_helper_delay_seconds',
          _waitSeconds * 1000,
        );
      }
      if (!_loggedStartupRetryHint &&
          _waitSeconds == IdleWatchPerformancePolicy.startupRetrySeconds) {
        _loggedStartupRetryHint = true;
        IdleWatchPerformancePolicy.logPerfSignal(
          'bootstrap_retry_delay_seconds',
          _waitSeconds * 1000,
        );
      }
    });
  }

  void _stopWaitTicker() {
    _waitTicker?.cancel();
    _waitTicker = null;
  }

  Future<void> _initialize() async {
    _initializationStartAt = DateTime.now();
    _loggedStartupHint = false;
    _loggedStartupRetryHint = false;
    setState(() {
      _isInitializing = true;
      _startupError = null;
      _waitSeconds = 0;
    });
    _startWaitTicker();

    if (_PerfTestHarnessConfig.bootstrapDelayMs > 0) {
      await Future.delayed(
        Duration(milliseconds: _PerfTestHarnessConfig.bootstrapDelayMs),
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        Firebase.app();
      }
    } on Exception catch (error) {
      _startupError = error.toString();
    }

    if (mounted) {
      if (_initializationStartAt != null) {
        IdleWatchPerformancePolicy.logPerfSignal(
          'bootstrap_init_ms',
          DateTime.now().difference(_initializationStartAt!).inMilliseconds,
          budgetMs: IdleWatchPerformancePolicy.firstRenderBudgetMs,
        );
      }
      setState(() {
        _isInitializing = false;
      });
    }
    _stopWaitTicker();
  }

  @override
  void dispose() {
    _stopWaitTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Starting IdleWatch')),
        body: _BootstrapLoadingState(
          elapsedSeconds: _waitSeconds,
          onRetry:
              _waitSeconds >= IdleWatchPerformancePolicy.startupRetrySeconds
                  ? _initialize
                  : null,
        ),
      );
    }

    if (_startupError != null) {
      return SetupErrorPage(message: _startupError!, onRetry: _initialize);
    }

    return const AuthGatePage();
  }
}

class SetupErrorPage extends StatelessWidget {
  const SetupErrorPage({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IdleWatch setup required')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firebase initialization failed. Complete Firebase setup from '
              'README.md and try again.',
            ),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.amberAccent)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  static List<Widget> buildSigningInHintsForTest({
    required BuildContext context,
    required bool isSigningIn,
    required int authWaitSeconds,
    required VoidCallback onRetry,
  }) {
    if (!isSigningIn) {
      return const [];
    }

    final widgets = <Widget>[];

    if (authWaitSeconds >= IdleWatchPerformancePolicy.authHelperSeconds) {
      widgets.addAll([
        const SizedBox(height: 10),
        Text(
          'Still signing in. This can take a moment if network or Firebase is slow.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ]);
    }

    if (authWaitSeconds >= IdleWatchPerformancePolicy.authRetrySeconds) {
      widgets.addAll([
        const SizedBox(height: 10),
        Text(
          'If this keeps spinning, verify Anonymous auth is enabled in Firebase and try again.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.amberAccent),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry sign-in'),
        ),
      ]);
    }

    return widgets;
  }

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  bool _isSigningIn = false;
  String? _authError;
  Timer? _authWaitTicker;
  int _authWaitSeconds = 0;
  DateTime? _signInStartedAt;
  bool _loggedSigningInHint = false;
  bool _loggedSigningInRetryHint = false;

  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  void _startAuthWaitTicker() {
    _authWaitTicker?.cancel();
    _authWaitTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isSigningIn) return;
      setState(() {
        _authWaitSeconds += 1;
      });

      if (!_loggedSigningInHint &&
          _authWaitSeconds == IdleWatchPerformancePolicy.authHelperSeconds) {
        _loggedSigningInHint = true;
        IdleWatchPerformancePolicy.logPerfSignal(
          'auth_helper_delay_seconds',
          _authWaitSeconds * 1000,
        );
      }
      if (!_loggedSigningInRetryHint &&
          _authWaitSeconds == IdleWatchPerformancePolicy.authRetrySeconds) {
        _loggedSigningInRetryHint = true;
        IdleWatchPerformancePolicy.logPerfSignal(
          'auth_retry_recovery_delay_seconds',
          _authWaitSeconds * 1000,
          budgetMs: IdleWatchPerformancePolicy.retryRecoveryBudgetMs,
        );
      }
    });
  }

  void _stopAuthWaitTicker() {
    _authWaitTicker?.cancel();
    _authWaitTicker = null;
  }

  Future<void> _signInAnonymously() async {
    _signInStartedAt = DateTime.now();
    _loggedSigningInHint = false;
    _loggedSigningInRetryHint = false;
    setState(() {
      _isSigningIn = true;
      _authError = null;
      _authWaitSeconds = 0;
    });
    _startAuthWaitTicker();

    if (_PerfTestHarnessConfig.authDelayMs > 0) {
      await Future.delayed(
        Duration(milliseconds: _PerfTestHarnessConfig.authDelayMs),
      );
    }

    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      _authError = '${error.code}: ${error.message ?? 'unknown auth error'}';
    } on Exception catch (error) {
      _authError = error.toString();
    }

    if (mounted) {
      if (_signInStartedAt != null) {
        IdleWatchPerformancePolicy.logPerfSignal(
          'auth_sign_in_ms',
          DateTime.now().difference(_signInStartedAt!).inMilliseconds,
          budgetMs: IdleWatchPerformancePolicy.retryRecoveryBudgetMs,
        );
      }
      setState(() {
        _isSigningIn = false;
      });
    }
    _stopAuthWaitTicker();
  }

  @override
  void dispose() {
    _stopAuthWaitTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null) {
          return const DashboardPage();
        }

        return Scaffold(
          appBar: AppBar(title: const Text('IdleWatch sign-in')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IdleWatch uses anonymous Firebase auth for this prototype. '
                  'No email/password is required.',
                ),
                const SizedBox(height: 12),
                if (_authError != null)
                  Text(
                    _authError!,
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSigningIn ? null : _signInAnonymously,
                  icon: _isSigningIn
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label:
                      Text(_isSigningIn ? 'Signing in…' : 'Continue as guest'),
                ),
                ...AuthGatePage.buildSigningInHintsForTest(
                  context: context,
                  isSigningIn: _isSigningIn,
                  authWaitSeconds: _authWaitSeconds,
                  onRetry: _signInAnonymously,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  static const int _secondsPerDay = 24 * 60 * 60;
  static const int hostSeriesLimit = 240;
  static const int hostActivityPageSize = 500;
  static const int hostActivityMaxPages = 20;

  @override
  State<DashboardPage> createState() => _DashboardPageState();

  static _ActivityBreakdown _buildActivityBreakdown(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final entries = docs.map((doc) => doc.data());
    return _buildActivityBreakdownFromEntries(entries);
  }

  static _ActivityBreakdown _buildActivityBreakdownFromEntries(
    Iterable<Map<String, dynamic>> entries, {
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final windowStart = anchor.subtract(const Duration(hours: 24));

    double cronjobSeconds = 0;
    double subagentSeconds = 0;
    var observedActivityDoc = false;

    for (final data in entries) {
      final ts = _asDateTime(data['ts']);
      if (ts == null || ts.isBefore(windowStart) || ts.isAfter(anchor)) {
        continue;
      }

      final source = _activitySource(data);
      final seconds = _activitySeconds(data);
      if (source == null || seconds == null || seconds <= 0) {
        continue;
      }

      observedActivityDoc = true;
      if (source == _ActivitySource.cronjob) {
        cronjobSeconds += seconds;
      } else if (source == _ActivitySource.subagent) {
        subagentSeconds += seconds;
      }
    }

    final normalized = computeNormalizedActivitySeconds(
      cronjobSeconds: cronjobSeconds,
      subagentSeconds: subagentSeconds,
    );

    return _ActivityBreakdown(
      cronjobSeconds: normalized['cronjobSeconds']!,
      subagentSeconds: normalized['subagentSeconds']!,
      idleSeconds: normalized['idleSeconds']!,
      hasActivityData: observedActivityDoc,
    );
  }

  @visibleForTesting
  static bool shouldContinueActivityWindowPagination({
    required List<Map<String, dynamic>> pageEntries,
    required DateTime now,
    required int pageSize,
  }) {
    if (pageEntries.length < pageSize) {
      return false;
    }

    final windowStart = now.subtract(const Duration(hours: 24));
    final oldestTs = pageEntries
        .map((entry) => _asDateTime(entry['ts']))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (oldest, ts) {
      if (oldest == null || ts.isBefore(oldest)) {
        return ts;
      }
      return oldest;
    });

    if (oldestTs == null) {
      return true;
    }

    return !oldestTs.isBefore(windowStart);
  }

  static _ActivitySource? _activitySource(Map<String, dynamic> data) {
    final candidates = [
      data['activitySource'],
      data['activity_source'],
      data['source'],
      data['runner'],
      data['actor'],
      data['kind'],
      data['type'],
    ];

    for (final candidate in candidates) {
      if (candidate is! String || candidate.trim().isEmpty) {
        continue;
      }
      final normalized = candidate.toLowerCase().trim();
      if (normalized.contains('cron')) {
        return _ActivitySource.cronjob;
      }
      if (normalized.contains('subagent') ||
          normalized.contains('agent') ||
          normalized.contains('worker')) {
        return _ActivitySource.subagent;
      }
    }

    if (data['isCronjob'] == true || data['cronjob'] == true) {
      return _ActivitySource.cronjob;
    }
    if (data['isSubagent'] == true || data['subagent'] == true) {
      return _ActivitySource.subagent;
    }

    return null;
  }

  static double? _activitySeconds(Map<String, dynamic> data) {
    const secondFields = [
      'activitySeconds',
      'activity_seconds',
      'activeSeconds',
      'active_seconds',
      'durationSeconds',
      'duration_seconds',
      'activeSec',
      'durationSec',
    ];
    const millisecondFields = [
      'activityMs',
      'activity_ms',
      'activeMs',
      'active_ms',
      'durationMs',
      'duration_ms',
    ];

    for (final key in secondFields) {
      final parsed = _secondsFromUnknown(data[key]);
      if (parsed != null) {
        return parsed;
      }
    }

    for (final key in millisecondFields) {
      final parsed = _millisecondsFromUnknown(data[key]);
      if (parsed != null) {
        return parsed / 1000;
      }
    }

    final genericDuration = _secondsFromUnknown(data['duration']);
    if (genericDuration != null) {
      return genericDuration;
    }

    final genericActive = _secondsFromUnknown(data['active']);
    if (genericActive != null) {
      return genericActive;
    }

    return null;
  }

  static double? _secondsFromUnknown(Object? raw) {
    if (raw is num) {
      if (raw <= 0) return null;
      return raw.toDouble();
    }

    if (raw is String) {
      final value = raw.trim().toLowerCase();
      if (value.isEmpty) {
        return null;
      }

      final number = double.tryParse(value);
      if (number != null && number > 0) {
        return number;
      }

      final msMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*ms$').firstMatch(value);
      if (msMatch != null) {
        return double.parse(msMatch.group(1)!) / 1000;
      }

      final secMatch =
          RegExp(r'^(\d+(?:\.\d+)?)\s*s(ec(?:onds?)?)?$').firstMatch(value);
      if (secMatch != null) {
        return double.parse(secMatch.group(1)!);
      }
    }

    return null;
  }

  static double? _millisecondsFromUnknown(Object? raw) {
    if (raw is num) {
      if (raw <= 0) return null;
      return raw.toDouble();
    }

    if (raw is String) {
      final value = raw.trim().toLowerCase();
      final number = double.tryParse(value);
      if (number != null && number > 0) {
        return number;
      }

      final msMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*ms$').firstMatch(value);
      if (msMatch != null) {
        return double.parse(msMatch.group(1)!);
      }
    }

    return null;
  }

  static double? _asNullableDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is double) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }

  static String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static Map<String, double> computeNormalizedActivitySeconds({
    required double cronjobSeconds,
    required double subagentSeconds,
  }) {
    var safeCron = math.max(0.0, cronjobSeconds);
    var safeSubagent = math.max(0.0, subagentSeconds);
    final activeTotal = safeCron + safeSubagent;

    if (activeTotal > _secondsPerDay) {
      final scale = _secondsPerDay / activeTotal;
      safeCron *= scale;
      safeSubagent *= scale;
    }

    final idle =
        math.max(0.0, _secondsPerDay.toDouble() - (safeCron + safeSubagent));
    return {
      'cronjobSeconds': safeCron,
      'subagentSeconds': safeSubagent,
      'idleSeconds': idle,
    };
  }

  static String formatDuration(double seconds) {
    final total = seconds.round();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (hours == 0) {
      return '${minutes}m';
    }
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static DashboardHostSelectionDecision decideHostSelection({
    required List<String> hosts,
    required String latestHost,
    required String? selectedHost,
    required bool hostSelectionReady,
  }) {
    if (hosts.isEmpty) {
      return const DashboardHostSelectionDecision(
        activeHost: 'unknown',
        fallbackHostToPersist: null,
      );
    }

    final fallbackHost = hosts.contains(latestHost) ? latestHost : hosts.first;

    if (selectedHost != null && hosts.contains(selectedHost)) {
      return DashboardHostSelectionDecision(
        activeHost: selectedHost,
        fallbackHostToPersist: null,
      );
    }

    if (!hostSelectionReady) {
      return DashboardHostSelectionDecision(
        activeHost: fallbackHost,
        fallbackHostToPersist: null,
      );
    }

    // Non-destructive fallback mode:
    // if a persisted host is missing from this discovery window, temporarily
    // render a fallback host but do not overwrite persisted preference.
    return DashboardHostSelectionDecision(
      activeHost: fallbackHost,
      fallbackHostToPersist: null,
    );
  }

  @visibleForTesting
  static Widget buildLoadingStateForTest({
    required int elapsedSeconds,
    VoidCallback? onRetry,
  }) {
    return _LoadingState(elapsedSeconds: elapsedSeconds, onRetry: onRetry);
  }

  @visibleForTesting
  static Widget buildNoValidSeriesStateForTest({
    required String host,
    required List<String> availableHosts,
    required String selectedHost,
    required ValueChanged<String> onHostChanged,
  }) {
    return _NoValidSeriesState(
      host: host,
      availableHosts: availableHosts,
      selectedHost: selectedHost,
      onHostChanged: onHostChanged,
    );
  }

  @visibleForTesting
  static Map<String, double> buildActivityBreakdownForTest(
    Iterable<Map<String, dynamic>> entries, {
    DateTime? now,
  }) {
    final activity = _buildActivityBreakdownFromEntries(entries, now: now);
    return {
      'cronjobSeconds': activity.cronjobSeconds,
      'subagentSeconds': activity.subagentSeconds,
      'idleSeconds': activity.idleSeconds,
      'totalSeconds': activity.totalSeconds,
    };
  }

  static DashboardSeriesData buildSeriesDataFromEntries(
    Iterable<Map<String, dynamic>> entries,
  ) {
    DateTime? firstValidTs;
    for (final data in entries) {
      final ts = _asDateTime(data['ts']);
      if (ts != null) {
        firstValidTs = ts;
        break;
      }
    }

    final cpuSpots = <FlSpot>[];
    final memSpots = <FlSpot>[];
    var droppedInvalidPoints = 0;

    for (final data in entries) {
      final ts = _asDateTime(data['ts']);
      if (ts == null || firstValidTs == null) {
        droppedInvalidPoints += 1;
        continue;
      }

      final cpu = _asNullableDouble(data['cpuPct']);
      final mem = _asNullableDouble(data['memPct']);
      if (cpu == null || mem == null) {
        droppedInvalidPoints += 1;
        continue;
      }

      final x = ts.difference(firstValidTs).inMinutes.toDouble();
      cpuSpots.add(FlSpot(x, cpu.clamp(0, 100)));
      memSpots.add(FlSpot(x, mem.clamp(0, 100)));
    }

    return DashboardSeriesData(
      firstTimestamp: firstValidTs,
      cpuSpots: cpuSpots,
      memSpots: memSpots,
      droppedInvalidPoints: droppedInvalidPoints,
    );
  }
}

class DashboardSeriesData {
  const DashboardSeriesData({
    required this.firstTimestamp,
    required this.cpuSpots,
    required this.memSpots,
    required this.droppedInvalidPoints,
  });

  final DateTime? firstTimestamp;
  final List<FlSpot> cpuSpots;
  final List<FlSpot> memSpots;
  final int droppedInvalidPoints;

  bool get hasValidSeries => cpuSpots.isNotEmpty && memSpots.isNotEmpty;
}

class DashboardHostSelectionDecision {
  const DashboardHostSelectionDecision({
    required this.activeHost,
    required this.fallbackHostToPersist,
  });

  final String activeHost;
  final String? fallbackHostToPersist;
}

class _DashboardPageState extends State<DashboardPage> {
  static const _selectedHostPrefKey = 'idlewatch.selectedHost';

  String? _selectedHost;
  bool _hostSelectionReady = false;
  Timer? _loadingTicker;
  int _loadingSeconds = 0;
  bool _loadingLoggedHelper = false;
  bool _loadingLoggedRetry = false;
  bool _firstRenderLogged = false;
  final DateTime _dashboardStartAt = DateTime.now();
  DateTime? _retryRequestedAt;
  DateTime? _debugDashboardDelayStartedAt;
  int _retryNonce = 0;
  String? _activityFutureHost;
  int _activityFutureRetryNonce = -1;
  Future<_ActivityBreakdown>? _activityBreakdownFuture;
  bool _didAutoRetryDashboardDelay = false;
  bool _isGeneratingEnrollmentCode = false;
  String? _generatedEnrollmentCode;
  DateTime? _generatedEnrollmentExpiry;
  String? _enrollmentError;

  @override
  void initState() {
    super.initState();
    if (_PerfTestHarnessConfig.dashboardDelayMs > 0) {
      _debugDashboardDelayStartedAt = DateTime.now();
    }
    _loadPersistedHostSelection();
  }

  Future<void> _loadPersistedHostSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString(_selectedHostPrefKey);
    if (!mounted) {
      return;
    }

    setState(() {
      if (persisted != null && persisted.isNotEmpty) {
        _selectedHost = persisted;
      }
      _hostSelectionReady = true;
    });
  }

  Future<void> _persistSelectedHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedHostPrefKey, host);
  }

  void _setSelectedHost(String host, {bool persist = true}) {
    if (_selectedHost == host) {
      return;
    }

    setState(() {
      _selectedHost = host;
    });
    if (persist) {
      unawaited(_persistSelectedHost(host));
    }
  }

  void _ensureLoadingTicker() {
    if (_loadingTicker != null) {
      return;
    }
    _loadingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _loadingSeconds += 1;
      });
      _logLoadingSignals();
    });
  }

  void _stopLoadingTicker() {
    _loadingTicker?.cancel();
    _loadingTicker = null;
    if (_loadingSeconds != 0) {
      _loadingSeconds = 0;
    }
  }

  bool _shouldHoldLoadingForDelay() {
    if (_debugDashboardDelayStartedAt == null ||
        _PerfTestHarnessConfig.dashboardDelayMs <= 0) {
      return false;
    }

    final elapsedMs = DateTime.now()
        .difference(_debugDashboardDelayStartedAt!)
        .inMilliseconds;
    return elapsedMs < _PerfTestHarnessConfig.dashboardDelayMs;
  }

  void _triggerDebugDashboardAutoRetryIfNeeded() {
    if (!_PerfTestHarnessConfig.enableDashboardAutoRetry) {
      return;
    }

    if (_didAutoRetryDashboardDelay) {
      return;
    }

    if (_loadingSeconds >= IdleWatchPerformancePolicy.loadingRetrySeconds) {
      _didAutoRetryDashboardDelay = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _retryStream();
      });
    }
  }

  void _logLoadingSignals() {
    if (!_loadingLoggedHelper &&
        _loadingSeconds == IdleWatchPerformancePolicy.loadingHelperSeconds) {
      _loadingLoggedHelper = true;
      IdleWatchPerformancePolicy.logPerfSignal(
        'dashboard_loading_helper_delay_seconds',
        _loadingSeconds * 1000,
      );
    }
    if (!_loadingLoggedRetry &&
        _loadingSeconds == IdleWatchPerformancePolicy.loadingRetrySeconds) {
      _loadingLoggedRetry = true;
      IdleWatchPerformancePolicy.logPerfSignal(
        'dashboard_loading_retry_recovery_delay_seconds',
        _loadingSeconds * 1000,
        budgetMs: IdleWatchPerformancePolicy.retryRecoveryBudgetMs,
      );
    }
  }

  void _logFirstRenderSignals() {
    if (!_firstRenderLogged) {
      _firstRenderLogged = true;
      IdleWatchPerformancePolicy.logPerfSignal(
        'dashboard_first_render_ms',
        DateTime.now().difference(_dashboardStartAt).inMilliseconds,
        budgetMs: IdleWatchPerformancePolicy.firstRenderBudgetMs,
      );
    }

    if (_retryRequestedAt != null) {
      IdleWatchPerformancePolicy.logPerfSignal(
        'dashboard_retry_recovery_ms',
        DateTime.now().difference(_retryRequestedAt!).inMilliseconds,
        budgetMs: IdleWatchPerformancePolicy.retryRecoveryBudgetMs,
      );
      _retryRequestedAt = null;
    }
  }

  void _retryStream() {
    _retryRequestedAt = DateTime.now();
    setState(() {
      _retryNonce += 1;
      _loadingSeconds = 0;
      _activityBreakdownFuture = null;
      _activityFutureHost = null;
      _activityFutureRetryNonce = -1;
      _loadingLoggedHelper = false;
      _loadingLoggedRetry = false;
    });
  }

  Future<_ActivityBreakdown> _fetchActivityBreakdown(String activeHost) async {
    final now = DateTime.now();
    final query = FirebaseFirestore.instance
        .collection('metrics')
        .where('host', isEqualTo: activeHost)
        .orderBy('ts', descending: true);

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;

    for (var page = 0; page < DashboardPage.hostActivityMaxPages; page++) {
      var pageQuery = query.limit(DashboardPage.hostActivityPageSize);
      if (cursor != null) {
        pageQuery = pageQuery.startAfterDocument(cursor);
      }

      final snapshot = await pageQuery.get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      docs.addAll(snapshot.docs);
      cursor = snapshot.docs.last;

      final shouldContinue =
          DashboardPage.shouldContinueActivityWindowPagination(
        pageEntries: snapshot.docs.map((doc) => doc.data()).toList(),
        now: now,
        pageSize: DashboardPage.hostActivityPageSize,
      );
      if (!shouldContinue) {
        break;
      }
    }

    return DashboardPage._buildActivityBreakdown(docs);
  }

  Future<_ActivityBreakdown> _ensureActivityBreakdownFuture(String activeHost) {
    if (_activityBreakdownFuture != null &&
        _activityFutureHost == activeHost &&
        _activityFutureRetryNonce == _retryNonce) {
      return _activityBreakdownFuture!;
    }

    final future = _fetchActivityBreakdown(activeHost);
    _activityFutureHost = activeHost;
    _activityFutureRetryNonce = _retryNonce;
    _activityBreakdownFuture = future;
    return future;
  }

  String _buildEnrollmentCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random.secure();
    final raw =
        List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    return '${raw.substring(0, 4)}-${raw.substring(4)}';
  }

  Future<void> _generateEnrollmentCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isGeneratingEnrollmentCode) return;

    setState(() {
      _isGeneratingEnrollmentCode = true;
      _enrollmentError = null;
    });

    final code = _buildEnrollmentCode();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 10));

    try {
      await FirebaseFirestore.instance.collection('enrollment_tokens').add({
        'ownerUid': user.uid,
        'ownerDisplayName': user.isAnonymous
            ? 'Anonymous iOS session'
            : (user.displayName ?? user.email ?? user.uid),
        'code': code,
        'status': 'issued',
        'createdAtMs': now.millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAtMs': expiresAt.millisecondsSinceEpoch,
      });

      if (!mounted) return;
      setState(() {
        _generatedEnrollmentCode = code;
        _generatedEnrollmentExpiry = expiresAt;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _enrollmentError = 'Could not create enrollment code (${error.code}).';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enrollmentError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingEnrollmentCode = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _loadingTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostDiscoveryQuery = FirebaseFirestore.instance
        .collection('metrics')
        .orderBy('ts', descending: true)
        .limit(DashboardPage.hostSeriesLimit);

    return Scaffold(
      appBar: AppBar(title: const Text('IdleWatch')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey('metrics-host-discovery-$_retryNonce'),
        stream: hostDiscoveryQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            _stopLoadingTicker();
            return _ErrorState(message: snapshot.error.toString());
          }

          if (_shouldHoldLoadingForDelay() || !snapshot.hasData) {
            _ensureLoadingTicker();
            _triggerDebugDashboardAutoRetryIfNeeded();
            return _LoadingState(
              elapsedSeconds: _loadingSeconds,
              onRetry: _loadingSeconds >=
                      IdleWatchPerformancePolicy.loadingRetrySeconds
                  ? _retryStream
                  : null,
            );
          }

          _stopLoadingTicker();
          final allDocs = snapshot.data!.docs.reversed.toList();
          if (allDocs.isEmpty) {
            return const _EmptyState();
          }

          final hosts = allDocs
              .map((doc) => (doc.data()['host'] ?? 'unknown').toString())
              .toSet()
              .toList()
            ..sort();

          final latestHost =
              (allDocs.last.data()['host'] ?? 'unknown').toString();
          final hostDecision = DashboardPage.decideHostSelection(
            hosts: hosts,
            latestHost: latestHost,
            selectedHost: _selectedHost,
            hostSelectionReady: _hostSelectionReady,
          );

          if (hostDecision.fallbackHostToPersist != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _setSelectedHost(hostDecision.fallbackHostToPersist!);
              }
            });
          }

          final activeHost = hostDecision.activeHost;
          final hostSeriesQuery = FirebaseFirestore.instance
              .collection('metrics')
              .where('host', isEqualTo: activeHost)
              .orderBy('ts', descending: true)
              .limit(DashboardPage.hostSeriesLimit);

          final activityBreakdownFuture =
              _ensureActivityBreakdownFuture(activeHost);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            key: ValueKey('metrics-host-series-$activeHost-$_retryNonce'),
            stream: hostSeriesQuery.snapshots(),
            builder: (context, hostSnapshot) {
              if (hostSnapshot.hasError) {
                return _ErrorState(message: hostSnapshot.error.toString());
              }

              if (_shouldHoldLoadingForDelay() || !hostSnapshot.hasData) {
                _ensureLoadingTicker();
                _triggerDebugDashboardAutoRetryIfNeeded();
                return _LoadingState(
                  elapsedSeconds: _loadingSeconds,
                  onRetry: _loadingSeconds >=
                          IdleWatchPerformancePolicy.loadingRetrySeconds
                      ? _retryStream
                      : null,
                );
              }

              _stopLoadingTicker();
              final docs = hostSnapshot.data!.docs.reversed.toList();
              if (docs.isEmpty) {
                return _EmptyStateForHost(
                  host: activeHost,
                  availableHosts: hosts,
                  selectedHost: activeHost,
                  onHostChanged: _setSelectedHost,
                );
              }

              final series = DashboardPage.buildSeriesDataFromEntries(
                docs.map((doc) => doc.data()),
              );
              final firstTs = series.firstTimestamp;
              final cpuSpots = series.cpuSpots;
              final memSpots = series.memSpots;
              final droppedInvalidPoints = series.droppedInvalidPoints;

              _logFirstRenderSignals();

              if (!series.hasValidSeries) {
                return _NoValidSeriesState(
                  host: activeHost,
                  availableHosts: hosts,
                  selectedHost: activeHost,
                  onHostChanged: _setSelectedHost,
                );
              }

              final chartStartTs = firstTs!;
              final latest = docs.last.data();
              final latestTs = DashboardPage._asDateTime(latest['ts']);
              final latestCpu =
                  DashboardPage._asNullableDouble(latest['cpuPct']);
              final latestMem =
                  DashboardPage._asNullableDouble(latest['memPct']);
              final latestTpm =
                  DashboardPage._asNullableDouble(latest['tokensPerMin']);
              final latestInvalid =
                  latestCpu == null || latestMem == null || latestTpm == null;
              final minX = cpuSpots.first.x;
              final maxX = cpuSpots.last.x;
              final span = (maxX - minX).abs();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricChip(
                        label: 'CPU',
                        value: latestCpu != null
                            ? '${latestCpu.toStringAsFixed(1)}%'
                            : '—',
                      ),
                      _MetricChip(
                        label: 'Memory',
                        value: latestMem != null
                            ? '${latestMem.toStringAsFixed(1)}%'
                            : '—',
                      ),
                      _MetricChip(
                        label: 'Tokens/min',
                        value: latestTpm != null
                            ? latestTpm.toStringAsFixed(0)
                            : '—',
                      ),
                    ],
                  ),
                  if (latestInvalid) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Latest sample has malformed metric values. Showing — for invalid fields.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.amberAccent),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _HostSelector(
                    hosts: hosts,
                    selectedHost: activeHost,
                    onChanged: _setSelectedHost,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last update ($activeHost): ${latestTs != null ? DashboardPage._formatTime(latestTs) : 'unknown'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (droppedInvalidPoints > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Skipped $droppedInvalidPoints malformed sample(s) for this host.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.amberAccent),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Enroll a new device',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _isGeneratingEnrollmentCode
                                  ? null
                                  : _generateEnrollmentCode,
                              icon: _isGeneratingEnrollmentCode
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.qr_code_2_outlined),
                              label: Text(_isGeneratingEnrollmentCode
                                  ? 'Generating…'
                                  : 'Generate code'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1) Generate an enrollment code. 2) Run IdleWatch on the new machine and paste it. 3) Device shows in Fleet once heartbeats begin.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_generatedEnrollmentCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Active code: $_generatedEnrollmentCode (expires ${_generatedEnrollmentExpiry != null ? DashboardPage._formatClock(_generatedEnrollmentExpiry!) : 'soon'})',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.tealAccent.shade100),
                          ),
                        ],
                        if (_enrollmentError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _enrollmentError!,
                            style: const TextStyle(color: Colors.amberAccent),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('devices')
                        .where('ownerUid',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .limit(50)
                        .snapshots(),
                    builder: (context, fleetSnapshot) {
                      if (fleetSnapshot.hasError) {
                        return Text(
                          'Fleet unavailable: ${fleetSnapshot.error}',
                          style: const TextStyle(color: Colors.amberAccent),
                        );
                      }
                      final docs = fleetSnapshot.data?.docs ?? const [];
                      final now = DateTime.now();
                      final onlineCount = docs.where((doc) {
                        final data = doc.data();
                        final ts = DashboardPage._asDateTime(
                            data['lastSeenTs'] ??
                                data['lastHeartbeatTs'] ??
                                data['ts']);
                        return ts != null && now.difference(ts).inMinutes <= 2;
                      }).length;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your fleet',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                                '${docs.length} devices • $onlineCount online • ${docs.length - onlineCount} offline',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            if (docs.isEmpty)
                              Text(
                                'No enrolled devices yet.',
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            else
                              ...docs.take(8).map((doc) {
                                final data = doc.data();
                                final host = (data['hostName'] ??
                                        data['hostId'] ??
                                        data['host'] ??
                                        'unknown-host')
                                    .toString();
                                final device = (data['deviceName'] ??
                                        data['deviceId'] ??
                                        doc.id)
                                    .toString();
                                final health =
                                    (data['healthStatus'] ?? 'unknown')
                                        .toString();
                                final cpu = DashboardPage._asNullableDouble(
                                    data['latestCpuPct'] ?? data['cpuPct']);
                                final mem = DashboardPage._asNullableDouble(
                                    data['latestMemPct'] ?? data['memPct']);
                                final lastSeen = DashboardPage._asDateTime(
                                    data['lastSeenTs'] ??
                                        data['lastHeartbeatTs'] ??
                                        data['ts']);
                                final online = lastSeen != null &&
                                    now.difference(lastSeen).inMinutes <= 2;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    '${online ? '🟢' : '⚪'} $host / $device • ${lastSeen != null ? DashboardPage._formatTime(lastSeen) : 'never'} • $health • CPU ${cpu?.toStringAsFixed(0) ?? '—'}% MEM ${mem?.toStringAsFixed(0) ?? '—'}%',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<_ActivityBreakdown>(
                    key: ValueKey(
                        'metrics-host-activity-$activeHost-$_retryNonce'),
                    future: activityBreakdownFuture,
                    builder: (context, activitySnapshot) {
                      if (activitySnapshot.hasError) {
                        return _ActivityPieCard(
                          activity: _ActivityBreakdown(
                            cronjobSeconds: 0,
                            subagentSeconds: 0,
                            idleSeconds:
                                DashboardPage._secondsPerDay.toDouble(),
                            hasActivityData: false,
                          ),
                        );
                      }

                      if (!activitySnapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      return _ActivityPieCard(activity: activitySnapshot.data!);
                    },
                  ),
                  const SizedBox(height: 20),
                  const _ChartLegend(),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 280,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 100,
                        minX: minX,
                        maxX: maxX,
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.white24),
                        ),
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (items) {
                              return items.map((item) {
                                final secondsFromStart = (item.x * 60).round();
                                final pointTs = chartStartTs
                                    .add(Duration(seconds: secondsFromStart));
                                final series =
                                    item.barIndex == 0 ? 'CPU' : 'MEM';
                                return LineTooltipItem(
                                  '${DashboardPage._formatClock(pointTs)}\n$series ${item.y.toStringAsFixed(1)}%',
                                  TextStyle(
                                    color: item.bar.color ?? Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: true, reservedSize: 34),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: span > 0 ? span / 2 : 1,
                              getTitlesWidget: (value, meta) {
                                final isStart = (value - minX).abs() < 0.5;
                                final isMiddle = span > 1 &&
                                    (value - (minX + span / 2)).abs() < 0.5;
                                final isEnd = (value - maxX).abs() < 0.5;
                                if (!(isStart || isMiddle || isEnd)) {
                                  return const SizedBox.shrink();
                                }

                                final secondsFromStart = (value * 60).round();
                                final labelTs = chartStartTs
                                    .add(Duration(seconds: secondsFromStart));
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    DashboardPage._formatClock(labelTs),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: cpuSpots,
                            isCurved: true,
                            barWidth: 2.5,
                            color: Colors.greenAccent,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: memSpots,
                            isCurved: true,
                            barWidth: 2.5,
                            color: Colors.blueAccent,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

enum _ActivitySource { cronjob, subagent }

class _ActivityBreakdown {
  const _ActivityBreakdown({
    required this.cronjobSeconds,
    required this.subagentSeconds,
    required this.idleSeconds,
    required this.hasActivityData,
  });

  final double cronjobSeconds;
  final double subagentSeconds;
  final double idleSeconds;
  final bool hasActivityData;

  double get totalSeconds => cronjobSeconds + subagentSeconds + idleSeconds;
}

class _ActivityPieCard extends StatelessWidget {
  const _ActivityPieCard({required this.activity});

  final _ActivityBreakdown activity;

  @override
  Widget build(BuildContext context) {
    final sections = [
      if (activity.cronjobSeconds > 0)
        PieChartSectionData(
          value: activity.cronjobSeconds,
          color: Colors.deepPurpleAccent,
          title: '',
          radius: 54,
        ),
      if (activity.subagentSeconds > 0)
        PieChartSectionData(
          value: activity.subagentSeconds,
          color: Colors.tealAccent.shade400,
          title: '',
          radius: 54,
        ),
      PieChartSectionData(
        value: activity.idleSeconds,
        color: Colors.white24,
        title: '',
        radius: 54,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity (last 24h)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pie is normalized to 24h total. Idle fills the remainder.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    startDegreeOffset: -90,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendDot(
                      color: Colors.deepPurpleAccent,
                      label:
                          'Cronjob ${DashboardPage.formatDuration(activity.cronjobSeconds)}',
                    ),
                    const SizedBox(height: 8),
                    _LegendDot(
                      color: Colors.tealAccent.shade400,
                      label:
                          'Subagent ${DashboardPage.formatDuration(activity.subagentSeconds)}',
                    ),
                    const SizedBox(height: 8),
                    _LegendDot(
                      color: Colors.white54,
                      label:
                          'Idle ${DashboardPage.formatDuration(activity.idleSeconds)}',
                    ),
                    if (!activity.hasActivityData) ...[
                      const SizedBox(height: 10),
                      Text(
                        'No recent activity telemetry found. Showing full idle day.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.amberAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _HostSelector extends StatelessWidget {
  const _HostSelector({
    required this.hosts,
    required this.selectedHost,
    required this.onChanged,
  });

  final List<String> hosts;
  final String selectedHost;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.dns_outlined, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Text('Host:', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButton<String>(
            value: selectedHost,
            isExpanded: true,
            items: hosts
                .map((host) => DropdownMenuItem(value: host, child: Text(host)))
                .toList(),
            onChanged: (next) {
              if (next != null) {
                onChanged(next);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendDot(color: Colors.greenAccent, label: 'CPU'),
        SizedBox(width: 16),
        _LegendDot(color: Colors.blueAccent, label: 'Memory'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _BootstrapLoadingState extends StatelessWidget {
  const _BootstrapLoadingState({required this.elapsedSeconds, this.onRetry});

  final int elapsedSeconds;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            const Text('Initializing Firebase…'),
            if (elapsedSeconds >=
                IdleWatchPerformancePolicy.startupHelperSeconds) ...[
              const SizedBox(height: 8),
              Text(
                'Still initializing. This can happen on first launch or slower networks.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (elapsedSeconds >=
                IdleWatchPerformancePolicy.startupRetrySeconds) ...[
              const SizedBox(height: 12),
              Text(
                'If this keeps spinning, check Firebase config/plist setup, then retry.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.amberAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry setup'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.elapsedSeconds, this.onRetry});

  final int elapsedSeconds;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            const Text('Connecting to metrics stream…'),
            if (elapsedSeconds >=
                IdleWatchPerformancePolicy.loadingHelperSeconds) ...[
              const SizedBox(height: 8),
              Text(
                'Still connecting. This can happen on slow or waking networks.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (elapsedSeconds >=
                IdleWatchPerformancePolicy.loadingRetrySeconds) ...[
              const SizedBox(height: 12),
              Text(
                'If this takes too long, check network access and Firestore permissions.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.amberAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry connection'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unable to load metrics right now.'),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.amberAccent)),
          const SizedBox(height: 8),
          const Text(
            'If this is a permission error, verify Firestore rules allow this '
            'authenticated user to read metrics.',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No metrics yet. Start the IdleWatch collector and push sample data '
          'to Firestore.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptyStateForHost extends StatelessWidget {
  const _EmptyStateForHost({
    required this.host,
    required this.availableHosts,
    required this.selectedHost,
    required this.onHostChanged,
  });

  final String host;
  final List<String> availableHosts;
  final String selectedHost;
  final ValueChanged<String> onHostChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No metrics found for the selected host.'),
          const SizedBox(height: 12),
          _HostSelector(
            hosts: availableHosts,
            selectedHost: selectedHost,
            onChanged: onHostChanged,
          ),
          const SizedBox(height: 8),
          Text(
            'Selected: $host',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NoValidSeriesState extends StatelessWidget {
  const _NoValidSeriesState({
    required this.host,
    required this.availableHosts,
    required this.selectedHost,
    required this.onHostChanged,
  });

  final String host;
  final List<String> availableHosts;
  final String selectedHost;
  final ValueChanged<String> onHostChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Host "$host" has samples, but no valid CPU/Memory numeric points to plot.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Some samples may have malformed timestamps or numeric fields.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.amberAccent),
          ),
          const SizedBox(height: 14),
          _HostSelector(
            hosts: availableHosts,
            selectedHost: selectedHost,
            onChanged: onHostChanged,
          ),
        ],
      ),
    );
  }
}
