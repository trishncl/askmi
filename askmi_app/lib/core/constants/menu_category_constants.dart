import 'package:flutter/material.dart';

/// Firestore stores an icon as a short string key (IconData isn't
/// serializable), resolved back to a real icon here. Keeping the map in
/// one place means the Add/Edit Category picker and every place a
/// category icon renders (menu cards, filters) can never disagree.
const Map<String, IconData> kCategoryIcons = {
  'ramen': Icons.ramen_dining_rounded,
  'breakfast': Icons.egg_alt_rounded,
  'noodles': Icons.dinner_dining_rounded,
  'addons': Icons.add_circle_outline_rounded,
  'tray': Icons.rice_bowl_rounded,
  'dessert': Icons.icecream_rounded,
  'drink': Icons.local_drink_rounded,
  'fastfood': Icons.fastfood_rounded,
  'grill': Icons.outdoor_grill_rounded,
  'soup': Icons.soup_kitchen_rounded,
  'other': Icons.restaurant_menu_rounded,
};

const String kDefaultCategoryIconKey = 'other';

IconData iconForKey(String key) => kCategoryIcons[key] ?? kCategoryIcons[kDefaultCategoryIconKey]!;

/// Shown before an Owner has configured any categories in Firestore, so
/// Add/Edit Menu Item and the filter bar aren't empty on a fresh project.
/// (name, iconKey, displayOrder)
const List<(String, String, int)> kDefaultCategorySeed = [
  ('Lomi', 'ramen', 0),
  ('All Day Breakfast', 'breakfast', 1),
  ('Pansit', 'noodles', 2),
  ('Add-ons', 'addons', 3),
  ('Bilao', 'tray', 4),
  ('Desserts', 'dessert', 5),
  ('Beverages', 'drink', 6),
];