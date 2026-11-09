class StudySeries {
  StudySeries({
    required Map<String, List<double?>> lines,
    required this.notEnoughData,
  }) : lines = Map.unmodifiable({
         for (final entry in lines.entries)
           entry.key: List<double?>.unmodifiable(entry.value),
       });
  final Map<String, List<double?>> lines;
  final bool notEnoughData;
}
