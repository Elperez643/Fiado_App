# Fiado App - Mobile QA Checklist

## Auth Startup Recovery

- Instalacion limpia Android abre LoginScreen sin quedarse en logo.
- DB antigua migra o muestra error recuperable con Reintentar/Cerrar sesion.
- Sin sesion local navega a LoginScreen, no a pantalla de error.
- Login local entra si el usuario existe en el dispositivo aunque backend este apagado.
- Login cloud vincula/crea usuario local si existe en backend y no en SQLite.
- Web abre LoginScreen y no intenta usar SQLite local en splash.
- Boton Restablecer nube limpia token/config cloud y permite reintentar.

## Integridad de Identidad de Clientes

- Crear deuda a un cliente, editar nombre y confirmar que deuda, saldo, cobranza, score y comprobante siguen visibles.
- Editar telefono del cliente y confirmar que Cobranza Inteligente abre el mismo cliente por `cliente_id`.
- Registrar pago despues de editar telefono y confirmar que baja el saldo del mismo cliente.
- Ejecutar `dart run tools\qa\run_client_identity_integrity_audit.dart` y revisar que no existan movimientos/ciclos/scores huerfanos.

## Formato Monetario Global

- Confirmar que `1000` se muestra como `1,000`.
- Confirmar que `15000` se muestra como `15,000`.
- Confirmar que `1000000` se muestra como `1,000,000`.
- Confirmar que `50.05` se muestra como `50.05`.
- Confirmar que `1000.75` se muestra como `1,000.75`.
- Confirmar que `100000.00` se muestra como `100,000.00`.
- Confirmar formato en Dashboard Ejecutivo, Clientes, Detalle Cliente,
  Inventario, Inventario Inteligente, Cobranza Inteligente, Personal,
  Suscripciones, comprobantes y PDF.

## Sincronizacion Simple

- Iniciar sesion con backend encendido e internet y confirmar que
  `Sincronizacion` muestra `Conectado a la nube`.
- Confirmar que no es necesario pegar token manual para sincronizar.
- Iniciar sesion con backend apagado y confirmar que login local funciona sin
  crash.
- Cerrar sesion y confirmar que la nube queda desconectada al volver a entrar
  sin internet.
- Abrir `Sincronizacion` y confirmar que no aparecen JWT, token, baseUrl,
  endpoint, push, pull, payload ni `sync_queue`.
- Confirmar estados visibles: `Todo sincronizado`, `Pendiente de sincronizar`,
  `Sin conexion`, `Sincronizando...` y `Error al sincronizar`.
- Tocar `Sincronizar con la nube` y confirmar progreso simple.
- Crear datos sin internet y confirmar que la app indica pendientes sin perder
  informacion local.
- Recuperar internet y confirmar intento automatico de sincronizacion.
- Confirmar indicador de nube en Dashboard: verde, amarillo, gris o azul segun
  estado.
- En debug, confirmar que `Configuracion avanzada de nube` conserva pruebas
  tecnicas.

## Security Hardening v1

- Configurar token manual y confirmar que BackendSettings muestra solo vista parcial.
- Limpiar token desde BackendSettings y confirmar que sync pide login/token nuevamente.
- Cerrar sesion y confirmar que no se puede volver a pantallas protegidas con back.
- Probar timeout de sesion y confirmar limpieza de token JWT local.
- Confirmar que Personal no ve opciones de negocio.
- Confirmar que Colaborador no edita productos existentes sin solicitud.
- Validar que no aparecen tokens completos en mensajes de error.


## Seguridad De Sesion

- Iniciar sesion como Negocio y esperar 9 minutos sin tocar la app: debe aparecer advertencia.
- En advertencia, tocar Continuar sesion: debe mantenerse la sesion.
- Esperar 10 minutos sin tocar la app: debe cerrar sesion y volver a Login.
- Enviar app a segundo plano durante 1 minuto: al volver no debe cerrar sesion.
- Enviar app a segundo plano durante 2 minutos o mas: al volver debe pedir login.
- Validar el mismo flujo como Personal.
- Validar el mismo flujo como Colaborador.
- Confirmar que no aparece advertencia en LoginScreen.
- Confirmar que el logout deja la sesion local inactiva y no conserva JWT accesible.


