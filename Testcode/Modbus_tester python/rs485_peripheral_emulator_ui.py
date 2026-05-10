#!/usr/bin/env python3
"""
RS-485 Peripheral Emulator UI
-----------------------------
Nice Tkinter UI for the RS-485 peripheral bus emulator.

Install:
  pip install pyserial

Run:
  python rs485_peripheral_emulator_ui.py

Keep this file in the same folder as rs485_peripheral_emulator.py.
"""

from __future__ import annotations

import queue
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox
from typing import Any, Callable, Optional

try:
    import serial
    import serial.tools.list_ports
except ImportError as exc:
    raise SystemExit("pyserial is missing. Install with: pip install pyserial") from exc

try:
    import rs485_peripheral_emulator as core
except ImportError as exc:
    raise SystemExit(
        "Could not import rs485_peripheral_emulator.py. Put this UI file in the same folder."
    ) from exc


BG = "#08111f"
PANEL = "#0f1b2d"
PANEL_2 = "#14243a"
BORDER = "#243852"
TEXT = "#e9f1ff"
MUTED = "#8fa6c4"
ACCENT = "#37d6c2"
GREEN = "#34d399"
RED = "#fb7185"
YELLOW = "#facc15"
BLUE = "#60a5fa"


class UiEmulator(core.PeripheralBusEmulator):
    def __init__(self, *args: Any, log_cb: Callable[[str], None], **kwargs: Any):
        super().__init__(*args, **kwargs)
        self.log_cb = log_cb
        self.trace = False  # UI handles trace output itself

    def log(self, text: str) -> None:
        self.log_cb(text)

    def dispatch(self, addr: int, command: int, payload: bytes) -> None:
        self.log(
            f"RX  addr=0x{addr:02X}  cmd=0x{command:02X} "
            f"{core.CMD_NAMES.get(command, '?'):<11}  len={len(payload):>3}  "
            f"{core.hexdump(payload)}"
        )
        super().dispatch(addr, command, payload)

    def _queue_frame(self, addr: int, command: int, payload: bytes = b"") -> None:
        self.log(
            f"TX  addr=0x{addr:02X}  cmd=0x{command:02X} "
            f"{core.CMD_NAMES.get(command, '?'):<11}  len={len(payload):>3}  "
            f"{core.hexdump(payload)}"
        )
        super()._queue_frame(addr, command, payload)

    def send_frame(self, addr: int, command: int, payload: bytes = b"") -> None:
        self.log(
            f"TX* addr=0x{addr:02X}  cmd=0x{command:02X} "
            f"{core.CMD_NAMES.get(command, '?'):<11}  len={len(payload):>3}  "
            f"{core.hexdump(payload)}"
        )
        super().send_frame(addr, command, payload)


def parse_int(text: str, default: int = 0) -> int:
    try:
        return int(str(text).strip(), 0)
    except Exception:
        return default


