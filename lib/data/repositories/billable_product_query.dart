// ignore: depend_on_referenced_packages
import 'package:sqflite_common/sqlite_api.dart';

import '../../core/database/database_schema.dart';
import '../models/billable_product.dart';

class BillableProductQuery {
  const BillableProductQuery._();

  static Future<List<BillableProduct>> obtenerProductosFacturables(
    Database db, {
    required int negocioId,
    bool soloConStock = true,
  }) async {
    final stockFilter = soloConStock ? 'AND p.cantidad > 0' : '';
    final rows = await db.rawQuery(
      '''
SELECT
  p.id,
  p.legacy_id,
  p.negocio_id,
  p.nombre,
  p.codigo_referencia,
  p.categoria,
  p.descripcion,
  p.ubicacion,
  p.cantidad,
  p.costo_unitario,
  p.precio_compra,
  p.precio_venta,
  p.porcentaje_ganancia,
  p.activo,
  (
    SELECT pi.local_path
    FROM ${DatabaseSchema.productoImagenesTable} pi
    WHERE pi.negocio_id = p.negocio_id
      AND pi.producto_id = p.id
      AND pi.deleted_at IS NULL
      AND pi.sync_status != 'deleted'
    ORDER BY pi.orden ASC, pi.id ASC
    LIMIT 1
  ) AS imagen_principal_path
FROM ${DatabaseSchema.productosTable} p
WHERE p.negocio_id = ?
  AND p.activo = 1
  $stockFilter
ORDER BY p.nombre COLLATE NOCASE ASC
''',
      [negocioId],
    );
    return rows.map(BillableProduct.fromMap).toList(growable: false);
  }
}