## Business Copilot

- Abrir Dashboard Negocio y confirmar bloque "Fiado App recomienda".
- Abrir Business Copilot desde menu lateral.
- Ver tabs: Todo, Cobranza, Inventario, Promociones, Clientes, Operaciones.
- Cliente bloqueado genera recomendacion critica.
- Cliente score bajo genera recomendacion de credito.
- Producto agotado genera recomendacion de inventario.
- Producto promocionable genera recomendacion de campana.
- Auditoria pendiente genera recomendacion.
- Solicitud pendiente genera recomendacion.
- Trial proximo a vencer genera recomendacion.
- Boton accion abre la pantalla correspondiente.
- Boton descartar oculta recomendacion.
- Boton refrescar recalcula cache.


## Cobranza Inteligente

- Abrir Dashboard Negocio y confirmar KPIs: Cobrar hoy, Vencen pronto, Mora critica, Monto critico y Recuperacion sugerida.
- Abrir menu lateral y entrar a Cobranza Inteligente.
- Validar cliente que vence en 3 dias.
- Validar cliente que vence hoy.
- Validar cliente vencido 30.
- Validar cliente mora 45.
- Validar cliente bloqueado 60.
- Validar cliente al dia con saldo.
- Tocar Ver cliente desde una tarjeta.
- Tocar Mensaje WhatsApp y confirmar que se abre WhatsApp o se copia el mensaje si no esta disponible.
- Confirmar que datos de otro negocio no aparecen.


Checklist manual para validar Fiado App en Android antes de publicar nuevas
funciones.

## Preparacion

- Instalar el APK debug mas reciente en un dispositivo Android fisico.
- Probar con pantalla pequena y teclado visible.
- Confirmar que la app abre sin borrar datos locales existentes.
- Confirmar que `sync_queue` no hace llamadas HTTP reales.

## Registro Personal

- Abrir app sin sesion activa.
- Entrar a registro.
- Seleccionar `Personal`.
- Completar nombre y telefono de 10 digitos.
- Crear cuenta.
- Confirmar que entra al portal personal.
- Cerrar sesion y volver a login.

## Login Personal

- Iniciar con telefono.
- Usar contrasena inicial igual al telefono.
- Confirmar que abre `Mi historial`.
- Confirmar que no hay acceso a inventario, colaboradores, suscripcion ni
  reportes de negocio.
- Probar contrasena incorrecta y validar mensaje visible.

## Registro Negocio

- Entrar a registro.
- Seleccionar `Negocio`.
- Completar nombre negocio, administrador, telefono, contrasena, confirmar
  contrasena y plan inicial.
- Confirmar que crea trial gratis de 30 dias.
- Confirmar que abre dashboard principal completo.

## Login Negocio

- Iniciar con telefono y contrasena creada.
- Confirmar que abre `Dashboard ejecutivo`.
- Confirmar que no queda pantalla blanca despues de tocar `Entrar al negocio`.
- Si hay error post-login, confirmar pantalla recuperable con `Reintentar` y
  `Cerrar sesion`.
- Confirmar KPIs visibles: clientes activos, monto fiado, cobrado este mes,
  score promedio, clientes en riesgo, stock bajo, vencidos 30 y bloqueados 60.
- Confirmar que `Noticias importantes` muestra alertas o estado estable.
- Abrir el menu lateral y confirmar accesos a Clientes, Inventario,
  Cuentas por cobrar, Auditorias, Reportes, Solicitudes, Colaboradores,
  Inteligencia comercial, Suscripcion, Pagos, Sincronizacion, Backend,
  Ayuda / Ver guia nuevamente y Cerrar sesion.
- Probar contrasena incorrecta y validar mensaje visible.

## Onboarding v2

