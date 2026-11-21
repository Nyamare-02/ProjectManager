Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Konfiguration & Persistenz ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$configFile = Join-Path $scriptDir "config.json"

function Get-Config {
    if (Test-Path $configFile) {
        $loaded = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        $normalizedGenres = @()
        foreach ($item in $loaded.Genres) {
            if ($item -is [string]) {
                $normalizedGenres += [PSCustomObject]@{
                    Name      = $item
                    SubGenres = @()
                }
            }
            else {
                $subs = if ($null -ne $item.SubGenres) { @($item.SubGenres) } else { @() }
                $normalizedGenres += [PSCustomObject]@{
                    Name      = $item.Name
                    SubGenres = $subs
                }
            }
        }

        $isDark = if ($null -ne $loaded.DarkMode) { [bool]$loaded.DarkMode } else { $false }

        return [PSCustomObject]@{
            LastPath = if ($loaded.LastPath) { $loaded.LastPath } else { [Environment]::GetFolderPath("Desktop") }
            DarkMode = $isDark
            Genres   = $normalizedGenres
        }
    }

    return [PSCustomObject]@{
        LastPath = [Environment]::GetFolderPath("Desktop")
        DarkMode = $true
        Genres   = @(
            [PSCustomObject]@{ Name = "Anime"; SubGenres = @("Cyberpunk", "Fantasy") },
            [PSCustomObject]@{ Name = "Fotorealismus"; SubGenres = @() },
            [PSCustomObject]@{ Name = "Sci-Fi"; SubGenres = @() },
            [PSCustomObject]@{ Name = "Fantasy"; SubGenres = @() },
            [PSCustomObject]@{ Name = "Concept Art"; SubGenres = @() }
        )
    }
}

function Save-Config($config) {
    $config | ConvertTo-Json -Depth 4 | Set-Content $configFile -Encoding UTF8
}

