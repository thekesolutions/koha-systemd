# Koha systemd Package - Implementation Summary

## Package Structure

A new `koha-systemd` package has been created as a systemd-only alternative to the traditional init script approach.

## Design Decisions

### Scope: Service Management Only

**Decision: Systemd units handle service lifecycle only, not configuration management**

The existing koha-* scripts (koha-plack, koha-sip, etc.) do more than start/stop services:
- Enable/disable features (modify Apache configs)
- Validate environment (check Apache modules)
- Read instance-specific configuration
- Handle development/debug modes
- Fix permissions

**What systemd units do:**
- Start/stop/restart services
- Monitor and restart on failure
- Manage dependencies
- Capture logs

**What systemd units don't do:**
- Enable/disable Plack in Apache config (still use `koha-plack --enable`)
- Validate Apache modules
- Handle debugger setup
- Fix log file permissions (use RuntimeDirectory/LogsDirectory or ExecStartPre)

**Implication:** The koha-* scripts remain useful for configuration management. Systemd units are an alternative for service lifecycle management only.

### Worker Queue Handling

**Decision: Separate templates per queue**

Koha has multiple background job queues (default, long_tasks). We provide separate templates for the standard queues:

- `koha-worker@.service` - default queue
- `koha-worker-long@.service` - long_tasks queue

For custom queues, administrators can create additional unit files by copying and modifying these templates.

Benefits:
- Simple and explicit
- No parsing required
- Clear service names
- Easy to understand and maintain

Alternatives considered:
- Multi-level templates (`instance:queue` format) - rejected because systemd cannot extract the queue suffix, would require wrapper script

Benefits:
- No redundant unit files - single template handles all queues
- Arbitrary queues - sites can define custom queues without modifying package
- Explicit naming - queue name is visible in unit name
- Standard systemd - uses native template feature, no custom parsing

### Daemon Wrapper Removal

**Decision: Use plain commands, no daemon/start-stop-daemon wrappers**

Systemd provides native daemonization, PID tracking, respawning, and logging. The `daemon` and `start-stop-daemon` wrappers used in init scripts are unnecessary.

Services invoke binaries directly:
```ini
ExecStart=/usr/bin/zebrasrv -f /etc/koha/sites/%i/koha-conf.xml
```

Benefits:
- Simpler - fewer layers of indirection
- Standard - follows systemd best practices
- Better control - systemd manages process lifecycle directly
- Cleaner logs - no wrapper noise in journald

## Files Created

### Systemd Unit Files (debian/systemd/)

**Service Templates:**
- `koha-plack@.service` - Plack/Starman web server
- `koha-zebra@.service` - Zebra indexing server  
- `koha-sip@.service` - SIP2 server (conditional on sip.enabled)
- `koha-z3950@.service` - Z39.50/SRU server (conditional on z3950/config.xml)
- `koha-worker@.service` - Background worker (default queue)
- `koha-worker-long@.service` - Background worker (long_tasks queue)
- `koha-indexer@.service` - Zebra indexing daemon
- `koha-es-indexer@.service` - Elasticsearch indexing daemon

**Target Units:**
- `koha@.target` - Per-instance target (groups all services for one instance)
- `koha.target` - Global target (groups all instances)

### Debian Package Files

- `koha-systemd.install` - Installs units to /usr/lib/systemd/system
- `koha-systemd.postinst` - Runs daemon-reload after install
- `koha-systemd.prerm` - Runs daemon-reload on removal
- `koha-systemd.dirs` - Creates systemd directory
- `koha-systemd.README.Debian` - User documentation
- `control.in` - Updated with koha-systemd package definition

## Key Design Decisions

### 1. Instance Templates
All services use systemd instance templates (`@.service`) where `%i` represents the instance name.

### 2. Service Grouping
- Each service is `PartOf=koha@%i.target` - stops when instance target stops
- Each service has `WantedBy=koha@%i.target` - enables with instance
- Instance targets have `WantedBy=koha.target` - enables with global target

### 3. Conditional Services
Services like SIP and Z3950 use `ConditionPathExists=` to only start when enabled.

### 4. Worker Queues
Separate templates for different queues rather than parameterization for simplicity.

