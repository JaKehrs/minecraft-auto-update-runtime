param(
  [Parameter(Mandatory=$true)] [string]$Config,        # Pfad zu modpack-extender.json (ehem. termmodrinth.json)
  [Parameter(Mandatory=$true)] [string]$Instance,      # .minecraft\overrides
  [Parameter(Mandatory=$true)] [string]$McVersion,     # z.B. 1.21.8
  [AllowEmptyString()] [string]$RP = "",
  [AllowEmptyString()] [string]$SP = "",
  [AllowEmptyString()] [string]$Mods = "",
  [AllowEmptyString()] [string]$RequestModDeps = ""    # "true"/"false" (leerer String erlaubt)
)

$ErrorActionPreference = 'Stop'

# Laden oder Grundstruktur erzeugen
if (Test-Path -LiteralPath $Config) {
  $j = Get-Content -Raw -LiteralPath $Config | ConvertFrom-Json
} else {
  $j = [pscustomobject]@{
    mods                   = @()
    resourcepacks          = @()
    shaders                = @()
    storage                = "./storage"
    cache_lifetime_minutes = 4
    tmp_path               = "./tmp"
    instance_path          = ""
    threads                = 4
    modrinth               = [pscustomobject]@{
      max_queries_per_minute = 256
      minecraft_versions     = [pscustomobject]@{}
      loader                 = [pscustomobject]@{}
      request_dependencies   = @('required','#optional')
      primaries_only         = [pscustomobject]@{ mods = $true; resourcepacks = $false; shaders = $true }
      try_not_download_sources = [pscustomobject]@{ mods = $true; resourcepacks = $true; shaders = $true }
      fallback_to_latest     = [pscustomobject]@{ mods = $false; resourcepacks = $true; shaders = $true }
      allow_prereleases      = [pscustomobject]@{ mods = $false; resourcepacks = $false; shaders = $false }
      user                   = [pscustomobject]@{ login=""; password="" }
    }
  }
}

# Pflichtblöcke absichern
if (-not $j.modrinth) { $j | Add-Member -NotePropertyName modrinth -NotePropertyValue ([pscustomobject]@{}) }
if (-not $j.modrinth.minecraft_versions) { $j.modrinth | Add-Member -NotePropertyName minecraft_versions -NotePropertyValue ([pscustomobject]@{}) }
if (-not $j.modrinth.loader) { $j.modrinth | Add-Member -NotePropertyName loader -NotePropertyValue ([pscustomobject]@{}) }

# instance_path setzen
$j.instance_path = (Get-Item -LiteralPath $Instance).FullName

# Loader fixieren
$j.modrinth.loader.mods         = 'fabric'
$j.modrinth.loader.resourcepacks= 'minecraft'
$j.modrinth.loader.shaders      = 'iris'

# CSV → Arrays
function CsvToArray([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return @() }
  return ($s -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

$rpList = CsvToArray $RP
$spList = CsvToArray $SP
$mdList = CsvToArray $Mods

# Arrays in Top-Level schreiben (nie null, nie ein langer String)
$j.resourcepacks = @($rpList)
$j.shaders      = @($spList)
$j.mods         = @($mdList)

# MC-Versionen
$j.modrinth.minecraft_versions.resourcepacks = @($McVersion)
$j.modrinth.minecraft_versions.shaders      = @($McVersion)

$wantModDeps = $false
if (-not [string]::IsNullOrWhiteSpace($RequestModDeps)) {
  $wantModDeps = ($RequestModDeps -match '^(?i:true|1|yes|on)$')
}

if ($mdList.Count -gt 0 -or $wantModDeps) {
  $j.modrinth.minecraft_versions.mods = @($McVersion)
} else {
  $j.modrinth.minecraft_versions.mods = @()
}

# request_dependencies: Array, nie null
if ($wantModDeps) {
  $j.modrinth.request_dependencies = @('required', '#optional')
} else {
  $j.modrinth.request_dependencies = @()
}

# JSON schreiben (Indent, wenn verfügbar)
$hasIndent = (Get-Command ConvertTo-Json).Parameters.ContainsKey('Indent')
$json = if ($hasIndent) { $j | ConvertTo-Json -Depth 12 -Indent 2 } else { $j | ConvertTo-Json -Depth 12 }
$json | Set-Content -LiteralPath $Config -Encoding UTF8
Write-Host "[OK] termmodrinth.json updated: $Config"
exit 0
