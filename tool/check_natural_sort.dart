import '../lib/utils/natural_sort.dart';

void main() {
  final names = [
    'dani_podmena_01.1.mp4',
    'dani_podmena_01.mp4',
    'dani_podmena_010.mp4',
    'dani_podmena_011.mp4',
    'dani_podmena_012.mp4',
    'dani_podmena_02.mp4',
    'dani_podmena_09.mp4',
  ]..sort(naturalCompare);
  for (final n in names) {
    print(n);
  }
}
