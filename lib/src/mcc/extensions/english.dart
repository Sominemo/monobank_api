import '../mcc.dart';
import 'package:monobank_api/data/mcc/english.dart';

/// English pack for MCC
///
/// Descriptions of MCC codes in English
extension EnglishMCC on MCC {
  /// Description in English. Empty string if not found
  String get english =>
      MCCEnglishDataset[code.toString().padLeft(4, '0')] ?? '';
}