- Crear usuario Personal nuevo y confirmar que ve la guia Personal una sola vez.
- Completar la guia Personal y confirmar que no vuelve a salir al reiniciar.
- Crear usuario Negocio nuevo y confirmar que ve la guia Negocio una sola vez.
- Omitir la guia Negocio y confirmar que no vuelve a salir al reiniciar.
- Crear Colaborador nuevo desde un Negocio, iniciar sesion como colaborador y
  confirmar que ve la guia Colaborador una sola vez.
- Completar u omitir la guia Colaborador y confirmar que no vuelve a salir.
- Desde Personal, Negocio y Colaborador abrir
  `Ayuda / Ver guia nuevamente` manualmente desde el menu y confirmar que no
  altera el estado de onboarding.
- Forzar cierre por session timeout, iniciar sesion de nuevo y confirmar que la
  guia no reaparece si ya fue completada u omitida.

## Crear Colaborador

- Desde usuario Negocio abrir `Colaboradores`.
- Crear colaborador con nombre, telefono y contrasena.
- Validar limite del plan:
  - Basico: 3 colaboradores.
  - Crecimiento: 7 colaboradores.
  - Empresarial: 15 colaboradores.
- Confirmar error visible al exceder limite.
- Confirmar que colaborador queda activo.

## Login Colaborador

- Cerrar sesion.
- Iniciar con telefono y contrasena creada por negocio.
- Confirmar `Dashboard colaborador` con KPIs de auditorias realizadas,
  pendientes, solicitudes enviadas/aprobadas y productos agregados.
- Confirmar noticias operativas de auditoria, solicitudes e inventario.
- Abrir el menu lateral y validar accesos a Inventario, Auditorias,
  Mis auditorias, Mis solicitudes, Ayuda / Ver guia nuevamente y Cerrar sesion.
- Confirmar que no puede abrir Clientes/deudas/pagos.
- Confirmar que no ve Suscripcion ni Colaboradores.
- Confirmar que puede abrir Inventario y Mis solicitudes.

## Dashboard Personal

- Iniciar como usuario Personal.
- Confirmar KPIs: total adeudado, negocios donde debe, proximo vencimiento e
  historial de cumplimiento.
- Confirmar noticias personales de deuda, recordatorios o pago registrado.
- Abrir menu lateral y validar Dashboard, Mis deudas, Historial,
  Comprobantes, Ayuda / Ver guia nuevamente y Cerrar sesion.
- Confirmar que el contenido no muestra informacion de otros clientes.
- Abrir `Recordatorios de pago` desde el menu lateral.
- Confirmar que las deudas aparecen agrupadas por negocio.
- Confirmar que cada tarjeta muestra monto, fecha limite, prioridad y consejo
  suave.
- Abrir `Ver detalle` y confirmar movimientos/comprobantes propios.
- Confirmar que no se muestran datos internos del negocio ni de otros
  telefonos.
- Confirmar que no se dispara WhatsApp, push ni modal automatico.

## Responsive Dashboard

- En telefono pequeno confirmar que KPIs bajan a una columna o dos columnas sin
  overflow.
- En tablet/desktop/web confirmar grid amplio y noticias organizadas.
- Abrir y cerrar drawer en cada rol.
- Confirmar logout desde menu lateral en Negocio, Personal y Colaborador.

## Visual Refresh

- Confirmar que Login y Registro usan hero visual moderno, inputs claros y
  botones con feedback.
- Confirmar Dashboard Ejecutivo usa KPIs con microanimacion y tarjetas limpias.
- Confirmar Clientes e Inventario mantienen jerarquia visual clara, chips y
  estados de alerta sin overflow.
- Confirmar Suscripcion muestra planes como tarjetas SaaS, USD principal y DOP
  solo aproximado cuando aplique.
- Confirmar SyncStatusScreen y DetalleClienteScreen heredan tema moderno,
  contraste suficiente y botones redondeados.
- Confirmar que no aparecen precios historicos RD$700/RD$1500/RD$2800.

## Crear Producto Con Imagen

