
# 13. Local Testing & Debugging

Before submitting your application, you must thoroughly test the complete lifecycle on a **TNAS device**.

**TOS7 Development Environment Quick Setup:**

1. **Option A: Ubuntu 22.04 Virtual Machine (Recommended)**
   - Download VirtualBox or VMware
   - Import the official **TOS7 developer VM** from the TOS Developer Platform
   - The VM includes pre-configured **TOS7 tools** and simulated services

2. **Option B: Docker-Based Development Container**
   ```bash
   docker run -it --name tos7-dev -v $(pwd):/workspace ubuntu:22.04 /bin/bash
   apt-get update && apt-get install -y dpkg-dev lintian systemd
   ```

3. **Option C: Physical TNAS Device (For Final Testing)**
   - Final verification must be performed on an actual device before submission
   - Must run TOS 7.0 or later
   - Enable SSH access for debugging

### 13.1 Deb Application Testing

```bash
# 1. Install the deb package
sudo dpkg -i <appid>_<version>_amd64.deb

# 2. Check if the service is running
sudo systemctl status <appid>

# 3. View service logs (real-time)
sudo journalctl -u <appid> -f

# 4. View recent logs
sudo journalctl -u <appid> --since "1 hour ago"

# 5. Check if the Web UI is accessible (Web apps)
curl http://localhost:<port>

# 6. Test start/stop
sudo systemctl stop <appid>
sudo systemctl start <appid>
sudo systemctl restart <appid>

# 7. Test uninstallation
sudo dpkg --remove <appid>       # Keep configuration
sudo dpkg --purge <appid>        # Complete removal

# 8. Verify cleanup (no residual files/services)
systemctl list-unit-files | grep <appid>
# Check application directory (the path the app itself uses)
ls -la /usr/local/<appid> 2>/dev/null
# Check persistent data (shared folder)
ls /Volume*/<appid> 2>/dev/null
# Check system user
id <appid> 2>/dev/null

# 9. Test upgrade path
sudo dpkg -i <appid>_0.9.0_amd64.deb   # Install old version
# ... Add some data to /Volume*/<appid>/ ...
sudo dpkg -i <appid>_1.0.0_amd64.deb   # Upgrade to new version
# Verify data is preserved and migrated
```

> **Note:** These are the paths your application uses. After installation the platform maps `/usr/local/<appid>/` onto the volume the user chose at installation, where the same directory physically lives at `/Volume<N>/@apps/<appid>/`. `*` is documentation notation for that volume number (e.g., Volume1, Volume2) — the platform does **not** expand it, so never write `/Volume*/…` into a compose file, a systemd unit, a lifecycle script, or any other machine-read configuration.
> - `/usr/local/<appid>/` — Application directory: program files, logs, cache, temporary files
> - `/Volume*/<appid>/` — Persistent user data (shared folder, created by the application)

### 13.2 Docker Application Testing

```bash
# 1. Ensure DockerEngine is installed and running
# Docker Engine is available in the TOS App Center — users will be prompted to install it if not already present.
sudo systemctl status docker

# 2. Start the application
docker-compose -f docker-compose.yml up -d

# 3. Check container status
docker ps | grep <appid>

# 4. View container logs (real-time)
docker logs -f <appid>

# 5. Check resource usage
docker stats <appid>

# 6. Check if the Web UI is accessible
curl http://localhost:<port>

# 7. Test stop/restart
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose.yml up -d

# 8. Test data persistence
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose.yml up -d
# Verify data still exists in /Volume*/DockerAppData/<appid>/ and /Volume*/<appid>/

# 9. Test health check
docker inspect --format='{{.State.Health.Status}}' <appid>

# 10. Cleanup
docker-compose -f docker-compose.yml down -v
```

### 13.3 Developer Debugging Toolkit

