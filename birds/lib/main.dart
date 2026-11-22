
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
          title: 'Birds',
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

enum BirdSortMode { id, asc, desc }

class _BirdsPageState extends State<BirdsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final BirdApi api = BirdApi();
  late Future<List<Bird>> birdsFuture;
  BirdSortMode _sortMode = BirdSortMode.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    birdsFuture = api.getBirds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void reloadBirds() {
    setState(() {
      birdsFuture = api.getBirds();
    });
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
        titleSpacing: 12,
        title: Row(
          children: [
            const Text(
              'Birds',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.label,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelStyle: const TextStyle(fontSize: 11, height: 1),
                unselectedLabelStyle: const TextStyle(fontSize: 11, height: 1),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.library_books_outlined, size: 16),
                    text: 'Library',
                  ),
                  Tab(
                    icon: Icon(Icons.graphic_eq, size: 16),
                    text: 'Recognize',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => toggleTheme(context),
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              size: 28,
            ),
            tooltip: 'Toggle theme',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 50,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: reloadBirds,
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: 'Refresh',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 50,
            ),
          ),
          const SizedBox(width: 8),
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
                  size: 28,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 50,
                  minHeight: 50,
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
          const SizedBox(width: 6),
        ],
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          Stack(
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
                              ? const Color(0xFF777FC1).withValues(alpha: 0.55)
                              : const Color(0xFF929CEB).withValues(alpha: 0.4),
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
                              ? const Color(0xFF514078).withValues(alpha: 0.6)
                              : const Color(0xFFC0C7F6).withValues(alpha: 0.5),
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
                color: decorationColor.withValues(alpha: 0.045),
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
                color: decorationColor.withValues(alpha: 0.04),
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

              final birds = [...?snapshot.data];

              // ID mode preserves the API's original order.
              if (_sortMode == BirdSortMode.asc) {
                birds.sort((a, b) => (a.commonName ?? '')
                    .toLowerCase()
                    .compareTo((b.commonName ?? '').toLowerCase()));
              } else if (_sortMode == BirdSortMode.desc) {
                birds.sort((a, b) => (b.commonName ?? '')
                    .toLowerCase()
                    .compareTo((a.commonName ?? '').toLowerCase()));
              }

              if (birds.isEmpty) {
                return const Center(
                  child: Text('No birds found'),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1200
                      ? 5
                      : constraints.maxWidth >= 600
                          ? 3
                          : 2;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome section.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, 12,
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
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Explore beautiful species and listen '
                                    'to the sounds of nature.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withValues(alpha: 0.75),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<BirdSortMode>(
                              tooltip: 'Sort birds',
                              initialValue: _sortMode,
                              onSelected: (mode) {
                                setState(() => _sortMode = mode);
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: BirdSortMode.id,
                                  child: Text('By ID (default order)'),
                                ),
                                PopupMenuItem(
                                  value: BirdSortMode.asc,
                                  child: Text('Name: A–Z'),
                                ),
                                PopupMenuItem(
                                  value: BirdSortMode.desc,
                                  child: Text('Name: Z–A'),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: decorationColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sort,
                                  size: 23,
                                  color: decorationColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Birds grid.
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            12, 0, 12, 20,
                          ),
                          itemCount: birds.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
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
          const RecordingPage(),
        ],
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
                        ? CachedNetworkImage(
                            imageUrl: widget.bird.imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 700,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.flutter_dash, size: 34),
                            ),
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
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bird.commonName ?? 'Unknown bird',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
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
