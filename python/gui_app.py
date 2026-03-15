import os
import sys
import threading
import time
import socket
import logging
import traceback
import queue
import tkinter as tk
from tkinter import ttk, scrolledtext
import uvicorn

# --- AGIR KUTUPHANELERI ANA THREAD'DE DISARIDA IMPORT ET ---
print("Uygulama yukleniyor, lutfen bekleyin...")
try:
    import cv2
    import numpy as np
    from PIL import Image
    import rembg
    from api import app as fastapi_app
    print("Tum bilesenler hazir.")
except Exception as e:
    print(f"Yukleme hatasi: {e}")

# Loglama ayarları
exe_dir = os.path.dirname(sys.executable) if getattr(sys, 'frozen', False) else os.path.dirname(__file__)
log_file = os.path.join(exe_dir, "app_logs.txt")

logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

class ServerThread(threading.Thread):
    def __init__(self, gui_callback, host="0.0.0.0", port=8000):
        threading.Thread.__init__(self)
        self.gui_callback = gui_callback
        self.host = host
        self.port = port
        self.server = None
        self.daemon = True

    def run(self):
        try:
            self.gui_callback("Sunucu yapılandırılıyor...")
            
            # Uvicorn'un 'isatty' hatası vermemesi için log konfigürasyonu
            log_config = {
                "version": 1,
                "disable_existing_loggers": False,
                "formatters": {
                    "default": {
                        "()": "uvicorn.logging.DefaultFormatter",
                        "fmt": "%(levelprefix)s %(message)s",
                        "use_colors": False,
                    },
                    "access": {
                        "()": "uvicorn.logging.AccessFormatter",
                        "fmt": '%(levelprefix)s %(client_addr)s - "%(request_line)s" %(status_code)s',
                        "use_colors": False,
                    },
                },
                "handlers": {
                    "default": {
                        "formatter": "default",
                        "class": "logging.NullHandler",
                    },
                    "access": {
                        "formatter": "access",
                        "class": "logging.NullHandler",
                    },
                },
                "loggers": {
                    "uvicorn": {"handlers": ["default"], "level": "INFO"},
                    "uvicorn.error": {"level": "INFO"},
                    "uvicorn.access": {"handlers": ["access"], "level": "INFO"},
                },
            }

            config = uvicorn.Config(
                fastapi_app, 
                host=self.host, 
                port=self.port, 
                log_level="info",
                access_log=True,
                log_config=log_config
            )
            self.server = uvicorn.Server(config)
            
            # Logları arayüze yönlendir
            uvicorn_error = logging.getLogger("uvicorn.error")
            class GuiLogHandler(logging.Handler):
                def __init__(self, callback):
                    super().__init__()
                    self.callback = callback
                def emit(self, record):
                    self.callback(f"LOG: {self.format(record)}")
            
            handler = GuiLogHandler(self.gui_callback)
            handler.setFormatter(logging.Formatter("%(message)s"))
            uvicorn_error.addHandler(handler)
            logging.getLogger("uvicorn.access").addHandler(handler)
            
            self.gui_callback("Sunucu başlatıldı. Port: 8000")
            self.server.run()
        except Exception as e:
            err = f"SUNUCU HATASI: {str(e)}"
            self.gui_callback(err)
            logging.error(err)
            logging.error(traceback.format_exc())

    def stop(self):
        if self.server:
            self.server.should_exit = True