function Test-ValidFolderName([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    return ($name -notmatch "[$([RegEx]::Escape($invalidChars))]")
}

# --- Theme-Engine (Light / Dark) ---
function Get-ThemeColors([bool]$dark) {
    if ($dark) {
        return @{
            FormBg       = [System.Drawing.Color]::FromArgb(30, 30, 34)
            ControlBg    = [System.Drawing.Color]::FromArgb(45, 45, 52)
            ButtonBg     = [System.Drawing.Color]::FromArgb(55, 55, 64)
            CreateBg     = [System.Drawing.Color]::FromArgb(35, 85, 50)
            Border       = [System.Drawing.Color]::FromArgb(80, 80, 92)
            Text         = [System.Drawing.Color]::FromArgb(238, 238, 242)
            TreeLine     = [System.Drawing.Color]::FromArgb(130, 130, 145)
        }
    }
    else {
        return @{
            FormBg       = [System.Drawing.SystemColors]::Control
            ControlBg    = [System.Drawing.Color]::White
            ButtonBg     = [System.Drawing.Color]::FromArgb(242, 242, 245)
            CreateBg     = [System.Drawing.Color]::FromArgb(215, 240, 220)
            Border       = [System.Drawing.Color]::FromArgb(180, 180, 185)
            Text         = [System.Drawing.Color]::FromArgb(20, 20, 24)
            TreeLine     = [System.Drawing.Color]::Gray
        }
    }
}

function Set-ControlTheme($ctrl, $theme) {
    if ($ctrl -is [System.Windows.Forms.Form]) {
        $ctrl.BackColor = $theme.FormBg
        $ctrl.ForeColor = $theme.Text
    }
    elseif ($ctrl -is [System.Windows.Forms.Label]) {
        $ctrl.ForeColor = $theme.Text
    }
    elseif ($ctrl -is [System.Windows.Forms.TextBox] -or $ctrl -is [System.Windows.Forms.ListBox]) {
        $ctrl.BackColor = $theme.ControlBg
        $ctrl.ForeColor = $theme.Text
        $ctrl.BorderStyle = "FixedSingle"
    }
    elseif ($ctrl -is [System.Windows.Forms.TreeView]) {
        $ctrl.BackColor = $theme.ControlBg
        $ctrl.ForeColor = $theme.Text
        $ctrl.LineColor = $theme.TreeLine
        $ctrl.BorderStyle = "FixedSingle"
    }
    elseif ($ctrl -is [System.Windows.Forms.Button]) {
        $ctrl.FlatStyle = "Flat"
        $ctrl.FlatAppearance.BorderColor = $theme.Border
        $ctrl.FlatAppearance.BorderSize = 1
        $ctrl.ForeColor = $theme.Text
        if ($ctrl.Tag -eq "CreateButton") {
            $ctrl.BackColor = $theme.CreateBg
        }
        else {
            $ctrl.BackColor = $theme.ButtonBg
        }
    }

    foreach ($child in $ctrl.Controls) {
        Set-ControlTheme $child $theme
    }
}

$config = Get-Config

# --- Hauptfenster ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "KI-Projekt Generator"
$form.Size = New-Object System.Drawing.Size(580, 430)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# --- Linke Seite: Eingaben & Buttons ---
$lblProjekt = New-Object System.Windows.Forms.Label
$lblProjekt.Text = "Projektname:"
$lblProjekt.Location = New-Object System.Drawing.Point(20, 20)
$lblProjekt.AutoSize = $true
$form.Controls.Add($lblProjekt)

$txtProjekt = New-Object System.Windows.Forms.TextBox
$txtProjekt.Location = New-Object System.Drawing.Point(20, 45)
$txtProjekt.Size = New-Object System.Drawing.Size(250, 28)
$form.Controls.Add($txtProjekt)

$lblPfad = New-Object System.Windows.Forms.Label
$lblPfad.Text = "Zielpfad:"
$lblPfad.Location = New-Object System.Drawing.Point(20, 85)
$lblPfad.AutoSize = $true
$form.Controls.Add($lblPfad)

$txtPfad = New-Object System.Windows.Forms.TextBox
$txtPfad.Text = $config.LastPath
$txtPfad.Location = New-Object System.Drawing.Point(20, 110)
$txtPfad.Size = New-Object System.Drawing.Size(210, 28)
$form.Controls.Add($txtPfad)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "..."
$btnBrowse.Location = New-Object System.Drawing.Point(235, 109)
$btnBrowse.Size = New-Object System.Drawing.Size(35, 27)
$form.Controls.Add($btnBrowse)

$btnManage = New-Object System.Windows.Forms.Button
$btnManage.Text = "Genres`nverwalten"
$btnManage.Location = New-Object System.Drawing.Point(20, 155)
$btnManage.Size = New-Object System.Drawing.Size(120, 50)
$form.Controls.Add($btnManage)

$btnCreate = New-Object System.Windows.Forms.Button
$btnCreate.Text = "Projekt`nerstellen"
$btnCreate.Tag = "CreateButton"
$btnCreate.Location = New-Object System.Drawing.Point(150, 155)
$btnCreate.Size = New-Object System.Drawing.Size(120, 50)
$form.Controls.Add($btnCreate)

# Dark-Mode Umschalter unten links
$btnTheme = New-Object System.Windows.Forms.Button
$btnTheme.Location = New-Object System.Drawing.Point(20, 330)
$btnTheme.Size = New-Object System.Drawing.Size(250, 35)
$form.Controls.Add($btnTheme)

function Update-MainTheme {
    $theme = Get-ThemeColors $config.DarkMode
    Set-ControlTheme $form $theme
    $btnTheme.Text = if ($config.DarkMode) { "☀️ Light Mode aktivieren" } else { "🌙 Dark Mode aktivieren" }
}

$btnTheme.Add_Click({
    $config.DarkMode = -not $config.DarkMode
    Save-Config $config
    Update-MainTheme
})

# --- Rechte Seite: Genre- & Sub-Genre-Baum ---
$lblGenres = New-Object System.Windows.Forms.Label
$lblGenres.Text = "Genres & Sub-Genres auswählen:"
$lblGenres.Location = New-Object System.Drawing.Point(295, 20)
$lblGenres.AutoSize = $true
$form.Controls.Add($lblGenres)

$treeGenres = New-Object System.Windows.Forms.TreeView
$treeGenres.Location = New-Object System.Drawing.Point(295, 45)
$treeGenres.Size = New-Object System.Drawing.Size(250, 320)
$treeGenres.CheckBoxes = $true
$form.Controls.Add($treeGenres)

function Update-GenreTree {
    $treeGenres.Nodes.Clear()
    foreach ($g in $config.Genres) {
        $parentNode = New-Object System.Windows.Forms.TreeNode($g.Name)
        foreach ($sub in $g.SubGenres) {
            $childNode = New-Object System.Windows.Forms.TreeNode($sub)
            [void]$parentNode.Nodes.Add($childNode)
        }
        [void]$treeGenres.Nodes.Add($parentNode)
    }
    $treeGenres.ExpandAll()
}
Update-GenreTree

$script:isUpdatingTree = $false
$treeGenres.Add_AfterCheck({
    param($eventSender, $e)
    if ($script:isUpdatingTree) { return }
    $script:isUpdatingTree = $true
    try {
        if ($null -eq $e.Node.Parent) {
            foreach ($child in $e.Node.Nodes) {
                $child.Checked = $e.Node.Checked
            }
        }
        elseif ($e.Node.Checked -and -not $e.Node.Parent.Checked) {
            $e.Node.Parent.Checked = $true
        }
    }
    finally {
        $script:isUpdatingTree = $false
    }
})

# --- Events ---
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $txtPfad.Text
    if ($dialog.ShowDialog() -eq "OK") {
        $txtPfad.Text = $dialog.SelectedPath
    }
})

