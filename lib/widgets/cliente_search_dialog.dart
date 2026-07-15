import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cliente.dart';

Future<Cliente?> showClienteSearchDialog({
  required BuildContext context,
  required List<Cliente> clientes,
}) {
  return showDialog<Cliente>(
    context: context,
    builder: (_) => _ClienteSearchDialog(clientes: clientes),
  );
}

class _ClienteSearchDialog extends StatefulWidget {
  final List<Cliente> clientes;

  const _ClienteSearchDialog({required this.clientes});

  @override
  State<_ClienteSearchDialog> createState() => _ClienteSearchDialogState();
}

class _ClienteSearchDialogState extends State<_ClienteSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Cliente> get _resultados {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) {
      return widget.clientes;
    }

    return widget.clientes
        .where(
          (cliente) =>
              cliente.nombre.toLowerCase().contains(query) ||
              cliente.telefono.contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Buscar cliente'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre o telefono',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              keyboardType: TextInputType.text,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
            const SizedBox(height: 14),
            Flexible(
              child: resultados.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No se encontraron clientes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF66756D)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: resultados.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cliente = resultados[index];

                        return ListTile(
                          leading: const Icon(Icons.person_search_outlined),
                          title: Text(cliente.nombre),
                          subtitle: Text(cliente.telefono),
                          onTap: () => Navigator.pop(context, cliente),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
