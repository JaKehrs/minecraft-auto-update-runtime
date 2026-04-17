# Minecraft Auto-Update Runtime

Highly experimental local setup for updating and starting Minecraft without user interaction.

The scripts in this repository are intended to automate the required steps around the local runtime, toolchain, and launcher flow.

## Status

Highly experimental.  
Structure, scripts, and behavior may change at any time.

## Purpose

This repository contains Batch and PowerShell scripts for a local Minecraft workflow that is meant to:

- update Minecraft-related components automatically,
- prepare the required local runtime tools,
- and start Minecraft without user interaction.

Prism Launcher is used as one tool within that workflow, not as the main purpose of the repository.

## Runtime structure

### `.data/runtime/java/`
Place the required Java JRE here.

### `.data/runtime/launcher/`
Place Prism Launcher here, including the executable and its required files.

### `.data/runtime/modpack_manager/`
Place Ferium here.

### `.data/runtime/python/`
Place Python **3.13.7** here in local embedded-style form, not as a normal PATH-based system installation.

Expected `python313._pth` content:

```text
python313.zip
.
..\modpack_extender
# Uncomment to run site.main() automatically
import site
Lib\site-packages