# Unterfenster zum Hinzufügen/Löschen von Genres & Sub-Genres
$btnManage.Add_Click({
    $subForm = New-Object System.Windows.Forms.Form
    $subForm.Text = "Genres & Sub-Genres verwalten"
    $subForm.Size = New-Object System.Drawing.Size(620, 365)
    $subForm.StartPosition = "CenterParent"
    $subForm.FormBorderStyle = "FixedDialog"
    $subForm.MaximizeBox = $false
    $subForm.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

    $workingList = New-Object System.Collections.ArrayList
    foreach ($g in $config.Genres) {
        [void]$workingList.Add([PSCustomObject]@{
            Name      = $g.Name
            SubGenres = [System.Collections.ArrayList]@($g.SubGenres)
        })
    }

    # --- Linke Seite: Haupt-Genres ---
    $lblMain = New-Object System.Windows.Forms.Label
    $lblMain.Text = "Haupt-Genres:"
    $lblMain.Location = New-Object System.Drawing.Point(15, 12)
    $lblMain.AutoSize = $true
    $subForm.Controls.Add($lblMain)

    $listBoxMain = New-Object System.Windows.Forms.ListBox
    $listBoxMain.Location = New-Object System.Drawing.Point(15, 35)
    $listBoxMain.Size = New-Object System.Drawing.Size(275, 185)
    $subForm.Controls.Add($listBoxMain)

    $txtNewGenre = New-Object System.Windows.Forms.TextBox
    $txtNewGenre.Location = New-Object System.Drawing.Point(15, 230)
    $txtNewGenre.Size = New-Object System.Drawing.Size(185, 25)
    $subForm.Controls.Add($txtNewGenre)

    $btnAddMain = New-Object System.Windows.Forms.Button
    $btnAddMain.Text = "Hinzufügen"
    $btnAddMain.Location = New-Object System.Drawing.Point(205, 229)
    $btnAddMain.Size = New-Object System.Drawing.Size(85, 26)
    $subForm.Controls.Add($btnAddMain)

    $btnDelMain = New-Object System.Windows.Forms.Button
    $btnDelMain.Text = "Markiertes Genre löschen"
    $btnDelMain.Location = New-Object System.Drawing.Point(15, 268)
    $btnDelMain.Size = New-Object System.Drawing.Size(275, 32)
    $subForm.Controls.Add($btnDelMain)

    # --- Rechte Seite: Sub-Genres ---
    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Sub-Genres (Unterordner):"
    $lblSub.Location = New-Object System.Drawing.Point(310, 12)
    $lblSub.AutoSize = $true
    $subForm.Controls.Add($lblSub)

    $listBoxSub = New-Object System.Windows.Forms.ListBox
    $listBoxSub.Location = New-Object System.Drawing.Point(310, 35)
    $listBoxSub.Size = New-Object System.Drawing.Size(275, 185)
    $subForm.Controls.Add($listBoxSub)

    $txtNewSub = New-Object System.Windows.Forms.TextBox
    $txtNewSub.Location = New-Object System.Drawing.Point(310, 230)
    $txtNewSub.Size = New-Object System.Drawing.Size(185, 25)
    $txtNewSub.Enabled = $false
    $subForm.Controls.Add($txtNewSub)

    $btnAddSub = New-Object System.Windows.Forms.Button
    $btnAddSub.Text = "Hinzufügen"
    $btnAddSub.Location = New-Object System.Drawing.Point(500, 229)
    $btnAddSub.Size = New-Object System.Drawing.Size(85, 26)
    $btnAddSub.Enabled = $false
    $subForm.Controls.Add($btnAddSub)

    $btnDelSub = New-Object System.Windows.Forms.Button
    $btnDelSub.Text = "Markiertes Sub-Genre löschen"
    $btnDelSub.Location = New-Object System.Drawing.Point(310, 268)
    $btnDelSub.Size = New-Object System.Drawing.Size(275, 32)
    $btnDelSub.Enabled = $false
    $subForm.Controls.Add($btnDelSub)

    function Update-MainUI {
        $listBoxMain.Items.Clear()
        foreach ($entry in $workingList) {
            [void]$listBoxMain.Items.Add($entry.Name)
        }
        if ($listBoxMain.Items.Count -gt 0) {
            $listBoxMain.SelectedIndex = 0
        }
    }

    function Update-SubUI {
        $listBoxSub.Items.Clear()
        $idx = $listBoxMain.SelectedIndex
        if ($idx -ge 0 -and $idx -lt $workingList.Count) {
            $selectedObj = $workingList[$idx]
            $lblSub.Text = "Sub-Genres für '$($selectedObj.Name)':"
            $txtNewSub.Enabled = $true
            $btnAddSub.Enabled = $true
            $btnDelSub.Enabled = $true
            foreach ($s in $selectedObj.SubGenres) {
                [void]$listBoxSub.Items.Add($s)
            }
        }
        else {
            $lblSub.Text = "Sub-Genres (bitte Genre wählen):"
            $txtNewSub.Enabled = $false
            $btnAddSub.Enabled = $false
            $btnDelSub.Enabled = $false
        }
    }

    $listBoxMain.Add_SelectedIndexChanged({ Update-SubUI })

    $btnAddMain.Add_Click({
        $val = $txtNewGenre.Text.Trim()
        if (-not (Test-ValidFolderName $val)) {
            [System.Windows.Forms.MessageBox]::Show("Bitte einen gültigen Ordnernamen ohne Sonderzeichen (\ / : * ? `" < > |) eingeben.", "Hinweis", "OK", "Warning")
            return
        }
        if ($listBoxMain.Items -notcontains $val) {
            [void]$workingList.Add([PSCustomObject]@{
                Name      = $val
                SubGenres = New-Object System.Collections.ArrayList
            })
            Update-MainUI
            $listBoxMain.SelectedIndex = $listBoxMain.Items.Count - 1
            $txtNewGenre.Clear()
        }
    })

    $btnDelMain.Add_Click({
        $idx = $listBoxMain.SelectedIndex
        if ($idx -ge 0) {
            $workingList.RemoveAt($idx)
            Update-MainUI
            Update-SubUI
        }
    })

    $btnAddSub.Add_Click({
        $mainIdx = $listBoxMain.SelectedIndex
        $val = $txtNewSub.Text.Trim()
        if ($mainIdx -lt 0) { return }
        if (-not (Test-ValidFolderName $val)) {
            [System.Windows.Forms.MessageBox]::Show("Bitte einen gültigen Ordnernamen ohne Sonderzeichen (\ / : * ? `" < > |) eingeben.", "Hinweis", "OK", "Warning")
            return
        }
        $subList = $workingList[$mainIdx].SubGenres
        if ($subList -notcontains $val) {
            [void]$subList.Add($val)
            Update-SubUI
            $txtNewSub.Clear()
        }
    })

    $btnDelSub.Add_Click({
        $mainIdx = $listBoxMain.SelectedIndex
        $subIdx = $listBoxSub.SelectedIndex
        if ($mainIdx -ge 0 -and $subIdx -ge 0) {
            $workingList[$mainIdx].SubGenres.RemoveAt($subIdx)
            Update-SubUI
        }
    })

    $subForm.Add_FormClosing({
        $finalGenres = @()
        foreach ($entry in $workingList) {
            $finalGenres += [PSCustomObject]@{
                Name      = $entry.Name
                SubGenres = @($entry.SubGenres)
            }
        }
        $config.Genres = $finalGenres
        Save-Config $config
        Update-GenreTree
    })

    Set-ControlTheme $subForm (Get-ThemeColors $config.DarkMode)

    Update-MainUI
    Update-SubUI
    [void]$subForm.ShowDialog()
})

