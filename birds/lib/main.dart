import 'package:flutter/material.dart';

import 'models/bird.dart';
import 'services/bird_api.dart';
import 'screens/bird_details_page.dart';
import 'screens/recording_page.dart';

void main() {
  runApp(const BirdsApp());
}

class BirdsApp extends StatelessWidget {
  const BirdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bird Library',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const BirdsPage(),
    );
  }
}

class BirdsPage extends StatefulWidget {
  const BirdsPage({super.key});

  @override
  State<BirdsPage> createState() => _BirdsPageState();
}

class _BirdsPageState extends State<BirdsPage> {
  final BirdApi api = BirdApi();

  late Future<List<Bird>> birdsFuture;

  @override
  void initState() {
    super.initState();
    birdsFuture = api.getBirds();
  }

  void reloadBirds() {
    setState(() {
      birdsFuture = api.getBirds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bird Library'),
        actions: [
          IconButton(
            onPressed: reloadBirds,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<Bird>>(
        future: birdsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load birds:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: reloadBirds,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final birds = snapshot.data ?? [];

          if (birds.isEmpty) {
            return const Center(
              child: Text('No birds found'),
            );
          }

          return ListView.builder(
            itemCount: birds.length,
            itemBuilder: (context, index) {
              final bird = birds[index];

              return ListTile(
                leading: bird.imageUrl != null &&
                        bird.imageUrl!.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(bird.imageUrl!),
                      )
                    : const CircleAvatar(
                        child: Icon(Icons.flutter_dash),
                      ),
                title: Text(
                  bird.commonName ?? 'Unknown bird',
                ),
                subtitle: Text(
                  bird.scientificName ?? 'Scientific name unavailable',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BirdDetailsPage(bird: bird),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RecordingPage(),
            ),
          );
        },
        icon: const Icon(Icons.mic),
        label: const Text('Record bird'),
      ),
    );
  }
}