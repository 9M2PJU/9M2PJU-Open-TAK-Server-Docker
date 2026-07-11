# 9M2PJU OpenTAKServer Docker

[![OpenTAKServer](https://img.shields.io/badge/OpenTAKServer-1.7.12-blue)](https://docs.opentakserver.io)
[![License](https://img.shields.io/badge/License-GPL%20v3-green)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)

Production-ready Docker deployment of **[OpenTAKServer (OTS)](https://github.com/brian7704/OpenTAKServer)** — an open-source TAK (Team Awareness Kit) server compatible with ATAK, WinTAK, and iTAK clients.

## Architecture

```mermaid
flowchart TB
    subgraph Compose[Docker Compose]
        PG[(PostgreSQL\n:5432\ndata)]
        RMQ[(RabbitMQ\n:5672\nmsg q)]
        OTS[OpenTAKServer]
        OTS --> API[API :8081]
        OTS --> EUD[EUD :8089\nSSL CoT]
        OTS --> CoT[CoT Parser\nRabbitMQ]
        PG <--> OTS
        RMQ <--> OTS
    end
    ATAK[ATAK/WinTAK\nClients] -. SSL :8089 .-> EUD
    WEB[Web Browser\nWeb UI] -. HTTP :8081 .-> API
```

## Why this exists

TAK is the de-facto standard for real-time situational awareness used by first responders, search & rescue, emergency management, and amateur radio operators worldwide. The official TAK server (TAK Server) is Java-heavy, painful to set up, and locked behind a portal. OpenTAKServer flips that — pure Python, actively developed, and now containerized.

This repo packages OTS into a clean, reproducible Docker Compose stack with PostgreSQL + RabbitMQ. No hand-tuned supervisord configs, no manual CA wrangling, no fragile host installs.

## What you get

- **Three-container stack** — PostgreSQL 16, RabbitMQ, and OpenTAKServer, isolated and scalable.
- **Automatic CA + client certificates** — OTS generates its own CA and issues per-user certs via the Web UI. No OpenSSL gymnastics.
- **ATAK / WinTAK / iTAK compatible** — speaks the same SSL CoT streaming protocol as the official TAK Server.
- **Web UI** — manage users, certs, data packages, and view the live map from a browser.
- **Persistent volumes** — database, certs, and config survive container rebuilds.
- **nginx-fronted Web UI** — clean HTTP access on `:8080` instead of exposing the raw Flask app.
- **GPL v3** — fully open source, no vendor lock-in, no phone-home.

## Use cases

- **Android ATAK in the field** — the primary client. ATAK on Android phones/tablets connects over SSL CoT to share position, chat, overlays, and imagery with the rest of the team. This server is the hub those handhelds report into.
- **Search & Rescue (SAR)** — track field teams in real time on a shared map, push overlay data to handhelds.
- **Emergency management / EOC** — coordinate multi-agency response with live positioning and chat.
- **Amateur radio / ARES / RACES** — field deployments for public service events and disaster comms.
- **Airsoft / MilSim** — blue-force tracker for organized scenario play.
- **Drone operations** — feed UAV positions into a common operating picture.
- **Maritime / AIS & ADS-B** — OTS ingests AIS and ADS-B feeds for vessel and aircraft tracking.
- **Meshtastic integration** — bridge LoRa mesh radios into the TAK picture.
- **Training & education** — stand up a classroom TAK server in minutes without licensing headaches.

## Comparison: OpenTAKServer vs FreeTAKServer

Sourced from the [official OpenTAKServer feature comparison](https://docs.opentakserver.io/feature_comparison.html) (OTS 1.7.x docs) and the [FreeTAKServer repo](https://github.com/FreeTAKTeam/FreeTakServer). FreeTAKServer 2.x is in active development and aims to close some of these gaps (federation, LDAP, protobuf CoT); the table below reflects the current stable FTS release.

| Feature | OpenTAKServer | FreeTAKServer |
|---------|:------------:|:-------------:|
| TCP / SSL CoT | ✅ | ✅ |
| Actively Developed | ✅ | ❌ (1.x stable; 2.x in progress) |
| Automatic CA Generation | ✅ | ❌ |
| Certificate Enrollment | ✅ | ❌ |
| EUD Authentication | ✅ | ❌ |
| Groups / Channels | ✅ | ❌ |
| Device Profiles | ✅ | ❌ |
| Plugin / Update Server | ✅ | ❌ |
| Data Packages / DataSync | ✅ | ✅ |
| Mission API | ✅ | ✅ |
| Federation | ⏳ Coming in 1.7.x | ✅ |
| ExCheck | ⏳ Coming Soon | ✅ |
| Video Streaming | ✅ | ✅ |
| Video Recording / Playback | ✅ | ❌ |
| Mumble Server Auth | ✅ | ❌ |
| ADS-B (Airplanes.live) | ✅ | ❌ |
| AIS (AISHub.net) | ✅ | ❌ |
| Meshtastic Bridge | ✅ | ❌ |
| LDAP / Active Directory | ✅ | ❌ (planned in 2.x) |
| 2FA (TOTP / Email) | ✅ | ❌ |
| Web UI with Live Map | ✅ | ✅ |
| Database | SQLAlchemy / PostGIS | SQLAlchemy / SQLite |
| Runs on Raspberry Pi | ✅ | ✅ |
| Language | Python | Python |
| License | GPL v3 | Eclipse Public License |

## License

This Docker deployment is provided under the [GNU General Public License v3.0](LICENSE).

OpenTAKServer itself is © Brian Wallen and contributors, licensed under GPL v3.

---

<div align="center">
  <b>73 — 9M2PJU</b>
  <br>
  <i>Open source TAK for everyone</i>
</div>
