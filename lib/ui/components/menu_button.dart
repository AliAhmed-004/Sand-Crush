import 'package:flutter/material.dart';
import 'package:sandfall/theme/theme.dart';

class MenuButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final VoidCallback onPressed;

  const MenuButton({
    required this.label,
    this.sublabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        color: SandColors.darkBg.withAlpha(150),
        borderRadius: BorderRadius.circular(2),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: SandColors.primaryGold.withAlpha(180),
          side: BorderSide(color: SandColors.deepSand.withAlpha(80), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: SandColors.lightSand.withAlpha(100),
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
