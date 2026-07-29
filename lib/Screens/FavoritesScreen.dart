import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/models.dart';
import '../api/repositories.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = FavoritesRepository.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await _repo.refresh();
    } catch (_) {
      // Keep whatever is cached; the empty state explains the rest.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthService.instance.session != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Favorites',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: !signedIn
          ? const Center(
              child: Text('Sign in to see your saved items.',
                  style: TextStyle(color: Colors.grey)),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<List<Listing>>(
                  valueListenable: _repo.favorites,
                  builder: (context, favorites, _) {
                    if (favorites.isEmpty) {
                      return const Center(
                        child: Text('No favorite items saved yet.',
                            style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final item = favorites[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.primaryImageUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey.shade300),
                                ),
                              ),
                              title: Text(item.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(item.displayPrice,
                                  style: const TextStyle(
                                      color: Colors.indigo,
                                      fontWeight: FontWeight.bold)),
                              trailing: IconButton(
                                icon: const Icon(Icons.favorite,
                                    color: Colors.red),
                                onPressed: () => _repo.toggle(item.id),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
