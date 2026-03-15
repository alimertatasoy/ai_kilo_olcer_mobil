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
import 'main.dart';

class WizardEkran extends StatefulWidget {
  const WizardEkran({super.key});

  @override
  State<WizardEkran> createState() => _WizardEkranState();
}

class _WizardEkranState extends State<WizardEkran> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6; // Welcome, Front, Side, Size, Processing, Result

  File? onFoto;
  File? yanFoto;
  double kareCm = 20.0;
  bool yukleniyor = false;
  Map<String, dynamic>? sonuc;
  String? hata;

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

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
            Text(onMu ? 'Ön Fotoğraf' : 'Yan Fotoğraf', style: const TextStyle(color: ThemeColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(onMu ? 'Tam karşıdan, dik ve ortalanmış şekilde' : 'Tam yandan, dik ve ortalanmış şekilde', style: const TextStyle(color: ThemeColors.subText, fontSize: 12)),
            const SizedBox(height: 20),
            ModalButon(
              ikon: Icons.camera_alt_rounded,
              renk: ThemeColors.accent,
              yazi: 'Kamera ile Çek',
              altyazi: 'Uygulama içinde, ızgaralı rehber ile',
              tikla: () async {
                Navigator.pop(ctx);
                if (availCams.isEmpty) {
                  setState(() => hata = 'Cihazda kamera bulunamadı.');
                  return;
                }
                final File? f = await Navigator.push<File>(context, MaterialPageRoute(builder: (_) => KameraEkrani(cameras: availCams, etiket: onMu ? 'ÖN' : 'YAN')));
                if (f != null) {
                  setState(() { 
                    if (onMu) onFoto = f; else yanFoto = f; 
                    sonuc = null; 
                    hata = null; 
                  });
                  _nextStep();
                }
              },
            ),
            const SizedBox(height: 10),
            ModalButon(
              ikon: Icons.photo_library_rounded,
              renk: const Color(0xFF818CF8),
              yazi: 'Galeriden Seç',
              altyazi: 'Cihazınızdaki fotoğrafı seçin',
              tikla: () async {
                Navigator.pop(ctx);
                final XFile? xf = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
                if (xf != null) {
                  setState(() { 
                    if (onMu) onFoto = File(xf.path); else yanFoto = File(xf.path); 
                    sonuc = null; 
                    hata = null; 
                  });
                  _nextStep();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> analiz() async {
    setState(() { 
      yukleniyor = true; 
      hata = null; 
      sonuc = null; 
      _currentStep = 4; // Processing step
    });
    _pageController.animateToPage(4, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);

    try {
      final req = http.MultipartRequest('POST', Uri.parse(AppConfig.tahminEndpoint));
      req.files.add(await http.MultipartFile.fromPath('on', onFoto!.path));
      req.files.add(await http.MultipartFile.fromPath('yan', yanFoto!.path));
      req.fields['kare_cm'] = kareCm.toStringAsFixed(0);

      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        setState(() {
          sonuc = jsonDecode(res.body) as Map<String, dynamic>;
          yukleniyor = false;
        });
        _pageController.animateToPage(5, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      } else {
        setState(() {
          hata = 'Hata ${res.statusCode}: ${res.body}';
          yukleniyor = false;
        });
        _pageController.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic); // Go back to size/submit
      }
    } catch (e) {
      setState(() {
        hata = 'Bağlantı hatası: $e';
        yukleniyor = false;
      });
      _pageController.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0 && _currentStep < 4 ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThemeColors.text, size: 20),
          onPressed: _prevStep,
        ) : null,
        title: _StepProgress(current: _currentStep, total: _totalSteps),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet, size: 20, color: ThemeColors.subText),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IpAyarEkran())),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentStep = i),
        children: [
          _WelcomeStep(onNext: _nextStep),
          _PhotoStep(
            title: 'Ön Fotoğraf',
            desc: 'Lütfen kamerayı dik tutarak tam karşıdan bir fotoğraf çekin.',
            foto: onFoto,
            icon: Icons.face_rounded,
            guideAsset: 'assets/front_guide.png',
            onPick: () => fotoDialog(true),
            onNext: _nextStep,
          ),
          _PhotoStep(
            title: 'Yan Fotoğraf',
            desc: 'Lütfen yana dönerek vücut profilinizi gösteren bir fotoğraf çekin.',
            foto: yanFoto,
            icon: Icons.accessibility_rounded,
            guideAsset: 'assets/side_guide.png',
            onPick: () => fotoDialog(false),
            onNext: _nextStep,
          ),
          _SizeStep(
            kareCm: kareCm,
            onChanged: (v) => setState(() => kareCm = v),
            onAnalyze: analiz,
            hata: hata,
          ),
          const _ProcessingStep(),
          if (sonuc != null) _ResultStep(sonuc: sonuc!, onRestart: () {
            setState(() {
              onFoto = null;
              yanFoto = null;
              sonuc = null;
              hata = null;
              _currentStep = 0;
            });
            _pageController.jumpToPage(0);
          }) else Container(),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int current, total;
  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: 120,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 120 * ((current + 1) / total),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ThemeColors.accentDark, ThemeColors.accent]),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: ThemeColors.accent.withAlpha(100), blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ThemeColors.accent.withAlpha(50),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'AI Kilo Tahmin',
              style: TextStyle(color: ThemeColors.accent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hoş Geldiniz!',
              style: TextStyle(color: ThemeColors.text, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yapay zeka ile kilo tahmini yapmak için sadece iki fotoğrafınıza ihtiyacımız var.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeColors.subText, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 48),
            
            _DetailedInfoItem(
              icon: Icons.camera_alt_rounded, 
              title: 'Fotoğrafları Çekin', 
              desc: 'Ön ve yan profilden vücudunuzu gösteren görseller yükleyin.'
            ),
            const SizedBox(height: 24),
            _DetailedInfoItem(
              icon: Icons.straighten_rounded, 
              title: 'Ölçüleri Doğrulayın', 
              desc: 'Referans nesnenin gerçek boyutunu saniyeler içinde girin.'
            ),
            const SizedBox(height: 24),
            _DetailedInfoItem(
              icon: Icons.security_rounded, 
              title: 'Gizlilik ve Güvenlik', 
              desc: 'Fotoğraflarınız kesinlikle sunucuda saklanmaz ve 3. şahıslarla paylaşılmaz.'
            ),
            
            const SizedBox(height: 60),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: ThemeColors.subText, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gizliliğiniz bizim için önemli. Analiz bittiğinde tüm veriler anlık olarak silinir.',
                      style: TextStyle(color: ThemeColors.subText, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            _LargeButton(text: 'Hadi Başlayalım', icon: Icons.arrow_forward_rounded, onPressed: onNext, isPrimary: true),
          ],
        ),
      ),
    );
  }
}

