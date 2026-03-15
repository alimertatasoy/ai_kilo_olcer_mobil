# AI Kilo Ölçer (Mobile + Backend)

Bu proje, bir veya iki adet fotoğraf (ön ve opsiyonel yan görünüm) kullanarak kişinin boy ve kilosunu tahmin eden yapay zeka tabanlı bir sistemdir. Sistem, kalibrasyon için fotoğraftaki yeşil bir referans karesini kullanır ve görüntü işleme/segmentasyon teknikleriyle vücut hacmi üzerinden ağırlık hesaplar.

## 🚀 Proje Bileşenleri

1.  **Python Backend (API):** `FastAPI` tabanlı, görüntü işleme ve kilo tahmini yapan çekirdek sistem.
2.  **Flutter Mobile:** Kullanıcının fotoğraf çekmesini ve sonuçları görmesini sağlayan mobil uygulama.

---

## 🛠️ Nasıl Çalışır? (Teknik Detaylar)

Sistem şu adımları izleyerek tahmin yürütür:

1.  **Referans Tespiti:** Ön fotoğraftaki saf yeşil kareyi (`HSV` renk uzayında) tespit eder. Karenin gerçek boyutunu (örn: 30x30 cm) referans alarak **piksel/cm** oranını hesaplar.
2.  **Segmentasyon (AI):** `rembg` (U2-Net tabanlı) kütüphanesini kullanarak arka planı kaldırır ve kişinin siluetini izole eder.
3.  **Boy Hesaplama:** Siluetin dikey uzunluğunu piksel/cm oranıyla çarparak gerçek boyu belirler.
4.  **Hacim Hesaplama (Dilimleme Metodu):** 
    *   Vücut, başından ayağına kadar 1'er piksellik yatay dilimlere ayrılır.
    *   Her dilim için ön ve yan (varsa) genişlikler alınır. 
    *   Eğer yan fotoğraf yoksa, derinlik ön genişliğin belirli bir rasyosu (varsayılan: 0.70) olarak tahmin edilir.
    *   Her dilimin alanı, eliptik bir kesit alanı ($\pi \times \frac{w}{2} \times \frac{d}{2}$) olarak hesaplanır ve entegre edilerek toplam hacim (`cm³`) bulunur.
5.  **Kilo Tahmini:** Hesaplanan hacim, insan vücut yoğunluğu (ortalama $1.01 \, g/cm^3$) ve yapılandırma dosyasındaki düzeltme faktörleriyle çarpılarak toplam ağırlık (`kg`) elde edilir.

---

## 📁 Klasör Yapısı

*   `python/`: Backend dosyaları.
    *   `api.py`: FastAPI API sunucusu.
    *   `weight_estimator.py`: Kilo tahmini yapan ana sınıf.
    *   `config.json`: Renk aralıkları, derinlik rasyosu ve yoğunluk gibi parametreler.
*   `flutter/`: Mobil uygulama kaynak kodları.
    *   `lib/kamera_ekrani.dart`: Fotoğraf çekim arayüzü.
    *   `lib/ana_ekran.dart`: Sonuç ekranı.

---

## ⚙️ Kurulum ve Çalıştırma

### 1. Backend Hazırlığı
```bash
cd python
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python api.py
```
*API varsayılan olarak `8000` portunda çalışır.*

### 2. Flutter Mobil Uygulama
*   `flutter/lib/config.dart` dosyasından veya uygulama içindeki ayar menüsünden API IP adresini (bilgisayarınızın yerel IP'si) güncelleyin.
*   Uygulamayı çalıştırın: `flutter run`

---

## 📸 Kullanım İpuçları
- **Yeşil Kare:** Mutlaka ön fotoğrafta kişinin yanında, kamera ile aynı mesafede ve düz durmalıdır.
- **Işık:** Arka plan ile kişi arasındaki kontrast ne kadar iyi olursa (sade duvar önü gibi), AI segmentasyonu o kadar hatasız çalışır.
- **Yan Fotoğraf:** Daha doğru sonuçlar için yan fotoğraf eklenmesi tavsiye edilir.

---

**Geliştirici:** [alimertatasoy](https://github.com/alimertatasoy)  
**Lisans:** MIT