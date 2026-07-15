class BillingCycle {
  static const mensual = 'mensual';
  static const trimestral = 'trimestral';
  static const anual = 'anual';

  static const all = [mensual, trimestral, anual];

  static int months(String billingCycle) {
    switch (billingCycle) {
      case trimestral:
        return 3;
      case anual:
        return 12;
      case mensual:
      default:
        return 1;
    }
  }

  static int discountPercent(String billingCycle) {
    switch (billingCycle) {
      case trimestral:
        return 10;
      case anual:
        return 20;
      case mensual:
      default:
        return 0;
    }
  }

  static String label(String billingCycle) {
    switch (billingCycle) {
      case trimestral:
        return 'Trimestral';
      case anual:
        return 'Anual';
      case mensual:
      default:
        return 'Mensual';
    }
  }
}

class SubscriptionPlan {
  final String id;
  final String nombre;
  final double precioMensual;
  final int maxColaboradores;
  final String clientesRecomendados;
  final List<String> beneficios;
  final bool recomendado;

  const SubscriptionPlan({
    required this.id,
    required this.nombre,
    required this.precioMensual,
    required this.maxColaboradores,
    required this.clientesRecomendados,
    required this.beneficios,
    this.recomendado = false,
  });

  SubscriptionPlanPrice priceFor(String billingCycle) {
    final months = BillingCycle.months(billingCycle);
    final discountPercent = BillingCycle.discountPercent(billingCycle);
    final originalPrice = SubscriptionPlans.money(precioMensual * months);
    final finalPrice = SubscriptionPlans.calcularPrecioFinal(
      precioMensual: precioMensual,
      billingCycle: billingCycle,
    );

    return SubscriptionPlanPrice(
      planId: id,
      planNombre: nombre,
      billingCycle: billingCycle,
      discountPercent: discountPercent,
      originalPrice: originalPrice,
      finalPrice: finalPrice,
      currencyCode: SubscriptionPlans.currencyCode,
    );
  }
}

class SubscriptionPlanPrice {
  final String planId;
  final String planNombre;
  final String billingCycle;
  final int discountPercent;
  final double originalPrice;
  final double finalPrice;
  final String currencyCode;

  const SubscriptionPlanPrice({
    required this.planId,
    required this.planNombre,
    required this.billingCycle,
    required this.discountPercent,
    required this.originalPrice,
    required this.finalPrice,
    required this.currencyCode,
  });

  double get ahorro => SubscriptionPlans.money(originalPrice - finalPrice);
  bool get hasDiscount => discountPercent > 0;

  Map<String, Object?> toMap() {
    return {
      'plan_id': planId,
      'plan_nombre': planNombre,
      'billing_cycle': billingCycle,
      'discount_percent': discountPercent,
      'original_price': originalPrice,
      'final_price': finalPrice,
      'currency_code': currencyCode,
    };
  }
}

class SubscriptionPlans {
  static const currencyCode = 'USD';

  static const basico = SubscriptionPlan(
    id: 'basico',
    nombre: 'Basico',
    precioMensual: 4.99,
    maxColaboradores: 3,
    clientesRecomendados: 'Hasta 1,000 clientes recomendados',
    beneficios: [
      'Reportes basicos',
      'Soporte estandar',
      'Sincronizacion normal',
    ],
  );

  static const crecimiento = SubscriptionPlan(
    id: 'crecimiento',
    nombre: 'Crecimiento',
    precioMensual: 12.99,
    maxColaboradores: 7,
    clientesRecomendados: 'Hasta 5,000 clientes recomendados',
    beneficios: [
      'Reportes avanzados',
      'Exportacion avanzada futura',
      'Sincronizacion prioritaria',
    ],
    recomendado: true,
  );

  static const empresarial = SubscriptionPlan(
    id: 'empresarial',
    nombre: 'Empresarial',
    precioMensual: 20.99,
    maxColaboradores: 15,
    clientesRecomendados: 'Hasta 100,000+ clientes recomendados',
    beneficios: [
      'Reportes completos',
      'Prioridad maxima de sincronizacion',
      'Preparado para multi sucursal futura',
    ],
  );

  static const all = [basico, crecimiento, empresarial];

  static List<SubscriptionPlanPrice> pricesForCycle(String billingCycle) {
    return all.map((plan) => plan.priceFor(billingCycle)).toList();
  }

  static SubscriptionPlan byId(String planId) {
    for (final plan in all) {
      if (plan.id == planId) return plan;
    }
    return basico;
  }

  static bool validarDuracionSuscripcion(String billingCycle) {
    return BillingCycle.all.contains(billingCycle);
  }

  static double calcularPrecioFinal({
    required double precioMensual,
    required String billingCycle,
  }) {
    final months = BillingCycle.months(billingCycle);
    final subtotal = precioMensual * months;
    final discount = BillingCycle.discountPercent(billingCycle) / 100;
    return money(subtotal * (1 - discount));
  }

  static double money(double value) {
    return (value * 100).floorToDouble() / 100;
  }
}
