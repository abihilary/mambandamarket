import 'package:flutter/material.dart';
import '../Service/AppServices.dart';


class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Favorites', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<List<Map<String, String>>>(
        valueListenable: FavoriteService().favoritesNotifier,
        builder: (context, favorites, _) {
          if (favorites.isEmpty) {
            return const Center(
              child: Text('No favorite items saved yet.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final item = favorites[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item['imageUrl']!, width: 50, height: 50, fit: BoxFit.cover),
                  ),
                  title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item['price']!, style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () => FavoriteService().toggleFavorite(item),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}