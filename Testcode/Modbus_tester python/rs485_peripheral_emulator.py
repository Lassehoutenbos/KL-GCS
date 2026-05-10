#!/usr/bin/env python3
"""
RS-485 Peripheral Bus Emulator - Python
--------------------------------------
Emulates the four GCS peripheral bus slaves on a PC/Raspberry Pi with a
USB-RS485 adapter:

  0x01 Searchlight
  0x02 Radar / rangefinder
  0x03 Pan-tilt unit
  0x04 External lighting bar

Protocol:
  SOF, ADDR, CMD, LEN, PAYLOAD..., CRC8/MAXIM
  0xAB, addr, cmd, len, payload..., crc(addr..payload)

Install:
  pip install pyserial

Examples:
  python rs485_peripheral_emulator.py --port COM7 --trace
  python rs485_peripheral_emulator.py --port /dev/ttyUSB0 --trace
  python rs485_peripheral_emulator.py --port /dev/serial0 --de-gpio 17 --trace

Notes:
- Most USB-RS485 adapters handle TX/RX direction automatically.
- If you use a bare transceiver on a Raspberry Pi UART, pass --de-gpio.
- Peripherals do not initiate normal replies. They answer only when addressed.
- STREAM_DATA is included but disabled by default because your spec says slaves
  do not transmit unsolicited except through /INT. Enable with --allow-stream-tx
  if you want to stress-test master RX handling.
"""

from __future__ import annotations

import argparse
import cmd as cmdlib
import queue
import random
import sys
import threading
import time
from dataclasses import dataclass, field
from typing import Callable, Dict, Optional

try:
    import serial
    import serial.tools.list_ports
except ImportError as exc:
    raise SystemExit("pyserial is missing. Install with: pip install pyserial") from exc


RS485_SOF = 0xAB
ADDR_BROADCAST = 0xFF

CMD_PING = 0x01
CMD_PONG = 0x02
CMD_SET_OUTPUT = 0x10
CMD_GET_STATUS = 0x11
CMD_STATUS = 0x12
CMD_SET_PARAM = 0x20
CMD_GET_PARAM = 0x21
CMD_PARAM_VAL = 0x22
CMD_STREAM_ON = 0x30
CMD_STREAM_OFF = 0x31
CMD_STREAM_DATA = 0x32
CMD_ERROR = 0xF0
CMD_SYNC = 0xFF

FW_VERSION = 0x07

CMD_NAMES = {
    CMD_PING: "PING",
    CMD_PONG: "PONG",
    CMD_SET_OUTPUT: "SET_OUTPUT",
    CMD_GET_STATUS: "GET_STATUS",
    CMD_STATUS: "STATUS",
    CMD_SET_PARAM: "SET_PARAM",
    CMD_GET_PARAM: "GET_PARAM",
    CMD_PARAM_VAL: "PARAM_VAL",
    CMD_STREAM_ON: "STREAM_ON",
    CMD_STREAM_OFF: "STREAM_OFF",
    CMD_STREAM_DATA: "STREAM_DATA",
    CMD_ERROR: "ERROR",
    CMD_SYNC: "SYNC",
}


def clamp_u8(value: int) -> int:
    return max(0, min(255, int(value)))


def clamp_i8(value: int) -> int:
    return max(-128, min(127, int(value)))


def clamp_u16(value: int) -> int:
    return max(0, min(65535, int(value)))


def crc8_maxim(data: bytes) -> int:
    """CRC-8/MAXIM as used in the provided RS-485 bus document."""
    crc = 0x00
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ 0x31) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc


def frame_build(addr: int, command: int, payload: bytes = b"") -> bytes:
    if len(payload) > 255:
        raise ValueError("payload too long")
    head = bytes([addr & 0xFF, command & 0xFF, len(payload) & 0xFF])
    crc = crc8_maxim(head + payload)
    return bytes([RS485_SOF]) + head + payload + bytes([crc])


def hexdump(data: bytes) -> str:
    return " ".join(f"{b:02X}" for b in data)


def parse_num(text: str) -> int:
    return int(str(text), 0)


