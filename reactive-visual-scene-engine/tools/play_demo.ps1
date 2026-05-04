# play_demo.ps1
# Synced audio + visual demo helper for the Reactive Visual Scene Engine.
#
# This is the ONLY interface you need at runtime -- forget the Vitis
# Serial Terminal. The script:
#   1. Auto-detects the Zybo's FTDI USB serial port.
#   2. Streams FPGA UART output into this PowerShell window.
#   3. Waits for the FPGA to print [READY] before letting you press ENTER.
#   4. On ENTER, sends 'G' to the FPGA AND starts MP3 playback in the
#      same instant (sync: ~10-50 ms).
#   5. Forwards your keystrokes to the FPGA so you can drive the menu
#      (1-6, h, s, G) without leaving this window.
#   6. On Ctrl-C, sends 's' to silence the FPGA (BRAM zeroed, visuals
#      collapse to baseline), then stops the audio player and closes
#      the port.
#
# Prereqs:
#   - FPGA programmed and Vitis app launched (no need to open the
#     Vitis Serial Terminal -- close it if it's open, this script
#     needs the COM port exclusively).
#   - data\song.mp3 exists.
#
# Usage:
#   PS> cd C:\Users\khuon\ECE520\final_project\reactive-visual-scene-engine
#   PS> .\tools\play_demo.ps1
#   PS> .\tools\play_demo.ps1 -ComPort COM7
#   PS> .\tools\play_demo.ps1 -SongPath data\other.mp3

param(
    [string]$ComPort  = "",
    [string]$SongPath = "data\song.mp3",
    [int]   $BaudRate = 115200
)

# ---- Resolve song ----------------------------------------------------------
$resolved = Resolve-Path $SongPath -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "ERROR: $SongPath not found" -ForegroundColor Red
    Write-Host "  cd into the repo root, or pass -SongPath data\song.mp3"
    exit 1
}
$songFull = $resolved.Path
Write-Host "Song : $songFull"

# ---- Auto-detect FTDI COM port --------------------------------------------
if (-not $ComPort) {
    $usb = Get-PnpDevice -Class Ports -Status OK -ErrorAction SilentlyContinue |
           Where-Object {
               $_.InstanceId -match 'FTDIBUS|VID_0403' -and
               $_.FriendlyName -notmatch 'Bluetooth'
           }
    if (-not $usb) {
        Write-Host "ERROR: no FTDI USB Serial Port found." -ForegroundColor Red
        Write-Host "  Is the Zybo plugged in via USB and powered on?"
        exit 1
    }
    $match = [regex]::Match($usb[0].FriendlyName, 'COM(\d+)')
    if (-not $match.Success) {
        Write-Host "ERROR: couldn't parse COM port from '$($usb[0].FriendlyName)'" -ForegroundColor Red
        exit 1
    }
    $ComPort = "COM" + $match.Groups[1].Value
    Write-Host "COM  : $ComPort  (auto-detected as Zybo FTDI UART)"
} else {
    Write-Host "COM  : $ComPort"
}

# ---- Open the serial port -------------------------------------------------
try {
    $serial = New-Object System.IO.Ports.SerialPort $ComPort, $BaudRate, 'None', 8, 'One'
    $serial.NewLine     = "`r`n"
    $serial.ReadTimeout  = 50
    $serial.WriteTimeout = 1000
    $serial.Open()
} catch {
    Write-Host "ERROR: could not open $ComPort -- $_" -ForegroundColor Red
    Write-Host "  Close any other program holding the port (Vitis Serial Terminal, PuTTY, etc.)"
    exit 1
}

# ---- Pre-load the MP3 player without playing yet --------------------------
Add-Type -AssemblyName PresentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$player.Open([uri]$songFull)
Start-Sleep -Milliseconds 500   # give WPF time to parse media metadata

# ---- Bidirectional terminal core ------------------------------------------
# Helper: drain UART -> stdout, return everything we read so callers can
# pattern-match against it.
function Drain-Uart([System.IO.Ports.SerialPort]$port) {
    if ($port.BytesToRead -gt 0) {
        try {
            $chunk = $port.ReadExisting()
            Write-Host -NoNewline $chunk
            return $chunk
        } catch { return "" }
    }
    return ""
}

Write-Host ""
Write-Host "================ FPGA UART ================" -ForegroundColor Cyan

# ---- Wait until FPGA prints [READY] (or settles for 1.5 s) ---------------
# Catches both fresh boot (will print [READY] when ready) and re-runs
# (FPGA may already be at the menu prompt with no new output).
$buffer       = ""
$ready        = $false
$lastActivity = Get-Date
$startTime    = Get-Date
Write-Host "Waiting for FPGA to be ready..." -ForegroundColor Yellow
while (-not $ready) {
    $chunk = Drain-Uart $serial
    if ($chunk.Length -gt 0) {
        $buffer       += $chunk
        $lastActivity  = Get-Date
        if ($buffer -match '\[READY\]') {
            $ready = $true
        }
    } else {
        # Settle path: ~1.5 s of UART silence after at least 1 s elapsed
        $idleMs    = ((Get-Date) - $lastActivity).TotalMilliseconds
        $elapsedMs = ((Get-Date) - $startTime).TotalMilliseconds
        if ($elapsedMs -gt 1000 -and $idleMs -gt 1500) {
            $ready = $true
        }
        Start-Sleep -Milliseconds 50
    }
}

Write-Host ""
Write-Host "[FPGA READY -- press ENTER to fire GO + audio. Ctrl-C to stop.]" -ForegroundColor Green

# ---- Wait for ENTER (still draining UART meanwhile) -----------------------
$go = $false
while (-not $go) {
    Drain-Uart $serial | Out-Null
    if ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Enter') { $go = $true }
    }
    Start-Sleep -Milliseconds 30
}

# ---- The simultaneous fire -------------------------------------------------
$serial.Write([byte[]](0x47), 0, 1)   # 'G'
$player.Play()

Write-Host ""
Write-Host "[GO sent + audio playing. Type menu commands here. Ctrl-C to stop.]" -ForegroundColor Green
Write-Host ""

# ---- Main interactive loop -------------------------------------------------
try {
    while ($true) {
        Drain-Uart $serial | Out-Null

        # Forward keystrokes to FPGA (with local echo of printable chars).
        while ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            $c = $k.KeyChar
            if ([int]$c -ge 32 -and [int]$c -lt 127) {
                Write-Host -NoNewline $c
                $serial.Write([string]$c)
            }
            # ENTER, arrow keys, etc. ignored; the FPGA menu is single-char.
        }

        # Loop the song when it ends so visuals + audio keep cycling.
        if ($player.NaturalDuration.HasTimeSpan -and
            $player.Position -ge $player.NaturalDuration.TimeSpan) {
            $player.Position = [TimeSpan]::Zero
            $player.Play()
        }

        Start-Sleep -Milliseconds 30
    }
} finally {
    Write-Host ""
    Write-Host "[exit] sending 's' to silence FPGA BRAM..." -ForegroundColor Yellow
    try { $serial.Write([string][char]'s') } catch { }
    Start-Sleep -Milliseconds 300
    try {
        if ($serial.BytesToRead -gt 0) {
            Write-Host -NoNewline ($serial.ReadExisting())
        }
    } catch { }
    Write-Host ""
    Write-Host "[exit] stopping audio + closing port" -ForegroundColor Yellow
    $player.Stop()
    $player.Close()
    if ($serial.IsOpen) { $serial.Close() }
}