- Como Negocio o Colaborador abrir Inventario.
- Crear articulo con nombre, codigo opcional, cantidad, costo unitario,
  porcentaje de ganancia, precio de venta y stock minimo.
- Crear producto sin imagen y confirmar que se guarda sin pantalla roja.
- Crear producto con 1 imagen.
- Crear producto con 3 imagenes.
- Intentar crear producto con 4 imagenes y confirmar error claro.
- Cargar imagen de 5 MB y confirmar que se optimiza a 500x500 y maximo 300 KB.
- Cargar imagen de 300 KB y confirmar que queda entre 120 KB y 300 KB.
- Cargar PNG transparente y confirmar que se conserva PNG si queda bajo 300 KB
  o se genera JPG optimizado si excede el limite.
- Cancelar creacion de producto y confirmar que no guarda nada ni muestra
  pantalla roja.
- Crear producto como Negocio.
- Crear producto como Colaborador con permiso de agregar inventario.
- Escanear codigo de barras del producto y confirmar que llena
  `codigo_referencia`.
- Escanear codigo existente y confirmar aviso de duplicado local.
- Escanear ubicacion y confirmar que llena el campo `ubicacion`.
- Escribir ubicacion manualmente con el campo vacio.
- Confirmar que Windows/Linux muestran mensaje si el scanner no esta
  disponible.
- Confirmar que costo 100 + margen 30% calcula precio de venta RD$130.00.
- Editar costo/margen/precio como Negocio y confirmar que se guarda.
- Como Colaborador intentar editar costo, margen o precio de un producto
  existente y confirmar que queda solicitud pendiente para Negocio.
- Aprobar la solicitud como Negocio y confirmar que el producto queda
  actualizado.
- Agregar hasta 3 imagenes.
- Validar error si intenta mas de 3 imagenes.
- Confirmar resumen de imagen original vs imagen optimizada.
- Confirmar que el listado de inventario muestra la primera imagen del
  producto con miniatura cuadrada.
- Confirmar que productos sin imagen muestran placeholder visual.
- Confirmar que Personal no puede crear productos.
- Confirmar que Colaborador no edita imagenes de producto existente directo.

## Crear Deuda Con Detalle

- Como Negocio abrir Clientes.
- Seleccionar cliente.
- Agregar deuda.
- Escribir concepto.
- Seleccionar productos y confirmar que traen precio de venta automatico.
- Cambiar cantidad o precio unitario y confirmar subtotal en vivo.
- Agregar varios productos y confirmar total automatico.
- Confirmar que despues de tocar `Agregar articulo`, el selector vuelve a
  `Selecciona un producto`, precio unitario vuelve a `0.00`, cantidad vuelve a
  `1` y `Subtotal actual` vuelve a `RD$0.00`.
- Confirmar que el boton `Agregar articulo` queda desactivado hasta seleccionar
  un nuevo producto valido.
- Confirmar que al agregar el primer articulo `Monto total final` pasa de vacio
  al subtotal visualmente, por ejemplo `1,000`.
- Confirmar que al agregar un segundo articulo el campo cambia visualmente al
  nuevo subtotal, por ejemplo `1,500`.
- Confirmar que `Monto total` queda editable aunque haya articulos.
- Editar manualmente el monto total y confirmar que no se sobrescribe al quitar
  o agregar articulos.
- Usar `Usar subtotal` y confirmar que vuelve a la suma de subtotales.
- Escribir `1,500.50` en `Monto total final` y confirmar que guarda
  correctamente.
- Eliminar un producto de la factura y confirmar recalculo del total si el total
  no fue editado manualmente.
- Confirmar que deuda manual sin productos sigue funcionando.
- Confirmar advertencia cuando el producto no tiene precio de venta.
- Confirmar que productos sin imagen, descripcion, categoria o codigo se pueden
  agregar.
- Guardar.
- Confirmar que inventario descuenta stock.
- Confirmar error visible si no hay stock suficiente.
- Confirmar que el selector no permite productos con stock 0.
- Confirmar que el selector no muestra productos de otro negocio.
- Confirmar que cambiar busqueda/listado de Inventario no desactiva el selector
  de articulos.
