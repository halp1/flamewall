# Flamewall

Minimal macOS menu-bar firewall: live Wi‑Fi usage tracking and per-app network filtering (whitelist / blacklist) with global and per-network profiles.

## Run it

```bash
./run
```

This builds, ad-hoc signs, installs to `/Applications/Flamewall.app`, and launches it. Look for the **flame** icon in the **menu bar** (top-right of the screen). No Dock icon.

```bash
./run --doctor      # check every gate, see what's unmet
./run --uninstall   # remove the extension and the installed app
```

---

## Getting the filter to activate (no paid account needed)

The filter is a `NEFilterDataProvider` system extension. Its entitlements are
**restricted**, which means AMFI ignores them on an ad-hoc signature — so the
extension silently fails to activate with `OSSystemExtensionErrorDomain code=4`.

A paid Apple Developer account is *one* way to fix this: it gives you a
certificate chain plus a provisioning profile authorizing the entitlement. But
it is not the only way. On a machine you control, you can tell AMFI to stand
down instead.

**What is actually required is not a paid account.** It is:

| Gate | How to satisfy it |
|---|---|
| SIP disabled | Recovery → Utilities → Terminal → `csrutil disable` |
| AMFI not enforcing | `sudo nvram boot-args=amfi_get_out_of_my_way=1` + reboot |
| Sysext developer mode | `sudo systemextensionsctl developer on` |
| Built-in firewall **off** | System Settings → Network → Firewall → off |
| Real bundle signature | handled by `./run` |
| App in `/Applications` | handled by `./run` |

On Apple Silicon, custom boot-args also need **Permissive Security**: shut down,
hold the power button → Options → Utilities → Startup Security Utility → select
your disk → Security Policy → Permissive.

Run `./run --doctor` and it will tell you which of these is missing.

> The firewall one is not optional and not obvious: with SIP disabled **and** the
> built-in firewall enabled, content filters receive no flows at all and block
> nothing, with no errors logged. That's an Apple bug ([FB15879569](https://developer.apple.com/forums/thread/768706)).

### Understand the tradeoff

`amfi_get_out_of_my_way=1` disables code-signature enforcement **machine-wide**,
not just for Flamewall. That is a broader reduction in security than disabling
SIP. It is a reasonable thing to do on a personal development machine and a bad
thing to do on a machine you rely on. Undo it with:

```bash
sudo nvram -d boot-args   # then reboot
```

### Turning it on

1. `./run`
2. Menu bar flame → Settings → System → **Activate Filter**
3. Approve in System Settings → General → Login Items & Extensions → **Network Extensions**
4. Verify: `systemextensionsctl list | grep flamewall` should show `[activated enabled]`

If it fails, the real reason is in the log — the `sysextd` line
`no policy, cannot allow apps outside /Applications` is a **red herring** and
appears even when the app is in `/Applications`:

```bash
log show --last 2m --predicate 'process == "sysextd" OR process == "amfid"' \
  --style compact | grep -v 'xpc:connection'
```

### Known risk on macOS 26

There are reports of `sysextd` rejecting *new* `NEFilterDataProvider`
activations on macOS 26 even for paid, notarized apps
([forum thread](https://developer.apple.com/forums/thread/817101), unresolved as
of April 2026). If you hit that wall, it is not something signing can fix.

### If you do have a paid Apple Developer account

1. Xcode → Settings → Accounts → add your paid team.
2. Build the **Release** configuration, which uses automatic signing.
3. Set Team on both the **Flamewall** and **FlamewallFilter** targets.

Both configurations use the same entitlements files; only the signing style
differs.

---

## Behavior summary

| Mode | Empty list | Listed apps |
|------|------------|-------------|
| Filter Off | Allow all | — |
| Blacklist On | Allow all | Block listed |
| Whitelist On | Block all | Allow listed only |

Per-network profiles **override** global on that Wi‑Fi SSID. Usage pauses when there is no Wi‑Fi SSID.

## Extra

See [docs/setup.md](docs/setup.md) for logs / extension reset commands.
