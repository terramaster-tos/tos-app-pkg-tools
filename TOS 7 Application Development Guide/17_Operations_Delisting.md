# 17. Operations & Delisting


### 17.1 Version Rollback

If serious issues arise after publishing:

1. Submit a rollback request with reason via the Developer Platform
2. The platform can roll back the app to the previous stable version
3. Users who installed the problematic version will receive a prompt to upgrade to the rolled-back version
4. A post-mortem analysis report must be submitted to the Developer Platform

### 17.2 App Delisting

#### Developer-Initiated Delisting:
1. Submit a delisting request via the Developer Platform
2. Provide the reason (discontinued, replaced, merged, etc.)
3. Existing users retain their installed apps but no longer receive updates
4. New users can no longer find/install the app
5. Repository resources should remain available for 60 days after delisting for existing users

#### Platform-Enforced Delisting (Violations):
1. The platform sends a violation notice via email
2. The developer has 7 days to respond and rectify. The violation rectification period is 7 days (different from the 30-day rectification period for review rejections).
3. If no response is received within 7 days, the app will be forcibly delisted
4. Severe violations (malware, data theft, violation of TOS) result in immediate delisting without a waiting period

#### Discontinuation & Archiving:
- Mark the app as "Discontinued" in the Developer Platform
- Users see a "Discontinued — No Longer Maintained" indicator
- New installations are not allowed
- Existing installations continue to work but receive no further updates
- Discontinued apps are archived after 12 months

### 17.3 Ongoing Operations

1. **Version Updates**: Include release notes with each submission. Increasing the version number is recommended — the App Center detects updates by comparing version numbers numerically, so a version that is not greater than the installed one will not reach existing users as an update.
2. **Security Patches**: Promptly fix security vulnerabilities and compatibility issues.
3. **Review Feedback**: Respond to platform rectification notices and complete fixes within the specified timeframe.
4. **TOS Compatibility**: Continuously adapt to TOS system updates. Test on new TOS versions before user releases.
5. **Repository Maintenance**: Keep public repository resources available long-term. Do not delete published resources.
6. **ABI Monitoring**: Subscribe to TOS release notes and deprecation notices. Plan migrations in advance for announced breaking changes.
7. **Image Updates**: Regularly update Docker base images to include security patches.

---

← [Previous: Review Standards](16_Review_Standards.md) &nbsp;&nbsp;|&nbsp;&nbsp; [Next: Commercialization & Donations](18_Commercialization_Donations.md) → &nbsp;&nbsp;|&nbsp;&nbsp; [📖 Back to Contents](../README.md)
