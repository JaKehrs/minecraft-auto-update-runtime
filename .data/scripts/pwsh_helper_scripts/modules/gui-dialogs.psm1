function Show-SelectionDialog {
    param (
        [string]$JsonPath,
        [ScriptBlock]$DebugLog = $null
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    function Log { param($msg); if ($DebugLog) { & $DebugLog $msg } }

    function Get-WindowsTheme {
        try {
            $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            $regName = "AppsUseLightTheme"
            $themeValue = Get-ItemProperty -Path $regKey | Select-Object -ExpandProperty $regName
            if ($themeValue -eq 0) { "Dark" } else { "Light" }
        } catch { "Light" }
    }

    if (!(Test-Path $JsonPath)) { Log "[ERROR] JSON nicht gefunden: $JsonPath"; return $null }

    $raw = Get-Content -Raw -Path $JsonPath | ConvertFrom-Json

    # Unterstützt alte Struktur (reine Liste) und neue (Defaults + Options)
    $defaultsRP = @()
    $defaultsSP = @()
    $options = @()

    if ($raw.PSObject.Properties.Name -contains 'Options') {
        $defaultsRP = @($raw.Defaults.Resourcepacks) | Where-Object { $_ } | Select-Object -Unique
        $defaultsSP = @($raw.Defaults.Shaderpacks)   | Where-Object { $_ } | Select-Object -Unique
        $options    = @($raw.Options)
    } else {
        # Fallback auf alte Struktur (dein bisheriges Array) – minimaler Support
        $options = @($raw)
    }

    if (-not $options -or $options.Count -eq 0) { Log "[ERROR] Keine Einträge gefunden."; return $null }

    $optionNames = $options | ForEach-Object { $_.OptionName }

    $theme = Get-WindowsTheme
    $backColor = [System.Drawing.SystemColors]::Window
    $foreColor = [System.Drawing.SystemColors]::WindowText
    if ($theme -eq "Dark") { $backColor = [System.Drawing.Color]::FromArgb(30,30,30); $foreColor = [System.Drawing.Color]::White }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Modpack-Auswahl"
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.Topmost = $true
    $form.AutoSize = $true
    $form.AutoSizeMode = 'GrowAndShrink'
    $form.BackColor = $backColor
    $form.ForeColor = $foreColor
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.KeyPreview = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Wähle ein Modpack zum Starten:"
    $label.MaximumSize = New-Object System.Drawing.Size(400, 0)
    $label.AutoSize = $true
    $label.BackColor = $form.BackColor
    $label.ForeColor = $form.ForeColor
    $form.Controls.Add($label)

    $radioButtons = @()
    foreach ($option in $optionNames) {
        $rb = New-Object System.Windows.Forms.RadioButton
        $rb.Text = $option
        $rb.AutoSize = $true
        $rb.BackColor = $form.BackColor
        $rb.ForeColor = $form.ForeColor
        $form.Controls.Add($rb)
        $radioButtons += $rb
    }
    if ($radioButtons.Count -gt 0) { $radioButtons[0].Checked = $true }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.AutoSize = $true
    $okButton.FlatStyle = 'Flat'
    $okButton.BackColor = if ($theme -eq "Dark") { [System.Drawing.Color]::FromArgb(50,50,50) } else { [System.Drawing.SystemColors]::Control }
    $okButton.ForeColor = $foreColor
    $form.Controls.Add($okButton)

    $okButton.Add_Click({
        $selected = $radioButtons | Where-Object { $_.Checked } | Select-Object -First 1
        if ($selected) { $form.Tag = $selected.Text; $form.Close() }
    })

    $form.Add_Shown({
        $paddingX = 40; $rightPadding = 50
        $maxTextWidth = ($radioButtons + $label | Measure-Object -Property Width -Maximum).Maximum
        $desiredWidth = $paddingX + $maxTextWidth + $rightPadding
        $form.MinimumSize = New-Object System.Drawing.Size($desiredWidth, 0)

        $label.Left = $paddingX; $label.Top = 20
        $topOffset = $label.Bottom + 20
        foreach ($rb in $radioButtons) { $rb.Left = $paddingX; $rb.Top = $topOffset; $topOffset += $rb.Height + 6 }
        $okButton.Top = $topOffset + 15
        $okButton.Left = ($form.ClientSize.Width - $okButton.Width) / 2
    })

    $form.ShowDialog() > $null
    $selectedText = $form.Tag
    if (-not $selectedText) { Log "[INFO] Keine Auswahl."; return $null }

    $selectedEntry = $options | Where-Object { $_.OptionName -eq $selectedText } | Select-Object -First 1
    if (-not $selectedEntry) { Log "[ERROR] Keine Übereinstimmung."; return $null }

    # Merge: Defaults vor Option, dann Dupe-Removal; extend/replace je Liste
    function Merge-List {
		param([string]$mode, [array]$defaults, [array]$overrides)

		if (-not $mode) { $mode = "extend" }

		$d = @($defaults | Where-Object { $_ })     # säubern
		$o = @($overrides | Where-Object { $_ })

		if ($mode -eq "replace") {
			,(@($o | Select-Object -Unique))
		} else {
			,(@($d + $o) | Select-Object -Unique)
		}
	}

    $rpMode = $selectedEntry.ResourcepacksMode
    $spMode = $selectedEntry.ShaderpacksMode
    $rpFinal = Merge-List -mode $rpMode -defaults $defaultsRP -overrides $selectedEntry.Resourcepacks
    $spFinal = Merge-List -mode $spMode -defaults $defaultsSP -overrides $selectedEntry.Shaderpacks

    # Bool mit Fallback (nur Option; kein Default nötig)
    $useMods = $false
    if ($selectedEntry.PSObject.Properties.Name -contains 'UseMods') { $useMods = [bool]$selectedEntry.UseMods }

    # InstallOverrides defensiv (Fallback true wie bisher bei dir)
    $installOverrides = $true
    if ($selectedEntry.PSObject.Properties.Name -contains 'InstallOverrides') { $installOverrides = [bool]$selectedEntry.InstallOverrides }

    return [PSCustomObject]@{
        OptionName            = $selectedEntry.OptionName
        ProfileName           = $selectedEntry.ProfileName
        ModpackID             = $selectedEntry.ModpackID
        InstallOverrides      = $installOverrides
        ResourcepacksFinal    = $rpFinal
        ShaderpacksFinal      = $spFinal
        UseMods               = $useMods
    }
}
