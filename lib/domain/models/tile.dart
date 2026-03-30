import 'package:flutter/material.dart';

@immutable
class Tile {
  final String id;
  final int row;
  final int col;
  final Color color;
  final String letter;
  final int value;

  const Tile({
    required this.id,
    required this.row,
    required this.col,
    required this.color,
    required this.letter,
    required this.value,
  });

  Tile copyWith({
    int? row,
    int? col,
    Color? color,
    String? letter,
    int? value,
  }) {
    return Tile(
      id: id,
      row: row ?? this.row,
      col: col ?? this.col,
      color: color ?? this.color,
      letter: letter ?? this.letter,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          row == other.row &&
          col == other.col &&
          color == other.color &&
          letter == other.letter &&
          value == other.value;

  @override
  int get hashCode =>
      id.hashCode ^
      row.hashCode ^
      col.hashCode ^
      color.hashCode ^
      letter.hashCode ^
      value.hashCode;

  @override
  String toString() {
    return 'Tile(id: $id, row: $row, col: $col, letter: $letter, value: $value)';
  }
}
