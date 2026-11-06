import 'package:flutter/material.dart';

import '../auth/partner_screen.dart';

/// Opens the partner-connection screen (used by every dead-end CTA so they
/// work even when a screen is opened standalone without callbacks).
void openPartnerConnection(BuildContext context) {
  Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => const PartnerScreen()));
}
