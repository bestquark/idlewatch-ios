import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  bool _isInitializing = true;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _startupError = null;
    });

    try {
      await Firebase.initializeApp();
    } on Exception catch (error) {
      _startupError = error.toString();
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  bool _isSigningIn = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isSigningIn = true;
      _authError = null;
    });

    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (error) {
      _authError = '${error.code}: ${error.message ?? 'unknown auth error'}';
    } on Exception catch (error) {
      _authError = error.toString();
    }

    if (mounted) {
      setState(() {
        _isSigningIn = false;
      });
    }
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
                  label: Text(_isSigningIn ? 'Signing in…' : 'Continue as guest'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('metrics')
        .orderBy('ts', descending: true)
        .limit(120);

    return Scaffold(
      appBar: AppBar(title: const Text('IdleWatch')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.reversed.toList();
          if (docs.isEmpty) {
            return const _EmptyState();
          }

          final cpuSpots = <FlSpot>[];
          final memSpots = <FlSpot>[];

          for (var index = 0; index < docs.length; index++) {
            final data = docs[index].data();
            cpuSpots.add(FlSpot(index.toDouble(), _asDouble(data['cpuPct'])));
            memSpots.add(FlSpot(index.toDouble(), _asDouble(data['memPct'])));
          }

          final latest = docs.last.data();
          final latestTs = _asDateTime(latest['ts']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricChip(label: 'CPU', value: '${_asDouble(latest['cpuPct']).toStringAsFixed(1)}%'),
                  _MetricChip(label: 'Memory', value: '${_asDouble(latest['memPct']).toStringAsFixed(1)}%'),
                  _MetricChip(label: 'Tokens/min', value: '${_asDouble(latest['tokensPerMin']).toStringAsFixed(0)}'),
                  _MetricChip(label: 'Host', value: '${latest['host'] ?? 'unknown'}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last update: ${latestTs != null ? _formatTime(latestTs) : 'unknown'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const _ChartLegend(),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white24),
                    ),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
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
      ),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
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

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
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
        Text(label),
      ],
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
