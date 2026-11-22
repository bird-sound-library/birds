
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/cache_service.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(bird.commonName ?? 'Bird details'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline),
            tooltip: 'Bird information',
          ),
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF1E2158),
                    Color(0xFF292653),
                    Color(0xFF171638),
                  ]
                : const [
                    Color(0xFFE2E5FB),
                    Color(0xFFF3F0FF),
                    Color(0xFFFFFFFF),
                  ],
          ),
        ),

        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Bird photograph.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 650,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: double.infinity,
                    height: 320,
                    color: colors.surface,
                    child: bird.imageUrl != null &&
                            bird.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: bird.imageUrl!,
                            cacheManager: BirdCacheService.imageCache,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                color: colors.primary,
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.flutter_dash,
                              size: 70,
                              color: colors.primary,
                            ),
                          )
                        : Icon(
                            Icons.flutter_dash,
                            size: 70,
                            color: colors.primary,
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Bird name and scientific name.
            Text(
              bird.commonName ?? 'Unknown bird',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.7,
              ),
            ),

            if (bird.scientificName != null) ...[
              const SizedBox(height: 6),
              Text(
                bird.scientificName!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colors.primary,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // About section.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'About this bird',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    bird.description ?? 'No description available.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
                  ),

                  if (bird.wikipediaUrl != null) ...[
                    const SizedBox(height: 18),
                    Divider(
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.language,
                          color: colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            'Wikipedia: ${bird.wikipediaUrl}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Sounds section.
            Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: colors.primary,
                  size: 27,
                ),
                const SizedBox(width: 10),
                Text(
                  'Bird sounds',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Listen to recordings of this species',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),

            const SizedBox(height: 16),

            FutureBuilder<List<Sound>>(
              future: soundsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 35,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Could not load sounds.',
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              soundsFuture =
                                  api.getBirdSounds(bird.birdId);
                            });
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }

                final sounds = snapshot.data ?? [];

                if (sounds.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.music_off_rounded,
                          size: 36,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No sounds available yet.',
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: sounds.map((sound) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoundPlayerTile(sound: sound),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
