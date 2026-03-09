# Project Generation Summary

## Initial Request
"Read debian/koha-common.init and related scripts, and analyze how viable it would be to make a systemd-compliant version that handles each subservice as a separate unit, maybe using templates for the instances"

## Key Decisions Made During Development

### 1. Separate Package Approach
- Initially considered adding to Koha's debian/ directory
- Pivoted to standalone project with independent release cycle
- Rationale: Easier maintenance, testing, and adoption

### 2. Worker Queue Handling
- **Decision**: Multi-level systemd templates (`koha-worker@queue:instance.service`)
- Allows arbitrary queue names without creating separate unit files
- Uses systemd's native template feature with `%i` (full string) and `%p` (prefix)

### 3. Daemon Wrapper Removal
- **Decision**: Use plain commands, no daemon/start-stop-daemon wrappers
- Systemd handles daemonization, PID tracking, respawning, logging natively
- Simpler and follows systemd best practices

### 4. Scope Definition
- **Decision**: Service lifecycle only, not configuration management
- Scripts like `koha-plack --enable` still needed for Apache config
- Package depends on koha-common, acts as add-on

### 5. Build Strategy
- **Decision**: Single build for arch:all package
- Works on Debian 11, 12, 13 (and future versions)
- No need for per-version builds since it's just text files

## Problem Being Solved (Bug 40901)

Current koha-common.service bundles all daemons under one systemd service:
- No process isolation
- OOM-killer can kill sub-daemons without systemd restarting them
- Poor observability (can't see which component uses resources)
- Can't use systemd features (MemoryMax, CPUQuota, per-service logging)

## Solution Architecture

**Service Templates:**
- koha-plack@.service
- koha-zebra@.service
- koha-sip@.service
- koha-z3950@.service
- koha-worker@.service (multi-level template)
- koha-indexer@.service
- koha-es-indexer@.service

**Grouping:**
- koha@.target (per-instance)
- koha.target (global)

**Helper:**
- koha-systemd-ctl script

## Repository Structure
```
koha-systemd/
├── .github/workflows/build.yml  # Builds .deb on tags
├── debian/                       # Package metadata
├── systemd/                      # Unit files
├── scripts/                      # Helper script
├── README.md                     # Usage documentation
└── DESIGN.md                     # Technical decisions
```

## Build Process
- GitHub Actions triggered on version tags (v*)
- Builds single .deb using Debian 12 (bookworm)
- Publishes to GitHub Releases

## Usage Example
```bash
# Enable instance
systemctl enable --now koha@library.target

# Start specific service
systemctl start koha-plack@library.service

# Custom worker queue
systemctl start koha-worker@my_queue:library.service

# View logs
journalctl -u koha-plack@library.service -f
```

## Key Files Generated
- 8 systemd service templates
- 2 systemd targets
- 1 helper script
- Complete debian packaging
- GitHub Actions workflow
- Documentation (README, DESIGN)

## Prompt Engineering Notes
- Started with analysis request
- Iteratively refined based on feedback
- Made architectural decisions collaboratively
- Pivoted from in-tree to standalone project
- Fixed GitHub Actions issues iteratively
- Optimized build strategy (removed unnecessary matrix builds)
