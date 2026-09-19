# X PRIME OPTIMIZATION SCRIPTS
# Simple menu-driven PowerShell optimizer
# Run as Administrator.

$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# ---------------- ADMIN ----------------
function Ensure-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)

    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host ""
        Write-Host "X PRIME requires Administrator privileges." -ForegroundColor Yellow
        Write-Host "Requesting Administrator access..." -ForegroundColor Yellow
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
}
Ensure-Admin

# ---------------- LOGGING ----------------
$LogRoot = "$env:ProgramData\XPrime\Logs"
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$LogFile = Join-Path $LogRoot ("XPrime_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Log {
    param([string]$Text)
    Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Text)
}

function Pause-XP {
    Write-Host ""
    Read-Host "Press ENTER to return to the main menu" | Out-Null
}

function Header {
    Clear-Host
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host "                 X PRIME OPTIMIZATION SCRIPTS" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host ""
}

function Step {
    param([string]$Text)
    Write-Host "  > $Text" -ForegroundColor Gray
    Log $Text
}

function OK {
    param([string]$Text)
    Write-Host "    [OK] $Text" -ForegroundColor Green
    Log "OK: $Text"
}

function Warn {
    param([string]$Text)
    Write-Host "    [!] $Text" -ForegroundColor Yellow
    Log "WARN: $Text"
}

function Set-Reg {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        return $true
    }
    catch {
        Warn "Could not set $Path\$Name"
        return $false
    }
}

function Stop-DisableService {
    param([string]$Name)

    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop

        if ($svc.Status -ne "Stopped") {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }

        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        OK "$Name stopped and disabled"
    }
    catch {
        Warn "$Name was not found or could not be changed"
    }
}

# ---------------- MODULE 0 ----------------
function Restore-Point {
    Header
    Write-Host "0 - RESTORE POINT" -ForegroundColor White
    Write-Host ""

    Step "Enabling System Protection on C:"
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        OK "System Protection enabled/requested"
    } catch {
        Warn "Could not enable System Protection"
    }

    Step "Setting C: shadow storage maximum to 10%"
    try {
        & vssadmin.exe Resize ShadowStorage /For=C: /On=C: /MaxSize=10% | Out-Null
        OK "Shadow storage limit set to 10%"
    } catch {
        Warn "Could not set shadow storage limit"
    }

    Step "Creating restore point"
    try {
        Checkpoint-Computer -Description "X PRIME Optimization" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        OK "Restore point created"
    } catch {
        Warn "Restore point could not be created. Windows may limit restore points to once per 24 hours."
    }

    Pause-XP
}

# ---------------- MODULE 1 ----------------
function System-Cleanup {
    Header
    Write-Host "1 - SYSTEM CLEANUP" -ForegroundColor White
    Write-Host ""

    $paths = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\SoftwareDistribution\Download\*"
    )

    foreach ($path in $paths) {
        Step "Cleaning $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        OK "Cleanup completed"
    }

    Step "Running Windows Disk Cleanup"
    Start-Process cleanmgr.exe -ArgumentList "/VERYLOWDISK" -Wait -WindowStyle Hidden
    OK "Disk Cleanup completed"

    Step "Optimizing C: drive"
    try {
        Optimize-Volume -DriveLetter C -ErrorAction Stop | Out-Null
        OK "C: drive optimization completed"
    } catch {
        Warn "C: drive optimization could not be completed"
    }

    Pause-XP
}

# ---------------- MODULE 2 ----------------
function Settings-Optimization {
    Header
    Write-Host "2 - SETTINGS OPTIMIZATION" -ForegroundColor White
    Write-Host ""

    Step "Turning off blurry-app fixing"
    Set-Reg "HKCU:\Control Panel\Desktop" "EnablePerProcessSystemDPI" 0 | Out-Null

    Step "Turning off System notifications"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0 | Out-Null

    Step "Turning off Storage Sense"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0 | Out-Null

    Step "Turning off Timeline / Activity History"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 | Out-Null

    Step "Removing Internet Explorer optional feature"
    Disable-WindowsOptionalFeature -Online -FeatureName Internet-Explorer-Optional-amd64 -NoRestart | Out-Null

    Step "Turning on Dark Mode"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0 | Out-Null

    Step "Turning off Transparency Effects"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 | Out-Null

    Step "Turning off Privacy > General personalization"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338393Enabled" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" 0 | Out-Null

    Step "Turning off inking and typing personalization"
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1 | Out-Null

    Step "Setting Diagnostics and Feedback to Required"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1 | Out-Null

    Step "Turning off activity history storage"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 | Out-Null

    Step "Turning off Windows location"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableWindowsLocationProvider" 1 | Out-Null

    Step "Turning off privacy notification access"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessNotifications" 2 | Out-Null

    Step "Turning off radio access"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessRadios" 2 | Out-Null

    Step "Turning off app diagnostics access"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsGetDiagnosticInfo" 2 | Out-Null

    OK "Settings optimization applied"
    Pause-XP
}

