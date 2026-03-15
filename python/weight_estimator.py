import sys
if sys.stdout is not None:
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import cv2
import numpy as np
import argparse
import os
import json

from PIL import Image
from rembg import remove as rembg_remove

# ─────────────────────────────────────────────
#  Fotoğraftan Kilo Tahmin Edici
#  Gerekli: ön fotoğraf (yeşil kare ile birlikte)
#  Opsiyonel: yan fotoğraf (daha doğru hacim hesabı için)
# ─────────────────────────────────────────────

class WeightEstimator:
    def __init__(self, square_cm=None, density=None):
        self.config    = self.load_config()
        self.square_cm = square_cm if square_cm else self.config.get("default_square_cm", 10.0)
        self.density   = density   if density   else self.config.get("human_density", 1.01)
        self.depth_ratio = self.config.get("depth_ratio", 0.70)

    # ── Konfig yükle ──────────────────────────
    def load_config(self):
        # 1. Önce EXE'nin yanındaki config.json'a bak (Sizin düzenleyebilmeniz için)
        exe_dir = os.path.dirname(sys.argv[0])
        config_path_external = os.path.join(exe_dir, "config.json")
        
        # 2. Eğer o yoksa scriptin yanındakine bak
        config_path_internal = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
        
        target_path = config_path_external if os.path.exists(config_path_external) else config_path_internal
        
        if os.path.exists(target_path):
            with open(target_path, "r", encoding="utf-8") as f:
                return json.load(f)
        return {}

    # ── Yeşil kareyi bul, piksel/cm oranı döndür ──
    def find_reference_square(self, image):
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

        lower_green = np.array(self.config.get("green_hsv_lower", [35, 50, 50]))
        upper_green = np.array(self.config.get("green_hsv_upper", [85, 255, 255]))

        mask = cv2.inRange(hsv, lower_green, upper_green)
        # Gürültü temizle (Daha hassas 3x3 kernel)
        kernel = np.ones((3, 3), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN,  kernel)

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if not contours:
            return None

        # Her kontur için skor hesapla:
        #   karelik_skoru = 1 - |1 - w/h|   (1.0 = mükemmel kare, 0.0 = çok uzun dikdörtgen)
        #   alan_skoru    = normalize edilmiş alan
        # Ağırlıklı birleşim: kare şekline öncelik ver, alanı ikincil kullan.
        candidates = []
        max_area = 1
        for cnt in contours:
            area = cv2.contourArea(cnt)
            if area < 100:  # Daha küçük kareleri de kabul et
                continue
            peri   = cv2.arcLength(cnt, True)
            approx = cv2.approxPolyDP(cnt, 0.02 * peri, True) # Hassasiyeti artır (0.04 -> 0.02)
            # Kare tam düzgün olmayabilir, 4 yerine 4-8 arası köşe makul
            if len(approx) < 4 or len(approx) > 10:
                continue
            x, y, w, h = cv2.boundingRect(cnt)
            if w == 0 or h == 0:
                continue
            aspect = w / h if w >= h else h / w   # >= 1
            squareness = 1.0 / aspect               # 1 = kare, <1 = dikdörtgen
            candidates.append((area, squareness, cnt, (x, y, w, h)))
            if area > max_area:
                max_area = area

        if not candidates:
            return None

        # Skor: %70 karelik + %30 alan (normalize)
        best_cnt, best_rect, best_score = None, None, -1
        for area, squareness, cnt, rect in candidates:
            area_norm = area / max_area
            score = 0.70 * squareness + 0.30 * area_norm
            if score > best_score:
                best_score = score
                best_cnt   = cnt
                best_rect  = rect

        if best_cnt is not None:
            x, y, w, h = best_rect
            pixels_per_cm = (w + h) / (2.0 * self.square_cm)
            print(f"  Kare skoru: {best_score:.3f} (1.0 = mukemmel kare)")
            return pixels_per_cm, (x, y, w, h)
        return None


    # ── rembg ile arka planı kaldır, insan maskesi döndür ──
    #    is_side=True → gölge/kıyafet için orantısal erozyon uygular
    def get_person_mask(self, image_bgr, is_side=False):
        print("  [AI] Arka plan kaldırılıyor (rembg)...")
        rgb_image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        pil_img   = Image.fromarray(rgb_image)

        output  = rembg_remove(pil_img)
        out_arr = np.array(output)      # H x W x 4

        # Alpha > 128 → kişi
        alpha_mask = (out_arr[:, :, 3] > 128).astype(np.uint8)

        if is_side:
            # Gölge/kıyafet artıklarını temizlemek için erozyon.
            # Görüntü genişliğinin %3.5'i kadar (yüksek çözünürlükte de etkili olur).
            img_w  = image_bgr.shape[1]
            pct    = float(self.config.get("side_mask_erosion_pct", 3.5))
            erosion_px = max(8, int(img_w * pct / 100.0))
            kernel = np.ones((erosion_px, erosion_px), np.uint8)
            alpha_mask = cv2.erode(alpha_mask, kernel, iterations=1)
            print(f"  Erozyon: {erosion_px}px ({pct:.1f}% x goruntu genisligi={img_w}px)")

        return alpha_mask

    # ─────────────────────────────────────────────
    #  Ana analiz fonksiyonu
    # ─────────────────────────────────────────────
    def estimate_weight(self, front_image_path, side_image_path=None):
        print(f"\n{'='*55}")
        print("  Kilo Tahmini Başlatılıyor...")
        print(f"{'='*55}")

        # ─── 1. Önden fotoğrafı yükle ───────────────
        front_img = cv2.imread(front_image_path)
        if front_img is None:
            print(f"HATA: Ön fotoğraf okunamadı → {front_image_path}")
            return None

        # ─── 2. Kalibrasyon (yeşil kare) ────────────
        print("\n[1/4] Yesil kare aranıyor...")
        ref_data = self.find_reference_square(front_img)

        # DEBUG: Yeşil maskeyi kaydet
        hsv = cv2.cvtColor(front_img, cv2.COLOR_BGR2HSV)
        lower_green = np.array(self.config.get("green_hsv_lower", [35, 50, 50]))
        upper_green = np.array(self.config.get("green_hsv_upper", [85, 255, 255]))
        green_mask_debug = cv2.inRange(hsv, lower_green, upper_green)
        out_dir_debug = os.path.dirname(os.path.abspath(front_image_path))
        cv2.imwrite(os.path.join(out_dir_debug, "debug_green_mask.jpg"), green_mask_debug)
        print("  DEBUG: debug_green_mask.jpg kaydedildi (kare nerede tespit edildi?)")

        if not ref_data:
            print("HATA: Yeşil referans kare bulunamadı!")
            print("  → Ön fotoğrafta saf yeşil bir kare olduğundan emin olun.")
            return None

        px_per_cm, rect = ref_data
        sq_w_cm = rect[2] / px_per_cm
        sq_h_cm = rect[3] / px_per_cm
        print(f"  Oran      : {px_per_cm:.2f} piksel/cm")
        print(f"  Kare (px) : {rect[2]}x{rect[3]}")
        print(f"  Kare (cm) : {sq_w_cm:.1f}x{sq_h_cm:.1f}")

        # ─── 3. Ön fotoğraf segmentasyonu ───────────
        print("\n[2/4] Ön fotoğraf segmentasyonu...")
        front_mask = self.get_person_mask(front_img)
        if front_mask is None or not np.any(front_mask):
            print("HATA: Ön fotoğrafta kişi tespit edilemedi.")
            return None

        f_ys, f_xs = np.where(front_mask)
        top_y = int(np.min(f_ys))
        bot_y = int(np.max(f_ys))
        height_cm   = (bot_y - top_y) / px_per_cm
        max_w_cm    = (int(np.max(f_xs)) - int(np.min(f_xs))) / px_per_cm

        print(f"  Boy          : {height_cm:.1f} cm")
        print(f"  Max Genişlik : {max_w_cm:.1f} cm")

        # ─── 4. Yan fotoğraf (opsiyonel) ────────────
        side_mask = None
        s_ys_all  = None
        s_xs_all  = None
        s_top_y   = None
        s_bot_y   = None

        if side_image_path:
            print("\n[3/4] Yan fotograf segmentasyonu...")
            side_img = cv2.imread(side_image_path)
            if side_img is None:
                print(f"  UYARI: Yan fotograf okunamadı → {side_image_path}")
            else:
                # is_side=True → ek erozyon uygulanır
                side_mask = self.get_person_mask(side_img, is_side=True)
                if side_mask is not None and np.any(side_mask):
                    s_ys_all, s_xs_all = np.where(side_mask)
                    s_top_y  = int(np.min(s_ys_all))
                    s_bot_y  = int(np.max(s_ys_all))
                    raw_max_d_cm = (int(np.max(s_xs_all)) - int(np.min(s_xs_all))) / px_per_cm
                    print(f"  Ham Max Derinlik : {raw_max_d_cm:.1f} cm (erozyon sonrası)")
                else:
                    print("  UYARI: Yan fotografta kişi tespit edilemedi. Tahmin kullanılacak.")
                    side_mask = None
        else:
            print(f"\n[3/4] Yan fotograf yok → derinlik x{self.depth_ratio} ile tahmin edilecek")

        use_side = (side_mask is not None and s_ys_all is not None and len(s_ys_all) > 0)

        # ─── 5. Hacim hesabı (dilim dilim entegrasyon) ──
        print("\n[4/4] Hacim hesaplanıyor...")
        total_volume_cm3 = 0.0
        slice_h_cm = 1.0 / px_per_cm

        max_depth_ratio = float(self.config.get("max_depth_ratio",   0.85))
        max_depth_cm    = float(self.config.get("max_depth_cm",       28.0))
        volume_scale    = float(self.config.get("volume_scale_factor", 1.0))
        total_depth_sum = 0.0
        total_slices    = 0

        for y in range(top_y, bot_y):
            row_xs = f_xs[f_ys == y]
            if len(row_xs) == 0:
                continue
            w_front_cm = (int(np.max(row_xs)) - int(np.min(row_xs))) / px_per_cm

            # Yan derinlik
            if use_side:
                rel_y  = (y - top_y) / max(bot_y - top_y, 1)
                side_y = int(s_top_y + rel_y * (s_bot_y - s_top_y))
                side_y = max(s_top_y, min(s_bot_y, side_y))
                s_row  = s_xs_all[s_ys_all == side_y]
                if len(s_row) > 0:
                    w_side_raw = (int(np.max(s_row)) - int(np.min(s_row))) / px_per_cm
                else:
                    w_side_raw = w_front_cm * self.depth_ratio
            else:
                w_side_raw = w_front_cm * self.depth_ratio

            # Gerçekçi çift sınır:
            # 1) En fazla on genişliğinin max_depth_ratio kadarı (orantısal)
            # 2) Mutlak insan gövde sınırı max_depth_cm (genellikle 28 cm)
            w_side_cm = min(w_side_raw,
                           w_front_cm * max_depth_ratio,
                           max_depth_cm)

            total_depth_sum += w_side_cm
            total_slices    += 1

            # Eliptik kesit alanı: π × a × b
            area_cm2 = np.pi * (w_front_cm / 2.0) * (w_side_cm / 2.0)
            total_volume_cm3 += area_cm2 * slice_h_cm

        # Ölçek faktörü uygula
        total_volume_cm3 *= volume_scale

        avg_depth_cm = total_depth_sum / max(total_slices, 1)

        # ─── 6. Kilo ────────────────────────────────
        estimated_weight_kg = (total_volume_cm3 * self.density) / 1000.0
        method = "On + Yan Fotograf" if use_side else f"Sadece On Fotograf (x{self.depth_ratio})"

        print(f"\n" + "-"*55)
        print(f"  SONUCLAR  -  {method}")
        print("-"*55)
        print(f"  Tahmini Boy        : {height_cm:.1f} cm")
        print(f"  Ort. Derinlik      : {avg_depth_cm:.1f} cm  (max: {max_depth_cm}cm, x{max_depth_ratio})")
        print(f"  Olcek faktoru      : x{volume_scale}")
        print(f"  Hacim              : {total_volume_cm3:.0f} cm3")
        print(f"  Tahmini Kilo       : {estimated_weight_kg:.1f} kg")
        print("-"*55 + "\n")

        # ─── 7. Görsel çıktı ────────────────────────
        debug_img = front_img.copy()
        # Yeşil kare çerçevesi
        cv2.rectangle(debug_img,
                      (rect[0], rect[1]),
                      (rect[0]+rect[2], rect[1]+rect[3]),
                      (0, 220, 0), 3)
        # Kişi maskesi (yarı şeffaf mavi)
        overlay = debug_img.copy()
        overlay[front_mask == 1] = [255, 80, 0]
        cv2.addWeighted(overlay, 0.25, debug_img, 0.75, 0, debug_img)
        # Sonuç metni
        cv2.putText(debug_img,
                    f"Boy: {height_cm:.1f} cm | Kilo: {estimated_weight_kg:.1f} kg",
                    (20, 55), cv2.FONT_HERSHEY_SIMPLEX, 1.3, (0, 0, 0), 5)
        cv2.putText(debug_img,
                    f"Boy: {height_cm:.1f} cm | Kilo: {estimated_weight_kg:.1f} kg",
                    (20, 55), cv2.FONT_HERSHEY_SIMPLEX, 1.3, (30, 220, 30), 3)

        out_dir  = os.path.dirname(os.path.abspath(front_image_path))
        out_path = os.path.join(out_dir, "output_analysis.jpg")
        cv2.imwrite(out_path, debug_img)
        print(f"Analiz gorseli kaydedildi: {out_path}")

        # Hem CLI hem API icin sonuc sozlugu don
        return {
            "boy_cm":                round(float(height_cm),              1),
            "kilo_kg":               round(float(estimated_weight_kg),     1),
            "hacim_cm3":             round(float(total_volume_cm3),        0),
            "ortalama_derinlik_cm":  round(float(avg_depth_cm),            1),
            "max_genislik_cm":       round(float(max_w_cm),                1),
            "px_per_cm":             round(float(px_per_cm),               2),
            "yontem":                method,
            "output_gorseli":        out_path,
        }


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Komut Satırı
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Fotograftan kilo tahmini - referans: yesil kare",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "--on",
        type=str,
        dest="front",
        required=False,
        default="on.jpeg",
        help="Onden cekilmis fotografin yolu (varsayilan: on.jpeg)"
    )
    parser.add_argument(
        "--yan",
        type=str,
        dest="side",
        required=False,
        default="yan.jpeg",
        help="Yandan cekilmis fotografin yolu (varsayilan: yan.jpeg)"
    )
    parser.add_argument(
        "--kare_cm",
        type=float,
        default=None,
        dest="square_cm",
        help="Yesil karenin gercek kenar uzunlugu (cm). Varsayilan: config.json (10.0)"
    )

    args = parser.parse_args()

    # Dosya var mi kontrol et
    if not os.path.exists(args.front):
        print(f"HATA: On fotograf bulunamadi: {args.front}")
        print("Kullanim: python weight_estimator.py --on on.jpeg --yan yan.jpeg --kare_cm 30")
    else:
        estimator = WeightEstimator(square_cm=args.square_cm)
        side_path = args.side if (args.side and os.path.exists(args.side)) else None
        if args.side and not os.path.exists(args.side):
            print(f"UYARI: Yan fotograf bulunamadi ({args.side}), sadece on fotograf kullanilacak.")
        estimator.estimate_weight(args.front, side_path)
