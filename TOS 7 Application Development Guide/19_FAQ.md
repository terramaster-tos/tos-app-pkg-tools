# 19. FAQ

### 19.1 Review

**Q: What should I do if my review is rejected?**  
Review the rejection reason, correct it, and resubmit. Common rejection reasons include: JSON format errors, missing language files, port conflicts, icon format or icon path issues. Refer to the Review Standards chapter for details.

**Q: How long does the review take?**  
Usually 3–5 business days. Initial submissions may take longer (full manual review of all content). Update version reviews are faster (typically 1–3 business days).

**Q: Can the app ID be changed?**  
It cannot be changed after creation. Please confirm the app ID carefully before publishing.

### 19.2 Technical Issues

**Q: What should I do about port conflicts?**  
- Use of system-reserved ports is prohibited: 22, 80, 443, 8181, 5050
- Recommended range: 8000–19999
- Detect port occupation in a preinst script before installation
- Different apps use different ports; the platform does not auto-assign ports

**Q: What are the version numbering rules?**  
- The platform does not enforce any: the version comes from the `version` field in `config.ini`, and non-standard formats, duplicates, and lower version numbers are not rejected
- **However**, the App Center currently detects updates by comparing version numbers numerically — a version that is not greater than the installed one will not reach existing users as an update
- Recommended: digits and dots only, increasing over time (e.g. `1.0.0` → `1.0.1`); SemVer `major.minor.patch` is a good default
- For beta versions, use the `"beta": true` field instead of a `-beta` / `-rc` suffix

**Q: Single-package or dual-package?**  
- Starting from scratch → Single-package mode (all files integrated into one deb package)
- Existing general-purpose standard deb package, complex build → Dual-package mode (source package + data package)
- Simple binary program → Single-package mode

**Q: The config.ini file has a .ini extension but the content is JSON — why?**  
Early TOS configuration systems used the `.ini` extension. To maintain backward compatibility and reduce developer migration costs, new versions retain this extension, but the internal parser has been upgraded to JSON format. Developers only need to write using JSON syntax.

### 19.3 Installation & Running

**Q: What should I do if app installation fails?**  
1. Check `systemctl status <system_id>` to view service status
2. Check `journalctl -u <system_id> -n 50` to view service logs
3. Verify that all required fields in config.ini are correctly filled
4. Verify that the systemd service file path and permissions are correct
5. Verify that the port is not in use: `ss -tlnp | grep <port>`

**Q: How do I debug WebUI internal-opening apps?**  
1. Check whether `/var/api/<app_id>.sock` exists
2. Use `curl --unix-socket /var/api/<app_id>.sock http://localhost/` to directly test the backend
3. In the browser DevTools Network panel, check requests to `/v2/proxy/<app_id>/`
4. Verify that the frontend correctly includes the `Cookie` and `X-Csrf-Token` headers

**Q: How do I debug WebUI external-opening apps?**  
1. Check that the backend is listening on `0.0.0.0:<port>` (not 127.0.0.1)
2. Check the nginx configuration file path and syntax: `nginx -t`
3. Directly access `http://<TNAS_IP>:<port>` to confirm the backend responds correctly
4. Verify that the proxy_pass port in the nginx location block matches the backend listening port

---

← [Previous: Commercialization & Donations](18_Commercialization_Donations.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Appendix](20_Appendix.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
