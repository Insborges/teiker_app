import 'package:flutter/material.dart';

class CurvedCalendarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Começa no topo esquerdo
    path.lineTo(0, 0);

    // Vai para o topo direito
    path.lineTo(size.width, 0);

    // Vai para o fundo direito
    path.lineTo(size.width, size.height - 30);

    // Cria a curva no canto inferior direito
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - 30,
      size.height,
    );

    // Linha reta no fundo
    path.lineTo(30, size.height);

    // Cria a curva no canto inferior esquerdo
    path.quadraticBezierTo(0, size.height, 0, size.height - 30);

    // Fecha o path voltando ao início
    path.lineTo(0, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
