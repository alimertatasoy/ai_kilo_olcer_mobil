@echo off
echo AI Weight Estimator Pro - VENV Build System (Tkinter Fix)
echo -------------------------------------------

:: Eski calisanlari kapat
taskkill /f /im AI_Weight_Estimator_Pro.exe 2>nul
taskkill /f /im python.exe 2>nul

:: 1. Sanal Ortam Olusturma
echo [1/4] Sanal ortam hazirlaniyor...
if exist venv rmdir /s /q venv
python -m venv venv --system-site-packages
echo [1/4] Sanal ortam hazir.

:: 2. Kutuphaneleri Yukleme
echo [2/4] Kutuphaneler yukleniyor...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install pyinstaller rembg onnxruntime uvicorn fastapi python-multipart opencv-python pillow numba numpy pymatting

:: 3. Tkinter Kontrol
echo [3/4] Tkinter kontrol ediliyor...
python -c "import tkinter; print('Tkinter basariyla dogrulandi.')"

:: 4. EXE Olusturma
echo.
echo [4/4] EXE dosyasi paketleniyor...
echo -------------------------------------------
:: Eski dosyalari manuel temizle
if exist dist rmdir /s /q dist
if exist build rmdir /s /q build

pyinstaller --name "AI_Weight_Estimator_Pro" ^
            --onefile ^
            --noconsole ^
            --add-data "config.json;." ^
            --collect-all rembg ^
            --collect-all onnxruntime ^
            --collect-all pymatting ^
            --clean ^
            gui_app.py

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo HATA: Paketleme sirasinda bir sorun olustu.
    pause
    exit /b %ERRORLEVEL%
)

:: 5. Tamamlama
echo.
echo Islem tamamladi!
echo -------------------------------------------
echo Uygulamaniz dist klasoru icinde hazirdir.
echo.
pause
