import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'theme_colors.dart';

class KameraEkrani extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String etiket;

  const KameraEkrani({
    super.key,
    required this.cameras,
    required this.etiket,
  });

  @override
  State<KameraEkrani> createState() => _KameraEkraniState();
}

class _KameraEkraniState extends State<KameraEkrani> {
  CameraController? ctrl;
  bool hazir = false;
  bool cekiyor = false;
  int camIdx = 0;

  @override
  void initState() {
    super.initState();
    _baslat(camIdx);
  }

  Future<void> _baslat(int idx) async {
    setState(() => hazir = false);
    final old = ctrl;
    ctrl = null;
    await old?.dispose();

    final cam = widget.cameras[idx % widget.cameras.length];
    final c = CameraController(
      cam,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      if (mounted) {
        setState(() {
          ctrl = c;
          hazir = true;
        });
      } else {
        await c.dispose();
      }
    } catch (e) {
      await c.dispose();
    }
  }

  Future<void> _cek() async {
    if (ctrl == null || !hazir || cekiyor) return;
    setState(() => cekiyor = true);
    try {
      final xf = await ctrl!.takePicture();
      if (mounted) {
        Navigator.pop(context, File(xf.path));
      }
    } catch (e) {
      if (mounted) setState(() => cekiyor = false);
    }
  }

  Future<void> _kameraDegistir() async {
    if (widget.cameras.length < 2) return;
    camIdx = (camIdx + 1) % widget.cameras.length;
    await _baslat(camIdx);
  }

  @override
  void dispose() {
    ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool onMu = widget.etiket == 'ÖN';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ThemeColors.accent.withAlpha(150), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: ThemeColors.accent, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.etiket,
                          style: const TextStyle(color: ThemeColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.cameras.length > 1 ? _kameraDegistir : null,
                    icon: Icon(
                      Icons.flip_camera_ios_rounded,
                      color: widget.cameras.length > 1 ? Colors.white : Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hazir && ctrl != null)
                    ClipRect(child: CameraPreview(ctrl!))
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(child: CircularProgressIndicator(color: ThemeColors.accent)),
                    ),
                  if (hazir) CustomPaint(painter: GridPainter()),
                  if (hazir) Padding(padding: const EdgeInsets.all(32), child: CustomPaint(painter: CornerPainter())),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          onMu ? 'Tam önünden, dik durun — tüm vücut görünsün' : 'Tam yandan, dik durun — tüm vücut görünsün',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final XFile? xf = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
                      if (xf != null && mounted) Navigator.pop(context, File(xf.path));
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  GestureDetector(
                    onTap: cekiyor ? null : _cek,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          decoration: BoxDecoration(color: cekiyor ? ThemeColors.accent : Colors.white, shape: BoxShape.circle),
                          child: cekiyor
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withAlpha(45)..strokeWidth = 0.8;
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(GridPainter _) => false;
}

class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = ThemeColors.accent..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const double L = 22.0;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(const Offset(0, L), const Offset(0, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(L, 0), p);
    canvas.drawLine(Offset(w - L, 0), Offset(w, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, L), p);
    canvas.drawLine(Offset(0, h - L), Offset(0, h), p);
    canvas.drawLine(Offset(0, h), Offset(L, h), p);
    canvas.drawLine(Offset(w - L, h), Offset(w, h), p);
    canvas.drawLine(Offset(w, h), Offset(w, h - L), p);
  }
  @override
  bool shouldRepaint(CornerPainter _) => false;
}
