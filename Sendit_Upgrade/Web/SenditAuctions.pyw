"""
Sendit auction data app (built into SenditAuctions.exe by tools/build_auctions.ps1): one small window to
set up, update and remove the background fetch of the auction house (auctions.py does the work).

  SenditAuctions.exe          the window: API client, region, WoW folder; Set up / Fetch now / Uninstall
  SenditAuctions.exe --task   one quiet look, as the Windows task runs it every EVERY minutes
  SenditAuctions.exe --install / --uninstall   the same without the window (the saved config is used)

Set up copies the program to %LOCALAPPDATA%/Programs/Sendit Auctions, adds a start menu entry and the
task, then fetches at once. Uninstall removes task, entry and program; the API client stays in the
config so a new setup needs nothing typed again. Texts follow the Windows language (en/de/fr/es/ru).
"""
import ctypes
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
import tkinter as tk
import urllib.error
import webbrowser
from pathlib import Path
from tkinter import filedialog, ttk

import auctions as core

APP = "SenditAuctions.exe"
INSTALL_DIR = Path(os.environ.get("LOCALAPPDATA", Path.home())) / "Programs" / "Sendit Auctions"
SHORTCUT = (Path(os.environ.get("APPDATA", Path.home())) / "Microsoft" / "Windows" / "Start Menu" / "Programs"
            / "Sendit Auctions.lnk")
NO_WINDOW = 0x08000000
DETACHED = 0x00000008
REGIONS = ("eu", "us", "kr", "tw")
STATUS_EVERY = 20000  # ms between two status reads (the task writes the config)
WIDTH = 580

COLORS = {"bg": "#181d2d", "panel": "#1c2234", "field": "#232a3f", "side": "#121624", "text": "#f6f8fd",
          "dim": "#c3cadd", "muted": "#9aa2b9", "accent": "#e6ba66", "onAccent": "#0a0d14",
          "success": "#6bd999", "warning": "#fabf4d", "danger": "#f57373", "line": "#2b3248"}

