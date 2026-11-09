import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_sheet.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';

/// Opens the buy/sell sheet. It closes when the order is placed; a failure
/// shows inline above Confirm, never as a snackbar under the sheet.
Future<void> showOrderSheet(BuildContext context, OrderDraftSeed seed) =>
    showSpSheet<void>(
      context,
      builder: (sheetContext) {
        final height = min(MediaQuery.sizeOf(sheetContext).height * 0.9, 720.0);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: height,
            child: OrderSheet(seed: seed),
          ),
        );
      },
    );
