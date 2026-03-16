// ignore_for_file: avoid_print
// lib/models/shop_item.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final String category;
  final List<String>? biomes;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.biomes,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: json['price'] as int,
      category: json['category'] as String,
      biomes: json['biomes'] != null ? List<String>.from(json['biomes']) : null,
    );
  }

  static Future<List<ShopItem>> loadAll() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/shop_items.json',
      );
      final List<dynamic> data = json.decode(response);
      return data.map((item) => ShopItem.fromJson(item)).toList();
    } catch (e) {
      print('Error loading shop items: $e');
      return [];
    }
  }
}
