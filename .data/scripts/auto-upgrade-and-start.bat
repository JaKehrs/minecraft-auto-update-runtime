@echo off
REM Batch script to dynamically update config.json, run ferium.exe, extract versions, update the JSON file,
REM and launch MultiMC (plus: run TermModrinth to fetch resourcepacks/shaders directly into the instance)

REM Get the directory of the script
SET "SCRIPT_DIR=%~dp0"
SET "RUNTIME_DIR=%SCRIPT_DIR%..\.runtime"
SET "CONFIG_DIR=%SCRIPT_DIR%..\config"
SET "TMP_DIR=%SCRIPT_DIR%..\.temp\script_auto-upgrade-and-start"

SET "PYTHON_PORTABLE=%RUNTIME_DIR%\python\python.exe"
SETLOCAL ENABLEDELAYEDEXPANSION

REM Define default variables
SET "PROFILE_NAME=Fabulously Optimized"
SET "MODPACK_ID=1KVo5zza"
SET "USER_NAME=JAiXER"

REM ====== MODPACK GUI AUSWAHL STARTEN ======
REM 7 Tokens: Profile | ModpackID | InstallOverrides | RP-CSV | SP-CSV | Mods-CSV | RequestModDeps
FOR /F "tokens=1,2,3,4,5,6,7 delims=|" %%A IN ('pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%pwsh_helper_scripts\select-modpack.ps1"') DO (
    SET "PROFILE_NAME=%%A"
    SET "MODPACK_ID=%%B"
    SET "INSTALL_OVERRIDES=%%C"
    SET "TRM_RESOURCEPACKS=%%D"
    SET "TRM_SHADERPACKS=%%E"
    SET "TRM_MODS=%%F"
    SET "TRM_REQUEST_MOD_DEPS=%%G"
    echo [DEBUG] Selection: PROFILE_NAME="%%A" MODPACK_ID="%%B" INSTALL_OVERRIDES="%%C" RP="%%D" SP="%%E" MODS="%%F" RequestModDeps="%%G"
)

REM Wenn keine Auswahl getroffen wurde (z.B. Fenster abgebrochen)
IF NOT DEFINED PROFILE_NAME (
    echo [ERROR] Keine Modpack-Auswahl getroffen. Vorgang abgebrochen.
    exit /b 1
)

echo [DEBUG] Selection: PROFILE_NAME="%PROFILE_NAME%" MODPACK_ID="%MODPACK_ID%"

REM Paths relative to the script directory

SET "LAUNCHER_DIR=%RUNTIME_DIR%\launcher"
SET "LAUNCHER=%LAUNCHER_DIR%\MultiMC.exe"

SET "INSTANCE_BASE_DIR=%SCRIPT_DIR%..\gamefiles\instances\%PROFILE_NAME%"
SET "INSTANCE_DIR=%INSTANCE_BASE_DIR%\.minecraft"
SET "INSTANCE_CONFIG=%INSTANCE_BASE_DIR%\mmc-pack.json"

SET "MODPACK_MANAGER=%RUNTIME_DIR%\modpack_manager\ferium.exe"
SET "MODPACK_MANAGER_CONFIG=%CONFIG_DIR%\modpack-manager.json"

SET "MODPACK_EXTENDER_DIR=%RUNTIME_DIR%\modpack_extender"
SET "MODPACK_EXTENDER=%MODPACK_EXTENDER_DIR%\termmodrinth.py"
SET "MODPACK_EXTENDER_CONFIG=%CONFIG_DIR%\modpack-extender.json"

REM Check if INSTANCE_DIR exists (the profile must be set up manually first)
IF NOT EXIST "%INSTANCE_DIR%" (
    echo Error: Profile not found.
    exit /b 1
)

echo Starting the update process...
echo Updating config.json with the correct INSTANCE_DIR, name and ModrinthModpack identifier...
powershell -Command ^
    "$config = Get-Content -Raw '%MODPACK_MANAGER_CONFIG%' | ConvertFrom-Json;" ^
    "$instanceDir = '\\?\'+ (Get-Item -Path '%INSTANCE_DIR%').FullName;" ^
    "$config.modpacks[0].output_dir = $instanceDir;" ^
    "$config.modpacks[0].name = '%PROFILE_NAME%';" ^
    "$config.modpacks[0].identifier.ModrinthModpack = '%MODPACK_ID%';" ^
    "$config.modpacks[0].install_overrides = [System.Convert]::ToBoolean('%INSTALL_OVERRIDES%');" ^
    "$jsonString = $config | ConvertTo-Json -Depth 10;" ^
    "$jsonString = $jsonString -replace '  ', ' '; " ^
    "$jsonString | Set-Content '%MODPACK_MANAGER_CONFIG%';"

IF ERRORLEVEL 1 (
    echo Error: Failed to update config.json.
    exit /b 1
)

echo Running ferium.exe to update modpack...
"%MODPACK_MANAGER%" --config-file "%MODPACK_MANAGER_CONFIG%" modpack upgrade > %TMP_DIR%\output.txt

IF ERRORLEVEL 1 (
    echo Error: ferium.exe failed to run.
    exit /b 1
)

SET "fabric_version="
SET "minecraft_version="