# Ordnerstruktur erstellen
$btnCreate.Add_Click({
    $projektName = $txtProjekt.Text.Trim()
    $basisPfad = $txtPfad.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($projektName)) {
        [System.Windows.Forms.MessageBox]::Show("Bitte einen Projektnamen eingeben.", "Fehler", "OK", "Warning")
        return
    }

    if (-not (Test-Path $basisPfad)) {
        [System.Windows.Forms.MessageBox]::Show("Der angegebene Zielpfad existiert nicht.", "Fehler", "OK", "Error")
        return
    }

    if (-not (Test-ValidFolderName $projektName)) {
        [System.Windows.Forms.MessageBox]::Show("Der Projektname enthält ungültige Zeichen (\ / : * ? `" < > |).", "Fehler", "OK", "Warning")
        return
    }

    $projektPfad = Join-Path $basisPfad $projektName

    try {
        New-Item -ItemType Directory -Path $projektPfad -Force | Out-Null

        foreach ($parentNode in $treeGenres.Nodes) {
            $checkedSubNodes = @($parentNode.Nodes | Where-Object { $_.Checked })

            if ($parentNode.Checked -or $checkedSubNodes.Count -gt 0) {
                $genrePfad = Join-Path $projektPfad $parentNode.Text
                New-Item -ItemType Directory -Path $genrePfad -Force | Out-Null

                foreach ($subNode in $checkedSubNodes) {
                    $subPfad = Join-Path $genrePfad $subNode.Text
                    New-Item -ItemType Directory -Path $subPfad -Force | Out-Null
                }
            }
        }

        $config.LastPath = $basisPfad
        Save-Config $config

        [System.Windows.Forms.MessageBox]::Show("Projektordner erfolgreich angelegt:`n$projektPfad", "Fertig", "OK", "Information")
        $txtProjekt.Clear()
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Fehler beim Erstellen: $_", "Fehler", "OK", "Error")
    }
})

Update-MainTheme
[void]$form.ShowDialog()