### 5. User/Group
All services run as `%i-koha:%i-koha` matching existing conventions.

### 6. Environment
- `KOHA_CONF=/etc/koha/sites/%i/koha-conf.xml`
- `PERL5LIB=/usr/share/koha/lib`

## Usage Examples

```bash
# Enable and start all services for instance "library"
systemctl enable --now koha@library.target

# Start individual service
systemctl start koha-plack@library.service

# View logs
journalctl -u koha-plack@library.service -f

# Check status of all services for instance
systemctl status 'koha-*@library.service'
```

## Advantages Over Init Script

1. **Granular Control** - Start/stop individual services
2. **Proper Dependencies** - systemd handles ordering and failures
3. **Resource Limits** - Can add CPUQuota, MemoryLimit, etc.
4. **Journald Integration** - Centralized logging with metadata
5. **Socket Activation** - Potential for on-demand startup
6. **Security Hardening** - Can add PrivateTmp, ProtectSystem, etc.
7. **Monitoring** - Native status checks and notifications

## Migration Path

The package is designed to coexist with koha-common:

1. **Conflicts**: `Conflicts: koha-common (<< 24.05)` prevents old versions
2. **Coexistence**: Can run alongside newer koha-common
3. **Migration**: Stop init services, enable systemd units, start

## Next Steps

1. Test with actual Koha instances
2. Add resource limits (optional)
3. Add security hardening directives (optional)
4. Create migration helper script (optional)
5. Update koha-create to support systemd mode (optional)

## Package Dependencies

- `systemd` - Required
- `koha-common (<< 24.05)` - Conflicts with old versions

## Installation

```bash
dpkg-buildpackage -us -uc
dpkg -i ../koha-systemd_*.deb
```

## Adding a New Service

To add a new service type to the systemd package:

### 1. Create the unit template

Create `debian/systemd/koha-{service}@.service`:

```ini
[Unit]
Description=Koha {service} for %i
PartOf=koha@%i.target
After=koha@%i.target

[Service]
Type=simple
User=%i-koha
Group=%i-koha
Environment=KOHA_CONF=/etc/koha/sites/%i/koha-conf.xml
Environment=PERL5LIB=/usr/share/koha/lib
ExecStart=/path/to/service/binary --args
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=koha@%i.target
```

**Note:** If the service needs configuration from koha-conf.xml (like Plack's max_requests/workers),
you may need an ExecStartPre script to generate a config file or environment file that systemd can read.

### 2. Add conditional enablement (if needed)

If the service should only run when explicitly enabled:

```ini
[Unit]
ConditionPathExists=/var/lib/koha/%i/{service}.enabled
```

### 3. Update package files

The unit will be automatically installed via the wildcard in `koha-systemd.install`:
```
debian/systemd/*.service usr/lib/systemd/system
```

### 4. Update helper script (optional)

Add service name to `koha-systemd-ctl` usage text:
```bash
Services: plack, zebra, sip, z3950, worker, {newservice}
```

### 5. Test

```bash
# Build package
dpkg-buildpackage -us -uc

# Install
dpkg -i ../koha-systemd_*.deb

# Test service
systemctl start koha-{service}@testinstance.service
systemctl status koha-{service}@testinstance.service
journalctl -u koha-{service}@testinstance.service
```

### Example: Adding a hypothetical "reports" service

```ini
# debian/systemd/koha-reports@.service
[Unit]
Description=Koha reports daemon for %i
PartOf=koha@%i.target
After=koha@%i.target

[Service]
Type=simple
User=%i-koha
Group=%i-koha
Environment=KOHA_CONF=/etc/koha/sites/%i/koha-conf.xml
Environment=PERL5LIB=/usr/share/koha/lib
ExecStart=/usr/share/koha/bin/reports_daemon.pl
Restart=on-failure

[Install]
WantedBy=koha@%i.target
```

Usage:
```bash
systemctl start koha-reports@library.service
```

## File Locations

- Units: `/usr/lib/systemd/system/`
- Instance configs: `/etc/koha/sites/{instance}/`
- Runtime: `/var/run/koha/{instance}/`
- Logs: Via journald (journalctl)
