import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    await Firebase.initializeApp();
    await FirebaseAuth.instance.signInAnonymously();
  } on Exception catch (error) {
    startupError = error.toString();
  }

  runApp(IdleWatchApp(startupError: startupError));
}

class IdleWatchApp extends StatelessWidget {
  const IdleWatchApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IdleWatch',
      theme: ThemeData.dark(),
      home: startupError == null
          ? const DashboardPage()
          : SetupErrorPage(message: startupError!),
    );
  }
}

class SetupErrorPage extends StatelessWidget {
  const SetupErrorPage({super.key, required this.message});

  final String message;

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
              'README.md and run again.',
            ),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.amberAccent)),
          ],
        ),
      ),
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.reversed.toList();
          final cpuSpots = <FlSpot>[];
          final memSpots = <FlSpot>[];

          for (var index = 0; index < docs.length; index++) {
            final data = docs[index].data();
            cpuSpots.add(FlSpot(index.toDouble(), _asDouble(data['cpuPct'])));
            memSpots.add(FlSpot(index.toDouble(), _asDouble(data['memPct'])));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: cpuSpots,
                    isCurved: true,
                    color: Colors.greenAccent,
                  ),
                  LineChartBarData(
                    spots: memSpots,
                    isCurved: true,
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }
}