# ---------------- MODULE 3 ----------------
function Increase-Responsiveness {
    Header
    Write-Host "3 - INCREASE RESPONSIVENESS" -ForegroundColor White
    Write-Host ""

    Step "Configuring Windows visual effects"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3 | Out-Null

    # Keep thumbnails instead of icons.
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0 | Out-Null

    # Keep smooth edges of screen fonts.
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothingType" 2 | Out-Null

    # Disable common animations.
    Set-Reg "HKCU:\Control Panel\Desktop" "MinAnimate" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0 | Out-Null

    OK "Responsiveness settings applied"
    Pause-XP
}

# ---------------- MODULE 4 ----------------
function Gaming-Booster {
    Header
    Write-Host "4 - GAMING BOOSTER" -ForegroundColor White
    Write-Host ""

    Step "Turning off Game Bar / Game DVR recording"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 | Out-Null
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0 | Out-Null

    Step "Turning on Game Mode"
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1 | Out-Null

    Step "Turning on Hardware-Accelerated GPU Scheduling"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2 | Out-Null

    Step "Turning off Variable Refresh Rate"
    Set-Reg "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimizeEnable=0;" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null

    OK "Gaming Booster applied"
    Pause-XP
}

# ---------------- MODULE 5 ----------------
function Network-Optimization {
    Header
    Write-Host "5 - NETWORK OPTIMIZATION" -ForegroundColor White
    Write-Host ""

    Step "Disabling IPv6 on active physical adapters"

    try {
        $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

        foreach ($adapter in $adapters) {
            Disable-NetAdapterBinding -Name $adapter.Name -ComponentID "ms_tcpip6" -ErrorAction SilentlyContinue
            OK "IPv6 disabled: $($adapter.Name)"
        }
    } catch {
        Warn "Could not modify one or more network adapters"
    }

    Pause-XP
}

# ---------------- MODULE 6 ----------------
function Latency-Removal {
    Header
    Write-Host "6 - LATENCY REMOVAL" -ForegroundColor White
    Write-Host ""

    Step "Turning off Enhance Pointer Precision"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null

    Step "Setting mouse pointer speed to 0"
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSensitivity" "1" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null

    OK "Mouse latency settings applied"
    Pause-XP
}

# ---------------- MODULE 7 ----------------
function Services-Optimization {
    Header
    Write-Host "7 - SERVICES OPTIMIZATION" -ForegroundColor White
    Write-Host ""

    Stop-DisableService "Spooler"
    Stop-DisableService "WSearch"
    Stop-DisableService "SysMain"
    Stop-DisableService "DiagTrack"
    Stop-DisableService "lfsvc"

    Pause-XP
}

# ---------------- MODULE 8 ----------------
function Background-Apps {
    Header
    Write-Host "8 - BACKGROUND APPS" -ForegroundColor White
    Write-Host ""

    Step "Restricting Windows background app execution"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1 | Out-Null

    OK "Background apps restricted"
    Pause-XP
}

# ---------------- MODULE 9 ----------------
function Fullscreen-Optimization {
    Header
    Write-Host "9 - FULL SCREEN OPTIMIZATION" -ForegroundColor White
    Write-Host ""

    Step "Disabling Windows Fullscreen Optimizations"
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2 | Out-Null
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 2 | Out-Null
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1 | Out-Null

    OK "Fullscreen optimization settings applied"
    Pause-XP
}

# ---------------- MODULE 10 ----------------
function Power-Tweaks {
    Header
    Write-Host "10 - POWER TWEAKS" -ForegroundColor White
    Write-Host ""

    Step "Applying High Performance power plan"

    try {
        powercfg -setactive SCHEME_MIN
        OK "High Performance power plan activated"
    } catch {
        Warn "Could not activate High Performance power plan"
    }

    Pause-XP
}

# ---------------- APPLY ALL ----------------
function Apply-All {
    Header
    Write-Host "APPLY ALL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "X PRIME will create a restore point before applying all modules." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Type YES to continue"
    if ($confirm -ne "YES") {
        Write-Host ""
        Write-Host "Cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        return
    }

    Restore-Point-NoPause
    System-Cleanup-NoPause
    Settings-Optimization-NoPause
    Increase-Responsiveness-NoPause
    Gaming-Booster-NoPause
    Network-Optimization-NoPause
    Latency-Removal-NoPause
    Services-Optimization-NoPause
    Background-Apps-NoPause
    Fullscreen-Optimization-NoPause
    Power-Tweaks-NoPause

    Header
    Write-Host "ALL OPTIMIZATIONS COMPLETED" -ForegroundColor Green
    Write-Host ""
    Write-Host "Log: $LogFile" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press ENTER to return to the main menu" | Out-Null
}

