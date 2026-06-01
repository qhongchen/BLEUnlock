class RssiSmoother {
  RssiSmoother({this.windowSize = 5}) {
    if (windowSize <= 0) {
      throw ArgumentError.value(windowSize, 'windowSize', 'must be positive');
    }
  }

  final int windowSize;
  final List<int> _samples = [];

  int add(int rssi) {
    _samples.add(rssi);
    if (_samples.length > windowSize) {
      _samples.removeAt(0);
    }

    final total = _samples.fold<int>(0, (sum, value) => sum + value);
    return (total / _samples.length).round();
  }

  void clear() {
    _samples.clear();
  }
}
