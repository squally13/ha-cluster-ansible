#!/usr/bin/env python3
"""Sonda logowania do MySQL dla testów etapu 2 (contracts/verification.md, research R11).

Użycie:
  MYSQL_PROBE_PASSWORD=... mysql_probe.py --host H --user U [--port 3306] [--database D]
                                          [--password-env MYSQL_PROBE_PASSWORD] [--sql "..."]
Hasło wyłącznie ze zmiennej środowiskowej — nigdy w argumentach (widoczne w `ps`).
Wypisuje dokładnie jedną linię i zawsze kończy się kodem 0 — wynik ocenia playbook:
  RESULT=<ok|denied|readonly|error> HOST=<host> USER=<user> [VALUE=<pierwsza kolumna>] [DETAIL=<błąd>]

- ok:       zalogowano i wykonano zapytania (VALUE = pierwsza kolumna pierwszego wiersza ostatniego zapytania),
- denied:   odmowa logowania (1045) albo brak dostępu do bazy (1044),
- readonly: zapis odrzucony przez read_only / super_read_only (1290, 1836),
- error:    każdy inny błąd (np. brak połączenia sieciowego).
Wiele zapytań: rozdziel średnikiem w --sql.
"""
import argparse
import os
import sys

import pymysql

DENIED = {1044, 1045}
READONLY = {1290, 1836}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=3306)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password-env", default="MYSQL_PROBE_PASSWORD")
    parser.add_argument("--database", default=None)
    parser.add_argument("--sql", default="SELECT 1")
    parser.add_argument("--timeout", type=int, default=5)
    args = parser.parse_args()

    prefix = f"HOST={args.host} USER={args.user}"
    try:
        conn = pymysql.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            password=os.environ.get(args.password_env, ""),
            database=args.database,
            connect_timeout=args.timeout,
            autocommit=True,
        )
    except pymysql.err.OperationalError as exc:
        code = exc.args[0] if exc.args else 0
        result = "denied" if code in DENIED else "error"
        print(f"RESULT={result} {prefix} DETAIL={code}")
        return 0

    value = ""
    try:
        with conn.cursor() as cur:
            for statement in [s.strip() for s in args.sql.split(";") if s.strip()]:
                cur.execute(statement)
                row = cur.fetchone()
                value = "" if row is None else str(row[0])
    except pymysql.err.MySQLError as exc:
        code = exc.args[0] if exc.args else 0
        if code in READONLY:
            result = "readonly"
        elif code in DENIED:
            result = "denied"
        else:
            result = "error"
        print(f"RESULT={result} {prefix} DETAIL={code}")
        return 0
    finally:
        conn.close()

    print(f"RESULT=ok {prefix} VALUE={value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
