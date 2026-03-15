import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'config.dart';
import 'theme_colors.dart';
import 'custom_widgets.dart';
import 'kamera_ekrani.dart';
import 'ip_ayar_ekran.dart';
import 'main.dart'; // availCams icin

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  File? onFoto;
  File? yanFoto;
  double kareCm = 20.0;
  bool yukleniyor = false;
  Map<String, dynamic>? sonuc;
  String? hata;

  Future<void> fotoDialog(bool onMu) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: ThemeColors.subText.withAlpha(80), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(onMu ? 'On Fotograf' : 'Yan Fotograf', style: const TextStyle(color: ThemeColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(onMu ? 'Tam karsidan, dik ve ortalanmis sekilde' : 'Tam yandan, dik ve ortalanmis sekilde', style: const TextStyle(color: ThemeColors.subText, fontSize: 12)),
            const SizedBox(height: 20),
            ModalButon(
              ikon: Icons.camera_alt_rounded,
              renk: ThemeColors.accent,
              yazi: 'Kamera ile Cek',
              altyazi: 'Uygulama icinde, izgarali rehber ile',
              tikla: () async {
                Navigator.pop(ctx);
                if (availCams.isEmpty) {
                  setState(() => hata = 'Cihazda kamera bulunamadi.');
                  return;
                }
                final File? f = await Navigator.push<File>(context, MaterialPageRoute(builder: (_) => KameraEkrani(cameras: availCams, etiket: onMu ? 'ON' : 'YAN')));
                if (f != null) setState(() { if (onMu) onFoto = f; else yanFoto = f; sonuc = null; hata = null; });
              },
            ),
            const SizedBox(height: 10),
            ModalButon(
              ikon: Icons.photo_library_rounded,
              renk: const Color(0xFF818CF8),
              yazi: 'Galeriden Sec',
              altyazi: 'Cihazinizdaki fotografi secin',
              tikla: () async {
                Navigator.pop(ctx);
                final XFile? xf = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
                if (xf != null) setState(() { if (onMu) onFoto = File(xf.path); else yanFoto = File(xf.path); sonuc = null; hata = null; });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> analiz() async {
    if (onFoto == null || yanFoto == null) {
      setState(() => hata = 'Lutfen her iki fotografi da ekleyin.');
      return;
    }
    setState(() { yukleniyor = true; hata = null; sonuc = null; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse(AppConfig.tahminEndpoint));
      req.files.add(await http.MultipartFile.fromPath('on', onFoto!.path));
      req.files.add(await http.MultipartFile.fromPath('yan', yanFoto!.path));
      req.fields['kare_cm'] = kareCm.toStringAsFixed(0);

      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        setState(() => sonuc = jsonDecode(res.body) as Map<String, dynamic>);
      } else {
        setState(() => hata = 'Hata ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      setState(() => hata = 'Baglanti hatasi: $e');
    } finally {
      setState(() => yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg,
      appBar: AppBar(
        backgroundColor: ThemeColors.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kilo Tahmini', style: TextStyle(color: ThemeColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Sunucu: ${AppConfig.serverIp}', style: const TextStyle(color: ThemeColors.accent, fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, size: 20, color: ThemeColors.subText),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IpAyarEkran())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThemeColors.accent.withAlpha(20), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeColors.accent.withAlpha(60))), child: const Row(children: [Icon(Icons.tips_and_updates_rounded, color: ThemeColors.accent, size: 18), SizedBox(width: 10), Expanded(child: Text('On ve yan fotograf yukleyin. Kare boyutunu ayarlayin.', style: TextStyle(color: ThemeColors.subText, fontSize: 12, height: 1.4)))])) ,
            const SizedBox(height: 16),
            Row(children: [Expanded(child: FotoKarti(foto: onFoto, etiket: 'On Fotograf', ikon: Icons.face_rounded, tikla: () => fotoDialog(true))), const SizedBox(width: 12), Expanded(child: FotoKarti(foto: yanFoto, etiket: 'Yan Fotograf', ikon: Icons.accessibility_rounded, tikla: () => fotoDialog(false)))]),
            const SizedBox(height: 16),
            KareSlider(deger: kareCm, onChange: (v) => setState(() => kareCm = v)),
            const SizedBox(height: 16),
            _AnalizButon(hazir: onFoto != null && yanFoto != null, yukleniyor: yukleniyor, tikla: analiz),
            if (hata != null) ...[const SizedBox(height: 12), _HataKutusu(mesaj: hata!)],
            if (sonuc != null) ...[const SizedBox(height: 20), _SonucKarti(veri: sonuc!)],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AnalizButon extends StatelessWidget {
  final bool hazir, yukleniyor;
  final VoidCallback tikla;
  const _AnalizButon({required this.hazir, required this.yukleniyor, required this.tikla});
  @override
  Widget build(BuildContext context) {
    if (yukleniyor) return Container(height: 54, decoration: BoxDecoration(color: ThemeColors.card, borderRadius: BorderRadius.circular(14)), child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: ThemeColors.accent, strokeWidth: 2)), SizedBox(width: 12), Text('Analiz ediliyor...', style: TextStyle(color: ThemeColors.accent, fontWeight: FontWeight.w600))])));
    return GestureDetector(
      onTap: tikla,
      child: Container(height: 54, decoration: BoxDecoration(gradient: LinearGradient(colors: hazir ? [ThemeColors.accentDark, ThemeColors.accent] : [ThemeColors.card, ThemeColors.card]), borderRadius: BorderRadius.circular(14), boxShadow: hazir ? [BoxShadow(color: ThemeColors.accent.withAlpha(70), blurRadius: 12, offset: const Offset(0, 4))] : []), child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.analytics_rounded, color: hazir ? Colors.black : ThemeColors.subText, size: 20), const SizedBox(width: 8), Text('Analiz Et', style: TextStyle(color: hazir ? Colors.black : ThemeColors.subText, fontSize: 16, fontWeight: FontWeight.bold))]))),
    );
  }
}

