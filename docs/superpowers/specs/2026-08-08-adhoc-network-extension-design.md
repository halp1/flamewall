# Running Flamewall's Network Extension Without a Paid Apple Developer Account

Date: 2026-08-08
Status: approved, implementing

## Problem

Flamewall's per-app filtering uses a `NEFilterDataProvider` packaged as a system
extension. The README claimed this requires a paid Apple Developer Program
membership ($99/year), and that a free Personal Team is the blocker.

That diagnosis is wrong. It conflates two different gates.

## What actually blocks activation

Measured on this machine (macOS 26.5.2, Apple M5), not inferred:

| Gate | State | Blocking? |
|---|---|---|
| SIP | already disabled | no |
| `systemextensionsctl developer` | already on | no |
| Built-in firewall | off | no — but see below |
| AMFI restricted-entitlement check | **enforcing** | **yes** |

A spike app embedding the real `FlamewallFilter.systemextension`, ad-hoc signed
with the full NE entitlements, failed activation with
`OSSystemExtensionErrorDomain code=4`. The `sysextd` line
`no policy, cannot allow apps outside /Applications` is a **red herring** — it
appears identically when the app *is* in `/Applications`. The real cause is in
`amfid`:

```
Adhoc signed app with restricted entitlements detected
Spike not valid: Code=-424 "The file is adhoc signed but contains restricted entitlements"
```

Two findings worth keeping:

- AMFI *will* launch an ad-hoc binary that merely **carries**
  `com.apple.developer.networking.networkextension`. Carrying it is fine;
  having it **honored** is what fails. So "you need a provisioning profile to
  run this at all" is false.
- A paid account fixes this by supplying a certificate chain plus a profile that
  authorizes the entitlement. It is not the only way to satisfy AMFI.

The built-in firewall must stay off: with SIP disabled and the firewall enabled,
content filters silently receive no flows at all (Apple bug FB15879569).

## Approach

Disable AMFI enforcement machine-wide via the `amfi_get_out_of_my_way=1`
boot-arg, and keep every line of the existing `FilterDataProvider` / XPC
implementation. Chosen over a `pf` + GID helper rewrite because it preserves the
codebase and is cheap to test.

This is a real reduction in security posture — broader than SIP-off, since it
turns off code-signature enforcement for the whole system. Accepted by the user
for a personal development machine.

## Phase 0 — Machine prep (manual, one time)

Custom boot-args require **Permissive Security** on Apple Silicon (SIP-off alone
only needs Reduced Security):

```bash
sudo nvram boot-args=amfi_get_out_of_my_way=1   # then reboot
```

Preconditions to keep true: firewall off, `systemextensionsctl developer on`.

## Phase 1 — Build and signing changes

1. **`scripts/generate_xcodeproj.py`** — Debug config for the host and filter
   targets uses the full entitlements files rather than the stripped
   `.Debug.entitlements` ones, keeping `CODE_SIGN_IDENTITY = "-"`,
   `CODE_SIGN_STYLE = Manual`, empty `DEVELOPMENT_TEAM`. Debug and Release now
   need identical entitlements — only signing style differs — so
   `Flamewall.Debug.entitlements` and `FlamewallFilter.Debug.entitlements` are
   deleted along with their file references and group entries.

2. **Both entitlements files** — drop `com.apple.security.application-groups`.
   The group `group.com.flamewall.shared` is declared but never referenced in
   code: policy is transported over XPC (`com.flamewall.app.filter.xpc`, which
   matches the filter's `NEMachServiceName`) and persisted under Application
   Support. An unprefixed app group with no team ID is a validation risk for
   zero functional gain.

3. **`scripts/run.sh`** — Xcode's *linker-signed* ad-hoc signature leaves
   `Info.plist=not bound` and `Sealed Resources=none`, which `sysextd` will not
   accept. After building, re-sign explicitly with `codesign --force --sign -`:
   **inner system extension first** (with its entitlements), then the app.
   Then install to `/Applications/Flamewall.app` and launch from there.

4. **`./run --doctor`** — report each gate independently: SIP, AMFI boot-arg,
   developer mode, firewall state, signature seals, install location, and
   current extension state. Six independent gates is too many to debug by
   guesswork.

## Phase 2 — Verification

Success criteria, in order:

1. `./run --doctor` reports all gates met.
2. Approve in System Settings → General → Login Items & Extensions → Network
   Extensions.
3. `systemextensionsctl list` shows
   `com.flamewall.app.filter ... [activated enabled]`.
4. Functional test: blacklist a GUI app, confirm its traffic is dropped while
   another app's is not.

Rollback:

```bash
systemextensionsctl uninstall - com.flamewall.app.filter
sudo nvram -d boot-args    # restores AMFI enforcement
```

## Phase 3 — README correction

Rewrite the "About that Xcode Build Failed" section around the real gate. The
current text asserts filtering is impossible without a paid account, which is
what made this confusing.

## Known risks (not retired)

These need a reboot to test, so they are carried explicitly rather than assumed:

- **Team ID matching.** `sysextd` may require a non-nil team identifier and a
  match between app and extension. Ad-hoc gives both `not set`; whether nil
  equals nil here is unverified.
- **`NEMachServiceName` prefixing.** NE Mach service names are conventionally
  team-prefixed. Whether this is enforced for ad-hoc extensions is unverified.
- **macOS 26 regression.** Apple Developer Forums thread 817101 reports
  `sysextd` rejecting *new* `NEFilterDataProvider` activations on macOS 26 even
  for paid, notarized apps — unresolved as of April 2026. This path may be dead
  on 26.5 regardless of signing.

Fallback if any of these bite: replace NetworkExtension with a privileged
LaunchDaemon driving `pfctl` group-based rules, tagging apps into a blocked or
allowed GID at launch. Verified reachable: `pfctl` accepts `group` rules, and
`sandbox-exec -p '(deny network*)'` blocks a launched process outright. Phase 1
is worth doing either way, since it is what makes the boot-arg testable.

## References

- <https://developer.apple.com/forums/thread/768706> — filters break with SIP off + firewall on (FB15879569)
- <https://developer.apple.com/forums/thread/128767> — NE entitlements and Personal Team limits
- <https://developer.apple.com/forums/thread/817101> — macOS 26 `sysextd` activation regression
