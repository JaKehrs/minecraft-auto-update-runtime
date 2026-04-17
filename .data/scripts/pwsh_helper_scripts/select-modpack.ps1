param(
  [string]$JsonPath = $null
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $JsonPath) { $JsonPath = Join-Path $scriptDir "..\..\config\modpack-list.json" }

$modulePath = Join-Path $scriptDir "modules\gui-dialogs.psm1"
Import-Module $modulePath -Force

# Helper
function To-Csv([object[]]$arr) {
  if (-not $arr) { return "" }
  ($arr | Where-Object { $_ } | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -ne "" }) -join ','
}
function Merge-List($defaults, $mode, $overrides) {
  $d = @(); if ($defaults)  { $d = $defaults  | Where-Object { $_ } }
  $o = @(); if ($overrides) { $o = $overrides | Where-Object { $_ } }
  switch -Regex ($mode) {
    '^(?i:replace)$' { return @($o) }
    default          { return @($d + $o) } # extend (default)
  }
}

# 1) User-Auswahl
$selection = Show-SelectionDialog -JsonPath $JsonPath -DebugLog { param($msg) }

if (-not $selection) {
  Write-Host "[ERROR] Keine Auswahl getroffen oder ungültige Daten." -ForegroundColor Red
  exit 1
}

# 2) JSON laden (für Fallbacks)
$json = Get-Content -Raw -LiteralPath $JsonPath | ConvertFrom-Json
$defaults = $json.Defaults
$option =
  ($json.Options | Where-Object { $_.OptionName -eq $selection.OptionName }) |
  Select-Object -First 1
if (-not $option) {
  # Fallback: nach ProfileName matchen
  $option = ($json.Options | Where-Object { $_.ProfileName -eq $selection.ProfileName }) | Select-Object -First 1
}

# 3) Finale Listen bestimmen
# Falls das Modul bereits *Final*-Listen liefert, nehmen wir die;
# sonst bauen wir sie aus Defaults + Option[Mode] + Option[List].
$rpFinal = $selection.ResourcepacksFinal
$spFinal = $selection.ShaderpacksFinal
$mdFinal = $selection.ModsFinal

if (-not $rpFinal) {
  $rpFinal = Merge-List $defaults.Resourcepacks $option.ResourcepacksMode $option.Resourcepacks
}
if (-not $spFinal) {
  $spFinal = Merge-List $defaults.Shaderpacks $option.ShaderpacksMode $option.Shaderpacks
}
if (-not $mdFinal) {
  $mdFinal = Merge-List $defaults.Mods        $option.ModsMode        $option.Mods
}

# 4) RequestModDependencies bool
$reqDeps = $false
if ($selection.PSObject.Properties.Name -contains 'RequestModDependencies') {
  $reqDeps = [bool]$selection.RequestModDependencies
} elseif ($option -and ($option.PSObject.Properties.Name -contains 'RequestModDependencies')) {
  $reqDeps = [bool]$option.RequestModDependencies
}

# 5) CSV bauen
$rpCsv = To-Csv $rpFinal
$spCsv = To-Csv $spFinal
$mdCsv = To-Csv $mdFinal
$reqDepsStr = $reqDeps.ToString().ToLower()

# 6) 7 Felder an die BAT ausgeben
Write-Output "$($selection.ProfileName)|$($selection.ModpackID)|$($selection.InstallOverrides)|$rpCsv|$spCsv|$mdCsv|$reqDepsStr"
exit 0