TEXTS = {
    "en": {
        "title": "Auction data", "subtitle": "Fetches your auction house for the upgrade scan of Sendit Upgrade.",
        "installed": "Set up - looks every {} minutes", "not_installed": "Not set up",
        "data": "Data from {} · {} · {} auctions", "no_data": "No auction data yet",
        "last": "Last look {}: {}", "new": "new data", "same": "no newer data",
        "client_id": "Client ID", "secret": "Client secret", "region": "Region", "wow": "WoW folder",
        "create_client": "Create a free API client", "install": "Set up", "update": "Update",
        "fetch": "Fetch now", "uninstall": "Uninstall", "busy": "Working ...",
        "err_fields": "Please fill in client ID, client secret and the WoW Forever folder.",
        "err_wow": "This folder has no Interface and WTF folder - pick the _forever_ folder of WoW.",
        "err_auth": "Battle.net refused the client ID or the client secret.",
        "err_net": "No connection to Battle.net: {}",
        "done_install": "Set up. The data is fetched every {} minutes; in game /reload loads it.",
        "done_fresh": "The data addon is new: restart the game once.",
        "uninstall_q": "Remove the background job and the program?\nYour client ID and secret stay saved.",
        "uninstalled": "Removed. Client ID and secret stay saved for a new setup.",
        "house_title": "Your auction house",
        "house_text": "No in-game scan to match yet. Scan once at the auction house in game (/gc ah, Scan again) "
                      "and press Fetch now - or pick the house here:",
        "ok": "OK", "cancel": "Cancel",
    },
    "de": {
        "title": "Auktionsdaten", "subtitle": "Holt dein Auktionshaus für den Upgrade-Scan von Sendit Upgrade.",
        "installed": "Eingerichtet - schaut alle {} Minuten", "not_installed": "Nicht eingerichtet",
        "data": "Stand {} · {} · {} Auktionen", "no_data": "Noch keine Auktionsdaten",
        "last": "Zuletzt geschaut {}: {}", "new": "neue Daten", "same": "keine neueren Daten",
        "client_id": "Client-ID", "secret": "Client-Secret", "region": "Region", "wow": "WoW-Ordner",
        "create_client": "Kostenlosen API-Client anlegen", "install": "Einrichten", "update": "Aktualisieren",
        "fetch": "Jetzt holen", "uninstall": "Deinstallieren", "busy": "Arbeite ...",
        "err_fields": "Bitte Client-ID, Client-Secret und den WoW-Forever-Ordner angeben.",
        "err_wow": "In diesem Ordner fehlen Interface und WTF - wähle den _forever_-Ordner von WoW.",
        "err_auth": "Battle.net hat Client-ID oder Client-Secret abgelehnt.",
        "err_net": "Keine Verbindung zu Battle.net: {}",
        "done_install": "Eingerichtet. Die Daten werden alle {} Minuten geholt; im Spiel lädt /reload sie.",
        "done_fresh": "Das Daten-Addon ist neu: das Spiel einmal neu starten.",
        "uninstall_q": "Hintergrund-Job und Programm entfernen?\nClient-ID und Secret bleiben gespeichert.",
        "uninstalled": "Entfernt. Client-ID und Secret bleiben für ein neues Einrichten gespeichert.",
        "house_title": "Dein Auktionshaus",
        "house_text": "Noch kein Scan zum Zuordnen. Scanne im Spiel einmal am Auktionshaus (/gc ah, Neu scannen) "
                      "und drücke dann Jetzt holen - oder wähle das Auktionshaus hier:",
        "ok": "OK", "cancel": "Abbrechen",
    },
    "fr": {
        "title": "Données d'enchères", "subtitle": "Récupère votre hôtel des ventes pour le scan d'améliorations de Sendit Upgrade.",
        "installed": "Configuré - vérifie toutes les {} minutes", "not_installed": "Non configuré",
        "data": "Données de {} · {} · {} enchères", "no_data": "Pas encore de données d'enchères",
        "last": "Dernière vérification {} : {}", "new": "nouvelles données", "same": "rien de plus récent",
        "client_id": "ID client", "secret": "Secret client", "region": "Région", "wow": "Dossier WoW",
        "create_client": "Créer un client API gratuit", "install": "Configurer", "update": "Mettre à jour",
        "fetch": "Récupérer", "uninstall": "Désinstaller", "busy": "En cours ...",
        "err_fields": "Indiquez l'ID client, le secret client et le dossier WoW Forever.",
        "err_wow": "Ce dossier n'a pas de dossiers Interface et WTF - choisissez le dossier _forever_ de WoW.",
        "err_auth": "Battle.net a refusé l'ID client ou le secret client.",
        "err_net": "Pas de connexion à Battle.net : {}",
        "done_install": "Configuré. Les données sont récupérées toutes les {} minutes ; en jeu, /reload les charge.",
        "done_fresh": "L'addon de données est nouveau : redémarrez le jeu une fois.",
        "uninstall_q": "Supprimer la tâche de fond et le programme ?\nL'ID et le secret client restent enregistrés.",
        "uninstalled": "Supprimé. L'ID et le secret client restent enregistrés pour une nouvelle configuration.",
        "house_title": "Votre hôtel des ventes",
        "house_text": "Aucun scan en jeu à comparer. Scannez une fois à l'hôtel des ventes en jeu (/gc ah, Rescanner) "
                      "puis Récupérer - ou choisissez l'hôtel ici :",
        "ok": "OK", "cancel": "Annuler",
    },
    "es": {
        "title": "Datos de subastas", "subtitle": "Obtiene tu casa de subastas para el escaneo de mejoras de Sendit Upgrade.",
        "installed": "Configurado: mira cada {} minutos", "not_installed": "Sin configurar",
        "data": "Datos de las {} · {} · {} subastas", "no_data": "Aún no hay datos de subastas",
        "last": "Última consulta {}: {}", "new": "datos nuevos", "same": "nada más reciente",
        "client_id": "ID de cliente", "secret": "Secreto de cliente", "region": "Región", "wow": "Carpeta de WoW",
        "create_client": "Crear un cliente API gratuito", "install": "Configurar", "update": "Actualizar",
        "fetch": "Obtener ahora", "uninstall": "Desinstalar", "busy": "Trabajando ...",
        "err_fields": "Indica el ID de cliente, el secreto y la carpeta de WoW Forever.",
        "err_wow": "Esta carpeta no tiene Interface ni WTF: elige la carpeta _forever_ de WoW.",
        "err_auth": "Battle.net rechazó el ID o el secreto de cliente.",
        "err_net": "Sin conexión con Battle.net: {}",
        "done_install": "Configurado. Los datos se obtienen cada {} minutos; en el juego, /reload los carga.",
        "done_fresh": "El addon de datos es nuevo: reinicia el juego una vez.",
        "uninstall_q": "¿Quitar la tarea de fondo y el programa?\nEl ID y el secreto de cliente se conservan.",
        "uninstalled": "Quitado. El ID y el secreto de cliente se conservan para volver a configurar.",
        "house_title": "Tu casa de subastas",
        "house_text": "Aún no hay escaneo para comparar. Escanea una vez en la casa de subastas en el juego "
                      "(/gc ah, Volver a escanear) y pulsa Obtener ahora, o elige la casa aquí:",
        "ok": "Aceptar", "cancel": "Cancelar",
    },
    "ru": {
        "title": "Данные аукциона", "subtitle": "Загружает ваш аукцион для поиска улучшений Sendit Upgrade.",
        "installed": "Настроено — проверка каждые {} мин.", "not_installed": "Не настроено",
        "data": "Данные от {} · {} · лотов: {}", "no_data": "Данных аукциона пока нет",
        "last": "Последняя проверка {}: {}", "new": "новые данные", "same": "новых данных нет",
        "client_id": "ID клиента", "secret": "Секрет клиента", "region": "Регион", "wow": "Папка WoW",
        "create_client": "Создать бесплатный API-клиент", "install": "Настроить", "update": "Обновить",
        "fetch": "Загрузить сейчас", "uninstall": "Удалить", "busy": "Работаю ...",
        "err_fields": "Укажите ID клиента, секрет клиента и папку WoW Forever.",
        "err_wow": "В этой папке нет Interface и WTF — выберите папку _forever_ игры.",
        "err_auth": "Battle.net отклонил ID или секрет клиента.",
        "err_net": "Нет связи с Battle.net: {}",
        "done_install": "Настроено. Данные загружаются каждые {} мин.; в игре их загружает /reload.",
        "done_fresh": "Аддон данных новый: перезапустите игру один раз.",
        "uninstall_q": "Удалить фоновую задачу и программу?\nID и секрет клиента останутся сохранены.",
        "uninstalled": "Удалено. ID и секрет клиента сохранены для новой настройки.",
        "house_title": "Ваш аукцион",
        "house_text": "Пока нет скана для сравнения. Отсканируйте аукцион в игре (/gc ah, Сканировать снова) "
                      "и нажмите Загрузить сейчас — или выберите аукцион здесь:",
        "ok": "OK", "cancel": "Отмена",
    },
}


