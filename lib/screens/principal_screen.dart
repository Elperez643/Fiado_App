import 'package:flutter/material.dart';

import '../widgets/adaptive_layout.dart';
import 'clientes_screen.dart';
import 'inventario_screen.dart';

class PrincipalScreen extends StatelessWidget {
  const PrincipalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                AdaptiveLayout.horizontalPadding(constraints.maxWidth);
            final mostrarEnFila =
                AdaptiveLayout.isTabletOrWider(constraints.maxWidth);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                24,
              ),
              child: AdaptiveWidth(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fiado App',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17322C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecciona el modulo que quieres abrir.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF66756D),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (mostrarEnFila)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 360,
                                child: _clientesCard(context),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: SizedBox(
                                height: 360,
                                child: _inventarioCard(context),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            SizedBox(
                              height: 230,
                              child: _clientesCard(context),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 230,
                              child: _inventarioCard(context),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _clientesCard(BuildContext context) {
    return _PrincipalOptionCard(
      title: 'Clientes',
      description: 'Gestiona clientes, deudas, pagos e historial.',
      icon: Icons.groups_2_outlined,
      gradient: const [Color(0xFF17322C), Color(0xFF1F7A6B)],
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientesScreen(),
          ),
        );
      },
    );
  }

  Widget _inventarioCard(BuildContext context) {
    return _PrincipalOptionCard(
      title: 'Inventario',
      description: 'Consulta stock, auditorias y reportes del inventario.',
      icon: Icons.inventory_2_outlined,
      gradient: const [Color(0xFF5B3A00), Color(0xFFE7B04B)],
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InventarioScreen(),
          ),
        );
      },
    );
  }
}

class _PrincipalOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _PrincipalOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2217322C),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFFF2F4F3),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
