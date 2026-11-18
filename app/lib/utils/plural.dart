import 'package:intl/intl.dart';

/// "1 osoba", "3 osoby", "5 osób", "22 osoby".
String people(int n) =>
    '$n ${Intl.plural(n, one: 'osoba', few: 'osoby', many: 'osób', other: 'osoby', locale: 'pl')}';

/// Genitive, as in "na podstawie 1 tygodnia" / "3 tygodni".
String weeksGenitive(int n) => n == 1 ? '1 tygodnia' : '$n tygodni';
