import 'package:flutter/material.dart';

enum ReportKpiType {
  netSales,
  grossSales,
  totalOrders,
  averageOrder,
  discounts,
  tax,
  refunds,
  expectedCash,
}

enum ProductTrend { up, down, neutral }

enum TransactionReportStatus { paid, refunded }

enum PaymentMethodType { card, cash, digitalWallet, split }

enum ReportOrderType { dineIn, takeaway, delivery }

class ReportKpiItem {
  const ReportKpiItem({
    required this.type,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });
  final ReportKpiType type;
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
}

class HourlySalesPoint {
  const HourlySalesPoint({
    required this.label,
    required this.value,
    this.isPeak = false,
  });
  final String label;
  final double value;
  final bool isPeak;
}

class PaymentMethodReportItem {
  const PaymentMethodReportItem({
    required this.type,
    required this.label,
    required this.percent,
    required this.value,
    required this.color,
  });
  final PaymentMethodType type;
  final String label;
  final int percent;
  final String value;
  final Color color;
}

class OrderTypeReportItem {
  const OrderTypeReportItem({
    required this.type,
    required this.label,
    required this.count,
    required this.value,
    required this.icon,
  });
  final ReportOrderType type;
  final String label;
  final int count;
  final String value;
  final IconData icon;
}

class TopSellingProductItem {
  const TopSellingProductItem({
    required this.name,
    required this.category,
    required this.quantitySold,
    required this.revenueDisplay,
    required this.trend,
  });
  final String name;
  final String category;
  final int quantitySold;
  final String revenueDisplay;
  final ProductTrend trend;
}

class RefundReportItem {
  const RefundReportItem({
    required this.orderNumber,
    required this.reason,
    required this.details,
    required this.value,
  });
  final String orderNumber;
  final String reason;
  final String details;
  final String value;
}

class DiscountUsageReportItem {
  const DiscountUsageReportItem({
    required this.name,
    required this.type,
    required this.usageCount,
    required this.totalValueDisplay,
    required this.revenueAfterDisplay,
  });
  final String name;
  final String type;
  final int usageCount;
  final String totalValueDisplay;
  final String revenueAfterDisplay;
}

class RecentTransactionReportItem {
  const RecentTransactionReportItem({
    required this.orderNumber,
    required this.time,
    required this.customer,
    required this.orderType,
    required this.payment,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.status,
  });
  final String orderNumber;
  final String time;
  final String customer;
  final String orderType;
  final String payment;
  final String subtotal;
  final String discount;
  final String tax;
  final String total;
  final TransactionReportStatus status;
}

class DailyReportData {
  const DailyReportData({
    required this.kpis,
    required this.hourlySales,
    required this.paymentMethods,
    required this.orderTypes,
    required this.topProducts,
    required this.refunds,
    required this.discounts,
    required this.transactions,
  });
  final List<ReportKpiItem> kpis;
  final List<HourlySalesPoint> hourlySales;
  final List<PaymentMethodReportItem> paymentMethods;
  final List<OrderTypeReportItem> orderTypes;
  final List<TopSellingProductItem> topProducts;
  final List<RefundReportItem> refunds;
  final List<DiscountUsageReportItem> discounts;
  final List<RecentTransactionReportItem> transactions;

