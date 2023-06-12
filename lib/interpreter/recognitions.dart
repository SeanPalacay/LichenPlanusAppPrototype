import 'dart:ui';

/// Represents the recognition output from the model
class Recognition {
  int id;
  String label;
  double score;
  Rect? location;
  Recognition(this.id, this.label, this.score, this.location);
}