echo Extracting FabricLoader and Minecraft versions...
FOR /F "usebackq delims=" %%A IN ("%TMP_DIR%\output.txt") DO (
    echo %%A | findstr /C:"FabricLoader" > NUL
    IF NOT ERRORLEVEL 1 (
        FOR /F "tokens=2 delims= " %%B IN ("%%A") DO SET "fabric_version=%%B"
    )
    echo %%A | findstr /C:"Minecraft" > NUL
    IF NOT ERRORLEVEL 1 (
        FOR /F "tokens=2 delims= " %%B IN ("%%A") DO SET "minecraft_version=%%B"
    )
)

IF DEFINED fabric_version (
    echo Found FabricLoader version: %fabric_version%
) ELSE (
    echo Error: FabricLoader version not found.
    exit /b 1
)

IF DEFINED minecraft_version (
    echo Found Minecraft version: %minecraft_version%
) ELSE (
    echo Error: Minecraft version not found.
    exit /b 1
)

echo Updating the JSON file with new versions...
powershell -Command ^
    "$json = Get-Content -Raw '%INSTANCE_CONFIG%' | ConvertFrom-Json;" ^
    "foreach ($component in $json.components) {" ^
        "if ($component.cachedName -eq 'Minecraft') {" ^
            "$component.version = '%minecraft_version%';" ^
        "} elseif ($component.cachedName -eq 'Fabric Loader') {" ^
            "$component.version = '%fabric_version%';" ^
        "} elseif ($component.cachedName -eq 'Intermediary Mappings') {" ^
            "$component.version = '%minecraft_version%';" ^
        "}" ^
    "};" ^
    "$jsonString = $json | ConvertTo-Json -Depth 10;" ^
    "$jsonString = $jsonString -replace '  ', ' '; " ^
    "$jsonString | Set-Content '%INSTANCE_CONFIG%';"

IF ERRORLEVEL 1 (
    echo Error: Failed to update the JSON file.
    exit /b 1
)

REM ====== TermModrinth-Konfiguration patchen und Python-Downloader ausführen ======
IF NOT EXIST "%MODPACK_EXTENDER_CONFIG%" (
  echo [WARN] TermModrinth-Config nicht gefunden: %MODPACK_EXTENDER_CONFIG%
  echo [WARN] Ueberspringe TermModrinth-Schritt.
  goto SKIP_TERMMODRINTH
)

echo Updating termmodrinth.json (instance_path, versions, slug lists)
pwsh -NoProfile -File "%SCRIPT_DIR%pwsh_helper_scripts\update-termmodrinth.ps1" ^
  -Config "%MODPACK_EXTENDER_CONFIG%" ^
  -Instance "%INSTANCE_DIR%\overrides" ^
  -McVersion "%minecraft_version%" ^
  -RP "%TRM_RESOURCEPACKS%" ^
  -SP "%TRM_SHADERPACKS%" ^
  -Mods "%TRM_MODS%" ^
  -RequestModDeps "%TRM_REQUEST_MOD_DEPS%"

IF ERRORLEVEL 1 (
  echo [ERROR] Konnte termmodrinth.json nicht aktualisieren.
  goto SKIP_TERMMODRINTH
)

for %%D in ("%MODPACK_EXTENDER_CONFIG%") do set "MODPACK_EXTENDER_CONFIG_DIR=%%~dpD"
pushd "%MODPACK_EXTENDER_CONFIG_DIR%"

set "TRM_EXITCODE=0"
echo Running TermModrinth downloader via portable Python...

set "PYTHONPATH=%MODPACK_EXTENDER_DIR%;%PYTHONPATH%"
"%PYTHON_PORTABLE%" -s -c "import sys,runpy; sys.path.insert(0, r'%MODPACK_EXTENDER_DIR%'); runpy.run_path(r'%MODPACK_EXTENDER%', run_name='__main__')"
set "TRM_EXITCODE=%ERRORLEVEL%"
echo [DBG] TermModrinth exitcode: %TRM_EXITCODE%

REM --- Immer Inhalte aus .minecraft\overrides nach .minecraft kopieren (nicht löschen, nur overwrite) ---
set "OVERRIDES_DIR=%INSTANCE_DIR%\overrides"
if exist "%OVERRIDES_DIR%" (
  echo Copying overrides content into instance (non-destructive^)
    robocopy "%OVERRIDES_DIR%" "%INSTANCE_DIR%" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 >nul
	set "RC=%ERRORLEVEL%"
	if !RC! GEQ 8 (
		echo [WARN] robocopy reported error level !RC! while copying overrides. Continuing anyway.
	) else (
		echo [OK] overrides copied.
	)
) else (
  echo [WARN] No overrides directory found at "%OVERRIDES_DIR%".
  if exist "%INSTANCE_DIR%" dir /b "%INSTANCE_DIR%"
)

REM --- Ferium-Backups entfernen: alle *.old Ordner in mods/resourcepacks/shaderpacks ---
for %%D in ("mods" "resourcepacks" "shaderpacks") do (
  if exist "%INSTANCE_DIR%\%%~D" (
    for /d %%O in ("%INSTANCE_DIR%\%%~D\*.old") do (
      echo [CLEAN] Removing old backup folder: "%%~fO"
      rmdir /s /q "%%~fO"
    )
  )
)

popd

:SKIP_TERMMODRINTH

echo Cleaning up temporary files...
del /f /q "%TMP_DIR%\output.txt" 2>nul

echo Launching MultiMC...
start "" "%LAUNCHER%" -d "%LAUNCHER_DIR%" -l "%PROFILE_NAME%" -a "%USER_NAME%" >nul 2>&1
