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
import os, yaml

config = {}
for key, value in os.environ.items():
    if key.startswith("OTS_") or key in ("SQLALCHEMY_DATABASE_URI", "DEBUG", "SECRET_KEY", "SECURITY_PASSWORD_SALT"):
        # Convert "True"/"False" strings to booleans
        if value.lower() == "true":
            value = True
        elif value.lower() == "false":
            value = False
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
