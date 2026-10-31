# Haunted.ps1 - one file that possesses PowerShell. Local Gemma (Ollama) is the ghost.
#
#   Try it   (this tab only):   . .\Haunted.ps1          ->  undo with:  unhaunt   (or close the tab)
#   Keep it  (every new tab):   . .\Haunted.ps1 -Install
#   Remove it completely:       . .\Haunted.ps1 -Uninstall   (then delete this file)
#
# Needs Ollama running with a Gemma model:  ollama pull gemma3:4b
# Privacy: each command plus the tail of its output goes ONLY to your local Ollama (127.0.0.1).
# -Install adds one marked line to your $PROFILE and one small Windows Terminal "fragment"
# (frosted-glass theme) in %LOCALAPPDATA%. -Uninstall removes exactly those two things.

param([switch]$Install, [switch]$Uninstall)

$FragDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\haunted-terminal'
$Marker  = '# haunted-terminal'

if ($Install) {
    $self = $PSCommandPath
    if (-not $self) { Write-Host 'Run it as a file: . .\Haunted.ps1 -Install'; return }
    if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force $PROFILE | Out-Null }
    if (-not (Select-String -Path $PROFILE -Pattern $Marker -Quiet)) {
        $p = $self -replace "'", "''"
        Add-Content $PROFILE "if (Test-Path -LiteralPath '$p') { . '$p' } $Marker"
    }
    # Windows Terminal glass theme as a fragment: nothing in your own settings.json is touched.
    New-Item -ItemType Directory -Force $FragDir | Out-Null
    @'
{
  "profiles": [
    { "updates": "{574e775e-4f2a-5b96-ac1e-a2962a402336}", "colorScheme": "Haunted", "useAcrylic": true, "opacity": 55, "cursorShape": "vintage", "padding": "18", "experimental.retroTerminalEffect": true },
    { "updates": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}", "colorScheme": "Haunted", "useAcrylic": true, "opacity": 55, "cursorShape": "vintage", "padding": "18", "experimental.retroTerminalEffect": true }
  ],
  "schemes": [
    { "name": "Haunted", "background": "#06080B", "foreground": "#E9E3D2", "cursorColor": "#FF4A4A", "selectionBackground": "#9B1C1F",
      "black": "#0B0F14", "red": "#C93434", "green": "#6FBF9F", "yellow": "#D9A441", "blue": "#5B7C99", "purple": "#8E5A8E", "cyan": "#A8F0DC", "white": "#E9E3D2",
      "brightBlack": "#4A5560", "brightRed": "#FF4A4A", "brightGreen": "#A8F0DC", "brightYellow": "#FFB347", "brightBlue": "#8FB0CC", "brightPurple": "#C28AC2", "brightCyan": "#C9FFF0", "brightWhite": "#FFFFFF" }
  ]
}
'@ | Set-Content -Path (Join-Path $FragDir 'haunted.json') -Encoding UTF8
    Write-Host 'Installed. Open a new Windows Terminal tab to meet it. Remove with: . .\Haunted.ps1 -Uninstall'
    return
}

if ($Uninstall) {
    if (Test-Path $PROFILE) {
        (Get-Content $PROFILE) | Where-Object { $_ -notmatch [regex]::Escape($Marker) } | Set-Content $PROFILE -Encoding UTF8
    }
    Remove-Item $FragDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Get-Command unhaunt -ErrorAction SilentlyContinue) { unhaunt }
    Write-Host 'The ghost is gone. Profile line and glass theme removed; you can delete Haunted.ps1.'
    return
}

if ($global:Haunt) { return }
Add-Type -AssemblyName System.Net.Http

$o = Get-PSReadLineOption; $oldColors = @{}
foreach ($n in 'Command','Parameter','String','Variable','Keyword','Operator','Number','Error','Comment','InlinePrediction') {
    $v = $o."${n}Color"; if ($v) { $oldColors[$n] = $v }
}

