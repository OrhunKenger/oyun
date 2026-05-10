import 'package:flutter/material.dart';

class PixelModel {
  final int x;
  final int y;
  final String? ownerId;
  final String? ownerUsername;
  final int defensePower;

  PixelModel({
    required this.x,
    required this.y,
    this.ownerId,
    this.ownerUsername,
    required this.defensePower,
  });

  factory PixelModel.fromJson(Map<String, dynamic> json) => PixelModel(
        x: json['x'],
        y: json['y'],
        ownerId: json['owner_id'],
        ownerUsername: json['owner_username'],
        defensePower: json['defense_power'],
      );

  Color toColor(String? myUserId) {
    if (ownerId == null) return const Color(0xFF1A1A2E);
    if (ownerId == myUserId) return const Color(0xFF00FF88);
    // Farklı kullanıcılar için hash ile renk üret
    final hash = ownerId.hashCode;
    return Color(0xFF000000 | (hash & 0xFFFFFF)).withOpacity(0.9);
  }
}
