import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/widgets/status_pill.dart';
import 'package:flutter/material.dart';

class CapabilityRow extends StatelessWidget {
  const CapabilityRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          StatusPill(label: zhDisplayText(value), icon: Icons.info_outline),
        ],
      ),
    );
  }
}