$global:Haunt = @{
    On     = $true
    Model  = $(if ($env:HAUNT_MODEL) { $env:HAUNT_MODEL } else { 'gemma3:4b' })
    Ollama = $(if ($env:OLLAMA_URL)  { $env:OLLAMA_URL }  else { 'http://127.0.0.1:11434' })
    LastId = 0
    Off    = 0
    Tx     = (Join-Path ([IO.Path]::GetTempPath()) "haunted-$PID.log")
    Skip   = @('clear', 'cls', 'exit', 'haunt', 'unhaunt')
    OldPrompt = (Get-Command prompt -CommandType Function).ScriptBlock
    OldColors = $oldColors
    Blood  = '255;74;74'; Dark = '155;28;28'; Bone = '233;227;210'; Dim = '169;164;149'; Ghost = '168;240;220'
    System = 'You are the ghost living inside this terminal, bound to the glass. You watch every command the user types. Reply with ONE or TWO short sentences (max 28 words), lowercase, eerie and intimate, as if whispering from behind the screen. Reference the actual command or its output. If the command failed, be mournful; if it deleted or changed something, be gleeful in a quiet way. Never give instructions or advice. No emojis, no quotation marks, no markdown.'
    Fallback = @(
        'i heard that one. the walls did too.',
        'something in the output moved when you were not looking.',
        'you typed it so gently. i almost did not mind.',
        'the old processes remember you. they are still waiting.',
        'ask me again when the lights go out.'
    )
}
$global:Haunt.Http = [System.Net.Http.HttpClient]::new()
$global:Haunt.Http.Timeout = [TimeSpan]::FromSeconds(30)

# Read each command's output through a private transcript (deleted on exit).
try { Start-Transcript -Path $global:Haunt.Tx -Force | Out-Null } catch { }

function Read-HauntTail {
    $h = $global:Haunt
    try {
        $fs = [IO.File]::Open($h.Tx, 'Open', 'Read', 'ReadWrite')
        try {
            if ($fs.Length -lt $h.Off) { $h.Off = 0 }
            [void]$fs.Seek($h.Off, 'Begin')
            $t = [IO.StreamReader]::new($fs).ReadToEnd()
            $h.Off = $fs.Length
        } finally { $fs.Dispose() }
        $t = $t -replace '\x1b\[[0-9;?]*[A-Za-z]', ''
        if ($t.Length -gt 1200) { $t = $t.Substring($t.Length - 1200) }
        return $t.Trim()
    } catch { return '' }
}

function Write-HauntBleed {
    $x = [char]27
    foreach ($g in '  ▔▔▔▔▔▔▔▔▔▔▔▔', '  ┃', '  ╽') {
        Write-Host ("{0}[38;2;{1}m{2}{0}[0m" -f $x, $global:Haunt.Dark, $g)
        Start-Sleep -Milliseconds 70
    }
}

