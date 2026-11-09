#!/usr/bin/env python3
"""Sonda TCP dla testów firewalla (contracts/verification.md).

Użycie: tcp_probe.py <host> <port> <timeout_s>
Wypisuje dokładnie jedną linię: RESULT=<connected|refused|timeout> HOST=<ip> PORT=<port>
i zawsze kończy się kodem 0 — wynik ocenia playbook.

- connected: połączenie nawiązane (port otwarty i dozwolony),
- refused:   aktywna odmowa (RST lub ICMP unreachable) — port zamknięty, ale ruch dociera,
- timeout:   brak odpowiedzi — pakiet porzucony przez firewall (policy drop).
"""
import socket
import sys


def probe(host: str, port: int, timeout: float) -> str:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return "connected"
    except (socket.timeout, TimeoutError):
        return "timeout"
    except OSError:
        # ConnectionRefusedError, EHOSTUNREACH itp. — host odpowiedział odmową
        return "refused"


def main() -> int:
    if len(sys.argv) != 4:
        print("Użycie: tcp_probe.py <host> <port> <timeout_s>", file=sys.stderr)
        return 2
    host, port, timeout = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
    print(f"RESULT={probe(host, port, timeout)} HOST={host} PORT={port}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