class _HataKutusu extends StatelessWidget {
  final String mesaj;
  const _HataKutusu({required this.mesaj});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThemeColors.danger.withAlpha(30), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeColors.danger.withAlpha(100))), child: Row(children: [const Icon(Icons.error_outline_rounded, color: ThemeColors.danger, size: 20), const SizedBox(width: 8), Expanded(child: Text(mesaj, style: const TextStyle(color: ThemeColors.danger, fontSize: 12)))]));
  }
}

class _SonucKarti extends StatelessWidget {
  final Map<String, dynamic> veri;
  const _SonucKarti({required this.veri});
  @override
  Widget build(BuildContext context) {
    final double kilo = (veri['kilo_kg'] ?? 0).toDouble();
    final double boy  = (veri['boy_cm'] ?? 0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Icons.check_circle_rounded, color: ThemeColors.accent, size: 18), const SizedBox(width: 6), const Text('Analiz Sonuclari', style: TextStyle(color: ThemeColors.text, fontWeight: FontWeight.bold, fontSize: 15)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: ThemeColors.accent.withAlpha(30), borderRadius: BorderRadius.circular(20)), child: Text(veri['yontem'] ?? '-', style: const TextStyle(color: ThemeColors.accent, fontSize: 11, fontWeight: FontWeight.w600)))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: _BuyukSonucCard(ikon: Icons.monitor_weight_outlined, etiket: 'Kilo', deger: '${kilo.toStringAsFixed(1)} kg', renk: ThemeColors.gold)), const SizedBox(width: 10), Expanded(child: _BuyukSonucCard(ikon: Icons.height_rounded, etiket: 'Boy', deger: '${boy.toStringAsFixed(1)} cm', renk: ThemeColors.accent))]),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
          children: [
            _MiniSonucCard(ikon: Icons.zoom_in_rounded, etiket: 'Derinlik', deger: '${(veri['ortalama_derinlik_cm'] ?? 0).toStringAsFixed(1)} cm'),
            _MiniSonucCard(ikon: Icons.swap_horiz_rounded, etiket: 'Genislik', deger: '${(veri['max_genislik_cm'] ?? 0).toStringAsFixed(1)} cm'),
            _MiniSonucCard(ikon: Icons.view_in_ar_rounded, etiket: 'Hacim', deger: '${((veri['hacim_cm3'] ?? 0) / 1000).toStringAsFixed(1)} L'),
            _MiniSonucCard(ikon: Icons.straighten_rounded, etiket: 'px/cm', deger: (veri['px_per_cm'] ?? 0).toStringAsFixed(2)),
          ],
        ),
      ],
    );
  }
}

class _BuyukSonucCard extends StatelessWidget {
  final IconData ikon; final String etiket, deger; final Color renk;
  const _BuyukSonucCard({required this.ikon, required this.etiket, required this.deger, required this.renk});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: ThemeColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: renk.withAlpha(60))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(ikon, color: renk, size: 24), const SizedBox(height: 8), Text(etiket, style: const TextStyle(color: ThemeColors.subText, fontSize: 12)), const SizedBox(height: 2), Text(deger, style: TextStyle(color: renk, fontSize: 22, fontWeight: FontWeight.bold))]));
  }
}

class _MiniSonucCard extends StatelessWidget {
  final IconData ikon; final String etiket, deger;
  const _MiniSonucCard({required this.ikon, required this.etiket, required this.deger});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ThemeColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)), child: Row(children: [Icon(ikon, color: ThemeColors.subText, size: 20), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(etiket, style: const TextStyle(color: ThemeColors.subText, fontSize: 10)), Text(deger, style: const TextStyle(color: ThemeColors.text, fontSize: 13, fontWeight: FontWeight.bold))])]));
  }
}
