# Security policy

## Supported versions

The latest release is supported. Pre-release builds may change their local preferences or wire assumptions without migration support.

## Reporting a vulnerability

Please use GitHub's **Report a vulnerability** form in the repository Security tab. Do not publish an issue containing an exploit, credential, private session data, or an exposed DSH endpoint.

For ordinary hardening ideas that do not disclose a vulnerability, open a normal GitHub issue.

DSH Island is a read-only viewer, but the DSH Host it connects to can expose powerful Agent capabilities. Non-loopback connections are opt-in and must be treated as trusted infrastructure.
