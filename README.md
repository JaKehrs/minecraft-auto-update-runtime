# Minecraft Auto-Update Runtime

Highly experimental local setup for updating and starting Minecraft without user interaction.

> [!WARNING]
> This project is highly experimental.  
> Structure, scripts, and behavior may change at any time.  
> Due to the nature of the PowerShell-based workflow and the current development target (which is my PC), this setup is currently **Windows-only**.

<a id="todo-roadmap"></a>
## TODO / Roadmap

> [!TIP]
> Current documentation and hardening backlog.

- [ ] Convert code comments to English
- [ ] Document how to get the project up and running
- [ ] Document known safety issues and explain why they are unsafe
- [ ] Revisit and improve those unsafe parts later

<details>
<summary><strong>Expanded TODO Notes</strong></summary>

### Documentation

- [ ] Standardize code comments in English
- [ ] Add a proper setup guide
- [ ] Add a startup flow explanation
- [ ] Document required external tools and where they have to be placed

### Safety / Reliability

- [ ] Identify areas that are currently unsafe
- [ ] Explain why those areas are unsafe
- [ ] Replace or harden unsafe parts later

</details>

<a id="table-of-contents"></a>
## Table of Contents

- [TODO / Roadmap](#todo-roadmap)
- [Overview](#overview)
- [Purpose](#purpose)
- [Runtime Structure](#runtime-structure)
  - [Python Runtime](#python-runtime)
- [External Components](#external-components)
  - [Official Sources](#official-sources)
- [Ignored Local Contents](#ignored-local-contents)

<a id="overview"></a>
## Overview

This repository contains Batch and PowerShell scripts for a local Minecraft workflow.

The goal is to automate the required steps around the local runtime, toolchain, and launcher flow with as little manual interaction as possible.

Prism Launcher is part of that workflow, but it is not the main purpose of the repository.

<a id="purpose"></a>
## Purpose

This setup is intended to:

- update Minecraft-related components automatically,
- prepare the required local runtime tools,
- and start Minecraft without user interaction.

<a id="runtime-structure"></a>
## Runtime Structure

| Path | Purpose |
|---|---|
| `.data/.runtime/java/` | Contains the required Java JRE |
| `.data/.runtime/launcher/` | Contains Prism Launcher, including the executable and its required files |
| `.data/.runtime/modpack_manager/` | Contains Ferium |
| `.data/.runtime/python/` | Contains Python 3.13.7 in embedded-style form |
| `.data/.runtime/silent_powershell/` | Contains the `RunHiddenConsole` executable |
| `.data/.temp/` | Temporary working directory |
| `.data/gamefiles/` | Working directory for managed game-related files |
| `.data/presentation/` | Presentation/output folder; not tracked in Git |

<a id="python-runtime"></a>
### Python Runtime

Place Python **3.13.7** in `.data/.runtime/python/` using a local embedded-style setup, not a normal system-wide PATH-based installation.

Expected `python313._pth` content:

```text
python313.zip
.
..\modpack_extender
# Uncomment to run site.main() automatically
import site
Lib\site-packages
```

<a id="external-components"></a>
## External Components

> [!IMPORTANT]
> The external components listed below are **not included** in this repository.  
> You must download and copy them into the matching folders yourself.  
> This repository does **not** redistribute them.

| Component | Target Folder | What to do |
|---|---|---|
| Java JRE | `.data/.runtime/java/` | Download and copy a matching JRE into this folder yourself. |
| Prism Launcher | `.data/.runtime/launcher/` | Download Prism Launcher yourself and copy the executable and required files into this folder. |
| Ferium | `.data/.runtime/modpack_manager/` | Download Ferium yourself and copy the executable into this folder. |
| Python 3.13.7 | `.data/.runtime/python/` | Download the embeddable package yourself and extract or copy it into this folder. |
| RunHiddenConsole | `.data/.runtime/silent_powershell/` | Download it yourself and copy the executable into this folder. |

<a id="official-sources"></a>
### Official Sources

- **Prism Launcher**
  - [Windows download page](https://prismlauncher.org/download/windows/ ".data/.runtime/launcher/")
  - [Direct portable ZIP (x86-64)](https://github.com/PrismLauncher/PrismLauncher/releases/download/11.0.2/PrismLauncher-Windows-MinGW-w64-Portable-11.0.2.zip ".data/.runtime/launcher/")

- **Ferium**
  - [Releases](https://github.com/gorilla-devs/ferium/releases ".data/.runtime/modpack_manager/")

- **Python 3.13.7**
  - [Release page](https://www.python.org/downloads/release/python-3137/ ".data/.runtime/python/")
  - [Embeddable package (64-bit)](https://www.python.org/ftp/python/3.13.7/python-3.13.7-embed-amd64.zip ".data/.runtime/python/")

- **RunHiddenConsole**
  - [Repository](https://github.com/SeidChr/RunHiddenConsole ".data/.runtime/silent_powershell/")
  - [Releases](https://github.com/SeidChr/RunHiddenConsole/releases ".data/.runtime/silent_powershell/")

<a id="ignored-local-contents"></a>
## Ignored Local Contents

The following contents are intended to remain local and should not be redistributed through this repository:

- runtime binaries and local tool files
- temporary files
- presentation and output files
- other machine-specific local artifacts