class DeviceCard(ttk.Frame):
    def __init__(self, master: tk.Widget, app: "App", addr: int, title: str):
        super().__init__(master, style="Card.TFrame", padding=14)
        self.app = app
        self.addr = addr
        self.title = title
        self.vars: dict[str, tk.Variable] = {}

        top = ttk.Frame(self, style="Card.TFrame")
        top.pack(fill="x")

        self.name_lbl = ttk.Label(top, text=f"0x{addr:02X}  {title}", style="CardTitle.TLabel")
        self.name_lbl.pack(side="left")

        self.enabled_var = tk.BooleanVar(value=True)
        self.enabled_var.trace_add("write", self._enabled_changed)
        self.enabled_chk = ttk.Checkbutton(top, text="online", variable=self.enabled_var, style="Switch.TCheckbutton")
        self.enabled_chk.pack(side="right")

        self.state_lbl = ttk.Label(self, text="waiting for bus", style="Muted.TLabel")
        self.state_lbl.pack(anchor="w", pady=(4, 10))

    def _enabled_changed(self, *_: Any) -> None:
        self.app.with_emulator(lambda emu: emu.set_enabled(self.addr, self.enabled_var.get()))

    def add_slider(self, label: str, field: str, from_: int, to: int, initial: int) -> tk.IntVar:
        row = ttk.Frame(self, style="Card.TFrame")
        row.pack(fill="x", pady=4)
        ttk.Label(row, text=label, style="Field.TLabel", width=12).pack(side="left")
        var = tk.IntVar(value=initial)
        self.vars[field] = var
        value_lbl = ttk.Label(row, text=str(initial), style="Value.TLabel", width=7, anchor="e")
        value_lbl.pack(side="right")
        scale = ttk.Scale(row, from_=from_, to=to, orient="horizontal")
        scale.set(initial)
        scale.pack(side="left", fill="x", expand=True, padx=8)

        def on_change(value: str) -> None:
            v = int(float(value))
            if var.get() != v:
                var.set(v)
            value_lbl.configure(text=str(v))
            self.app.poke(self.addr, field, v)

        scale.configure(command=on_change)
        return var

    def add_entry(self, label: str, field: str, initial: int, width: int = 8) -> tk.StringVar:
        row = ttk.Frame(self, style="Card.TFrame")
        row.pack(fill="x", pady=4)
        ttk.Label(row, text=label, style="Field.TLabel", width=12).pack(side="left")
        var = tk.StringVar(value=str(initial))
        self.vars[field] = var
        ent = ttk.Entry(row, textvariable=var, width=width, style="TEntry")
        ent.pack(side="left")

        def apply(_: Any = None) -> None:
            self.app.poke(self.addr, field, parse_int(var.get()))

        ent.bind("<Return>", apply)
        ent.bind("<FocusOut>", apply)
        ttk.Button(row, text="set", command=apply, style="Small.TButton").pack(side="left", padx=8)
        return var

    def add_buttons(self) -> None:
        row = ttk.Frame(self, style="Card.TFrame")
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="GET_STATUS", command=lambda: self.app.manual_send(self.addr, core.CMD_GET_STATUS), style="Small.TButton").pack(side="left")
        ttk.Button(row, text="PING", command=lambda: self.app.manual_send(self.addr, core.CMD_PING), style="Small.TButton").pack(side="left", padx=6)
        ttk.Button(row, text="INT", command=lambda: self.app.with_emulator(lambda e: e.set_int(self.addr, True)), style="Small.TButton").pack(side="right")

    def set_enabled_ui(self, enabled: bool) -> None:
        if self.enabled_var.get() != enabled:
            self.enabled_var.set(enabled)
        self.state_lbl.configure(text="online / replying" if enabled else "offline / silent")


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("GCS RS-485 Peripheral Emulator")
        self.geometry("1180x760")
        self.minsize(1050, 680)
        self.configure(bg=BG)

        self.emu: Optional[UiEmulator] = None
        self.emu_thread: Optional[threading.Thread] = None
        self.log_q: "queue.Queue[str]" = queue.Queue()
        self.cards: dict[int, DeviceCard] = {}

        self._setup_style()
        self._build_ui()
        self.refresh_ports()
        self.after(100, self._pump_log)
        self.after(300, self._refresh_state)
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def _setup_style(self) -> None:
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TFrame", background=BG)
        style.configure("Card.TFrame", background=PANEL, relief="flat")
        style.configure("Header.TFrame", background=BG)
        style.configure("TLabel", background=BG, foreground=TEXT, font=("Segoe UI", 10))
        style.configure("Title.TLabel", background=BG, foreground=TEXT, font=("Segoe UI", 21, "bold"))
        style.configure("Sub.TLabel", background=BG, foreground=MUTED, font=("Segoe UI", 10))
        style.configure("CardTitle.TLabel", background=PANEL, foreground=TEXT, font=("Segoe UI", 13, "bold"))
        style.configure("Muted.TLabel", background=PANEL, foreground=MUTED, font=("Segoe UI", 9))
        style.configure("Field.TLabel", background=PANEL, foreground=MUTED, font=("Segoe UI", 10))
        style.configure("Value.TLabel", background=PANEL, foreground=ACCENT, font=("Consolas", 10, "bold"))
        style.configure("StatusGood.TLabel", background=BG, foreground=GREEN, font=("Segoe UI", 10, "bold"))
        style.configure("StatusBad.TLabel", background=BG, foreground=RED, font=("Segoe UI", 10, "bold"))
        style.configure("TButton", font=("Segoe UI", 10), padding=(12, 7), background=PANEL_2, foreground=TEXT)
        style.map("TButton", background=[("active", BORDER)])
        style.configure("Accent.TButton", background=ACCENT, foreground="#031016", font=("Segoe UI", 10, "bold"))
        style.map("Accent.TButton", background=[("active", "#65f5e5")])
        style.configure("Small.TButton", font=("Segoe UI", 9), padding=(8, 4), background=PANEL_2, foreground=TEXT)
        style.configure("TCheckbutton", background=BG, foreground=TEXT, font=("Segoe UI", 10))
        style.configure("Switch.TCheckbutton", background=PANEL, foreground=TEXT, font=("Segoe UI", 9))
        style.configure("TCombobox", fieldbackground=PANEL, background=PANEL, foreground=TEXT, arrowcolor=TEXT)
        style.configure("TEntry", fieldbackground=PANEL_2, foreground=TEXT, insertcolor=TEXT)
        style.configure("Horizontal.TScale", background=PANEL, troughcolor=PANEL_2)

    def _build_ui(self) -> None:
        header = ttk.Frame(self, style="Header.TFrame", padding=(18, 14, 18, 8))
        header.pack(fill="x")
        ttk.Label(header, text="GCS RS-485 Peripheral Emulator", style="Title.TLabel").pack(anchor="w")
        ttk.Label(header, text="Emuleert Searchlight, Radar, Pan-Tilt en Light Bar op de RS-485 bus", style="Sub.TLabel").pack(anchor="w", pady=(2, 0))

        controls = ttk.Frame(self, style="Header.TFrame", padding=(18, 4, 18, 10))
        controls.pack(fill="x")

        ttk.Label(controls, text="Port", style="Sub.TLabel").pack(side="left")
        self.port_var = tk.StringVar()
        self.port_box = ttk.Combobox(controls, textvariable=self.port_var, width=24, state="readonly")
        self.port_box.pack(side="left", padx=(8, 12))
        ttk.Button(controls, text="refresh", command=self.refresh_ports, style="Small.TButton").pack(side="left")

        ttk.Label(controls, text="Baud", style="Sub.TLabel").pack(side="left", padx=(18, 0))
        self.baud_var = tk.StringVar(value="115200")
        ttk.Entry(controls, textvariable=self.baud_var, width=9).pack(side="left", padx=(8, 12))

        self.stream_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(controls, text="allow stream TX", variable=self.stream_var).pack(side="left", padx=(6, 0))
        self.jitter_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(controls, text="jitter", variable=self.jitter_var).pack(side="left", padx=(10, 0))

        ttk.Label(controls, text="DE GPIO", style="Sub.TLabel").pack(side="left", padx=(18, 0))
        self.de_var = tk.StringVar()
        ttk.Entry(controls, textvariable=self.de_var, width=7).pack(side="left", padx=(8, 0))

        self.status_lbl = ttk.Label(controls, text="stopped", style="StatusBad.TLabel")
        self.status_lbl.pack(side="right", padx=(14, 0))
        self.start_btn = ttk.Button(controls, text="start", command=self.toggle_start, style="Accent.TButton")
        self.start_btn.pack(side="right")

        body = ttk.Frame(self, padding=(18, 0, 18, 18))
        body.pack(fill="both", expand=True)

        left = ttk.Frame(body)
        left.pack(side="left", fill="both", expand=True)
        right = ttk.Frame(body)
        right.pack(side="right", fill="both", padx=(14, 0))

        grid = ttk.Frame(left)
        grid.pack(fill="both", expand=True)
        for c in range(2):
            grid.columnconfigure(c, weight=1, uniform="cards")
        for r in range(2):
            grid.rowconfigure(r, weight=1, uniform="cards")

        self._make_cards(grid)

        log_head = ttk.Frame(right)
        log_head.pack(fill="x")
        ttk.Label(log_head, text="Bus trace", style="CardTitle.TLabel", background=BG).pack(side="left")
        ttk.Button(log_head, text="clear", command=self.clear_log, style="Small.TButton").pack(side="right")

        self.log_text = tk.Text(
            right,
            width=58,
            height=28,
            bg="#050b14",
            fg=TEXT,
            insertbackground=TEXT,
            relief="flat",
            font=("Consolas", 9),
            padx=10,
            pady=10,
            wrap="none",
        )
        self.log_text.pack(fill="both", expand=True, pady=(8, 0))
        self.log_text.tag_config("RX", foreground=BLUE)
        self.log_text.tag_config("TX", foreground=GREEN)
        self.log_text.tag_config("ERR", foreground=RED)
        self.log_text.tag_config("SYS", foreground=YELLOW)

        manual = ttk.Frame(right, style="Card.TFrame", padding=12)
        manual.pack(fill="x", pady=(12, 0))
        ttk.Label(manual, text="Manual frame", style="CardTitle.TLabel").grid(row=0, column=0, columnspan=6, sticky="w", pady=(0, 8))
        self.manual_addr = tk.StringVar(value="0x01")
        self.manual_cmd = tk.StringVar(value="0x11")
        self.manual_payload = tk.StringVar(value="")
        ttk.Label(manual, text="addr", style="Field.TLabel").grid(row=1, column=0, sticky="w")
        ttk.Entry(manual, textvariable=self.manual_addr, width=7).grid(row=1, column=1, padx=4)
        ttk.Label(manual, text="cmd", style="Field.TLabel").grid(row=1, column=2, sticky="w")
        ttk.Entry(manual, textvariable=self.manual_cmd, width=7).grid(row=1, column=3, padx=4)
        ttk.Label(manual, text="payload", style="Field.TLabel").grid(row=2, column=0, sticky="w", pady=(8, 0))
        ttk.Entry(manual, textvariable=self.manual_payload, width=30).grid(row=2, column=1, columnspan=3, padx=4, pady=(8, 0), sticky="ew")
        ttk.Button(manual, text="send", command=self.send_manual, style="Accent.TButton").grid(row=1, column=4, rowspan=2, padx=(10, 0), sticky="ns")
        manual.columnconfigure(3, weight=1)

    def _make_cards(self, parent: ttk.Frame) -> None:
        s = DeviceCard(parent, self, 0x01, "Searchlight")
        s.add_slider("brightness", "brightness", 0, 255, 0)
        s.add_slider("temp °C", "temp", -20, 100, 25)
        s.add_entry("faults", "faults", 0)
        s.add_buttons()
        s.grid(row=0, column=0, sticky="nsew", padx=(0, 8), pady=(0, 8))
        self.cards[0x01] = s

        r = DeviceCard(parent, self, 0x02, "Radar")
        r.add_entry("distance mm", "distance", 5000)
        r.add_slider("signal", "signal", 0, 255, 200)
        r.add_entry("status", "status", 0)
        r.add_entry("rate Hz", "rate", 10)
        r.add_buttons()
        r.grid(row=0, column=1, sticky="nsew", padx=(8, 0), pady=(0, 8))
        self.cards[0x02] = r

        p = DeviceCard(parent, self, 0x03, "Pan-Tilt")
        p.add_slider("pan", "pan", 0, 180, 90)
        p.add_slider("tilt", "tilt", 0, 180, 45)
        p.add_slider("moving", "moving", 0, 1, 0)
        p.add_entry("slew", "slew", 60)
        p.add_buttons()
        p.grid(row=1, column=0, sticky="nsew", padx=(0, 8), pady=(8, 0))
        self.cards[0x03] = p

        l = DeviceCard(parent, self, 0x04, "Light Bar")
        l.add_slider("brightness", "brightness", 0, 255, 0)
        l.add_slider("mode", "mode", 0, 5, 0)
        l.add_entry("rgb565", "color", 0xFFFF)
        l.add_buttons()
        l.grid(row=1, column=1, sticky="nsew", padx=(8, 0), pady=(8, 0))
        self.cards[0x04] = l

    def refresh_ports(self) -> None:
        ports = list(serial.tools.list_ports.comports())
        values = [p.device for p in ports]
        self.port_box.configure(values=values)
        if values and not self.port_var.get():
            self.port_var.set(values[0])
        self.log(f"SYS ports: {', '.join(values) if values else 'none found'}")

    def log(self, text: str) -> None:
        self.log_q.put(text)

    def _pump_log(self) -> None:
        while True:
            try:
                line = self.log_q.get_nowait()
            except queue.Empty:
                break
            tag = "SYS"
            if line.startswith("RX"):
                tag = "RX"
            elif line.startswith("TX"):
                tag = "TX"
            elif "ERROR" in line or "FAIL" in line:
                tag = "ERR"
            ts = time.strftime("%H:%M:%S")
            self.log_text.insert("end", f"[{ts}] {line}\n", tag)
            self.log_text.see("end")
        self.after(100, self._pump_log)

    def clear_log(self) -> None:
        self.log_text.delete("1.0", "end")

    def toggle_start(self) -> None:
        if self.emu is None:
            self.start_emulator()
        else:
            self.stop_emulator()

    def start_emulator(self) -> None:
        port = self.port_var.get().strip()
        if not port:
            messagebox.showerror("Geen poort", "Kies eerst een seriële poort.")
            return
        baud = parse_int(self.baud_var.get(), 115200)
        de_gpio: Optional[int] = None
        if self.de_var.get().strip():
            de_gpio = parse_int(self.de_var.get(), -1)
            if de_gpio < 0:
                messagebox.showerror("DE GPIO", "DE GPIO moet een geldig BCM pin nummer zijn.")
                return
        try:
            ser = serial.Serial(port, baud, timeout=0.01, write_timeout=1)
            direction = core.DirectionControl(de_gpio)
            self.emu = UiEmulator(
                ser=ser,
                direction=direction,
                trace=False,
                allow_stream_tx=self.stream_var.get(),
                jitter=self.jitter_var.get(),
                log_cb=self.log,
            )
            self.emu_thread = threading.Thread(target=self.emu.run, name="ui-emulator", daemon=True)
            self.emu_thread.start()
        except Exception as exc:
            self.emu = None
            messagebox.showerror("Start mislukt", str(exc))
            return
        self.status_lbl.configure(text=f"running on {port}", style="StatusGood.TLabel")
        self.start_btn.configure(text="stop")
        self.log(f"SYS started on {port} @ {baud}")

    def stop_emulator(self) -> None:
        if self.emu is not None:
            try:
                self.emu.close()
            except Exception:
                pass
        self.emu = None
        self.status_lbl.configure(text="stopped", style="StatusBad.TLabel")
        self.start_btn.configure(text="start")
        self.log("SYS stopped")

    def with_emulator(self, fn: Callable[[UiEmulator], Any]) -> None:
        if self.emu is None:
            return
        try:
            fn(self.emu)
        except Exception as exc:
            self.log(f"ERROR {exc}")

    def poke(self, addr: int, field: str, value: int) -> None:
        self.with_emulator(lambda emu: emu.poke(addr, field, value))

    def manual_send(self, addr: int, cmd: int, payload: bytes = b"") -> None:
        self.with_emulator(lambda emu: emu.send_frame(addr, cmd, payload))

    def send_manual(self) -> None:
        addr = parse_int(self.manual_addr.get(), 0x01)
        cmd = parse_int(self.manual_cmd.get(), core.CMD_GET_STATUS)
        payload = bytes(parse_int(x, 0) & 0xFF for x in self.manual_payload.get().split())
        self.manual_send(addr, cmd, payload)

    def _refresh_state(self) -> None:
        emu = self.emu
        if emu is not None:
            try:
                with emu._lock:
                    for addr, dev in emu.devices.items():
                        card = self.cards.get(addr)
                        if card:
                            card.set_enabled_ui(dev.enabled)
                            stream_txt = f", stream {dev.stream_interval_ms} ms" if dev.stream_on else ""
                            int_txt = ", INT pending" if dev.int_pending else ""
                            card.state_lbl.configure(
                                text=("online / replying" if dev.enabled else "offline / silent") + stream_txt + int_txt
                            )
            except Exception:
                pass
        self.after(300, self._refresh_state)

    def on_close(self) -> None:
        self.stop_emulator()
        self.destroy()


if __name__ == "__main__":
    App().mainloop()
