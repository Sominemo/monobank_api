import '../mcc.dart';
import 'package:monobank_api/data/mcc/mcc_emoji_dataset.dart';

/// Emoji dataset for MCC
///
/// Adds emojis for different MCC categories
extension EmojiMCC on MCC {
  /// Fallback emoji
  ///
  /// Is being used if no emoji is available in dataset
  static String fallbackEmoji = '💳';

  /// Related emoji
  String get emoji => MCCEmojiDataset.keys.firstWhere((e) {
        final emoji = MCCEmojiDataset[e];

        if (emoji == null) return false;
        return emoji.contains(code);
      }, orElse: () => fallbackEmoji);
}