class DirectionControl:
    """Optional DE/RE control for a bare RS-485 transceiver on Raspberry Pi."""

    def __init__(self, gpio_pin: Optional[int], invert: bool = False):
        self.gpio_pin = gpio_pin
        self.invert = invert
        self._gpio = None
        if gpio_pin is None:
            return
        try:
            import RPi.GPIO as GPIO  # type: ignore
        except ImportError as exc:
            raise SystemExit(
                "--de-gpio needs RPi.GPIO. Use a USB-RS485 adapter or install RPi.GPIO."
            ) from exc
        self._gpio = GPIO
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(gpio_pin, GPIO.OUT)
        self.rx()

    def _write(self, active: bool) -> None:
        if self._gpio is None or self.gpio_pin is None:
            return
        level = active ^ self.invert
        self._gpio.output(self.gpio_pin, self._gpio.HIGH if level else self._gpio.LOW)

    def tx(self) -> None:
        self._write(True)

    def rx(self) -> None:
        self._write(False)

    def close(self) -> None:
        if self._gpio is not None:
            self.rx()
            self._gpio.cleanup(self.gpio_pin)


@dataclass
class Peripheral:
    addr: int
    name: str
    enabled: bool = True
    stream_on: bool = False
    stream_interval_ms: int = 1000
    next_stream_at: float = 0.0
    int_pending: bool = False
    params: Dict[int, int] = field(default_factory=dict)

    def status_payload(self) -> bytes:
        return b""

    def stream_payload(self) -> bytes:
        return self.status_payload()

    def set_output(self, channel: int, value: int) -> None:
        pass

    def set_param(self, param_id: int, value: int) -> None:
        self.params[param_id] = clamp_u16(value)

    def get_param(self, param_id: int) -> int:
        return self.params.get(param_id, 0)

    def poke(self, field_name: str, value: int) -> bool:
        return False

    def summary(self) -> str:
        return ""


@dataclass
class Searchlight(Peripheral):
    brightness: int = 0
    temp_c: int = 25
    faults: int = 0

    def __init__(self) -> None:
        super().__init__(addr=0x01, name="Searchlight")
        self.brightness = 0
        self.temp_c = 25
        self.faults = 0
        self.params[0x01] = 0

    def status_payload(self) -> bytes:
        return bytes([clamp_u8(self.brightness), self.temp_c & 0xFF, clamp_u8(self.faults)])

    def set_output(self, channel: int, value: int) -> None:
        if channel == 0:
            self.brightness = clamp_u8(value)

    def poke(self, field_name: str, value: int) -> bool:
        if field_name in ("brightness", "bright", "b"):
            self.brightness = clamp_u8(value)
        elif field_name in ("temp", "temperature"):
            self.temp_c = clamp_i8(value)
        elif field_name == "faults":
            self.faults = clamp_u8(value)
        else:
            return False
        return True

    def summary(self) -> str:
        return f"brightness={self.brightness} temp={self.temp_c}C faults=0x{self.faults:02X}"


@dataclass
class Radar(Peripheral):
    distance_mm: int = 5000
    signal: int = 200
    status: int = 0
    mode: int = 1
    range_max_m: int = 12
    sample_rate_hz: int = 10

    def __init__(self) -> None:
        super().__init__(addr=0x02, name="Radar")
        self.distance_mm = 5000
        self.signal = 200
        self.status = 0
        self.mode = 1
        self.range_max_m = 12
        self.sample_rate_hz = 10
        self.params[0x01] = 0

    def status_payload(self) -> bytes:
        return bytes([
            clamp_u8(self.mode),
            clamp_u8(self.range_max_m),
            clamp_u8(self.sample_rate_hz),
        ])

    def stream_payload(self) -> bytes:
        d = clamp_u16(self.distance_mm)
        return bytes([d & 0xFF, d >> 8, clamp_u8(self.signal), clamp_u8(self.status)])

    def poke(self, field_name: str, value: int) -> bool:
        if field_name in ("distance", "dist"):
            self.distance_mm = clamp_u16(value)
        elif field_name == "signal":
            self.signal = clamp_u8(value)
        elif field_name == "status":
            self.status = clamp_u8(value)
        elif field_name == "mode":
            self.mode = clamp_u8(value)
        elif field_name in ("range", "range_max"):
            self.range_max_m = clamp_u8(value)
        elif field_name in ("rate", "sample_rate"):
            self.sample_rate_hz = clamp_u8(value)
        else:
            return False
        return True

    def summary(self) -> str:
        return f"distance={self.distance_mm}mm signal={self.signal} status={self.status} mode={self.mode}"


