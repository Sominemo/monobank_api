/// Operation MCC code container
///
/// This code describes category of the transaction
///
/// Use extensions located in /mcc/extensions to add features
///
/// These are being distributed as dedicated extensions because they import
/// quite large datasets for work
class MCC {
  /// Creates the MCC holder
  ///
  /// See [MCC]
  const MCC(this.code);

  /// The MCC code (see ISO 18245)
  final int code;

  @override
  int get hashCode => 18 + 37 * code.hashCode;

  /// Comparation operator
  ///
  /// Only MCC objects are allowed to be compared
  @override
  bool operator ==(dynamic other) {
    if (other is! MCC) return false;
    return code == other.code;
  }
}
