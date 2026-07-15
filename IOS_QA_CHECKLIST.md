# iOS QA Checklist

## Preparacion

- [ ] `flutter doctor -v` sin errores iOS criticos.
- [ ] `pod install` exitoso en `ios/`.
- [ ] `flutter build ios --debug --no-codesign` exitoso.
- [ ] Bundle identifier cambiado para el equipo de pruebas.
- [ ] Backend configurado para simulador o iPhone fisico.

## Flujos principales

- [ ] Login.
- [ ] Registro de negocio.
- [ ] Registro personal.
- [ ] Crear colaborador.
- [ ] Crear cliente.
- [ ] Crear producto.
- [ ] Crear producto con imagen desde galeria.
- [ ] Crear producto con imagen desde camara si se habilita esa opcion.
- [ ] Crear deuda con articulos.
- [ ] Registrar pago.
- [ ] Ver comprobante PDF.
- [ ] Compartir comprobante.
- [ ] Imprimir comprobante.
- [ ] Abrir/compartir enlace de WhatsApp.
- [ ] Sincronizar clientes.
- [ ] Sincronizar productos e imagenes.
- [ ] Sincronizar movimientos/deuda_items.
- [ ] Sincronizar comprobantes.
- [ ] Sincronizar ciclos de credito.
- [ ] Sincronizar auditorias.
- [ ] Sincronizar solicitudes.
- [ ] Sincronizar todo con backend.
- [ ] Logout.

## Responsive iPhone/iPad

- [ ] `LoginScreen` en iPhone SE y iPhone grande.
- [ ] `RegisterScreen` en iPhone SE y iPhone grande.
- [ ] `PrincipalScreen` en iPhone y iPad.
- [ ] `ClientesScreen` con busqueda, scroll y paginacion.
- [ ] `InventarioScreen` con busqueda, cards y dialogo de imagenes.
- [ ] `DetalleClienteScreen` con deuda, pagos, ciclos y comprobantes.
- [ ] `ComprobanteScreen` con PDF/share/print.
- [ ] `SyncStatusScreen` con todos los botones visibles por scroll.
- [ ] `BackendSettingsScreen` con teclado abierto.
- [ ] `SubscriptionScreen` en iPhone/iPad.

## Permisos

- [ ] Selector de fotos muestra prompt correcto.
- [ ] Camara muestra prompt correcto si se usa.
- [ ] Share sheet abre con PDF.
- [ ] AirPrint/printing no crashea si no hay impresoras.
- [ ] WhatsApp/link externo no crashea si WhatsApp no esta instalado.

## Criterios de salida

- [ ] Sin crashes en flujos principales.
- [ ] Sin overflows visibles.
- [ ] SQLite conserva datos tras cerrar/reabrir app.
- [ ] Sync no borra datos locales si falla backend.
- [ ] Logout limpia sesion/token visible.
