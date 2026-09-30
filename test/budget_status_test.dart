import 'package:dompet_pintar/core/budget_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tanpa anggaran selalu ok', () {
    expect(budgetStatusOf(0, null), BudgetStatus.ok);
    expect(budgetStatusOf(1000000, null), BudgetStatus.ok);
  });

  test('di bawah 80% adalah ok', () {
    expect(budgetStatusOf(799999, 1000000), BudgetStatus.ok);
  });

  test('tepat 80% adalah warning', () {
    expect(budgetStatusOf(800000, 1000000), BudgetStatus.warning);
  });

  test('antara 80% dan 100% adalah warning', () {
    expect(budgetStatusOf(950000, 1000000), BudgetStatus.warning);
  });

  test('tepat 100% belum over', () {
    expect(budgetStatusOf(1000000, 1000000), BudgetStatus.warning);
  });

  test('lebih dari 100% adalah over', () {
    expect(budgetStatusOf(1000001, 1000000), BudgetStatus.over);
    expect(budgetStatusOf(2000000, 1000000), BudgetStatus.over);
  });
}
