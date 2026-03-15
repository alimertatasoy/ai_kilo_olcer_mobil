# Fotoğraftan Kilo Ölçümü (Python)

## Nasıl Çalışır?

Fotoğrafa **yeşil bir kare** koyuyorsunuz. Program o karenin piksel boyutunu okuyarak cm/piksel oranını hesaplıyor.
Ardından iki fotoğrafi birleştirerek vücudun hacmini hesaplıyor ve yoğunluk × hacim = kilo formülüyle sonucu buluyor.

```
Hacim (cm³) × Yoğunluk (1.01 g/cm³) ÷ 1000 = Kilo (kg)
```

---

## Kurulum

```bash
pip install opencv-python mediapipe numpy
```

---

## Kullanım

### 2 Fotoğrafla (Önerilen — Daha Doğru)

```bash
python weight_estimator.py --on on_fotograf.jpg --yan yan_fotograf.jpg --kare_cm 10
```

### Sadece 1 Fotoğrafla

```bash
python weight_estimator.py --on on_fotograf.jpg --kare_cm 10
```

---

## Argümanlar

| Argüman     | Açıklama |
|-------------|----------|
| `--on`      | Önden çekilmiş fotoğraf yolu (zorunlu) |
| `--yan`     | Yandan çekilmiş fotoğraf yolu (opsiyonel) |
| `--kare_cm` | Yeşil karenin gerçek kenar uzunluğu cm cinsinden (varsayılan: 10.0) |

---

## Fotoğraf Çekim Kuralları

1. **Yeşil kare** fotoğrafta kişinin **yanında** (aynı düzlemde) durmalıdır
2. **Ön fotoğraf**: Kamera tam karşıdan çekilmeli, kişi dik durmalı
3. **Yan fotoğraf**: Kişi tam yana dönmeli (90°), kare de görünmeli
4. **Aynı mesafe**: Her iki fotoğraf da aynı mesafeden çekilmeli
5. **İyi ışık**: Yeşil renk belirgin olmalı (başka yeşil objeler olmamalı)
6. **Arka plan**: Mümkünse sade/düz arka plan kullanın

---

## Çıktı

Program çalıştıktan sonra şunları gösterir:
- Tahmini **boy** (cm)
- Tahmini **kilo** (kg)
- **Hacim** (cm³)
- Analizin görselini `output_analysis.jpg` olarak kaydeder

---

## Dikkat

Bu sistem bir **tahmin** aracıdır. Kesin medikal ölçüm değildir.
Sonuçlar: kıyafet kalınlığı, poz, ışık, kare boyutu gibi faktörlere göre değişebilir.
