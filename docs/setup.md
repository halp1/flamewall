# Flamewall — extra setup notes

Full beginner walkthrough lives in the root [README.md](../README.md). This file is for reset / debug commands.

## Developer mode

```bash
systemextensionsctl developer on
```

## See installed extensions

```bash
systemextensionsctl list
```

## Uninstall the filter during development

```bash
systemextensionsctl list
# then, using the team ID shown for Flamewall Filter:
systemextensionsctl uninstall <teamID> com.flamewall.app.filter
```

If you changed the bundle ID in Xcode, use that ID instead.

## Logs

```bash
log stream --predicate 'subsystem CONTAINS "flamewall" OR category CONTAINS "Filter"' --level debug
```

## Re-open signing UI quickly

```bash
./run --xcode
```

Then: blue **Flamewall** project icon → target **Flamewall** or **FlamewallFilter** → **Signing & Capabilities**.