  factory DailyReportData.mock() => const DailyReportData(
    kpis: <ReportKpiItem>[
      ReportKpiItem(
        type: ReportKpiType.netSales,
        label: 'Net Sales',
        value: '\$4,250.00',
        icon: Icons.trending_up_outlined,
      ),
      ReportKpiItem(
        type: ReportKpiType.grossSales,
        label: 'Gross Sales',
        value: '\$4,632.50',
      ),
      ReportKpiItem(
        type: ReportKpiType.totalOrders,
        label: 'Total Orders',
        value: '142',
      ),
      ReportKpiItem(
        type: ReportKpiType.averageOrder,
        label: 'Avg Order Value',
        value: '\$8.77',
      ),
      ReportKpiItem(
        type: ReportKpiType.discounts,
        label: 'Discounts',
        value: '-\$125.00',
        valueColor: Color(0xFFD97706),
      ),
      ReportKpiItem(
        type: ReportKpiType.tax,
        label: 'Tax Collected',
        value: '\$382.50',
      ),
      ReportKpiItem(
        type: ReportKpiType.refunds,
        label: 'Refunds',
        value: '-\$42.50',
        valueColor: Color(0xFFBA1A1A),
      ),
      ReportKpiItem(
        type: ReportKpiType.expectedCash,
        label: 'Expected Cash',
        value: '\$650.00',
        icon: Icons.point_of_sale_outlined,
      ),
    ],
    hourlySales: <HourlySalesPoint>[
      HourlySalesPoint(label: '6a', value: 180),
      HourlySalesPoint(label: '7a', value: 340),
      HourlySalesPoint(label: '8a', value: 610),
      HourlySalesPoint(label: '9a', value: 845.5, isPeak: true),
      HourlySalesPoint(label: '10a', value: 680),
      HourlySalesPoint(label: '11a', value: 550),
      HourlySalesPoint(label: '12p', value: 430),
      HourlySalesPoint(label: '1p', value: 360),
      HourlySalesPoint(label: '2p', value: 280),
      HourlySalesPoint(label: '3p', value: 220),
    ],
    paymentMethods: <PaymentMethodReportItem>[
      PaymentMethodReportItem(
        type: PaymentMethodType.card,
        label: 'Card',
        percent: 65,
        value: '\$2,762.50',
        color: Color(0xFF3B2417),
      ),
      PaymentMethodReportItem(
        type: PaymentMethodType.cash,
        label: 'Cash',
        percent: 20,
        value: '\$850.00',
        color: Color(0xFF805437),
      ),
      PaymentMethodReportItem(
        type: PaymentMethodType.digitalWallet,
        label: 'Digital Wallet',
        percent: 12,
        value: '\$510.00',
        color: Color(0xFFF0B68D),
      ),
      PaymentMethodReportItem(
        type: PaymentMethodType.split,
        label: 'Split',
        percent: 3,
        value: '\$127.50',
        color: Color(0xFFE7E2DA),
      ),
    ],
    orderTypes: <OrderTypeReportItem>[
      OrderTypeReportItem(
        type: ReportOrderType.dineIn,
        label: 'DINE-IN',
        count: 84,
        value: '\$2,840.00',
        icon: Icons.table_restaurant_outlined,
      ),
      OrderTypeReportItem(
        type: ReportOrderType.takeaway,
        label: 'TAKEAWAY',
        count: 45,
        value: '\$980.50',
        icon: Icons.shopping_bag_outlined,
      ),
      OrderTypeReportItem(
        type: ReportOrderType.delivery,
        label: 'DELIVERY',
        count: 13,
        value: '\$429.50',
        icon: Icons.delivery_dining_outlined,
      ),
    ],
    topProducts: <TopSellingProductItem>[
      TopSellingProductItem(
        name: 'Vanilla Latte',
        category: 'Espresso',
        quantitySold: 42,
        revenueDisplay: '\$210.00',
        trend: ProductTrend.up,
      ),
      TopSellingProductItem(
        name: 'Almond Croissant',
        category: 'Pastries',
        quantitySold: 38,
        revenueDisplay: '\$171.00',
        trend: ProductTrend.up,
      ),
      TopSellingProductItem(
        name: 'Caramel Macchiato',
        category: 'Espresso',
        quantitySold: 35,
        revenueDisplay: '\$192.50',
        trend: ProductTrend.up,
      ),
      TopSellingProductItem(
        name: 'Avocado Toast',
        category: 'Food',
        quantitySold: 24,
        revenueDisplay: '\$288.00',
        trend: ProductTrend.neutral,
      ),
      TopSellingProductItem(
        name: 'Cold Brew',
        category: 'Iced Coffee',
        quantitySold: 20,
        revenueDisplay: '\$90.00',
        trend: ProductTrend.up,
      ),
    ],
    refunds: <RefundReportItem>[
      RefundReportItem(
        orderNumber: '#1042',
        reason: 'Wrong Item',
        details: '10:15 AM • Jane D.',
        value: '-\$12.50',
      ),
      RefundReportItem(
        orderNumber: '#1088',
        reason: 'Quality Issue',
        details: '1:30 PM • Mark S.',
        value: '-\$25.00',
      ),
      RefundReportItem(
        orderNumber: '#1102',
        reason: 'Accidental Charge',
        details: '2:45 PM • Sarah L.',
        value: '-\$5.00',
      ),
    ],
    discounts: <DiscountUsageReportItem>[
      DiscountUsageReportItem(
        name: 'Morning Rush 10%',
        type: 'Percentage',
        usageCount: 18,
        totalValueDisplay: '-\$45.50',
        revenueAfterDisplay: '\$409.50',
      ),
      DiscountUsageReportItem(
        name: 'Staff Meal',
        type: 'Fixed Amount',
        usageCount: 5,
        totalValueDisplay: '-\$50.00',
        revenueAfterDisplay: '\$0.00',
      ),
      DiscountUsageReportItem(
        name: 'Loyalty Free Coffee',
        type: 'Item 100%',
        usageCount: 8,
        totalValueDisplay: '-\$24.00',
        revenueAfterDisplay: '\$0.00',
      ),
      DiscountUsageReportItem(
        name: 'Student Discount',
        type: 'Percentage',
        usageCount: 3,
        totalValueDisplay: '-\$5.50',
        revenueAfterDisplay: '\$49.50',
      ),
    ],
    transactions: <RecentTransactionReportItem>[
      RecentTransactionReportItem(
        orderNumber: '#1142',
        time: '3:45 PM',
        customer: 'Walk-in',
        orderType: 'Takeaway',
        payment: 'Card',
        subtotal: '\$12.50',
        discount: '-\$0.00',
        tax: '\$1.06',
        total: '\$13.56',
        status: TransactionReportStatus.paid,
      ),
      RecentTransactionReportItem(
        orderNumber: '#1141',
        time: '3:38 PM',
        customer: 'Emma T.',
        orderType: 'Dine-in',
        payment: 'Cash',
        subtotal: '\$24.00',
        discount: '-\$2.40',
        tax: '\$1.84',
        total: '\$23.44',
        status: TransactionReportStatus.paid,
      ),
      RecentTransactionReportItem(
        orderNumber: '#1140',
        time: '3:25 PM',
        customer: 'Walk-in',
        orderType: 'Takeaway',
        payment: 'Wallet',
        subtotal: '\$8.50',
        discount: '-\$0.00',
        tax: '\$0.72',
        total: '\$9.22',
        status: TransactionReportStatus.paid,
      ),
      RecentTransactionReportItem(
        orderNumber: '#1139',
        time: '3:15 PM',
        customer: 'Michael R.',
        orderType: 'Delivery',
        payment: 'Card',
        subtotal: '\$32.00',
        discount: '-\$0.00',
        tax: '\$2.72',
        total: '\$34.72',
        status: TransactionReportStatus.refunded,
      ),
      RecentTransactionReportItem(
        orderNumber: '#1138',
        time: '3:02 PM',
        customer: 'Walk-in',
        orderType: 'Dine-in',
        payment: 'Card',
        subtotal: '\$14.50',
        discount: '-\$0.00',
        tax: '\$1.23',
        total: '\$15.73',
        status: TransactionReportStatus.paid,
      ),
    ],
  );
}