@dataclass
class PanTilt(Peripheral):
    pan_deg: int = 90
    tilt_deg: int = 45
    moving: int = 0

    def __init__(self) -> None:
        super().__init__(addr=0x03, name="PanTilt")
        self.pan_deg = 90
        self.tilt_deg = 45
        self.moving = 0
        self.params[0x01] = 60  # slew deg/s
        self.params[0x02] = 0   # soft limits

    def status_payload(self) -> bytes:
        return bytes([clamp_u8(self.pan_deg), clamp_u8(self.tilt_deg), clamp_u8(self.moving)])

    def set_output(self, channel: int, value: int) -> None:
        if channel == 0:
            self.pan_deg = max(0, min(180, int(value)))
            self.moving = 1
        elif channel == 1:
            self.tilt_deg = max(0, min(180, int(value)))
            self.moving = 1

    def poke(self, field_name: str, value: int) -> bool:
        if field_name == "pan":
            self.pan_deg = max(0, min(180, int(value)))
        elif field_name == "tilt":
            self.tilt_deg = max(0, min(180, int(value)))
        elif field_name == "moving":
            self.moving = clamp_u8(value)
        elif field_name == "slew":
            self.params[0x01] = clamp_u16(value)
        elif field_name in ("soft", "soft_limits"):
            self.params[0x02] = clamp_u16(value)
        else:
            return False
        return True

    def summary(self) -> str:
        return f"pan={self.pan_deg} tilt={self.tilt_deg} moving={self.moving} slew={self.params[0x01]}"


@dataclass
class LightBar(Peripheral):
    brightness: int = 0
    mode: int = 0
    color_rgb565: int = 0xFFFF

    def __init__(self) -> None:
        super().__init__(addr=0x04, name="LightBar")
        self.brightness = 0
        self.mode = 0
        self.color_rgb565 = 0xFFFF
        self.params[0x01] = self.mode
        self.params[0x02] = self.color_rgb565

    def status_payload(self) -> bytes:
        color = clamp_u16(self.color_rgb565)
        return bytes([
            clamp_u8(self.brightness),
            self.mode & 0xFF,
            color & 0xFF,
            color >> 8,
        ])

    def stream_payload(self) -> bytes:
        power_ma = clamp_u16(self.brightness * 47)
        return bytes([power_ma & 0xFF, power_ma >> 8])

    def set_output(self, channel: int, value: int) -> None:
        if channel == 0:
            self.brightness = clamp_u8(value)

    def set_param(self, param_id: int, value: int) -> None:
        super().set_param(param_id, value)
        if param_id == 0x01:
            self.mode = clamp_u16(value)
        elif param_id == 0x02:
            self.color_rgb565 = clamp_u16(value)

    def poke(self, field_name: str, value: int) -> bool:
        if field_name in ("brightness", "bright", "b"):
            self.brightness = clamp_u8(value)
        elif field_name == "mode":
            self.mode = clamp_u16(value)
            self.params[0x01] = self.mode
        elif field_name in ("color", "colour", "rgb565"):
            self.color_rgb565 = clamp_u16(value)
            self.params[0x02] = self.color_rgb565
        else:
            return False
        return True

    def summary(self) -> str:
        return f"brightness={self.brightness} mode={self.mode} color=0x{self.color_rgb565:04X}"