**One-Click Debugging Script:**
Save as `debug.sh` and run to validate your application:
```bash
#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <appid>"
    exit 1
fi

APPID="$1"
echo "=== TOS7 App Debug: $APPID ==="

echo "--- Service Status ---"
systemctl status "$APPID" 2>/dev/null || echo "Service not found"

echo "--- Processes ---"
pgrep -a -f "@apps/$APPID/" 2>/dev/null || echo "No related processes found"

echo "--- Ports ---"
ss -tlnp | grep "$APPID"

echo "--- Application Directory ---"
ls -laR /usr/local/$APPID/ 2>/dev/null

echo "--- Persistent Data (Shared Folder) ---"
ls -laR /Volume*/$APPID/ 2>/dev/null

echo "--- Recent Errors ---"
journalctl -u "$APPID" -p err --since "10 minutes ago" --no-pager

echo "--- Disk Usage ---"
du -sh /usr/local/$APPID/ /Volume*/$APPID/ 2>/dev/null

echo "=== Debug Complete ==="
```

**Service Debugging**

```bash
# Verify service file validity
systemd-analyze verify /etc/systemd/system/<appid>.service

# Check service dependencies
systemd-analyze dump | grep -A5 <appid>

# Check port listening
ss -tlnp | grep <port>

# Check process details
ps aux | grep <appid>

# Check application directory
ls -laR /usr/local/<appid>/

# Check persistent data (shared folder)
ls -laR /Volume*/<appid>/

# View systemd error logs
journalctl -u <appid> -p err

# View system logs
grep <appid> /var/log/syslog
```

**Docker Debugging**

```bash
# Enter a running container
docker exec -it <appid> /bin/sh

# Inspect container details
docker inspect <appid>

# Check resource limits
docker stats --no-stream <appid>

# Check network
docker network ls
docker network inspect <network_name>

# View container filesystem changes
docker diff <appid>

# View image layers
docker history <image>
```

**Rapid Development Cycle**

Rapid iteration during development:

```bash
# Deb application: quick reinstall
sudo dpkg --purge <appid> && sudo dpkg -i <appid>_<version>_amd64.deb

# Docker application: quick rebuild
docker-compose down && docker-compose up -d --build

# Tail logs while testing
journalctl -u <appid> -f &   # Deb
docker logs -f <appid> &     # Docker
```

### 13.4 Common Issues & Solutions

| Issue | Possible Cause | Solution |
|---|---|---|
| Service fails to start | Missing dependencies or incorrect path | Check `journalctl -u <appid>`, verify `ExecStart` path |
| Port conflict | Another service using the same port | `ss -tlnp \| grep <port>`, switch to an available port |
| Permission denied | Incorrect file ownership or permissions | Verify `User`/`Group` in service file, check file ownership |
| Web UI inaccessible | Service not listening or firewall blocking | Check if service is running, verify port binding (`0.0.0.0` not `127.0.0.1`) |
| Container exits immediately | Application error inside container | `docker logs <appid>`, check entrypoint/command |
| Data lost after restart | Volume mount not configured | Add volume mapping in docker-compose.yml |
| App broken after TOS update | ABI change or service conflict | Check `low_version`, test on new TOS version |
| Configuration not loaded | Incorrect config path or permissions | Verify WorkingDirectory and config file path |
| Config permissions lost after upgrade | chown/chmod not re-applied in postinst | Add `chown -R <appid>:<appid>` in postinst script |
| Socket file residue causing startup failure | Socket not cleaned up from previous run | Add `rm -f /var/api/<appid>.sock` before starting service |
| Nginx reload failure | Invalid Nginx config syntax | Validate with `nginx -t` before reloading |
| Incorrect Docker volume permissions | Host vs container UID/GID mismatch | Use `PUID`/`PGID` environment variables matching host user |
| Service starts before network is ready | systemd unit missing `After=network.target` | Add `After=network.target` and `Wants=network.target` |
| Deb fails to install due to unmet dependencies | Missing Depends in DEBIAN/control | Missing system library dependency → add corresponding package name in `Depends` (DEBIAN/control); missing other app dependency → add in config.ini `depend` field |

---

← [Previous: Best Practices](12_Best_Practices.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: CICD Guide](14_CICD_Guide.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to TOC](../README.md)