class _DetailedInfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _DetailedInfoItem({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThemeColors.accent.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ThemeColors.accent, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: ThemeColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: ThemeColors.subText, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoStep extends StatelessWidget {
  final String title, desc;
  final File? foto;
  final IconData icon;
  final String guideAsset;
  final VoidCallback onPick;
  final VoidCallback onNext;
  
  const _PhotoStep({
    required this.title, 
    required this.desc, 
    required this.foto, 
    required this.icon, 
    required this.guideAsset,
    required this.onPick,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Decoration to reduce "emptiness"
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeColors.accent.withAlpha(10),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: ThemeColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(color: ThemeColors.text, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(desc, style: const TextStyle(color: ThemeColors.subText, fontSize: 15, height: 1.5)),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ThemeColors.card,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: foto != null ? ThemeColors.accent : Colors.white10, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: (foto != null ? ThemeColors.accent : Colors.black).withAlpha(30),
                            blurRadius: 30,
                            spreadRadius: -10,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: foto != null ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(foto!, fit: BoxFit.cover),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black.withAlpha(160), Colors.transparent, Colors.transparent],
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 24,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: ThemeColors.accent, size: 22),
                                    SizedBox(width: 8),
                                    Text('Fotoğraf Hazır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 20,
                              right: 20,
                              child: GestureDetector(
                                onTap: onPick,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.black.withAlpha(200), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ) : Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: 0.9,
                              child: Image.asset(guideAsset, fit: BoxFit.cover),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black.withAlpha(120), Colors.transparent],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                                  child: const Text('Rehber Görünüm', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Clothing Advice Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeColors.accent.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeColors.accent.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: ThemeColors.accent, size: 24),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Önemli İpucu', style: TextStyle(color: ThemeColors.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 4),
                          Text(
                            'Bol kıyafetler yerine vücudunuzu belli edecek kıyafetler daha doğru sonuçlar verir.',
                            style: TextStyle(color: ThemeColors.subText, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              _LargeButton(
                text: foto != null ? 'Devam Et' : 'Fotoğraf Seç',
                icon: foto != null ? Icons.arrow_forward_rounded : Icons.add_a_photo_rounded,
                onPressed: foto != null ? onNext : onPick,
                isPrimary: foto != null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SizeStep extends StatelessWidget {
  final double kareCm;
  final ValueChanged<double> onChanged;
  final VoidCallback onAnalyze;
  final String? hata;
  const _SizeStep({required this.kareCm, required this.onChanged, required this.onAnalyze, this.hata});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Son Adım', style: TextStyle(color: ThemeColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Fotoğraftaki yeşil referans karenin gerçek boyutunu girin.', style: TextStyle(color: ThemeColors.subText, fontSize: 14)),
          const SizedBox(height: 40),
          KareSlider(deger: kareCm, onChange: onChanged),
          if (hata != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ThemeColors.danger.withAlpha(30), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThemeColors.danger.withAlpha(100))),
              child: Row(children: [const Icon(Icons.error_outline_rounded, color: ThemeColors.danger), const SizedBox(width: 12), Expanded(child: Text(hata!, style: const TextStyle(color: ThemeColors.danger, fontSize: 13)))]),
            ),
          ],
          const Spacer(),
          _LargeButton(text: 'Analizi Başlat', icon: Icons.analytics_rounded, onPressed: onAnalyze, isPrimary: true),
        ],
      ),
    );
  }
}

