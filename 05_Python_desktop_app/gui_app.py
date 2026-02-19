# gui_app.py

import os
import threading
import queue
import logging
import tkinter as tk
from tkinter import filedialog, messagebox
import customtkinter as ctk

from excel_io import contar_registros
from orquestador import ejecutar
from utils_rutas import work_path
import sys

# Configuración inicial de CustomTkinter
ctk.set_appearance_mode("System")  # "System", "Dark", "Light"
ctk.set_default_color_theme("blue")  # "blue", "green", "dark-blue"


def resource_path(relative_path):
    base_path = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)


class QueueHandler(logging.Handler):
    """Envía records de logging a una cola (thread-safe)."""
    def __init__(self, log_queue: queue.Queue):
        super().__init__()
        self.log_queue = log_queue

    def emit(self, record):
        self.log_queue.put(record)


class App(ctk.CTk):
    def __init__(self):
        super().__init__()

        # Icono de la ventana
        try:
            self.iconbitmap(resource_path(r"assets\app.ico"))
        except Exception:
            pass # Si falla el icono no es crítico

        self.title("Orquestador AVANSAT")
        self.geometry("1100x750")

        # Logos (PNG) - Se mantienen con tk.PhotoImage por compatibilidad simple
        try:
            self.img_logo_pyp = tk.PhotoImage(file=resource_path(r"assets\Logo_PYP.png")).subsample(5, 5)
            self.img_logo_smart = tk.PhotoImage(file=resource_path(r"assets\SMART.png")).subsample(4, 4)
        except Exception:
            self.img_logo_pyp = None
            self.img_logo_smart = None

        # Estado
        self.excel_path = ""
        self.log_file = str(work_path("logs/run.log"))
        self.total_global = 0
        self.done_global = 0
        self.worker_running = False

        # Cola para logs/progreso
        self.log_queue = queue.Queue()

        # Variables GUI
        self.var_excel = tk.StringVar(value="(No seleccionado)")

        # Etiquetas (texto fijo)
        # Valores (numéricos)
        self.var_manifiestos_n = tk.StringVar(value="-")
        self.var_servicios_n = tk.StringVar(value="-")
        self.var_prefacturas_n = tk.StringVar(value="-")
        self.var_actualizar_n = tk.StringVar(value="-")

        self.var_etapa = tk.StringVar(value="Etapa: -")
        self.var_ver_navegador = tk.BooleanVar(value=False)

        self._build_ui()
        self.after(100, self._poll_log_queue)

    def _build_ui(self):
        # Frame principal con padding
        main_frame = ctk.CTkFrame(self)
        main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # ===== HEADER: Controles y Logos =====
        top_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        top_frame.pack(fill="x", pady=(0, 20))
        top_frame.columnconfigure(0, weight=1)
        top_frame.columnconfigure(1, weight=0)

        # --- Columna Izquierda: Archivo y Acciones ---
        left_panel = ctk.CTkFrame(top_frame, fg_color="transparent")
        left_panel.grid(row=0, column=0, sticky="nw")

        # Fila 1: Selección de Archivo
        file_frame = ctk.CTkFrame(left_panel)
        file_frame.pack(fill="x", pady=(0, 10))

        ctk.CTkLabel(file_frame, text="Archivo Excel:", font=ctk.CTkFont(weight="bold")).pack(side="left", padx=10, pady=10)
        self.lbl_excel = ctk.CTkLabel(file_frame, textvariable=self.var_excel, text_color="gray70", anchor="w")
        self.lbl_excel.pack(side="left", fill="x", expand=True, padx=(0, 10))
        
        self.btn_excel = ctk.CTkButton(left_panel, text="Cargar Excel Liquidaciones", command=self.on_cargar_excel, height=40)
        self.btn_excel.pack(fill="x", pady=(0, 10))

        # Checkbox
        self.chk_ver = ctk.CTkCheckBox(left_panel, text="Ver navegador (desactivar headless)", variable=self.var_ver_navegador)
        self.chk_ver.pack(anchor="w", pady=(0, 10))

        # Botón Iniciar destacado
        self.btn_iniciar = ctk.CTkButton(
            left_panel, 
            text="INICIAR PROCESO", 
            command=self.on_iniciar, 
            state="disabled", 
            height=50,
            font=ctk.CTkFont(size=16, weight="bold"),
            fg_color="#2CC985", hover_color="#229A66" # Verde estilo éxito
        )
        self.btn_iniciar.pack(fill="x")

        # --- Columna Derecha: Logos ---
        right_panel = ctk.CTkFrame(top_frame, fg_color="transparent")
        right_panel.grid(row=0, column=1, sticky="ne", padx=(40, 0))

        if self.img_logo_pyp:
            tk.Label(right_panel, image=self.img_logo_pyp, bg=self._apply_appearance_mode(self._fg_color)).pack(anchor="e", pady=(0, 10))
        if self.img_logo_smart:
            tk.Label(right_panel, image=self.img_logo_smart, bg=self._apply_appearance_mode(self._fg_color)).pack(anchor="e")

        # ===== STATS & PROGRESS =====
        info_frame = ctk.CTkFrame(main_frame)
        info_frame.pack(fill="x", pady=(0, 20))
        
        # Grid para contadores
        # Usaremos grid uniforme para que se vea ordenado
        for i in range(4):
            info_frame.columnconfigure(i, weight=1)

        def create_stat_card(parent, col, title, var_value):
            card = ctk.CTkFrame(parent, fg_color=("gray90", "gray20"))
            card.grid(row=0, column=col, padx=5, pady=10, sticky="ew")
            
            ctk.CTkLabel(card, text=title, font=ctk.CTkFont(size=12, weight="bold")).pack(pady=(10, 0))
            ctk.CTkLabel(card, textvariable=var_value, font=ctk.CTkFont(size=24, weight="bold"), text_color="#1f6aa5").pack(pady=(0, 10))

        create_stat_card(info_frame, 0, "Manifiestos", self.var_manifiestos_n)
        create_stat_card(info_frame, 1, "Servicios Esp.", self.var_servicios_n)
        create_stat_card(info_frame, 2, "Prefacturas", self.var_prefacturas_n)
        create_stat_card(info_frame, 3, "Act. Facturas", self.var_actualizar_n)

        # Barra de progreso
        self.progress_frame = ctk.CTkFrame(main_frame, fg_color="transparent")
        self.progress_frame.pack(fill="x", pady=(0, 10))

        self.lbl_etapa = ctk.CTkLabel(self.progress_frame, textvariable=self.var_etapa, anchor="w", font=ctk.CTkFont(size=13))
        self.lbl_etapa.pack(fill="x", pady=(0, 5))

        self.progress = ctk.CTkProgressBar(self.progress_frame, height=20)
        self.progress.pack(fill="x")
        self.progress.set(0)

        # ===== CONSOLA =====
        console_frame = ctk.CTkFrame(main_frame)
        console_frame.pack(fill="both", expand=True)

        ctk.CTkLabel(console_frame, text="Log de Ejecución:", font=ctk.CTkFont(weight="bold")).pack(anchor="w", padx=10, pady=(10, 5))

        self.txt = ctk.CTkTextbox(console_frame, font=("Consolas", 12))
        self.txt.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        self.txt.configure(state="disabled")

        # Hooks para colores en log (simulados porque CTkTextbox no soporta tags igual que tk.Text)
        # Nota: CTkTextbox no tiene soporte completo para tags de colores múltiples fácilmente como tk.Text.
        # Por simplicidad en esta versión moderna, usaremos texto plano, o insertaremos texto con prefijos claros.

        # Botón abrir log
        self.btn_abrir_log = ctk.CTkButton(
            console_frame, 
            text="Abrir archivo log completo", 
            command=self.on_abrir_log, 
            state="disabled", 
            fg_color="transparent", 
            border_width=1, 
            text_color=("gray10", "gray90")
        )
        self.btn_abrir_log.pack(anchor="e", padx=10, pady=10)

        # Footer
        self.var_firma = tk.StringVar(value="Desarrollado por Juan Saavedra • v3.5 (Modern UI)")
        ctk.CTkLabel(self, textvariable=self.var_firma, font=ctk.CTkFont(size=10), text_color="gray50").pack(side="bottom", pady=5)

    def on_cargar_excel(self):
        if self.worker_running:
            return

        path = filedialog.askopenfilename(
            title="Selecciona el Excel de liquidaciones",
            filetypes=[("Excel", "*.xlsx *.xls"), ("Todos", "*.*")]
        )
        if not path:
            return

        self._drain_queue()
        self._clear_console()
        self.progress.set(0)
        self.done_global = 0
        self.total_global = 0
        self.var_etapa.set("Etapa: -")

        self.excel_path = path
        self.var_excel.set(path)

        try:
            c = contar_registros(path)
            self.var_manifiestos_n.set(str(c["manifiestos"]))
            self.var_servicios_n.set(str(c["servicios_especiales"]))
            self.var_prefacturas_n.set(str(c["prefacturas"]))
            self.var_actualizar_n.set(str(c["actualizar_facturas"]))

            self.total_global = (
                int(c["manifiestos"])
                + int(c["servicios_especiales"])
                + int(c["prefacturas"])
                + int(c["actualizar_facturas"])
            )
            self.done_global = 0

            self.progress.set(0)
            self.var_etapa.set("Etapa: Listo para iniciar")
            self.btn_iniciar.configure(state="normal")

        except Exception as e:
            messagebox.showerror("Excel inválido", str(e))
            self.var_manifiestos_n.set(str(c.get("manifiestos", "-")))
            self.var_servicios_n.set(str(c.get("servicios_especiales", "-")))
            self.var_prefacturas_n.set(str(c.get("prefacturas", "-")))
            self.var_actualizar_n.set(str(c.get("actualizar_facturas", "-")))

            self.var_etapa.set("Etapa: -")
            self.btn_iniciar.configure(state="disabled")

    def on_iniciar(self):
        if self.worker_running:
            return

        if not self.excel_path:
            messagebox.showwarning("Falta Excel", "Primero selecciona el archivo Excel.")
            return

        cred = self._pedir_credenciales()
        if cred is None:
            return
        usuario, clave = cred

        self._setup_gui_logging()
        self._drain_queue()
        self._clear_console()

        self.done_global = 0
        try:
            c = contar_registros(self.excel_path)
            self.total_global = (
                int(c["manifiestos"])
                + int(c["servicios_especiales"])
                + int(c["prefacturas"])
                + int(c["actualizar_facturas"])
            )
        except Exception:
            self.total_global = 0

        self.progress.set(0)
        self.var_etapa.set(f"Etapa: Iniciando... (0/{self.total_global})")

        self.worker_running = True
        self.btn_iniciar.configure(state="disabled")
        self.btn_excel.configure(state="disabled")
        self.chk_ver.configure(state="disabled")
        self.btn_abrir_log.configure(state="disabled")

        self._append_text("INFO: Iniciando proceso...\n")

        t = threading.Thread(
            target=self._worker_run,
            args=(self.excel_path, usuario, clave, self.var_ver_navegador.get()),
            daemon=True
        )
        t.start()

    def _pedir_credenciales(self):
        win = ctk.CTkToplevel(self)
        win.title("Credenciales AVANSAT")
        win.geometry("400x250")
        win.transient(self)
        win.grab_set()
            
        # Centrar ventana
        win.update_idletasks()
        width = win.winfo_width()
        height = win.winfo_height()
        x = (win.winfo_screenwidth() // 2) - (width // 2)
        y = (win.winfo_screenheight() // 2) - (height // 2)
        win.geometry('{}x{}+{}+{}'.format(width, height, x, y))

        ctk.CTkLabel(win, text="Ingrese sus credenciales", font=ctk.CTkFont(size=16, weight="bold")).pack(pady=20)

        frame_form = ctk.CTkFrame(win, fg_color="transparent")
        frame_form.pack(pady=10)

        ctk.CTkLabel(frame_form, text="Usuario:  ", width=80, anchor="w").grid(row=0, column=0, padx=10, pady=5)
        ent_user = ctk.CTkEntry(frame_form, width=200)
        ent_user.grid(row=0, column=1, padx=10, pady=5)

        ctk.CTkLabel(frame_form, text="Contraseña:", width=80, anchor="w").grid(row=1, column=0, padx=10, pady=5)
        ent_pass = ctk.CTkEntry(frame_form, width=200, show="*")
        ent_pass.grid(row=1, column=1, padx=10, pady=5)

        result = {"ok": False, "user": "", "pwd": ""}

        def aceptar():
            u = ent_user.get().strip()
            p = ent_pass.get().strip()
            if not u or not p:
                messagebox.showwarning("Datos incompletos", "Usuario y contraseña son obligatorios.", parent=win)
                return
            result["ok"] = True
            result["user"] = u
            result["pwd"] = p
            win.destroy()

        def cancelar():
            win.destroy()

        btns = ctk.CTkFrame(win, fg_color="transparent")
        btns.pack(pady=20)

        ctk.CTkButton(btns, text="Cancelar", command=cancelar, fg_color="transparent", border_width=1, text_color=("gray10", "gray90")).pack(side="left", padx=10)
        ctk.CTkButton(btns, text="Aceptar", command=aceptar).pack(side="left", padx=10)

        ent_user.focus_set()
        self.wait_window(win)

        if result["ok"]:
            return result["user"], result["pwd"]
        return None

    def _setup_gui_logging(self):
        logger = logging.getLogger("run")
        for h in list(logger.handlers):
            if isinstance(h, QueueHandler):
                logger.removeHandler(h)

        qh = QueueHandler(self.log_queue)
        fmt = logging.Formatter("%(asctime)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
        qh.setFormatter(fmt)
        qh.setLevel(logging.INFO)
        logger.addHandler(qh)

    def _progress_cb(self, done, total, etapa):
        self.log_queue.put(("__progress__", int(done), int(total), str(etapa)))

    def _worker_run(self, excel_path, usuario, clave, ver_navegador):
        resultado = ejecutar(
            excel_path=excel_path,
            usuario=usuario,
            clave=clave,
            progress_cb=self._progress_cb,
            ver_navegador=ver_navegador
        )
        self.log_queue.put(("__done__", resultado))

    def _poll_log_queue(self):
        done_event_seen = False
        done_result = None

        while True:
            try:
                item = self.log_queue.get_nowait()
            except queue.Empty:
                break

            if isinstance(item, tuple) and item and item[0] == "__progress__":
                _, done, total, etapa = item
                self.done_global = done
                self.total_global = total

                pct = 0.0
                if total > 0:
                    pct = float(done) / float(total)
                    pct = max(0.0, min(1.0, pct))

                self.progress.set(pct)
                self.var_etapa.set(f"Etapa: {etapa} ({done}/{total})")
                continue

            if isinstance(item, tuple) and item and item[0] == "__done__":
                done_event_seen = True
                done_result = item[1]
                break

            if isinstance(item, logging.LogRecord):
                msg = item.getMessage()
                try:
                    logger = logging.getLogger("run")
                    qh = None
                    for h in logger.handlers:
                        if isinstance(h, QueueHandler):
                            qh = h
                            break
                    if qh and qh.formatter:
                        msg = qh.format(item)
                except Exception:
                    pass

                self._append_text(f"[{item.levelname}] {msg}\n")
                continue

            self._append_text(str(item) + "\n")

        if done_event_seen:
            self._handle_done(done_result)

        self.after(100, self._poll_log_queue)

    def _handle_done(self, resultado: dict):
        self.worker_running = False
        self.btn_excel.configure(state="normal")
        self.chk_ver.configure(state="normal")
        self.btn_abrir_log.configure(state="normal")
        self.btn_iniciar.configure(state="normal" if self.excel_path else "disabled")

        if resultado.get("ok"):
            messagebox.showinfo("Finalizado", "Proceso finalizado correctamente.")
            self._append_text("INFO: Proceso finalizado correctamente.\n")
        else:
            messagebox.showerror("Error", f"Proceso finalizó con error:\n{resultado.get('error')}")
            self._append_text(f"ERROR: Proceso finalizó con error: {resultado.get('error')}\n")

    def _append_text(self, text):
        self.txt.configure(state="normal")
        self.txt.insert("end", text)
        self.txt.configure(state="disabled")
        self.txt.yview("end")

    def _clear_console(self):
        self.txt.configure(state="normal")
        self.txt.delete("1.0", "end")
        self.txt.configure(state="disabled")

    def _drain_queue(self):
        try:
            while True:
                self.log_queue.get_nowait()
        except queue.Empty:
            pass

    def on_abrir_log(self):
        log_path = str(work_path("logs/run.log"))
        if not os.path.exists(log_path):
            messagebox.showwarning("No existe log", f"No se encontró el archivo:\n{log_path}")
            return
        os.startfile(log_path)


def main():
    app = App()
    app.mainloop()


if __name__ == "__main__":
    main()
