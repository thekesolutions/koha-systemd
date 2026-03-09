# koha-systemd

Native systemd service units for Koha ILS.

## Problem

The current `koha-common.service` bundles all Koha daemons (Plack, Zebra, SIP, Z3950, workers, indexers) under a single systemd service. This causes:

- **No process isolation**: All services run as children of one unit
- **OOM-killer issues**: Memory pressure can kill individual daemons without systemd restarting them
- **Poor observability**: Cannot see which component is using resources
- **No systemd features**: Cannot use MemoryMax, CPUQuota, or per-service restart policies

See [Bug 40901](https://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=40901) for details.

## Solution

This package provides native systemd units for each Koha service type:

- `koha-plack@.service` - Plack/Starman web server
- `koha-zebra@.service` - Zebra indexing server
- `koha-sip@.service` - SIP2 server
- `koha-z3950@.service` - Z39.50/SRU server
- `koha-worker@.service` - Background job workers (default queue)
- `koha-worker-long@.service` - Background job workers (long_tasks queue)
- `koha-indexer@.service` - Zebra indexing daemon
- `koha-es-indexer@.service` - Elasticsearch indexing daemon

Plus grouping targets:
- `koha@.target` - All services for one instance
- `koha.target` - All instances

## Installation

### From Release

Download the latest `.deb` from [Releases](https://github.com/thekesolutions/koha-systemd/releases):

```bash
wget -O koha-systemd.deb https://github.com/thekesolutions/koha-systemd/releases/latest/download/koha-systemd_1.0.1_all.deb
sudo dpkg -i koha-systemd.deb
```

Or let wget determine the filename:

```bash
wget --content-disposition https://github.com/thekesolutions/koha-systemd/releases/latest/download/koha-systemd_1.0.1_all.deb
sudo dpkg -i koha-systemd_*.deb
```

### From Source

```bash
git clone https://github.com/thekesolutions/koha-systemd.git
cd koha-systemd
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../koha-systemd_*.deb
```

## Usage

### Managing a complete instance

```bash
# Enable and start all services (replace [instance] with your instance name, e.g., library)
sudo systemctl enable --now koha@[instance].target

# Check status
sudo systemctl status koha@[instance].target

# Stop all services
sudo systemctl stop koha@[instance].target
```

### Managing individual services

```bash
# Restart just Plack
sudo systemctl restart koha-plack@[instance].service

# Check worker status
sudo systemctl status koha-worker@[instance].service
sudo systemctl status koha-worker-long@[instance].service
```

### Viewing logs

```bash
# All services for instance
sudo journalctl -u 'koha-*@[instance].service'

# Specific service
sudo journalctl -u koha-plack@[instance].service -f

# All Koha logs
sudo journalctl -u 'koha-*.service'
```

### Helper script

```bash
# Enable instance
sudo koha-systemd-ctl enable [instance]

# Start specific service
sudo koha-systemd-ctl start [instance] plack

# Check status
sudo koha-systemd-ctl status [instance]
```

## Design

See [DESIGN.md](DESIGN.md) for detailed design decisions and architecture.

## Requirements

- Debian 11 (Bullseye) or later
- systemd
- koha-common package

## Limitations

This package handles **service lifecycle only**. Configuration management tasks still require the koha-* scripts:

- Use `koha-plack --enable` to enable Plack in Apache config
- Use `koha-sip --enable` to enable SIP
- Use `koha-create` to create instances

**Custom worker queues:** The package provides templates for the two standard queues (default, long_tasks). For custom queues, copy and modify one of the worker templates.

## Contributing

Issues and pull requests welcome at https://github.com/thekesolutions/koha-systemd

## License

GPL-3.0-or-later (same as Koha)