class PeripheralBusEmulator:
    def __init__(
        self,
        ser: serial.Serial,
        direction: DirectionControl,
        trace: bool = False,
        allow_stream_tx: bool = False,
        jitter: bool = False,
    ):
        self.ser = ser
        self.direction = direction
        self.trace = trace
        self.allow_stream_tx = allow_stream_tx
        self.jitter = jitter
        self.devices: Dict[int, Peripheral] = {
            0x01: Searchlight(),
            0x02: Radar(),
            0x03: PanTilt(),
            0x04: LightBar(),
        }
        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._tx_queue: "queue.Queue[bytes]" = queue.Queue()

    def close(self) -> None:
        self._stop.set()
        self.direction.close()
        self.ser.close()

    def send_frame(self, addr: int, command: int, payload: bytes = b"") -> None:
        frame = frame_build(addr, command, payload)
        if self.jitter:
            time.sleep(random.uniform(0.0005, 0.006))
        self.direction.tx()
        time.sleep(0.00005)
        self.ser.write(frame)
        self.ser.flush()
        time.sleep(0.00002)
        self.direction.rx()
        if self.trace:
            print(
                f"[TX] addr=0x{addr:02X} cmd=0x{command:02X} "
                f"{CMD_NAMES.get(command, '?'):<11} len={len(payload)} payload={hexdump(payload)}"
            )

    def run(self) -> None:
        rx_thread = threading.Thread(target=self._rx_loop, name="rs485-rx", daemon=True)
        tx_thread = threading.Thread(target=self._tx_loop, name="rs485-tx", daemon=True)
        rx_thread.start()
        tx_thread.start()
        try:
            while not self._stop.is_set():
                self._periodic_tick()
                time.sleep(0.01)
        finally:
            self.close()

    def _tx_loop(self) -> None:
        while not self._stop.is_set():
            try:
                frame = self._tx_queue.get(timeout=0.05)
            except queue.Empty:
                continue
            self.direction.tx()
            time.sleep(0.00005)
            self.ser.write(frame)
            self.ser.flush()
            time.sleep(0.00002)
            self.direction.rx()

    def _queue_frame(self, addr: int, command: int, payload: bytes = b"") -> None:
        frame = frame_build(addr, command, payload)
        self._tx_queue.put(frame)
        if self.trace:
            print(
                f"[TX] addr=0x{addr:02X} cmd=0x{command:02X} "
                f"{CMD_NAMES.get(command, '?'):<11} len={len(payload)} payload={hexdump(payload)}"
            )

    def _rx_loop(self) -> None:
        state = "SOF"
        addr = command = length = 0
        payload = bytearray()
        last_byte = time.monotonic()

        while not self._stop.is_set():
            b = self.ser.read(1)
            if not b:
                if state != "SOF" and time.monotonic() - last_byte > 0.020:
                    state = "SOF"
                    payload.clear()
                continue

            byte = b[0]
            last_byte = time.monotonic()

            if state == "SOF":
                if byte == RS485_SOF:
                    state = "ADDR"
                continue
            if state == "ADDR":
                addr = byte
                state = "CMD"
                continue
            if state == "CMD":
                command = byte
                state = "LEN"
                continue
            if state == "LEN":
                length = byte
                payload.clear()
                state = "CRC" if length == 0 else "PAYLOAD"
                continue
            if state == "PAYLOAD":
                payload.append(byte)
                if len(payload) >= length:
                    state = "CRC"
                continue
            if state == "CRC":
                crc_got = byte
                body = bytes([addr, command, length]) + bytes(payload)
                crc_expected = crc8_maxim(body)
                if crc_got == crc_expected:
                    self.dispatch(addr, command, bytes(payload))
                elif self.trace:
                    print(
                        f"[RX] CRC FAIL got=0x{crc_got:02X} want=0x{crc_expected:02X} "
                        f"body={hexdump(body)}"
                    )
                state = "SOF"
                payload.clear()

    def dispatch(self, addr: int, command: int, payload: bytes) -> None:
        if self.trace:
            print(
                f"[RX] addr=0x{addr:02X} cmd=0x{command:02X} "
                f"{CMD_NAMES.get(command, '?'):<11} len={len(payload)} payload={hexdump(payload)}"
            )

        if addr == ADDR_BROADCAST:
            if command == CMD_SYNC and self.trace:
                timestamp = int.from_bytes(payload[:4].ljust(4, b"\x00"), "little")
                print(f"[BUS] SYNC timestamp_ms={timestamp}")
            return

        with self._lock:
            dev = self.devices.get(addr)
            if not dev or not dev.enabled:
                return
            response = self._handle_command(dev, command, payload)

        if response is not None:
            resp_cmd, resp_payload = response
            self._queue_frame(dev.addr, resp_cmd, resp_payload)

    def _handle_command(self, dev: Peripheral, command: int, payload: bytes) -> Optional[tuple[int, bytes]]:
        if command == CMD_PING:
            return CMD_PONG, bytes([FW_VERSION])

        if command == CMD_GET_STATUS:
            dev.int_pending = False
            return CMD_STATUS, dev.status_payload()

        if command == CMD_SET_OUTPUT:
            if len(payload) >= 2:
                dev.set_output(payload[0], payload[1])
                return CMD_STATUS, dev.status_payload()
            return CMD_ERROR, b"\x02"  # bad length

        if command == CMD_SET_PARAM:
            if len(payload) >= 3:
                param_id = payload[0]
                value = payload[1] | (payload[2] << 8)
                dev.set_param(param_id, value)
                value = dev.get_param(param_id)
                return CMD_PARAM_VAL, bytes([param_id, value & 0xFF, value >> 8])
            return CMD_ERROR, b"\x02"

        if command == CMD_GET_PARAM:
            if len(payload) >= 1:
                param_id = payload[0]
                value = dev.get_param(param_id)
                return CMD_PARAM_VAL, bytes([param_id, value & 0xFF, value >> 8])
            return CMD_ERROR, b"\x02"

        if command == CMD_STREAM_ON:
            if len(payload) >= 2:
                interval = payload[0] | (payload[1] << 8)
                dev.stream_interval_ms = max(10, interval)
                dev.stream_on = True
                dev.next_stream_at = time.monotonic() + dev.stream_interval_ms / 1000.0
                return CMD_STATUS, dev.status_payload()
            return CMD_ERROR, b"\x02"

        if command == CMD_STREAM_OFF:
            dev.stream_on = False
            return CMD_STATUS, dev.status_payload()

        return CMD_ERROR, b"\x01"  # unknown command

    def _periodic_tick(self) -> None:
        if not self.allow_stream_tx:
            return
        now = time.monotonic()
        due: list[tuple[int, bytes]] = []
        with self._lock:
            for dev in self.devices.values():
                if not dev.enabled or not dev.stream_on:
                    continue
                if now >= dev.next_stream_at:
                    dev.next_stream_at = now + dev.stream_interval_ms / 1000.0
                    due.append((dev.addr, dev.stream_payload()))
        for addr, payload in due:
            self._queue_frame(addr, CMD_STREAM_DATA, payload)

    def list_devices(self) -> str:
        with self._lock:
            rows = []
            for addr in sorted(self.devices):
                d = self.devices[addr]
                rows.append(
                    f"0x{addr:02X} {d.name:<12} enabled={'yes' if d.enabled else 'no '} "
                    f"stream={d.stream_interval_ms if d.stream_on else 0:>5}ms "
                    f"int={'yes' if d.int_pending else 'no '}  {d.summary()}"
                )
            return "\n".join(rows)

    def set_enabled(self, addr: int, enabled: bool) -> bool:
        with self._lock:
            dev = self.devices.get(addr)
            if not dev:
                return False
            dev.enabled = enabled
            return True

    def set_int(self, addr: int, pending: bool) -> bool:
        with self._lock:
            dev = self.devices.get(addr)
            if not dev:
                return False
            dev.int_pending = pending
            return True

    def poke(self, addr: int, field_name: str, value: int) -> bool:
        with self._lock:
            dev = self.devices.get(addr)
            return bool(dev and dev.poke(field_name, value))


