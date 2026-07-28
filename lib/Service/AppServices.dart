import 'package:flutter/foundation.dart';
import 'ChatService.dart'; // Uses the ChatService created earlier

// FAVORITES SERVICE
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  final ValueNotifier<List<Map<String, String>>> favoritesNotifier =
  ValueNotifier([
    {
      "id": "f1",
      "title": "Toyota Land Cruiser V8",
      "price": "65.000 €",
      "imageUrl": "https://picsum.photos/300/300?random=1",
    }
  ]);

  void toggleFavorite(Map<String, String> item) {
    final current = List<Map<String, String>>.from(favoritesNotifier.value);
    final exists = current.any((element) => element['id'] == item['id']);

    if (exists) {
      current.removeWhere((element) => element['id'] == item['id']);
    } else {
      current.add(item);
    }
    favoritesNotifier.value = current;
  }
}

// USER / ACCOUNT SERVICE
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final ValueNotifier<Map<String, dynamic>> currentUserNotifier =
  ValueNotifier({
    'id': 'usr_99',
    'name': 'Alex Johnson',
    'email': 'alex@example.com',
    'isBusiness': true,
    'avatarUrl': 'https://picsum.photos/100/100?logo=1',
  });
}