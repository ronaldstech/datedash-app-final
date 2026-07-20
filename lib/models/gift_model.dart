import 'package:flutter/material.dart';

class GiftItem {
  final String id;
  final String icon;
  final String name;
  final int cost;
  final Color color;

  GiftItem({
    required this.id,
    required this.icon,
    required this.name,
    required this.cost,
    required this.color,
  });
}

class GiftData {
  static final List<GiftItem> gifts = [
    GiftItem(
      id: 'rose',
      icon: '🌹',
      name: 'Rose',
      cost: 50,
      color: Colors.red,
    ),
    GiftItem(
      id: 'heart',
      icon: '❤️',
      name: 'Heart',
      cost: 100,
      color: Colors.pink,
    ),
    GiftItem(
      id: 'chocolate',
      icon: '🍫',
      name: 'Chocolate',
      cost: 250,
      color: Colors.brown,
    ),
    GiftItem(
      id: 'teddy',
      icon: '🧸',
      name: 'Teddy Bear',
      cost: 500,
      color: Colors.orange,
    ),
    GiftItem(
      id: 'champagne',
      icon: '🥂',
      name: 'Champagne',
      cost: 1000,
      color: Colors.amber,
    ),
    GiftItem(
      id: 'ring',
      icon: '💍',
      name: 'Diamond Ring',
      cost: 5000,
      color: Colors.cyan,
    ),
  ];
}
