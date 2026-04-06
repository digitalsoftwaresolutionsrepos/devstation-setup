# AgentWatch WebRTC Container Configuration

AgentWatch uses WebRTC to stream terminal sessions from devcontainers. In Docker bridge networking mode, WebRTC ICE candidates use the container's internal IP by default, which is unreachable from external clients. Three environment variables solve this by telling the AgentWatch daemon which host-side UDP ports and IP to advertise.

## Required Environment Variables

Every repo's `devcontainer.json` must have these three variables in `containerEnv`:

| Variable | Purpose | Example |
|----------|---------|---------|
| `AGENT_WATCH_PORT_RANGE_START` | First UDP port in the range | `"30050"` |
| `AGENT_WATCH_PORT_RANGE_END` | Last UDP port in the range (inclusive) | `"30099"` |
| `AGENT_WATCH_HOST_IP` | Host LAN IP for ICE candidates | `"192.168.2.85"` |

The AgentWatch daemon reads these at startup and uses them to configure WebRTC ICE candidates with the correct host-reachable IP and port range.

## Configuration Rules

1. **Each repo gets a unique, non-overlapping 50-port UDP range** (START to END inclusive = 50 ports)
2. **1:1 UDP port mapping** in `runArgs` — the container port range maps to the identical host port range
3. **HOST_IP must be the host's LAN IP** (`192.168.2.85`), never `127.0.0.1` or `0.0.0.0`
4. **No `portRangeStart`/`portRangeEnd` in `worker-config.json`** — the env vars are the sole source of truth
5. **No `configure_agentwatch_ports()` in post-create scripts** — the env vars are injected by Docker, not scripts

## devcontainer.json Example

```json
"containerEnv": {
  "AGENT_WATCH_PORT_RANGE_START": "30050",
  "AGENT_WATCH_PORT_RANGE_END": "30099",
  "AGENT_WATCH_HOST_IP": "192.168.2.85"
},

"runArgs": [
  "-p", "30050-30099:30050-30099/udp"
]
```

The `-p` flag creates a 1:1 mapping: host port 30050 maps to container port 30050, etc. The range in the `-p` flag must exactly match the `START` and `END` env var values.

## Port Allocation Registry

Each repo has a dedicated 50-port block. Ranges are contiguous starting at 30000.

| Repo | START | END | UDP Range |
|------|-------|-----|-----------|
| abstractcorenugetpackages | 30000 | 30049 | 30000-30049/udp |
| beacon | 30050 | 30099 | 30050-30099/udp |
| continuum-games | 30100 | 30149 | 30100-30149/udp |
| goldrushcitykiosk | 30150 | 30199 | 30150-30199/udp |
| goldrushcitykioskfrontend | 30200 | 30249 | 30200-30249/udp |
| kioskdevices | 30250 | 30299 | 30250-30299/udp |
| mcp-atlassian | 30300 | 30349 | 30300-30349/udp |
| primero-kiosk-api | 30350 | 30399 | 30350-30399/udp |
| primero-kiosk_back_end | 30400 | 30449 | 30400-30449/udp |
| primerowebportal | 30450 | 30499 | 30450-30499/udp |
| sas-control-plane-host | 30500 | 30549 | 30500-30549/udp |
| sas-edge-controller | 30550 | 30599 | 30550-30599/udp |
| stormchasers | 30600 | 30649 | 30600-30649/udp |
| kioskshellsupport | 30650 | 30699 | 30650-30699/udp |
| debix-vision | 30700 | 30749 | 30700-30749/udp |

**Next available block:** 30750-30799

## Adding a New Repo

When setting up a new repo's devcontainer:

1. Check this registry for the next available 50-port block
2. Add the three env vars to `containerEnv` in `devcontainer.json`
3. Add the `-p` UDP mapping to `runArgs`
4. Update this registry with the new repo's allocation
5. Rebuild the container: `~/devcontainer-rebuild.sh ~/code/REPO_NAME`

Example for a new repo getting the next block (30650-30699):

```json
"containerEnv": {
  "AGENT_WATCH_PORT_RANGE_START": "30650",
  "AGENT_WATCH_PORT_RANGE_END": "30699",
  "AGENT_WATCH_HOST_IP": "192.168.2.85"
}
```

```json
"runArgs": [
  "-p", "30650-30699:30650-30699/udp"
]
```

## Templates

The templates in `~/devstation-setup/templates/` include AgentWatch env vars and a UDP port mapping with **`XXXXX` placeholder values**. Each new repo needs a unique, non-overlapping port range assigned at setup time, so after copying the template:

1. Check the port allocation registry above for the next available 50-port block
2. Replace all `XXXXX` placeholders in `containerEnv` and `runArgs` with the assigned values
3. Update the registry with the new repo's allocation

## Daemon Startup

The AgentWatch daemon is started by the `start_agentwatch()` function in each repo's `post-create-command.sh`. This function is already present in all templates and repos. It reads `worker-config.json` from the `.agentwatch/` directory and starts the supervisor or daemon process. The WebRTC port configuration comes purely from the environment variables — the daemon reads them at startup.

## Changing the Host IP

If the host's LAN IP changes (e.g., DHCP reassignment, network reconfiguration):

1. Find the new IP: `hostname -I | awk '{print $1}'`
2. Update `AGENT_WATCH_HOST_IP` in all 13 repo `devcontainer.json` files
3. Rebuild all containers: `~/devcontainer-rebuild.sh ~/code`

## Troubleshooting

### WebRTC connections fail from external clients

- Verify `AGENT_WATCH_HOST_IP` matches the host's current LAN IP
- Check that the UDP port range is open on the host firewall: `sudo ufw status`
- Confirm the container's UDP ports are mapped: `docker port CONTAINER_ID`

### "Port already in use" on container start

- Two repos have overlapping port ranges — check the registry above
- A stopped container may still hold the ports — run `docker ps -a` and remove stale containers