- Confirmar que abrir Inventario Inteligente y volver a deuda no desactiva el
  selector de articulos.
- Confirmar que producto activo sin imagen aparece como articulo facturable.
- Pulsar `Cancelar` en agregar deuda y confirmar que cierra sin pantalla roja.
- Pulsar `Agregar` con articulos y confirmar que no aparece pantalla roja.
- Confirmar que despues de guardar se puede abrir el popup de detalle.
- Confirmar que el popup de detalle muestra Mercancias con nombre, codigo,
  cantidad, precio unitario y subtotal.
- Confirmar que `Ver comprobante` muestra las mismas mercancias.
- Exportar PDF y confirmar tabla de mercancias.
- Crear deuda con articulos y dejar `Monto total final` vacio: usa subtotal de
  articulos.
- Crear deuda con 1 articulo, no tocar `Monto total final` y confirmar que se
  guarda con el subtotal autollenado.
- Crear deuda con 3 articulos, no tocar `Monto total final` y confirmar que se
  guarda con la suma de subtotales.
- Crear deuda con articulos, borrar `Monto total final` y confirmar que se
  guarda usando el subtotal.
- Crear deuda manual sin articulos y campo vacio: muestra error claro.
- Crear deuda manual sin articulos y monto escrito: guarda correctamente.
- Crear deuda con articulos y `Monto total final` menor al subtotal: muestra
  abono inicial y movimiento de pago informativo.
- Crear deuda con articulos y `Monto total final` mayor al subtotal: muestra
  ajuste adicional.
- Crear deuda con articulos y `Monto total final` 0: pide confirmacion.

## Inventario Inteligente

- Como Negocio abrir menu lateral y entrar a `Inventario Inteligente`.
- Confirmar resumen superior: valor costo, valor venta, ganancia potencial,
  agotados, criticos, stock bajo y reposicion sugerida.
- Confirmar secciones: productos criticos, reposicion sugerida, sin movimiento,
  agotados, mayor ganancia potencial y sobre stock.
- Confirmar que cada tarjeta muestra nombre, codigo, ubicacion, stock,
  promedio diario, cobertura, reposicion, ganancia potencial y estado.
- Confirmar que productos con imagen muestran miniatura.
- Confirmar que productos sin imagen muestran placeholder.
- Confirmar refresh de la pantalla recalcula desde SQLite.
- Confirmar boton `Actualizar metricas`.
- Confirmar mensaje `Actualizando metricas de inventario...` cuando hay muchos
  productos dirty.
- Confirmar que no se crea entidad sync nueva para insights.

## Aislamiento Multi Negocio

- Crear `Negocio A`.
- Crear cliente `Juan` con telefono `8090000001`.
- Crear deuda a Juan con articulos.
- Cerrar sesion y crear `Negocio B`.
- Crear cliente `Juan` con el mismo telefono `8090000001`.
- Confirmar que Negocio B puede crearlo sin error.
- Confirmar que Negocio B no ve clientes, deudas, pagos ni productos de
  Negocio A.
- Crear colaborador de Negocio A.
- Iniciar como colaborador de Negocio A.
- Confirmar que Colaborador A no ve datos de Negocio B.
- Confirmar que el inventario mostrado al agregar deuda contiene solo articulos
  activos del negocio actual.

## Historial Personal Aislado

- Crear usuario Personal con telefono `8090000001`.
- Confirmar que solo ve su historial personal asociado.
- Confirmar que no ve todos los clientes globales con ese telefono.
- Confirmar que no puede entrar a Clientes, Inventario, Colaboradores ni
  pantallas internas de negocio.

## Registrar Pago

- Como Negocio abrir cliente con deuda.
- Registrar pago parcial.
- Confirmar deuda anterior y nuevo saldo.
- Confirmar que pago no altera inventario.

## Ciclos De Credito 30/45/60

