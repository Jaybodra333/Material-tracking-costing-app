class CostCalculation {
  final double rawMaterialCost;
  final double processingCost;
  final double manufacturingCost;
  final double desiredMarginPercentage;
  final double finalPrice;
  final double profitMargin;
  final int quantity;

  CostCalculation({
    required this.rawMaterialCost,
    required this.processingCost,
    required this.quantity,
    required this.desiredMarginPercentage,
  })  : manufacturingCost = rawMaterialCost + processingCost,
        finalPrice = (rawMaterialCost + processingCost) * (1 + desiredMarginPercentage / 100),
        profitMargin = ((rawMaterialCost + processingCost) * (desiredMarginPercentage / 100));

  double get unitCost => manufacturingCost / quantity;
  double get unitPrice => finalPrice / quantity;
  double get unitProfit => profitMargin / quantity;
  double get profitPercentage => (profitMargin / manufacturingCost) * 100;
}