class EmulatorShell(cmdlib.Cmd):
    intro = "RS-485 peripheral emulator. Type help or ?."
    prompt = "emu> "

    def __init__(self, emu: PeripheralBusEmulator):
        super().__init__()
        self.emu = emu

    def do_list(self, _arg: str) -> None:
        """list - show virtual peripherals"""
        print(self.emu.list_devices())

    def do_trace(self, arg: str) -> None:
        """trace on|off - print RX/TX frames"""
        v = arg.strip().lower()
        if v not in ("on", "off"):
            print("usage: trace on|off")
            return
        self.emu.trace = v == "on"
        print(f"trace {'on' if self.emu.trace else 'off'}")

    def do_enable(self, arg: str) -> None:
        """enable <addr> - enable a peripheral address"""
        try:
            print("ok" if self.emu.set_enabled(parse_num(arg), True) else "no such addr")
        except ValueError:
            print("usage: enable 0x01")

    def do_disable(self, arg: str) -> None:
        """disable <addr> - disable/silence a peripheral address"""
        try:
            print("ok" if self.emu.set_enabled(parse_num(arg), False) else "no such addr")
        except ValueError:
            print("usage: disable 0x01")

    def do_int(self, arg: str) -> None:
        """int <addr> - mark an async interrupt pending for a peripheral"""
        try:
            print("ok" if self.emu.set_int(parse_num(arg), True) else "no such addr")
        except ValueError:
            print("usage: int 0x01")

    def do_clrint(self, arg: str) -> None:
        """clrint <addr> - clear pending interrupt flag"""
        try:
            print("ok" if self.emu.set_int(parse_num(arg), False) else "no such addr")
        except ValueError:
            print("usage: clrint 0x01")

    def do_set(self, arg: str) -> None:
        """set <addr> <field> <value> - change emulated sensor/output value

Fields:
  0x01 Searchlight: brightness, temp, faults
  0x02 Radar:       distance, signal, status, mode, range, rate
  0x03 PanTilt:     pan, tilt, moving, slew, soft
  0x04 LightBar:    brightness, mode, color
"""
        parts = arg.split()
        if len(parts) != 3:
            print("usage: set <addr> <field> <value>")
            return
        try:
            addr = parse_num(parts[0])
            value = parse_num(parts[2])
        except ValueError:
            print("bad number")
            return
        print("ok" if self.emu.poke(addr, parts[1], value) else "unknown addr/field")

    def do_send(self, arg: str) -> None:
        """send <addr> <cmd> [payload bytes...] - manually transmit a frame"""
        parts = arg.split()
        if len(parts) < 2:
            print("usage: send <addr> <cmd> [payload bytes]")
            return
        try:
            addr = parse_num(parts[0])
            command = parse_num(parts[1])
            payload = bytes(parse_num(x) & 0xFF for x in parts[2:])
        except ValueError:
            print("bad number")
            return
        self.emu.send_frame(addr, command, payload)

    def do_quit(self, _arg: str) -> bool:
        """quit - exit"""
        self.emu.close()
        return True

    def do_exit(self, arg: str) -> bool:
        return self.do_quit(arg)

    def do_EOF(self, _arg: str) -> bool:
        print()
        return self.do_quit("")


