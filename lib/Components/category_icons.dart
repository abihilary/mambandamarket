import 'package:flutter/material.dart';

import '../api/models.dart';

/// Icon for a category, chosen by the `icon` key the database stores.
///
/// The old map lived inside HomeScreen and was keyed by slug, with one entry
/// per seeded category. That was fine for twelve of them and stopped being
/// fine at eighty-eight: every category added after it was written rendered
/// the same generic tag, and the picker could not reuse it at all because it
/// was private to another screen.
///
/// Keying on `categories.icon` instead means a category added in a migration
/// arrives with an icon already chosen, without an app release. The names are
/// lucide-style, matching what the seed writes; anything unrecognised still
/// falls back rather than throwing.
const Map<String, IconData> _byIconKey = {
  // Electronics
  'smartphone': Icons.smartphone,
  'laptop': Icons.laptop,
  'tv': Icons.tv_outlined,
  'washing-machine': Icons.local_laundry_service_outlined,
  'gamepad-2': Icons.sports_esports_outlined,
  'cable': Icons.cable,
  // Fashion
  'shirt': Icons.checkroom_outlined,
  'footprints': Icons.directions_walk_outlined,
  'shopping-bag': Icons.shopping_bag_outlined,
  'watch': Icons.watch_outlined,
  'scissors': Icons.content_cut_outlined,
  // Food & drink
  'utensils': Icons.restaurant_outlined,
  'shopping-basket': Icons.shopping_basket_outlined,
  'carrot': Icons.eco_outlined,
  'fish': Icons.set_meal_outlined,
  'cup-soda': Icons.local_drink_outlined,
  'utensils-crossed': Icons.dinner_dining_outlined,
  'croissant': Icons.bakery_dining_outlined,
  'chef-hat': Icons.room_service_outlined,
  // Beauty & health
  'sparkles': Icons.auto_awesome_outlined,
  'palette': Icons.palette_outlined,
  'droplet': Icons.water_drop_outlined,
  'flower-2': Icons.local_florist_outlined,
  'heart-pulse': Icons.monitor_heart_outlined,
  // Home & garden
  'sofa': Icons.weekend_outlined,
  'cooking-pot': Icons.soup_kitchen_outlined,
  'lamp': Icons.light_outlined,
  'bed': Icons.bed_outlined,
  'trees': Icons.park_outlined,
  'spray-can': Icons.cleaning_services_outlined,
  // Vehicles
  'car': Icons.directions_car_outlined,
  'bike': Icons.two_wheeler_outlined,
  'truck': Icons.local_shipping_outlined,
  // Property
  'home': Icons.home_outlined,
  'key': Icons.vpn_key_outlined,
  'map': Icons.map_outlined,
  'store': Icons.storefront_outlined,
  'bed-double': Icons.hotel_outlined,
  // Family & kids
  'baby': Icons.child_friendly_outlined,
  'blocks': Icons.toys_outlined,
  'backpack': Icons.backpack_outlined,
  // Sport
  'dumbbell': Icons.fitness_center_outlined,
  'trophy': Icons.emoji_events_outlined,
  'tent': Icons.forest_outlined,
  // Books & music
  'book-open': Icons.menu_book_outlined,
  'disc-3': Icons.album_outlined,
  'guitar': Icons.music_note_outlined,
  // Services
  'wrench': Icons.handyman_outlined,
  'camera': Icons.photo_camera_outlined,
  'graduation-cap': Icons.school_outlined,
  'printer': Icons.print_outlined,
  'briefcase': Icons.work_outline,
  'clock': Icons.schedule_outlined,
  // Agriculture
  'sprout': Icons.grass_outlined,
  'beef': Icons.kebab_dining_outlined,
  'wheat': Icons.agriculture_outlined,
  'tractor': Icons.agriculture_outlined,
  // Building
  'hammer': Icons.construction_outlined,
  'brick-wall': Icons.foundation_outlined,
  'pipette': Icons.plumbing_outlined,
  'plug-zap': Icons.electrical_services_outlined,
  // Pets, giveaways
  'paw-print': Icons.pets_outlined,
  'bone': Icons.pets_outlined,
  'gift': Icons.card_giftcard_outlined,
};

/// Kept for the twelve original categories, whose `icon` column predates this
/// map and may hold a key it does not know.
const Map<String, IconData> _bySlug = {
  'auto-rad': Icons.directions_car_outlined,
  'elektronik': Icons.devices_outlined,
  'mode': Icons.checkroom_outlined,
  'familie': Icons.child_friendly_outlined,
  'real-estate': Icons.home_outlined,
  'sport': Icons.sports_basketball_outlined,
  'jobs': Icons.work_outline,
  'moebel': Icons.weekend_outlined,
  'haustiere': Icons.pets_outlined,
  'dienstleistungen': Icons.handyman_outlined,
  'buecher-musik': Icons.menu_book_outlined,
  'verschenken': Icons.card_giftcard_outlined,
};

IconData categoryIcon(Category category) =>
    _byIconKey[category.icon] ??
    _bySlug[category.slug] ??
    Icons.sell_outlined;
