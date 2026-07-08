# 9M2PJU OpenTAKServer Docker

[![OpenTAKServer](https://img.shields.io/badge/OpenTAKServer-1.7.11-blue)](https://docs.opentakserver.io)
[![License](https://img.shields.io/badge/License-GPL%20v3-green)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)

Production-ready Docker deployment of **[OpenTAKServer (OTS)](https://github.com/brian7704/OpenTAKServer)** — an open-source TAK (Team Awareness Kit) server compatible with ATAK, WinTAK, and iTAK clients.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Compose                        │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐  │
│  │PostgreSQL│    │ RabbitMQ │    │  OpenTAKServer   │  │
│  │   :5432  │    │  :5672   │    │  ┌────────────┐  │  │
│  │  (data)  │    │ (msg q)  │    │  │ API :8081  │  │  │
│  └────┬─────┘    └────┬─────┘    │  ├────────────┤  │  │
│       └───────┬───────┘          │  │EUD :8089   │  │  │
│               │                  │  │(SSL CoT)   │  │  │
│               ▼                  │  ├────────────┤  │  │
│         ┌──────────┐             │  │CoT Parser  │  │  │
│         │  Shared  │             │  │(RabbitMQ)  │  │  │
│         │ Network  │             │  └────────────┘  │  │
│         └──────────┘             └──────────────────┘  │
└─────────────────────────────────────────────────────────┘
         ▲                          ▲
         │ SSL :8089                │ HTTP :8081
         ▼                          ▼
   ┌──────────┐              ┌──────────────┐
   │ATAK/WinTAK│              │  Web Browser │
   │  Clients  │              │  (Web UI)    │
   └──────────┘              └──────────────┘
```

## Quick Start

### Prerequisites

- Docker Engine 24+ and Docker Compose v2
- Git
- A domain or public IP reachable from your ATAK devices

### 1. Clone & Configure

```bash
git clone https://github.com/9M2PJU/9M2PJU-Open-TAK-Server-Docker.git
cd 9M2PJU-Open-TAK-Server-Docker
```

### 2. Edit Environment

```bash
nano .env
```

Set strong passwords and your organization details:

```ini
POSTGRES_PASSWORD=YourStrongDBPassword123
RABBITMQ_DEFAULT_PASS=YourStrongRabbitPassword123
OTS_CA_PASSWORD=YourCertPassword456
OTS_CA_ORGANIZATION=MyTeam
OTS_CA_CITY=Kuala_Lumpur
OTS_CA_STATE=Selangor
OTS_CA_COUNTRY=MY
```

### 3. Deploy

```bash
docker compose up -d --build
```

This starts three containers:
- `ots-postgres` — PostgreSQL 16 database
- `ots-rabbitmq` — RabbitMQ message broker
- `ots-server` — OpenTAKServer (API + EUD handler + CoT parser)

### 4. Verify

```bash
docker compose logs -f ots-server
```

Wait for: `Starting OTS processes via supervisord...`

Then check the Web UI at **http://YOUR_SERVER_IP:8080**

Default admin login:
- **Username:** `administrator`
- **Password:** `password`

> ⚠️ **Change the admin password immediately** after first login via the Web UI.

---

## Connecting ATAK

This is the most critical part. Follow these steps exactly.

### Step 1: Log into the Web UI

1. Open **http://YOUR_SERVER_IP:8081** in a browser
2. Login with `administrator` / `password`
3. Click your username (top-right) → **Profile** → **Change Password**

### Step 2: Create a User Account

1. Go to **Administration** → **Users**
2. Click **Create New User**
3. Fill in:
   - **Username:** `your callsign` (e.g. `9M2PJU`)
   - **Display Name:** Your name
   - **Password:** Choose a strong password
4. Click **Create**

### Step 3: Generate Client Certificate

1. Go to **Certificate Enrollment**
2. Click **Issue Certificate** for your user
3. Download the generated ZIP file (e.g. `9M2PJU_CONFIG.zip`)

### Step 4: Transfer to ATAK Device

**Method A — Cloud/Email:**
- Upload the ZIP to cloud storage or email it to yourself
- Download on the Android device

**Method B — Direct USB:**
- Connect the Android device to your computer
- Copy the ZIP to the device's `Download` folder

### Step 5: Import into ATAK

1. Open **ATAK** on your Android device
2. Tap the **toolbox icon** (⚙️) on the map screen
3. Go to **Data Package** → **Import Package**
4. Navigate to and select the ZIP file
5. ATAK will automatically apply the certificate and server configuration

### Step 6: Connect

1. Tap the **toolbox icon** (⚙️) again
2. Go to **Network Preferences** → **Server Connections**
3. You should see a connection entry for your server already configured from the data package
4. Tap the connection to enable it (checkmark turns green)
5. Wait a few seconds — your icon should appear on the Web UI map

### Manual Connection (if data package doesn't work)

If the automatic import fails, configure manually:

1. **ATAK** → **Settings** (⚙️) → **Network Preferences** → **Server Connections**
2. Tap **Add** ➕
3. Fill in:
   - **Connection Type:** `SSL`
   - **Host/Server:** `YOUR_SERVER_IP`
   - **Port:** `8089`
   - **Use Authentication:** ✅ Enabled
4. Go back to **Network Preferences** → **Certificate Manager**
5. Tap **Import Certificates**
6. Select the `.p12` file from the data package
7. Enter the password (from your `.env` `OTS_CA_PASSWORD`)
8. Select the `truststore-root.p12` as the CA certificate
9. Enter the password again
10. Go back to **Server Connections**, enable the connection

---

## Connecting WinTAK

1. Install [WinTAK](https://tak.gov) (requires free registration)
2. Open the downloaded `9M2PJU_CONFIG.zip`
3. Extract `9M2PJU.p12` and `truststore-root.p12` to a folder
4. Open WinTAK → **Settings** → **Network Preferences** → **Server Connections**
5. **Add** connection:
   - **Type:** `SSL`
   - **Address:** `YOUR_SERVER_IP`
   - **Port:** `8089`
6. **Certificate Manager** → Import both `.p12` files
7. Enable the connection

---

## Firewall / Port Reference

For clients **outside your local network**, open these ports in your firewall/router:

| Port | Protocol | Service | Required For |
|------|----------|---------|-------------|
| `8089` | TCP | SSL CoT Streaming | **ATAK/WinTAK client connection** |
| `8080` | TCP | OTS Web UI (nginx) | **Web interface, data packages** |
| `8446` | TCP | Certificate Enrollment | **Web-based cert enrollment** |

**Example — UFW:**
```bash
sudo ufw allow 8089/tcp comment 'ATAK SSL CoT'
sudo ufw allow 8080/tcp comment 'OTS Web UI'
sudo ufw allow 8446/tcp comment 'OTS Cert Enrollment'
```

**Example — iptables:**
```bash
iptables -A INPUT -p tcp --dport 8089 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --dport 8446 -j ACCEPT
```

> ⚠️ For production, restrict by source IP: `-s YOUR_IP_RANGE`

---

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `ots` | PostgreSQL username |
| `POSTGRES_PASSWORD` | *(required)* | PostgreSQL password |
| `POSTGRES_DB` | `ots` | PostgreSQL database name |
| `RABBITMQ_DEFAULT_USER` | `ots` | RabbitMQ username |
| `RABBITMQ_DEFAULT_PASS` | *(required)* | RabbitMQ password |
| `OTS_CA_PASSWORD` | `atakatak` | Certificate password (change this!) |
| `OTS_CA_ORGANIZATION` | `MyOrg` | Org name for certs |
| `OTS_CA_CITY` | `MyCity` | City for certs |
| `OTS_CA_STATE` | `MyState` | State for certs |
| `OTS_CA_COUNTRY` | `US` | Country code for certs |
| `OTS_MEDIAMTX_ENABLE` | `False` | Enable video streaming |

### Ports

| Variable | Default | Description |
|----------|---------|-------------|
| `OTS_SSL_STREAMING_PORT` | `8089` | SSL CoT (ATAK client) |
| `OTS_TCP_STREAMING_PORT` | `8088` | TCP CoT (unencrypted) |
| `OTS_MARTI_HTTPS_PORT` | `8443` | HTTPS Web UI |
| `OTS_CERTIFICATE_ENROLLMENT_PORT` | `8446` | Cert enrollment |
| `OTS_LISTENER_PORT` | `8081` | OTS API (Web UI backend) |

---

## Management

### View Logs
```bash
docker compose logs -f ots-server
```

### Stop
```bash
docker compose down
```

### Stop + Delete Data
```bash
docker compose down -v
```

### Update OTS
```bash
docker compose build --no-cache ots-server
docker compose up -d
```

### Check Status
```bash
docker compose ps
```

---

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| ATAK shows "Connection Failed" | Port 8089 blocked | Open port in firewall |
| Web UI not loading | Port 8081 blocked | Open port, check `docker compose ps` |
| "Certificate not trusted" on ATAK | Wrong cert password | Check `OTS_CA_PASSWORD` matches |
| "No route to host" | Wrong IP/domain | Double-check server address in ATAK |
| Database errors | PostgreSQL not ready | Wait, check `docker compose logs postgres` |
| RabbitMQ connection errors | RabbitMQ not ready | Wait, check `docker compose logs rabbitmq` |

### Reset Everything
```bash
docker compose down -v
rm -rf data/
docker compose up -d --build
```

---

## Comparison: OpenTAKServer vs FreeTAKServer

| Feature | OpenTAKServer | FreeTAKServer |
|---------|:------------:|:-------------:|
| Active Development | ✅ (2026) | ⚠️ Slower |
| Auto CA Generation | ✅ | ❌ |
| Certificate Enrollment | ✅ | ❌ |
| Groups/Channels | ✅ | ❌ |
| LDAP/AD | ✅ | ❌ |
| Meshtastic | ✅ | ❌ |
| ADSB/AIS Feeds | ✅ | ❌ |
| Device Profiles | ✅ | ❌ |
| Plugin System | ✅ | ❌ |
| Federation | Coming Soon | ✅ |
| ExCheck | Coming Soon | ✅ |
| Architecture | RabbitMQ + PostGIS | DigitalPy + ZeroMQ |

---

## License

This Docker deployment is provided under the [GNU General Public License v3.0](LICENSE).

OpenTAKServer itself is © Brian Wallen and contributors, licensed under GPL v3.

---

<div align="center">
  <b>73 — 9M2PJU</b>
  <br>
  <i>Open source TAK for everyone</i>
</div>
