import os
import traceback
import tempfile

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse
import uvicorn

# WeightEstimator'i ayni klasorden import et
from weight_estimator import WeightEstimator

# ─────────────────────────────────────────────
app = FastAPI(
    title="Fotograftan Kilo Tahmini API",
    description="""
## Fotograftan Kilo Tahmini

Iki fotograf gonderin:
- **on**: Ondan cekilmis fotograf (yesil kare bu fotografta olmali)
- **yan**: Yandan cekilmis fotograf (90 derece yan)

Ve yeşil karenin gercek boyutunu belirtin (`kare_cm`).

### Cevap
```json
{
  "boy_cm": 164.3,
  "kilo_kg": 69.7,
  "hacim_cm3": 68965,
  "ortalama_derinlik_cm": 19.8,
  "yontem": "On + Yan Fotograf"
}
```
""",
    version="1.0.0"
)

# ─────────────────────────────────────────────
#  Yardimci: upload edilen dosyayi gecici klasore kaydet
# ─────────────────────────────────────────────
def save_upload(upload: UploadFile) -> str:
    suffix = os.path.splitext(upload.filename)[1] if upload.filename else ".jpg"
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    tmp.write(upload.file.read())
    tmp.flush()
    tmp.close()
    return tmp.name


# ─────────────────────────────────────────────
#  POST /tahmin
#  Form-data:
#    on    : Fotograf dosyasi (zorunlu)
#    yan   : Fotograf dosyasi (opsiyonel)
#    kare_cm : float (opsiyonel, varsayilan config.json'dan)
# ─────────────────────────────────────────────
@app.post(
    "/tahmin",
    summary="Kilo Tahmini Yap",
    response_description="Tahmini boy ve kilo bilgisi",
)
async def tahmin(
    on:      UploadFile = File(...,  description="Ondan cekilmis fotograf (yesil kare icinde)"),
    yan:     UploadFile = File(None, description="Yandan cekilmis fotograf (opsiyonel)"),
    kare_cm: float      = Form(None, description="Yesil karenin kenar uzunlugu cm cinsinden"),
):
    front_path = None
    side_path  = None

    try:
        # Dosyalari gecici klasore kaydet
        front_path = save_upload(on)
        side_path  = save_upload(yan) if (yan and yan.filename) else None

        # Tahmin motoru
        estimator = WeightEstimator(square_cm=kare_cm)

        result = estimator.estimate_weight(front_path, side_path)

        if result is None:
            raise HTTPException(
                status_code=422,
                detail="Tahmin yapilamadi. Fotograflarda kisi veya yesil kare tespit edilemedi."
            )

        return JSONResponse(content=result)

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

    finally:
        # Gecici dosyalari temizle
        if front_path and os.path.exists(front_path):
            os.remove(front_path)
        if side_path and os.path.exists(side_path):
            os.remove(side_path)


# ─────────────────────────────────────────────
#  GET /saglik
# ─────────────────────────────────────────────
@app.get("/saglik", summary="API saglık kontrolu")
def saglik():
    return {"durum": "calisıyor", "versiyon": "1.0.0"}


# ─────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
