import 'dart:io';
import 'package:flutter/material.dart';
import 'theme_colors.dart';

class ModalButon extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String yazi;
  final String altyazi;
  final VoidCallback tikla;

  const ModalButon({super.key, required this.ikon, required this.renk, required this.yazi, required this.altyazi, required this.tikla});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tikla,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ThemeColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: renk.withAlpha(60))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: renk.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: Icon(ikon, color: renk, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(yazi, style: const TextStyle(color: ThemeColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(altyazi, style: const TextStyle(color: ThemeColors.subText, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ThemeColors.subText.withAlpha(130)),
          ],
        ),
      ),
    );
  }
}

class FotoKarti extends StatelessWidget {
  final File? foto;
  final String etiket;
  final IconData ikon;
  final VoidCallback tikla;

  const FotoKarti({super.key, required this.foto, required this.etiket, required this.ikon, required this.tikla});

  @override
  Widget build(BuildContext context) {
    final bool ok = foto != null;
    return GestureDetector(
      onTap: tikla,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 180,
        decoration: BoxDecoration(
          color: ThemeColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ok ? ThemeColors.accent : ThemeColors.subText.withAlpha(60), width: ok ? 1.5 : 1.0),
          boxShadow: ok ? [BoxShadow(color: ThemeColors.accent.withAlpha(40), blurRadius: 14, spreadRadius: 1)] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (ok) Image.file(foto!, fit: BoxFit.cover) else Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(ikon, color: ThemeColors.subText.withAlpha(90), size: 40),
                  const SizedBox(height: 8),
                  Text(etiket, style: const TextStyle(color: ThemeColors.subText, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('Dokun - Sec veya Cek', style: TextStyle(color: ThemeColors.subText, fontSize: 10)),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: ok ? ThemeColors.accent : Colors.black38, borderRadius: BorderRadius.circular(20)),
                  child: Text(ok ? ' Secildi' : (etiket == 'On Fotograf' ? 'ON' : 'YAN'), style: TextStyle(color: ok ? Colors.black : ThemeColors.text, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KareSlider extends StatelessWidget {
  final double deger;
  final ValueChanged<double> onChange;

  const KareSlider({super.key, required this.deger, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ThemeColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Icon(Icons.crop_square_rounded, color: ThemeColors.accent, size: 18), SizedBox(width: 8), Text('Referans Kare', style: TextStyle(color: ThemeColors.text, fontWeight: FontWeight.w600, fontSize: 14))]),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: ThemeColors.accent.withAlpha(40), borderRadius: BorderRadius.circular(20)), child: Text('${deger.toStringAsFixed(0)} cm', style: const TextStyle(color: ThemeColors.accent, fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
          Slider(value: deger, min: 5, max: 50, divisions: 45, activeColor: ThemeColors.accent, inactiveColor: ThemeColors.accent.withAlpha(40), onChanged: onChange),
        ],
      ),
    );
  }
}
