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
      id: json['id'].toString(),
      name: json['name'].toString(),
      description: json['description'].toString(),
      price: (json['price'] as num? ?? 0).toInt(),
      category: json['category'].toString(),
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
