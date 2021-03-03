import '../mcc.dart';
import 'emoji.dart';
import 'package:monobank_api/data/mcc/mcc_visuals_dataset.dart';

/// Visuals pack for MCC
///
/// Adds getters with visual assets related to the MCC code
/// (emoji, Material icon name, color)
extension VisualsMCC on MCC {
  /// Fallback if no visuals found
  static Map<String, String> fallbackVisual = {
    'icon': 'credit_card',
    'color': '#607d8b'
  };

  /// Get related visual assets as a map
  Map<String, String> get visuals => MCCVisualsDataset[emoji] ?? fallbackVisual;

  /// Get possible color for use
  String get color => visuals['color'] ?? 'crefit_card';

  /// Get Material icon name: https://material.io/icons
  String get icon => visuals['icon'] ?? '#607d8b';
}
