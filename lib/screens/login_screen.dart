import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';
import '../widgets/adaptive_layout.dart';
import 'personal_portal_screen.dart';
import 'principal_screen.dart';

enum _LoginMode { personal, negocios }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _claveController = TextEditingController();
  _LoginMode _modo = _LoginMode.negocios;
  bool _ocultarClave = true;

  @override
  void dispose() {
    _usuarioController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  void _cambiarModo(_LoginMode modo) {
    setState(() {
      _modo = modo;
      _claveController.clear();
      _ocultarClave = modo == _LoginMode.negocios;
    });
  }

  void _mostrarError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _modo == _LoginMode.negocios
              ? 'Usuario o contrasena de negocio incorrectos.'
              : 'Usuario o telefono personal incorrectos.',
        ),
      ),
    );
  }

  void _iniciarSesion() {
    final usuario = _usuarioController.text.trim();
    final clave = _claveController.text.trim();

    if (_modo == _LoginMode.negocios) {
      if (usuario == AppConstants.betaBusinessUser &&
          clave == AppConstants.betaBusinessPassword) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PrincipalScreen()),
        );
        return;
      }

      _mostrarError();
      return;
    }

    if (usuario == AppConstants.betaPersonalUser &&
        clave == AppConstants.betaPersonalPhone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PersonalPortalScreen(
            telefono: AppConstants.betaPersonalPhone,
          ),
        ),
      );
      return;
    }

    _mostrarError();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                AdaptiveLayout.horizontalPadding(constraints.maxWidth);
            final isWide = AdaptiveLayout.isTabletOrWider(
              constraints.maxWidth,
            );

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
                      _LoginHero(isWide: isWide),
                      const SizedBox(height: 18),
                      Container(
                        padding: EdgeInsets.all(isWide ? 24 : 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE3DED2)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 22,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tipo de acceso',
                              style: textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF17322C),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            isWide
                                ? Row(
                                    children: [
                                      Expanded(child: _modeCard(_LoginMode.personal)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _modeCard(_LoginMode.negocios)),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _modeCard(_LoginMode.personal),
                                      const SizedBox(height: 12),
                                      _modeCard(_LoginMode.negocios),
                                    ],
                                  ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _usuarioController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _claveController,
                              obscureText:
                                  _modo == _LoginMode.negocios && _ocultarClave,
                              keyboardType: _modo == _LoginMode.personal
                                  ? TextInputType.number
                                  : TextInputType.text,
                              maxLength:
                                  _modo == _LoginMode.personal ? 10 : null,
                              inputFormatters: _modo == _LoginMode.personal
                                  ? [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ]
                                  : null,
                              onSubmitted: (_) => _iniciarSesion(),
                              decoration: InputDecoration(
                                labelText: _modo == _LoginMode.personal
                                    ? 'Telefono'
                                    : 'Contrasena',
                                prefixIcon: Icon(
                                  _modo == _LoginMode.personal
                                      ? Icons.phone_outlined
                                      : Icons.lock_outline,
                                ),
                                counterText: '',
                                suffixIcon: _modo == _LoginMode.negocios
                                    ? IconButton(
                                        icon: Icon(
                                          _ocultarClave
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _ocultarClave = !_ocultarClave;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _iniciarSesion,
                                icon: const Icon(Icons.login_rounded),
                                label: Text(
                                  _modo == _LoginMode.negocios
                                      ? 'Entrar al negocio'
                                      : 'Ver mi historial',
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _modeCard(_LoginMode modo) {
    final selected = _modo == modo;
    final isPersonal = modo == _LoginMode.personal;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _cambiarModo(modo),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F3EF) : const Color(0xFFF8F6F0),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF1F7A6B) : const Color(0xFFE3DED2),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1F7A6B) : Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isPersonal ? Icons.badge_outlined : Icons.storefront_outlined,
                color: selected ? Colors.white : const Color(0xFF1F7A6B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPersonal ? 'Personal' : 'Negocios',
                    style: const TextStyle(
                      color: Color(0xFF17322C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPersonal
                        ? 'Solo tu historial'
                        : 'Acceso completo',
                    style: const TextStyle(
                      color: Color(0xFF66756D),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1F7A6B),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  final bool isWide;

  const _LoginHero({required this.isWide});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isWide ? 28 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF17322C), Color(0xFF1F7A6B)],
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
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: isWide ? 34 : 24),
          const Text(
            'Fiado App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Entra como negocio para administrar todo o como cliente para consultar solo tu historial.',
            style: TextStyle(
              color: Color(0xFFDCE9E5),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