def language():
    try:
        primary = ctypes.windll.kernel32.GetUserDefaultUILanguage() & 0x3FF
    except (AttributeError, OSError):
        return "en"
    return {0x07: "de", 0x0C: "fr", 0x0A: "es", 0x19: "ru"}.get(primary, "en")


T = TEXTS[language()]


def run(args):
    return subprocess.run(args, capture_output=True, text=True, creationflags=NO_WINDOW)


def task_command():
    """what the task starts: the installed exe, or this script under pythonw when run from source"""
    if getattr(sys, "frozen", False):
        return f'"{INSTALL_DIR / APP}" --task'
    return f'"{Path(sys.executable).with_name("pythonw.exe")}" "{Path(__file__).resolve()}" --task'


def task_installed():
    return run(["schtasks", "/query", "/tn", core.TASK]).returncode == 0


def quote_ps(text):
    return "'" + str(text).replace("'", "''") + "'"


def install():
    if getattr(sys, "frozen", False) and Path(sys.executable).resolve() != (INSTALL_DIR / APP).resolve():
        INSTALL_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(sys.executable, INSTALL_DIR / APP)
        target = INSTALL_DIR / APP
        SHORTCUT.parent.mkdir(parents=True, exist_ok=True)
        run(["powershell", "-NoProfile", "-Command",
             f"$s = (New-Object -ComObject WScript.Shell).CreateShortcut({quote_ps(SHORTCUT)}); "
             f"$s.TargetPath = {quote_ps(target)}; $s.WorkingDirectory = {quote_ps(INSTALL_DIR)}; $s.Save()"])
    done = run(["schtasks", "/create", "/f", "/tn", core.TASK, "/sc", "minute", "/mo", str(core.EVERY),
                "/tr", task_command()])
    if done.returncode != 0:
        raise RuntimeError((done.stderr or done.stdout).strip())


