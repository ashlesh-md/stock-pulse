/// What a `SnapshotStore` writes: any JSON object stamped with the time it
/// was taken, which decides when a stored copy is too old to show.
abstract interface class Snapshot {
  DateTime get savedAt;

  Map<String, Object?> toJson();
}
