
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'models/bird.dart';
import 'services/bird_api.dart';
import 'screens/bird_details_page.dart';
import 'screens/recording_page.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'screens/auth_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.initialize();
  runApp(const BirdsApp());
  return;
}

class BirdsApp extends StatelessWidget {
  const BirdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Bird Library',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: const BirdsPage(),
        );
      },
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

  void openRecordingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RecordingPage(),
      ),
    );
  }

  void openBirdDetails(Bird bird) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BirdDetailsPage(bird: bird),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decorationColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bird Library',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () => toggleTheme(context),
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            onPressed: reloadBirds,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          AnimatedBuilder(
            animation: AuthService.instance,
            builder: (context, _) {
              final user = AuthService.instance.currentUser;

              return IconButton(
                tooltip: user == null ? 'Sign in' : 'Account',
                icon: Icon(
                  user == null
                      ? Icons.login
                      : Icons.account_circle,
                ),
                onPressed: () async {
                  if (user == null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AuthPage(),
                      ),
                    );
                  } else {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Account'),
                        content: Text(
                          user['email']?.toString() ?? '',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, true),
                            child: const Text('Sign out'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true) {
                      await AuthService.instance.logout();
                    }
                  }
                },
              );
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          // Blurred gradient background.
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [
                                Color(0xFF1E2158),
                                Color(0xFF30266B),
                                Color(0xFF171638),
                              ]
                            : const [
                                Color(0xFFE2E5FB),
                                Color(0xFFC8C9F0),
                                Color(0xFFF3F0FF),
                              ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: -100,
                    right: -80,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 90,
                        sigmaY: 90,
                      ),
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF777FC1).withOpacity(0.55)
                              : const Color(0xFF929CEB).withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: 100,
                    left: -100,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 100,
                        sigmaY: 100,
                      ),
                      child: Container(
                        width: 350,
                        height: 350,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF514078).withOpacity(0.6)
                              : const Color(0xFFC0C7F6).withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Decorative bird and leaf.
          Positioned(
            top: 35,
            right: 25,
            child: IgnorePointer(
              child: Icon(
                Icons.flutter_dash,
                size: 170,
                color: decorationColor.withOpacity(0.045),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 10,
            child: IgnorePointer(
              child: Icon(
                Icons.eco_outlined,
                size: 130,
                color: decorationColor.withOpacity(0.04),
              ),
            ),
          ),

          FutureBuilder<List<Bird>>(
            future: birdsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
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
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                        ),
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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth < 600 ? 2 : 3;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          22, 24, 22, 20,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Discover the world of birds',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.7,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Explore beautiful species and listen '
                                    'to the sounds of nature.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.75),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: decorationColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.flutter_dash,
                                size: 34,
                                color: decorationColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Birds grid.
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            20, 0, 20, 24,
                          ),
                          itemCount: birds.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: 0.82,
                          ),
                          itemBuilder: (context, index) {
                            final bird = birds[index];

                            return BirdCard(
                              bird: bird,
                              onTap: () => openBirdDetails(bird),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: openRecordingPage,
        icon: const Icon(Icons.mic),
        label: const Text('Record bird'),
      ),
    );
  }
}

// Individual bird card with a hover animation.
class BirdCard extends StatefulWidget {
  final Bird bird;
  final VoidCallback onTap;

  const BirdCard({
    super.key,
    required this.bird,
    required this.onTap,
  });

  @override
  State<BirdCard> createState() => _BirdCardState();
}

class _BirdCardState extends State<BirdCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (event) {
        setState(() {
          isHovered = false;
        });
      },
      child: AnimatedScale(
        scale: isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: widget.bird.imageUrl != null &&
                            widget.bird.imageUrl!.isNotEmpty
                        ? Image.network(
                            widget.bird.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Center(
                                child: Icon(
                                  Icons.flutter_dash,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.flutter_dash,
                              size: 50,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bird.commonName ?? 'Unknown bird',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.bird.scientificName ??
                            'Scientific name unavailable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
