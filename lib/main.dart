import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();
  runApp(const IdleWatchApp());
}

class IdleWatchApp extends StatelessWidget {
  const IdleWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IdleWatch',
      theme: ThemeData.dark(),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('metrics')
        .orderBy('ts', descending: true)
        .limit(120);

    return Scaffold(
      appBar: AppBar(title: const Text('IdleWatch')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.reversed.toList();
          final cpu = <FlSpot>[];
          final mem = <FlSpot>[];
          for (var i = 0; i < docs.length; i++) {
            final d = docs[i].data();
            cpu.add(FlSpot(i.toDouble(), (d['cpuPct'] ?? 0).toDouble()));
            mem.add(FlSpot(i.toDouble(), (d['memPct'] ?? 0).toDouble()));
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(spots: cpu, isCurved: true, color: Colors.greenAccent),
                  LineChartBarData(spots: mem, isCurved: true, color: Colors.blueAccent),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
