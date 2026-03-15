import 'package:flutter/material.dart';
import 'config.dart';
import 'theme_colors.dart';
import 'wizard_ekran.dart';

class IpAyarEkran extends StatefulWidget {
  const IpAyarEkran({super.key});

  @override
  State<IpAyarEkran> createState() => _IpAyarEkranState();
}

class _IpAyarEkranState extends State<IpAyarEkran> {
  final TextEditingController _ipController = TextEditingController(text: AppConfig.serverIp);
  final _formKey = GlobalKey<FormState>();

  void _baglan() {
    if (_formKey.currentState!.validate()) {
      AppConfig.serverIp = _ipController.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WizardEkran()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeColors.accent.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lan_rounded, color: ThemeColors.accent, size: 64),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sunucu Bağlantısı',
                  style: TextStyle(color: ThemeColors.text, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Analiz sunucusunun IP adresini girin',
                  style: TextStyle(color: ThemeColors.subText, fontSize: 14),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _ipController,
                  style: const TextStyle(color: ThemeColors.text),
                  decoration: InputDecoration(
                    labelText: 'Sunucu IP Adresi',
                    labelStyle: const TextStyle(color: ThemeColors.accent),
                    hintText: 'Örn: 192.168.0.16',
                    hintStyle: TextStyle(color: ThemeColors.subText.withAlpha(100)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeColors.accent.withAlpha(100)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ThemeColors.accent, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.computer, color: ThemeColors.accent),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'IP adresi gerekli';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _baglan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: const Text('Bağlan ve Devam Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
