#!/bin/bash
# One-shot: generate config, run DB migrations, generate CA, then exit.
# Called by entrypoint before supervisor starts all processes.
set -e

export OTS_DATA_FOLDER="${OTS_DATA_FOLDER:-/data/ots}"
CONFIG_FILE="${OTS_DATA_FOLDER}/config.yml"
mkdir -p "${OTS_DATA_FOLDER}"

# Generate config.yml from all OTS_* environment variables
echo "Generating config.yml..."
python3 << 'PYEOF'
import os, yaml, secrets, string

config = {}
for key, value in os.environ.items():
    if key.startswith("OTS_") or key in ("SQLALCHEMY_DATABASE_URI", "DEBUG", "SECRET_KEY", "SECURITY_PASSWORD_SALT"):
        # Convert "True"/"False" strings to booleans
        if value.lower() == "true":
            value = True
        elif value.lower() == "false":
            value = False
        else:
            # Convert numeric strings to int
            try:
                value = int(value)
            except ValueError:
                try:
                    value = float(value)
                except ValueError:
                    pass
        config[key] = value

# Set defaults if not provided
config.setdefault("OTS_RABBITMQ_SERVER_ADDRESS", "rabbitmq")
config.setdefault("OTS_RABBITMQ_USERNAME", "ots")
config.setdefault("OTS_RABBITMQ_PASSWORD", "ots")
config.setdefault("OTS_CA_PASSWORD", "atakatak")
config.setdefault("OTS_MEDIAMTX_ENABLE", False)
config.setdefault("OTS_DATA_FOLDER", "/data/ots")

config_file = os.environ.get("OTS_DATA_FOLDER", "/data/ots") + "/config.yml"
os.makedirs(os.path.dirname(config_file), exist_ok=True)

# Preserve existing secret keys across restarts. These are used by Flask-Security
# as a password pepper and by Flask for session signing — regenerating them on
# every start invalidates all existing password hashes and sessions. Only
# generate new random values when no value exists in either the environment or
# the existing config.yml on disk.
existing = {}
if os.path.exists(config_file):
    with open(config_file) as f:
        existing = yaml.safe_load(f) or {}
for key in ("OTS_SECRET_KEY", "OTS_SECURITY_PASSWORD_SALT",
            "SECRET_KEY", "SECURITY_PASSWORD_SALT"):
    if not config.get(key) and existing.get(key):
        config[key] = existing[key]
if not config.get("OTS_SECRET_KEY"):
    config["OTS_SECRET_KEY"] = secrets.token_hex(32)
if not config.get("OTS_SECURITY_PASSWORD_SALT"):
    config["OTS_SECURITY_PASSWORD_SALT"] = secrets.token_hex(16)

# Flask (SECRET_KEY) and Flask-Security (SECURITY_PASSWORD_SALT) read the
# non-prefixed config keys, which DefaultConfig defaults to a random value on
# every import. Map the OTS_-prefixed values to the keys they actually read so
# they are persisted in config.yml and loaded by app.config.from_file. Without
# this, every restart generates a new pepper and breaks all password hashes.
config["SECRET_KEY"] = config["OTS_SECRET_KEY"]
config["SECURITY_PASSWORD_SALT"] = config["OTS_SECURITY_PASSWORD_SALT"]

with open(config_file, "w") as f:
    yaml.dump(config, f, default_flow_style=False)
print(f"Config written to {config_file}")
PYEOF

# Run DB migrations
echo "Running DB migrations..."
cd /data/ots
python3 -c "
from opentakserver.app import create_app
app = create_app(cli=False)
print('Migrations complete')
" 2>&1 || echo "Migration warning (will retry at runtime)"

# Generate CA if needed
if [ ! -f "${OTS_DATA_FOLDER}/ca/ca.pem" ]; then
  echo "Generating CA certs..."
  python3 -c "
import os, sys
os.environ['OTS_DATA_FOLDER'] = '${OTS_DATA_FOLDER}'
from opentakserver.defaultconfig import DefaultConfig
from opentakserver.certificate_authority import CertificateAuthority
import logging, yaml

# Load config
config_file = '${OTS_DATA_FOLDER}/config.yml'
config = {}
if os.path.exists(config_file):
    with open(config_file) as f:
        config = yaml.safe_load(f) or {}

# Fake app object
class App:
    config = DefaultConfig.__dict__.copy()
    config.update(config)
    config['OTS_CA_FOLDER'] = os.path.join(config.get('OTS_DATA_FOLDER', '/data/ots'), 'ca')
    def __init__(self):
        for k, v in self.config.items():
            if k.isupper():
                setattr(self, k, v)

app = App()
ca = CertificateAuthority(logging.getLogger(), app)
ca.create_ca()
print('CA created successfully')
" 2>&1 || echo "CA generation will happen at runtime"
else
  echo "CA certs already exist."
fi

echo "Init complete."