def uninstall():
    """task, start menu entry and program go; the config (API client) stays"""
    run(["schtasks", "/delete", "/f", "/tn", core.TASK])
    if SHORTCUT.exists():
        SHORTCUT.unlink()
    if not INSTALL_DIR.exists():
        return
    running_there = getattr(sys, "frozen", False) and INSTALL_DIR in Path(sys.executable).resolve().parents
    if running_there:  # a running exe cannot delete itself: a detached shell does it after the window closed
        subprocess.Popen(f'cmd /c ping -n 3 127.0.0.1 >nul & rmdir /s /q "{INSTALL_DIR}"',
                         creationflags=NO_WINDOW | DETACHED, close_fds=True)
    else:
        shutil.rmtree(INSTALL_DIR, ignore_errors=True)


def when(at):
    t = time.localtime(at)
    return time.strftime("%H:%M" if time.strftime("%Y%m%d", t) == time.strftime("%Y%m%d") else "%d.%m. %H:%M", t)


def thousands(n):
    return f"{n:,}".replace(",", ".") if language() in ("de", "es", "ru") else f"{n:,}"


class App:
    def __init__(self, root):
        self.root, self.work = root, queue.Queue()
        self.cfg = core.load_config()
        if not core.is_wow(self.cfg.get("wow")):
            found = core.find_wow(self.cfg)
            if found:
                self.cfg["wow"] = str(found)
        root.title("Sendit - " + T["title"])
        root.configure(bg=COLORS["bg"])
        root.resizable(False, False)
        root.minsize(WIDTH, 0)
        icon = Path(getattr(sys, "_MEIPASS", Path(__file__).parent)) / "SenditAuctions.ico"
        if icon.exists():
            root.iconbitmap(str(icon))
        self.style()
        self.build()
        self.refresh()
        root.after(100, self.poll)
        root.after(STATUS_EVERY, self.tick)

    def style(self):
        s = ttk.Style(self.root)
        s.theme_use("clam")
        s.configure("TCombobox", fieldbackground=COLORS["field"], background=COLORS["field"],
                    foreground=COLORS["text"], arrowcolor=COLORS["dim"], bordercolor=COLORS["line"],
                    lightcolor=COLORS["field"], darkcolor=COLORS["field"])
        s.map("TCombobox", fieldbackground=[("readonly", COLORS["field"])], foreground=[("readonly", COLORS["text"])])
        self.root.option_add("*TCombobox*Listbox.background", COLORS["field"])
        self.root.option_add("*TCombobox*Listbox.foreground", COLORS["text"])

    def label(self, parent, text="", color="dim", size=10, bold=False, bg="bg"):
        return tk.Label(parent, text=text, fg=COLORS[color], bg=COLORS[bg], anchor="w", justify="left", padx=0, bd=0,
                        font=("Segoe UI", size, "bold" if bold else "normal"))

    def entry(self, parent, var, secret=False):
        return tk.Entry(parent, textvariable=var, show="•" if secret else "", bg=COLORS["field"], fg=COLORS["text"],
                        insertbackground=COLORS["text"], relief="flat", font=("Segoe UI", 10),
                        highlightthickness=1, highlightbackground=COLORS["line"], highlightcolor=COLORS["accent"])

    def button(self, parent, text, command, primary=False):
        b = tk.Button(parent, text=text, command=command, relief="flat", cursor="hand2", padx=16, pady=6,
                      font=("Segoe UI", 10, "bold" if primary else "normal"),
                      bg=COLORS["accent"] if primary else COLORS["field"],
                      fg=COLORS["onAccent"] if primary else COLORS["text"],
                      activebackground=COLORS["warning"] if primary else COLORS["line"],
                      activeforeground=COLORS["onAccent"] if primary else COLORS["text"], bd=0)
        return b

    def build(self):
        root = self.root
        head = tk.Frame(root, bg=COLORS["side"], padx=24, pady=18)
        head.pack(fill="x")
        brand = tk.Frame(head, bg=COLORS["side"])
        brand.pack(anchor="w")
        self.label(brand, "Send", "text", 18, True, "side").pack(side="left")
        self.label(brand, "it", "accent", 18, True, "side").pack(side="left")
        self.label(brand, "  " + T["title"], "dim", 14, False, "side").pack(side="left", pady=(4, 0))
        self.label(head, T["subtitle"], "muted", 9, False, "side").pack(anchor="w", pady=(4, 0))

        card = tk.Frame(root, bg=COLORS["panel"], padx=24, pady=14)
        card.pack(fill="x")
        row = tk.Frame(card, bg=COLORS["panel"])
        row.pack(anchor="w", fill="x")
        self.dot = tk.Canvas(row, width=12, height=12, bg=COLORS["panel"], highlightthickness=0)
        self.dot.pack(side="left", padx=(0, 8))
        self.state = self.label(row, "", "text", 10, True, "panel")
        self.state.pack(side="left")
        self.data = self.label(card, "", "dim", 9, False, "panel")
        self.data.pack(anchor="w", pady=(6, 0))
        self.last = self.label(card, "", "muted", 9, False, "panel")
        self.last.pack(anchor="w")

        form = tk.Frame(root, bg=COLORS["bg"], padx=24, pady=16)
        form.pack(fill="x")
        form.columnconfigure(1, weight=1)
        self.client = tk.StringVar(value=self.cfg.get("client_id", ""))
        self.secret = tk.StringVar(value=self.cfg.get("client_secret", ""))
        self.region = tk.StringVar(value=self.cfg.get("region", "eu"))
        self.wow = tk.StringVar(value=self.cfg.get("wow", ""))
        fields = ((T["client_id"], self.entry(form, self.client)),
                  (T["secret"], self.entry(form, self.secret, True)),
                  (T["region"], ttk.Combobox(form, textvariable=self.region, values=REGIONS, state="readonly",
                                             width=6)))
        for i, (text, widget) in enumerate(fields):
            self.label(form, text).grid(row=i, column=0, sticky="w", pady=4, padx=(0, 16))
            widget.grid(row=i, column=1, columnspan=2, sticky="we" if i < 2 else "w", pady=4, ipady=4)
        self.label(form, T["wow"]).grid(row=3, column=0, sticky="w", pady=4, padx=(0, 16))
        self.entry(form, self.wow).grid(row=3, column=1, sticky="we", pady=4, ipady=4)
        self.button(form, "...", self.browse).grid(row=3, column=2, sticky="e", padx=(6, 0))
        link = self.label(form, T["create_client"] + "  ↗", "accent", 9)
        link.grid(row=4, column=1, sticky="w", pady=(6, 0))
        link.configure(cursor="hand2")
        link.bind("<Button-1>", lambda _: webbrowser.open(core.CLIENTS_URL))

        tk.Frame(root, bg=COLORS["line"], height=1).pack(fill="x")
        foot = tk.Frame(root, bg=COLORS["bg"], padx=24, pady=14)
        foot.pack(fill="x")
        self.message = self.label(foot, "", "dim", 9)
        self.message.pack(fill="x", pady=(0, 10))
        self.message.configure(wraplength=WIDTH - 48)
        self.remove = self.button(foot, T["uninstall"], self.on_uninstall)
        self.remove.pack(side="left")
        self.main = self.button(foot, T["install"], self.on_install, True)
        self.main.pack(side="right")
        self.now = self.button(foot, T["fetch"], self.on_fetch)
        self.now.pack(side="right", padx=(0, 8))

    def refresh(self):
        installed = task_installed()
        color = COLORS["success"] if installed else COLORS["muted"]
        self.dot.delete("all")
        self.dot.create_oval(1, 1, 11, 11, fill=color, outline=color)
        self.state.configure(text=T["installed"].format(core.EVERY) if installed else T["not_installed"])
        self.main.configure(text=T["update"] if installed else T["install"])
        self.remove.configure(state="normal" if installed or INSTALL_DIR.exists() else "disabled")
        cfg = core.load_config()
        info = core.data_info(cfg["wow"]) if cfg.get("wow") else None
        if info:
            at, name, count = info
            house = cfg.get("house") or {}
            where = f"{name} ({house['id']})" if house.get("id") else name
            self.data.configure(text=T["data"].format(when(at), where, thousands(count)))
        else:
            self.data.configure(text=T["no_data"])
        run_ = cfg.get("last_run")
        if run_:
            text = (T["new"] if run_.get("new") else T["same"]) if run_.get("ok") else run_.get("text", "")
            self.last.configure(text=T["last"].format(when(run_["at"]), text),
                                fg=COLORS["muted"] if run_.get("ok") else COLORS["danger"])
        else:
            self.last.configure(text="")

    def tick(self):
        self.refresh()
        self.root.after(STATUS_EVERY, self.tick)

    def say(self, text, color="dim"):
        self.message.configure(text=text, fg=COLORS[color])

    def browse(self):
        folder = filedialog.askdirectory(initialdir=self.wow.get() or None)
        if folder:
            self.wow.set(str(Path(folder)))

    def form(self):
        """the typed values into the newest config; None (and a message) when something is missing"""
        client, secret, wow = self.client.get().strip(), self.secret.get().strip(), self.wow.get().strip().strip('"')
        if not (client and secret and wow):
            self.say(T["err_fields"], "danger")
            return None
        if not core.is_wow(wow):
            self.say(T["err_wow"], "danger")
            return None
        cfg = core.load_config()
        if cfg.get("client_id") != client or cfg.get("client_secret") != secret or cfg.get("region") != self.region.get():
            cfg.pop("token", None)
        if cfg.get("wow") != wow:
            cfg.pop("modified", None)
        cfg.update(client_id=client, client_secret=secret, region=self.region.get(), wow=wow)
        core.save_config(cfg)
        return cfg

    def busy(self, on):
        for b in (self.main, self.now, self.remove):
            b.configure(state="disabled" if on else "normal")
        if on:
            self.say(T["busy"])

    def background(self, job, done):
        """runs job() off the window's thread; done(result, error) back on it"""
        self.busy(True)

        def worker():
            try:
                self.work.put((done, job(), None))
            except Exception as e:  # shown to the player instead of a dead window
                self.work.put((done, None, e))
        threading.Thread(target=worker, daemon=True).start()

    def poll(self):
        while not self.work.empty():
            done, result, error = self.work.get()
            self.busy(False)
            done(result, error)
            self.refresh()
        self.root.after(100, self.poll)

    def explain(self, error):
        if isinstance(error, urllib.error.HTTPError) and error.code in (400, 401, 403):
            return T["err_auth"]
        if isinstance(error, (urllib.error.URLError, OSError)):
            return T["err_net"].format(getattr(error, "reason", error))
        return f"{type(error).__name__}: {error}"

    def fetch_job(self, cfg, house=None):
        def job():
            try:
                result = core.fetch(cfg, house)
                cfg["last_run"] = {"at": int(time.time()), "ok": True, "new": result["new"],
                                   "text": "new data" if result["new"] else "no newer data"}
                return result
            finally:
                core.save_config(cfg)
        return job

    def fetched(self, cfg, intro=""):
        def done(result, error):
            if isinstance(error, core.NeedHouse):
                house = self.choose_house(error.houses)
                if house:
                    self.background(self.fetch_job(cfg, house), self.fetched(cfg, intro))
                else:
                    self.say(intro)
                return
            if error:
                self.say(self.explain(error), "danger")
                return
            text = intro
            if result.get("fresh"):
                text = (text + " " + T["done_fresh"]).strip()
            self.say(text or (T["new"] if result["new"] else T["same"]), "success")
        return done

    def on_install(self):
        cfg = self.form()
        if not cfg:
            return

        def job():
            core.Api(cfg)  # refuses a wrong client before anything is installed
            core.save_config(cfg)
            install()

        def done(_, error):
            if error:
                self.say(self.explain(error), "danger")
                return
            intro = T["done_install"].format(core.EVERY)
            self.background(self.fetch_job(cfg), self.fetched(cfg, intro))
        self.background(job, done)

    def on_fetch(self):
        cfg = self.form()
        if cfg:
            self.background(self.fetch_job(cfg), self.fetched(cfg))

    def on_uninstall(self):
        if not self.confirm(T["uninstall_q"]):
            return
        uninstall()
        self.refresh()
        self.say(T["uninstalled"], "success")

    def dialog(self, title):
        top = tk.Toplevel(self.root, bg=COLORS["bg"], padx=20, pady=16)
        top.title(title)
        top.transient(self.root)
        top.grab_set()
        top.resizable(False, False)
        return top

    def confirm(self, text):
        top, answer = self.dialog("Sendit"), {"yes": False}
        self.label(top, text, "text", 10).pack(anchor="w", pady=(0, 14))
        row = tk.Frame(top, bg=COLORS["bg"])
        row.pack(fill="x")

        def yes():
            answer["yes"] = True
            top.destroy()
        self.button(row, T["uninstall"], yes, True).pack(side="right")
        self.button(row, T["cancel"], top.destroy).pack(side="right", padx=(0, 8))
        self.root.wait_window(top)
        return answer["yes"]

    def choose_house(self, houses):
        top, picked = self.dialog(T["house_title"]), {"house": None}
        msg = self.label(top, T["house_text"], "dim", 9)
        msg.configure(wraplength=420)
        msg.pack(anchor="w", pady=(0, 10))
        box = tk.Listbox(top, bg=COLORS["field"], fg=COLORS["text"], selectbackground=COLORS["accent"],
                         selectforeground=COLORS["onAccent"], relief="flat", height=min(12, len(houses)),
                         font=("Segoe UI", 10), highlightthickness=0, activestyle="none")
        for h in houses:
            box.insert("end", f"{h['id']:>5}   {h['name']}")
        box.pack(fill="x")
        row = tk.Frame(top, bg=COLORS["bg"])
        row.pack(fill="x", pady=(12, 0))

        def ok():
            if box.curselection():
                picked["house"] = houses[box.curselection()[0]]
            top.destroy()
        self.button(row, T["ok"], ok, True).pack(side="right")
        self.button(row, T["cancel"], top.destroy).pack(side="right", padx=(0, 8))
        self.root.wait_window(top)
        return picked["house"]


def main():
    if "--task" in sys.argv:
        core.run_once(core.load_config())
        return
    if "--install" in sys.argv:
        install()
        core.run_once(core.load_config())
        return
    if "--uninstall" in sys.argv:
        uninstall()
        return
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