def list_ports() -> None:
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    for p in ports:
        print(f"{p.device:20} {p.description}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Emulate GCS RS-485 peripheral slaves")
    parser.add_argument("--port", help="serial port, e.g. COM7, /dev/ttyUSB0, /dev/serial0")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--trace", action="store_true", help="print RX/TX frames")
    parser.add_argument("--list-ports", action="store_true", help="show serial ports and exit")
    parser.add_argument("--de-gpio", type=int, help="optional BCM GPIO pin for DE/RE direction control")
    parser.add_argument("--de-invert", action="store_true", help="invert DE GPIO logic")
    parser.add_argument("--allow-stream-tx", action="store_true", help="allow unsolicited STREAM_DATA after STREAM_ON")
    parser.add_argument("--jitter", action="store_true", help="add small random reply delay")
    parser.add_argument("--no-shell", action="store_true", help="run emulator only; no interactive CLI")
    args = parser.parse_args()

    if args.list_ports:
        list_ports()
        return 0

    if not args.port:
        parser.error("--port is required, or use --list-ports")

    ser = serial.Serial(args.port, args.baud, timeout=0.01, write_timeout=1)
    direction = DirectionControl(args.de_gpio, args.de_invert)
    emu = PeripheralBusEmulator(
        ser=ser,
        direction=direction,
        trace=args.trace,
        allow_stream_tx=args.allow_stream_tx,
        jitter=args.jitter,
    )

    thread = threading.Thread(target=emu.run, name="emulator", daemon=True)
    thread.start()

    print(f"RS-485 peripheral emulator on {args.port} @ {args.baud}")
    print("Virtual devices: 0x01 Searchlight, 0x02 Radar, 0x03 PanTilt, 0x04 LightBar")
    print("Type 'list' to see state. Ctrl+C or 'quit' to stop.")

    try:
        if args.no_shell:
            while True:
                time.sleep(1)
        else:
            EmulatorShell(emu).cmdloop()
    except KeyboardInterrupt:
        print("\nStopping.")
    finally:
        emu.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