class _ProcessingStep extends StatefulWidget {
  const _ProcessingStep();

  @override
  State<_ProcessingStep> createState() => _ProcessingStepState();
}

class _ProcessingStepState extends State<_ProcessingStep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThemeColors.accent.withAlpha(100), width: 2),
              ),
              child: const Icon(Icons.sync_rounded, color: ThemeColors.accent, size: 48),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Kilonuz Hesaplanıyor...', style: TextStyle(color: ThemeColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Yapay zeka modellerimiz görselleri analiz ediyor.\nLütfen bekleyin.', textAlign: TextAlign.center, style: TextStyle(color: ThemeColors.subText, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ResultStep extends StatelessWidget {
  final Map<String, dynamic> sonuc;
  final VoidCallback onRestart;
  const _ResultStep({required this.sonuc, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final double kilo = (sonuc['kilo_kg'] ?? 0).toDouble();
    final double boy  = (sonuc['boy_cm'] ?? 0).toDouble();
    final double boyMetre = boy / 100;
    final double vki = boyMetre > 0 ? kilo / (boyMetre * boyMetre) : 0;

    String vkiDurum = '';
    Color vkiRenk = Colors.white;
    String vkiOneri = '';

    if (vki < 18.5) {
      vkiDurum = 'Zayıf';
      vkiRenk = Colors.lightBlueAccent;
      vkiOneri = 'Düzenli beslenmeye ve karbonhidrat alımına dikkat etmelisin.';
    } else if (vki < 25) {
      vkiDurum = 'Normal';
      vkiRenk = ThemeColors.accent;
      vkiOneri = 'Harika! Kilonuz boyunuz için ideal. Sağlıklı yaşam tarzınızı koruyun.';
    } else if (vki < 30) {
      vkiDurum = 'Fazla Kilolu';
      vkiRenk = Colors.orangeAccent;
      vkiOneri = 'Biraz daha hareket etmeyi ve porsiyon kontrolünü deneyebilirsin.';
    } else if (vki < 35) {
      vkiDurum = 'Obez (Tip 1)';
      vkiRenk = Colors.deepOrangeAccent;
      vkiOneri = 'Beslenme alışkanlıklarını gözden geçirmeli ve bir uzmana danışmalısın.';
    } else {
      vkiDurum = 'Aşırı Obez';
      vkiRenk = ThemeColors.danger;
      vkiOneri = 'Sağlığın için acilen spor ve diyet programına başlamanı öneririz.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: ThemeColors.accent, size: 64),
          const SizedBox(height: 16),
          const Text('Analiz Tamamlandı!', style: TextStyle(color: ThemeColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [ThemeColors.card, ThemeColors.surface]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _ResultRow(label: 'Tahmini Kilo', value: '${kilo.toStringAsFixed(1)} kg', color: ThemeColors.gold, icon: Icons.monitor_weight_rounded),
                const Divider(color: Colors.white10, height: 24),
                _ResultRow(label: 'Tahmini Boy', value: '${boy.toStringAsFixed(1)} cm', color: ThemeColors.accent, icon: Icons.height_rounded),
                const Divider(color: Colors.white10, height: 24),
                _ResultRow(label: 'Vücut Kitle Endeksi', value: '${vki.toStringAsFixed(1)} ($vkiDurum)', color: vkiRenk, icon: Icons.speed_rounded),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: vkiRenk.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: vkiRenk.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: vkiRenk, size: 20),
                    const SizedBox(width: 8),
                    const Text('Öneri', style: TextStyle(color: ThemeColors.text, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(vkiOneri, style: const TextStyle(color: ThemeColors.subText, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              _ResultMiniCard(label: 'Hacim', value: '${((sonuc['hacim_cm3'] ?? 0) / 1000).toStringAsFixed(1)} L', icon: Icons.view_in_ar_rounded),
              _ResultMiniCard(label: 'Genişlik', value: '${(sonuc['max_genislik_cm'] ?? 0).toStringAsFixed(1)} cm', icon: Icons.swap_horiz_rounded),
              _ResultMiniCard(label: 'Derinlik', value: '${(sonuc['ortalama_derinlik_cm'] ?? 0).toStringAsFixed(1)} cm', icon: Icons.zoom_in_rounded),
              _ResultMiniCard(label: 'Yöntem', value: sonuc['yontem'] ?? 'AI', icon: Icons.psychology_rounded),
            ],
          ),
          
          const SizedBox(height: 40),
          _LargeButton(text: 'Yeniden Dene', icon: Icons.refresh_rounded, onPressed: onRestart),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Helpers
class _AnimatedPulseIcon extends StatefulWidget {
  final IconData icon;
  const _AnimatedPulseIcon({required this.icon});

  @override
  State<_AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<_AnimatedPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ThemeColors.accent.withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: 64, color: ThemeColors.accent),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}



class _LargeButton extends StatelessWidget {
  final String text; final IconData icon; final VoidCallback onPressed; final bool isPrimary;
  const _LargeButton({required this.text, required this.icon, required this.onPressed, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? ThemeColors.accent : ThemeColors.card,
          foregroundColor: isPrimary ? Colors.black : ThemeColors.text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: isPrimary ? 8 : 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label, value; final Color color; final IconData icon;
  const _ResultRow({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 20),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: ThemeColors.subText, fontSize: 14)), Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]),
      ],
    );
  }
}

class _ResultMiniCard extends StatelessWidget {
  final String label, value; final IconData icon;
  const _ResultMiniCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ThemeColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ThemeColors.accent, size: 20),
          const Spacer(),
          Text(label, style: const TextStyle(color: ThemeColors.subText, fontSize: 11)),
          Text(value, style: const TextStyle(color: ThemeColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
