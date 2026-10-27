import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../models/sound.dart';
import '../services/bird_api.dart';
import '../widgets/sound_player_tile.dart';

class BirdDetailsPage extends StatefulWidget {
  final Bird bird;

  const BirdDetailsPage({
    super.key,
    required this.bird,
  });

  @override
  State<BirdDetailsPage> createState() => _BirdDetailsPageState();
}

class _BirdDetailsPageState extends State<BirdDetailsPage> {
  final BirdApi api = BirdApi();

  late Future<List<Sound>> soundsFuture;

  @override
  void initState() {
    super.initState();
    soundsFuture = api.getBirdSounds(widget.bird.birdId);
  }

  @override
  Widget build(BuildContext context) {
    final bird = widget.bird;

    return Scaffold(
      appBar: AppBar(
        title: Text(bird.commonName ?? 'Bird details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (bird.imageUrl != null && bird.imageUrl!.isNotEmpty)
            Image.network(
              bird.imageUrl!,
              height: 220,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image, size: 80),
            ),
          const SizedBox(height: 16),
          Text(
            bird.commonName ?? 'Unknown bird',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (bird.scientificName != null)
            Text(
              bird.scientificName!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          const SizedBox(height: 16),
          Text(bird.description ?? 'No description available.'),
          const SizedBox(height: 12),
          if (bird.wikipediaUrl != null)
            SelectableText('Wikipedia: ${bird.wikipediaUrl}'),
          const Divider(height: 32),
          Text(
            'Sounds',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          FutureBuilder<List<Sound>>(
            future: soundsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text('Could not load sounds: ${snapshot.error}');
              }

              final sounds = snapshot.data ?? [];

              if (sounds.isEmpty) {
                return const Text('No sounds available yet.');
              }

              return Column(
                children: sounds.map((sound) {
                  return SoundPlayerTile(sound: sound);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
