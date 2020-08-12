import '../mcc.dart';
import 'package:monobank_api/data/mcc/ukrainian.dart';

/// Ukrainian pack for MCC
///
/// Descriptions of MCC codes in Ukrainian
extension UkrainianMCC on MCC {
  /// Description in Ukrainian. Empty string if not found
  String get ukrainian =>
      MCCUkrainianDataset[code.toString().padLeft(4, '0')] ?? '';
}