class DesktopApp:
    def __init__(self, root):
        self.root = root
        self.root.title("AI Weight Estimator - Sunucu Yönetimi")
        self.root.geometry("600x450")
        self.root.configure(bg="#1e1e2e")
        self.server_thread = None
        self.log_queue = queue.Queue()
        
        # Stil Ayarları
        self.style = ttk.Style()
        self.style.theme_use('clam')
        
        # Layout
        self.create_widgets()
        self.update_ip()
        self.process_queue()

    def create_widgets(self):
        # Başlık
        header = tk.Label(self.root, text="AI Weight Estimator Pro", font=("Segoe UI", 18, "bold"), fg="#cba6f7", bg="#1e1e2e", pady=20)
        header.pack()

        # Durum Panel
        status_frame = tk.Frame(self.root, bg="#313244", padx=15, pady=10)
        status_frame.pack(fill="x", padx=50, pady=10)

        self.lbl_status = tk.Label(status_frame, text="SUNUCU DURUMU: DURDURULDU", font=("Segoe UI", 10, "bold"), fg="#f38ba8", bg="#313244")
        self.lbl_status.pack(side="left")

        self.lbl_ip = tk.Label(status_frame, text="IP: 0.0.0.0", font=("Segoe UI", 10), fg="#a6adc8", bg="#313244")
        self.lbl_ip.pack(side="right")

        # Butonlar
        btn_frame = tk.Frame(self.root, bg="#1e1e2e", pady=20)
        btn_frame.pack()

        self.btn_start = tk.Button(btn_frame, text="SUNUCUYU BAŞLAT", font=("Segoe UI", 10, "bold"), bg="#a6e3a1", fg="#11111b", 
                                   padx=20, pady=10, command=self.start_server, bd=0, cursor="hand2")
        self.btn_start.pack(side="left", padx=10)

        self.btn_stop = tk.Button(btn_frame, text="SUNUCUYU DURDUR", font=("Segoe UI", 10, "bold"), bg="#f38ba8", fg="#11111b", 
                                  padx=20, pady=10, command=self.stop_server, bd=0, state="disabled", cursor="hand2")
        self.btn_stop.pack(side="left", padx=10)

        # Log Penceresi
        log_label = tk.Label(self.root, text="İşlem Kayıtları:", font=("Segoe UI", 9), fg="#a6adc8", bg="#1e1e2e")
        log_label.pack(anchor="w", padx=50)
        
        self.log_area = scrolledtext.ScrolledText(self.root, height=10, bg="#181825", fg="#cdd6f4", font=("Consolas", 9), bd=0)
        self.log_area.pack(fill="both", padx=50, pady=(0, 20))
        
        self.add_log("Sistem hazir. 'BAŞLAT' düğmesine basın.")

    def add_log(self, message):
        self.log_queue.put(message)

    def process_queue(self):
        try:
            while True:
                message = self.log_queue.get_nowait()
                timestamp = time.strftime("[%H:%M:%S] ")
                self.log_area.insert(tk.END, timestamp + message + "\n")
                self.log_area.see(tk.END)
                logging.info(message)
                self.log_queue.task_done()
        except queue.Empty:
            pass
        self.root.after(100, self.process_queue)

    def update_ip(self):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            self.lbl_ip.config(text=f"IP: {ip}")
        except:
            self.lbl_ip.config(text="IP: Biliniyor")

    def start_server(self):
        if self.server_thread is None or not self.server_thread.is_alive():
            self.add_log("Sunucu baslatiliyor...")
            self.btn_start.config(state="disabled", bg="#585b70")
            self.lbl_status.config(text="SUNUCU DURUMU: ÇALIŞIYOR", fg="#a6e3a1")
            
            self.server_thread = ServerThread(self.add_log)
            self.server_thread.start()
            
            self.btn_stop.config(state="normal", bg="#f38ba8")

    def stop_server(self):
        if self.server_thread:
            self.add_log("Sunucu durduruluyor...")
            self.server_thread.stop()
            self.lbl_status.config(text="SUNUCU DURUMU: DURDURULDU", fg="#f38ba8")
            self.btn_start.config(state="normal", bg="#a6e3a1")
            self.btn_stop.config(state="disabled", bg="#585b70")
            self.add_log("Sunucu kapatıldı.")

if __name__ == "__main__":
    root = tk.Tk()
    app = DesktopApp(root)
    root.mainloop()
