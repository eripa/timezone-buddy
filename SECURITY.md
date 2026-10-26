# Security Policy

## Supported Versions

Timezone Buddy is a menu bar utility with no network access, accounts, or
analytics. Security fixes are made on the latest release line.

| Version | Supported |
| --- | --- |
| 1.5.x | Yes |
| Earlier | No |

## Reporting a Vulnerability

Please do **not** open a public issue for a security problem. Report it
privately through GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
for this repository, or email **eric@ripa.io** if the advisory form is not
available.

Include:

- A description of the issue and its impact
- Steps to reproduce
- The affected version and build number
- Any suggested fix or mitigation

You can expect an acknowledgement within a few days. This is a volunteer
project, so response times are best effort.

## Scope

The app stores its zone list and preferences in `UserDefaults`, is sandboxed,
and does not request network access. Reports about the release build's
code-signing or notarization status are welcome, but the project currently
publishes ad-hoc signed, unnotarized builds; that limitation is documented in
the README.
