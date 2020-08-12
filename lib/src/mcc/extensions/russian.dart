import '../mcc.dart';
import 'package:monobank_api/data/mcc/russian.dart';

/// Russian pack for MCC
///
/// Descriptions of MCC codes in Russian
extension RussianMCC on MCC {
  /// Description in Russian. Empty string if not found
  String get russian =>
      MCCRussianDataset[code.toString().padLeft(4, '0')] ?? '';
}
