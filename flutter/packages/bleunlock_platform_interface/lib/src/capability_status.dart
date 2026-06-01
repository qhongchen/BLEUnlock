enum CapabilityStatusKind {
  supported,
  unsupported,
  permissionDenied,
  temporarilyUnavailable,
  poweredOff,
  missingSecret,
  failedWithReason,
  unknown,
}

class CapabilityStatus {
  const CapabilityStatus._(this.kind, [this.description]);

  const CapabilityStatus.supported() : this._(CapabilityStatusKind.supported);

  const CapabilityStatus.unsupported()
      : this._(CapabilityStatusKind.unsupported);

  const CapabilityStatus.permissionDenied([String? description])
      : this._(CapabilityStatusKind.permissionDenied, description);

  const CapabilityStatus.temporarilyUnavailable([String? description])
      : this._(CapabilityStatusKind.temporarilyUnavailable, description);

  const CapabilityStatus.poweredOff([String? description])
      : this._(CapabilityStatusKind.poweredOff, description);

  const CapabilityStatus.missingSecret([String? description])
      : this._(CapabilityStatusKind.missingSecret, description);

  const CapabilityStatus.failedWithReason(String description)
      : this._(CapabilityStatusKind.failedWithReason, description);

  const CapabilityStatus.unknown([String? description])
      : this._(CapabilityStatusKind.unknown, description);

  final CapabilityStatusKind kind;
  final String? description;

  bool get isUsable => kind == CapabilityStatusKind.supported;
}