- Crear un cliente nuevo y registrar su primera deuda.
- Confirmar que se crea ciclo con fecha inicio igual a la deuda y limite a 30
  dias.
- Registrar segunda deuda dentro de los primeros 30 dias.
- Confirmar que no reinicia ni extiende el ciclo.
- Simular o preparar datos con deuda posterior al dia 30.
- Confirmar que la nueva deuda crea otro ciclo.
- Confirmar que ciclo `vencido_30` se muestra amarillo y aparece en Cuentas por
  cobrar.
- Confirmar que ciclo `mora_45` parpadea rojo/amarillo en detalle.
- Confirmar que ciclo `bloqueado_60` bloquea fiado normal.
- Pulsar `Fiar de todos modos`, registrar motivo opcional y confirmar que la
  deuda se guarda con excepcion.
- Registrar pago parcial y confirmar que reduce saldo pendiente sin cerrar el
  ciclo.
- Registrar pago total y confirmar que el ciclo queda `saldado`.
- Dia 1: crear deuda de 100, Dia 5: pagar 100, Dia 10: crear deuda de 50.
- Confirmar que la deuda del dia 10 crea un ciclo nuevo por Borron y Cuenta
  Nueva.
- Dia 1: crear deuda de 100, Dia 5: pagar 50, Dia 10: crear deuda de 60.
- Confirmar que la deuda del dia 10 entra al ciclo iniciado el Dia 1 porque el
  pago fue parcial.
- Dia 1: crear deuda de 100, Dia 29: pagar 100, Dia 30: crear deuda de 75.
- Confirmar que la deuda nueva crea un ciclo nuevo.
- Dia 30 desde Dia 1: si queda saldo, confirmar que pasa a `vencido_30`.
- Dia 45 desde Dia 1: si queda saldo, confirmar que pasa a `mora_45`.
- Dia 60 desde Dia 1: si queda saldo, confirmar que pasa a `bloqueado_60`.
- Crear usuario Personal con el telefono del cliente y confirmar aviso interno.
- Pulsar WhatsApp y confirmar que se comparte/abre mensaje con enlace `wa.me`.
- Validar multi-negocio: cliente bloqueado en Negocio A sigue normal en Negocio
  B.

## Ver Comprobante

- Tocar deuda registrada.
- Confirmar popup de detalle de mercancias.
- Pulsar `Ver comprobante`.
- Confirmar negocio, cliente, telefono, fecha, concepto, productos, total,
  saldo pendiente, usuario registrador y codigo unico.
- Tocar pago en historial.
- Confirmar comprobante de pago con deuda anterior y nuevo saldo.
- Abrir una deuda vieja sin items y confirmar mensaje de detalle no registrado.

## Compartir Comprobante

- En comprobante pulsar `Compartir`.
- Confirmar que aparece menu nativo Android.
- Elegir WhatsApp si esta instalado.
- Elegir app de correo si esta instalada.
- Confirmar texto resumen y PDF adjunto cuando la app destino lo soporte.

## Campanas Estados WhatsApp

- Abrir Dashboard de Negocio y entrar a `Campanas WhatsApp`.
- Seleccionar modo Catalogo y seleccionar varios productos con stock.
- Usar imagen optimizada del producto para renderizar estados.
- Escribir texto de estado de 30 caracteres o menos.
- Confirmar contador `0/30` y error si pasa de 30 caracteres.
- Generar preview y revisar franja inferior con texto, precio y Fiado App.
- Confirmar que un producto sin imagen genera flyer simple y muestra
  advertencia.
- Confirmar que productos con stock 0 no aparecen como publicables.
- Publicar en WhatsApp y confirmar que se comparten imagenes renderizadas.
- Al volver, confirmar manualmente la publicacion y revisar mensaje de vigencia
  estimada de 24 horas.
- Confirmar que si WhatsApp abre y el usuario responde `Si, ya publique`, el
  cupo queda consumido.
- Confirmar que si WhatsApp abre y el usuario responde `No publique`, el cupo
  tambien queda consumido.
