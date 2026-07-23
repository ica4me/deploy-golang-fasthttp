#!/usr/bin/env python3
import sys
from pathlib import Path
import yaml

config = Path(sys.argv[1] if len(sys.argv) > 1 else "config/hosts.yml")
data = yaml.safe_load(config.read_text())
hosts = data["all"]["children"]["fasthttp_backends"]["hosts"]
for name, values in hosts.items():
    print(f"{name}|{values['ansible_host']}")