# No-pause versions used only by Apply All.
function Restore-Point-NoPause {
    Step "Creating restore point and setting 10% shadow storage"
    Enable-ComputerRestore -Drive "C:\" | Out-Null
    & vssadmin.exe Resize ShadowStorage /For=C: /On=C: /MaxSize=10% | Out-Null
    try {
        Checkpoint-Computer -Description "X PRIME Optimization - Before Changes" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        OK "Restore point created"
    } catch {
        Warn "Restore point could not be created"
    }
}

function System-Cleanup-NoPause {
    $paths = @("$env:TEMP\*","$env:SystemRoot\Temp\*","$env:SystemRoot\Prefetch\*","$env:SystemRoot\SoftwareDistribution\Download\*")
    foreach ($path in $paths) {
        Step "Cleaning $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Start-Process cleanmgr.exe -ArgumentList "/VERYLOWDISK" -Wait -WindowStyle Hidden
    Optimize-Volume -DriveLetter C -ErrorAction SilentlyContinue | Out-Null
    OK "System Cleanup completed"
}

function Settings-Optimization-NoPause {
    Set-Reg "HKCU:\Control Panel\Desktop" "EnablePerProcessSystemDPI" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" "ToastEnabled" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 | Out-Null
    Disable-WindowsOptionalFeature -Online -FeatureName Internet-Explorer-Optional-amd64 -NoRestart | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableWindowsLocationProvider" 1 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessNotifications" 2 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessRadios" 2 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsGetDiagnosticInfo" 2 | Out-Null
    OK "Settings Optimization completed"
}

function Increase-Responsiveness-NoPause {
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0 | Out-Null
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothing" "2" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Desktop" "FontSmoothingType" 2 | Out-Null
    Set-Reg "HKCU:\Control Panel\Desktop" "MinAnimate" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0 | Out-Null
    OK "Responsiveness completed"
}

function Gaming-Booster-NoPause {
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 | Out-Null
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 | Out-Null
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1 | Out-Null
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimizeEnable=0;" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    OK "Gaming Booster completed"
}

function Network-Optimization-NoPause {
    Get-NetAdapter -Physical | Where-Object Status -eq "Up" | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID "ms_tcpip6" -ErrorAction SilentlyContinue
    }
    OK "Network Optimization completed"
}

function Latency-Removal-NoPause {
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    Set-Reg "HKCU:\Control Panel\Mouse" "MouseSensitivity" "1" ([Microsoft.Win32.RegistryValueKind]::String) | Out-Null
    OK "Latency Removal completed"
}

function Services-Optimization-NoPause {
    foreach ($s in @("Spooler","WSearch","SysMain","DiagTrack","lfsvc")) {
        try {
            Stop-Service $s -Force -ErrorAction SilentlyContinue
            Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
        } catch {}
    }
    OK "Services Optimization completed"
}

function Background-Apps-NoPause {
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2 | Out-Null
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1 | Out-Null
    OK "Background Apps completed"
}

function Fullscreen-Optimization-NoPause {
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2 | Out-Null
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehavior" 2 | Out-Null
    Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1 | Out-Null
    OK "Fullscreen Optimization completed"
}

function Power-Tweaks-NoPause {
    powercfg -setactive SCHEME_MIN
    OK "High Performance activated"
}

# ---------------- MAIN MENU ----------------
while ($true) {
    Header

    Write-Host "  [0]  Restore Point" -ForegroundColor White
    Write-Host "  [1]  System Cleanup" -ForegroundColor White
    Write-Host "  [2]  Settings Optimization" -ForegroundColor White
    Write-Host "  [3]  Increase Responsiveness" -ForegroundColor White
    Write-Host "  [4]  Gaming Booster" -ForegroundColor White
    Write-Host "  [5]  Network Optimization" -ForegroundColor White
    Write-Host "  [6]  Latency Removal" -ForegroundColor White
    Write-Host "  [7]  Services Optimization" -ForegroundColor White
    Write-Host "  [8]  Background Apps" -ForegroundColor White
    Write-Host "  [9]  Full Screen Optimization" -ForegroundColor White
    Write-Host "  [10] Power Tweaks" -ForegroundColor White
    Write-Host ""
    Write-Host "  [A]  Apply All" -ForegroundColor Cyan
    Write-Host "  [Q]  Quit" -ForegroundColor Red
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan

    $choice = Read-Host "X PRIME"

    switch ($choice.ToUpper()) {
        "0"  { Restore-Point }
        "1"  { System-Cleanup }
        "2"  { Settings-Optimization }
        "3"  { Increase-Responsiveness }
        "4"  { Gaming-Booster }
        "5"  { Network-Optimization }
        "6"  { Latency-Removal }
        "7"  { Services-Optimization }
        "8"  { Background-Apps }
        "9"  { Fullscreen-Optimization }
        "10" { Power-Tweaks }
        "A"  { Apply-All }
        "Q"  { Clear-Host; Write-Host "X PRIME closed." -ForegroundColor Cyan; exit }
        default {
            Write-Host ""
            Write-Host "Invalid option." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