- Simular error antes de abrir el menu de compartir y confirmar que no consume
  cupo.
- Reintentar la misma publicacion desde historial y confirmar que no consume
  cupo adicional.
- Cambiar productos, imagen o texto y publicar de nuevo; debe consumir cupo
  nuevo.
- Validar limites: Basico 1 publicacion/dia y 15 productos, Crecimiento 3/15,
  Empresarial 5/20.
- Modificar precio o stock antes de publicar y confirmar que se usan datos
  actuales.

## Exportar PDF

- En comprobante pulsar `Exportar PDF`.
- Confirmar que se genera PDF.
- Abrir PDF desde visor disponible.
- Validar encabezado Fiado App, tabla de productos y resumen financiero.

## Imprimir

- En comprobante pulsar `Imprimir`.
- Confirmar selector de impresion Android.
- Si no hay impresora configurada, confirmar que la app no se rompe.

## Auditoria Diaria

- Como Colaborador abrir Inventario.
- Ejecutar auditoria diaria.
- Confirmar productos auditados y estado.
- Si hay diferencias, confirmar solicitud pendiente al negocio.

## Auditoria Semanal

- Como Colaborador abrir Inventario.
- Ejecutar auditoria semanal.
- Confirmar productos clave auditados y estado.
- Confirmar solicitudes si hay diferencias.

## Solicitud De Autorizacion

- Como Colaborador intentar modificar stock o producto existente.
- Confirmar que se crea solicitud y no se aplica directo.
- Abrir `Mis solicitudes` y validar estado pendiente.

## Aprobar/Rechazar Solicitud

- Como Negocio abrir `Solicitudes pendientes`.
- Aprobar una solicitud y confirmar efecto en inventario.
- Rechazar otra solicitud con comentario.
- Confirmar que Colaborador ve estado actualizado en `Mis solicitudes`.

## Sync Status

- Como Negocio abrir `Estado de sincronizacion`.
- Confirmar pendientes y fallidos.
- Pulsar `Simular sincronizacion`.
- Confirmar que no se hacen llamadas HTTP reales.
- Pulsar `Limpiar sincronizados`.

## Stripe Test

- Configurar backend con `Stripe:SecretKey = sk_test_...`,
  `Stripe:WebhookSecret = whsec_...` y `Stripe:PriceIds`.
- Confirmar que los Price IDs corresponden a los precios USD actuales:
  Basico USD 4.99/13.47/47.90, Crecimiento USD 12.99/35.07/124.70 y
  Empresarial USD 20.99/56.67/201.50.
- Como Negocio abrir `Suscripcion`.
- Seleccionar plan/ciclo.
- Confirmar que USD aparece como precio principal y que DOP, si aparece, esta
  marcado como aproximado.
- Confirmar que no aparecen precios historicos en DOP como importes oficiales.
- Pulsar `Pagar con Stripe (modo prueba)`.
- Confirmar que se abre Stripe Checkout externo.
- Usar tarjeta test `4242 4242 4242 4242`.
- Confirmar retorno a `SuccessUrl`.
- Con Stripe CLI reenviando webhooks, validar que el backend registra eventos
  en `PaymentWebhookLogs` y actualiza la suscripcion.
- Si Stripe no esta configurado, confirmar mensaje claro y que el mock sigue
  disponible.

## Logout

- Cerrar sesion desde Personal, Negocio y Colaborador.
- Confirmar que vuelve a Login.
- Presionar boton atras de Android.
- Confirmar que no entra nuevamente al dashboard cerrado.
# Inventario Aislado Por Negocio

- [ ] Negocio nuevo muestra inventario vacio.
- [ ] Productos de un negocio no aparecen en otro.
- [ ] Colaborador solo ve inventario de su negocio.
- [ ] Personal no accede a inventario.
- [ ] Selector de articulos en fiado solo muestra productos del negocio activo.
- [ ] Campanas WhatsApp solo muestran productos del negocio activo.
- [ ] Inventario Inteligente y Business Copilot no mezclan productos.
