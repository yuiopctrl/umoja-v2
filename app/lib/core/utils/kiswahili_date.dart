/// Formats a date the way a Kiswahili-first UI should present it (e.g.
/// "21 Ago 2026") instead of a raw ISO string — display-only, the
/// underlying data model/storage format is untouched.
const _kiswahiliMonths = [
  '',
  'Jan',
  'Feb',
  'Mac',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatKiswahiliDate(DateTime date) {
  return '${date.day} ${_kiswahiliMonths[date.month]} ${date.year}';
}
