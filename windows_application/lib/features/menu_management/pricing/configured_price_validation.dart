import 'package:flutter/widgets.dart';

import '../../../app/localization/localization_extensions.dart';

const String configuredSellPriceMustBePositive =
    'configured_sell_price_must_be_positive';

String? localizedConfiguredPriceError(BuildContext context, String? error) =>
    error == configuredSellPriceMustBePositive
    ? context.l10n.configuredSellPriceMustBePositive
    : error;
