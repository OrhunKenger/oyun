import 'package:flutter/material.dart';

class TerritoryModel {
  final String userId;
  final String username;
  final int homeX;
  final int homeY;
  final double powerScore;
  final int territoryRadius;
  final int colorHue; // 0-360

  TerritoryModel({
    required this.userId,
    required this.username,
    required this.homeX,
    required this.homeY,
    required this.powerScore,
    required this.territoryRadius,
    required this.colorHue,
  });

  factory TerritoryModel.fromJson(Map<String, dynamic> json) => TerritoryModel(
        userId: json['user_id'],
        username: json['username'],
        homeX: json['home_x'],
        homeY: json['home_y'],
        powerScore: (json['power_score'] as num).toDouble(),
        territoryRadius: json['territory_radius'],
        colorHue: json['color_hue'],
      );

  /// Pikselin (px, py) bu territory'e ait olup olmadığını kontrol eder (Chebyshev distance)
  bool contains(int px, int py) {
    return (px - homeX).abs() <= territoryRadius && (py - homeY).abs() <= territoryRadius;
  }

  /// Territory'nin rengini döner - power yükseldikçe daha parlak
  Color toColor(String myUserId) {
    final hue = colorHue.toDouble();
    final saturation = 0.7;
    final lightness = userId == myUserId
        ? 0.45 + (powerScore / 500).clamp(0.0, 0.25)
        : 0.25 + (powerScore / 500).clamp(0.0, 0.20);
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}

// Eski PixelModel — geriye dönük uyumluluk için kısa alias
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
        defensePower: json['defense_power'] ?? 0,
      );
}
