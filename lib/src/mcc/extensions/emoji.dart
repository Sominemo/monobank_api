import '../mcc.dart';
import 'package:monobank_api/data/mcc/emoji.dart';

/// Emoji dataset for MCC
///
/// Adds emojis for different MCC categories
extension EmojiMCC on MCC {
  /// Fallback emoji
  ///
  /// Is being used if no emoji is available in dataset
  static String fallbackEmoji = '💳';

  /// Related emoji
  String get emoji =>
      MCCEmojiDataset.keys.firstWhere((e) => MCCEmojiDataset[e].contains(code),
          orElse: () => fallbackEmoji);
}