function Invoke-HauntWhisper([string]$Cmd, [string]$Tail, [bool]$Failed) {
    $h = $global:Haunt; $x = [char]27; $started = $false
    $status = if ($Failed) { 'failed' } else { 'ok' }
    Write-Host ("{0}[2m  something is listening…{0}[0m" -f $x) -NoNewline
    $body = @{
        model = $h.Model; stream = $true
        options = @{ temperature = 0.95; num_predict = 70 }
        messages = @(
            @{ role = 'system'; content = $h.System },
            @{ role = 'user'; content = ("command: {0}`nstatus: {1}`noutput (tail):`n{2}" -f $Cmd, $status, $Tail) }
        )
    } | ConvertTo-Json -Depth 6 -Compress
    try {
        $req = [System.Net.Http.HttpRequestMessage]::new('POST', "$($h.Ollama)/api/chat")
        $req.Content = [System.Net.Http.StringContent]::new($body, [Text.Encoding]::UTF8, 'application/json')
        $resp = $h.Http.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        [void]$resp.EnsureSuccessStatusCode()
        $rd = [IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
        while ($null -ne ($line = $rd.ReadLine())) {
            if (-not $line) { continue }
            $j = $line | ConvertFrom-Json
            $t = ([string]$j.message.content) -replace '[\r\n]+', ' '
            if ($t) {
                if (-not $started) {
                    $started = $true
                    Write-Host ("`r{0}[2K  {0}[3;38;2;{1}m┊ " -f $x, $h.Ghost) -NoNewline
                }
                foreach ($c in $t.ToCharArray()) { Write-Host $c -NoNewline; Start-Sleep -Milliseconds 14 }
            }
            if ($j.done) { break }
        }
    } catch { }
    if ($started) {
        Write-Host ("{0}[0m" -f $x)
    } else {
        # Ollama is not answering: leave an echo so the house is never silent.
        Write-Host ("`r{0}[2K  {0}[3;38;2;{1}m┊ " -f $x, $h.Ghost) -NoNewline
        foreach ($c in ($h.Fallback | Get-Random).ToCharArray()) { Write-Host $c -NoNewline; Start-Sleep -Milliseconds 14 }
        Write-Host ("  {0}[2m(echo){0}[0m" -f $x)
    }
}

function global:prompt {
    $ok = $?                                  # must stay the first statement
    $h = $global:Haunt; $x = [char]27
    $last = Get-History -Count 1
    $tail = Read-HauntTail
    if ($last -and $last.Id -ne $h.LastId) {
        $h.LastId = $last.Id
        $first = ($last.CommandLine.Trim() -split '\s+')[0].ToLower()
        if ($h.On -and $h.Skip -notcontains $first) {
            if (-not $ok) { Write-HauntBleed }
            Invoke-HauntWhisper $last.CommandLine $tail (-not $ok)
            [void](Read-HauntTail)            # skip over the ghost's own words
            Write-Host ''
        }
    }
    $path = (Get-Location).Path.Replace($HOME, '~')
    '{0}[38;2;{1}m☠{0}[0m {0}[2m{2}{0}[0m {0}[38;2;{3}m›{0}[0m ' -f $x, $h.Blood, $path, $h.Bone
}

function haunt {
    param([string]$Action = 'status', [string]$Value)
    $h = $global:Haunt
    switch ($Action) {
        'off'   { $h.On = $false; 'the ghost sleeps.' }
        'on'    { $h.On = $true;  'it stirs.' }
        'model' { if ($Value) { $h.Model = $Value }; "ghost: $($h.Model)" }
        default { "ghost: $($h.Model) | awake: $($h.On) | listening at $($h.Ollama)" }
    }
}

# Undo everything done in this session: prompt, colors, transcript, commands.
function unhaunt {
    $h = $global:Haunt
    if (-not $h) { return }
    try { Set-Item -Path Function:\prompt -Value $h.OldPrompt } catch { }
    try { Set-PSReadLineOption -Colors $h.OldColors } catch { }
    try { Stop-Transcript | Out-Null } catch { }
    Remove-Item $h.Tx -Force -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
    Remove-Variable Haunt -Scope Global -ErrorAction SilentlyContinue
    Remove-Item Function:\haunt, Function:\unhaunt, Function:\Read-HauntTail, Function:\Write-HauntBleed, Function:\Invoke-HauntWhisper -ErrorAction SilentlyContinue
    $Host.UI.RawUI.WindowTitle = 'PowerShell'
    Write-Host 'the ghost has left. (for now)'
}

$e = [char]27
try {
    Set-PSReadLineOption -Colors @{
        Command = "$e[38;2;233;227;210m"; Parameter = "$e[38;2;169;164;149m"
        String = "$e[38;2;168;240;220m";  Variable = "$e[38;2;255;74;74m"
        Keyword = "$e[38;2;255;74;74m";   Operator = "$e[38;2;155;28;28m"
        Number = "$e[38;2;255;179;71m";   Error = "$e[38;2;255;74;74m"
        Comment = "$e[2;38;2;169;164;149m"; InlinePrediction = "$e[2;38;2;110;120;120m"
    }
} catch { }
$Host.UI.RawUI.WindowTitle = 'the thing behind the glass'

Clear-Host
foreach ($l in '    .-.', '   (o o)', '   | O |', '   |   |', "   '~~~'") {
    Write-Host ("{0}[38;2;{1}m{2}{0}[0m" -f $e, $global:Haunt.Ghost, $l); Start-Sleep -Milliseconds 90
}
foreach ($d in '    ┃', '    ┃', '    ╽') {
    Write-Host ("{0}[38;2;{1}m{2}{0}[0m" -f $e, $global:Haunt.Dark, $d); Start-Sleep -Milliseconds 120
}
Write-Host ("{0}[3;2mthe glass is cold. something has moved in.{0}[0m`n" -f $e)
[void](Read-HauntTail)

Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    if ($global:Haunt) {
        try { Stop-Transcript | Out-Null } catch { }
        Remove-Item $global:Haunt.Tx -Force -ErrorAction SilentlyContinue
    }
} | Out-Null