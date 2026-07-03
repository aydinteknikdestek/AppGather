<#
.SYNOPSIS
    ATD | AppGather v6.0 - Sistem Optimizasyon ve Temizlik Aracı
.DESCRIPTION
    settings.ini dosyasını okuyarak Windows sistem optimizasyonu,
    temizlik, servis yönetimi ve uygulama kaldırma işlemlerini yapar.
.EXAMPLE
    .\main.ps1
    settings.ini'deki tüm ayarları uygular.
.EXAMPLE
    .\main.ps1 -DryRun
    Hangi işlemlerin yapılacağını gösterir, uygulamaz.
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

# ========== AYARLAR ==========
$SCRIPT_VERSION = "6.0.0"
$SCRIPT_NAME = "ATD | AppGather"
$ErrorActionPreference = "Continue"

# ========== YÖNETİCİ YETKİSİ ==========
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host ""
    Write-Host "[!] Yonetici yetkisi gerekli! Yeniden baslatiliyor..." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ========== LOG SİSTEMİ ==========
$LOG_PATH = "$env:APPDATA\ATD\AppGather\logs"
$LOG_FILE = "$LOG_PATH\appgather_$(Get-Date -Format 'yyyyMMdd').log"

function Write-Log {
    param($Message, $Type = "INFO")
    if (!(Test-Path $LOG_PATH)) { New-Item -ItemType Directory -Path $LOG_PATH -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Type] $Message"
    $entry | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    if ($Type -eq "ERROR") { Write-Host $entry -ForegroundColor Red }
    elseif ($Type -eq "WARNING") { Write-Host $entry -ForegroundColor Yellow }
    else { Write-Host $entry -ForegroundColor Gray }
}

# ========== INI OKUYUCU ==========
function Get-IniContent {
    param($Path)
    if (!(Test-Path $Path)) {
        Write-Log "settings.ini bulunamadi: $Path" -Type "ERROR"
        throw "settings.ini bulunamadi: $Path"
    }
    $content = Get-Content $Path -Raw -Encoding UTF8
    $sections = @{}
    $currentSection = "General"
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match "^\[(.*?)\]$") {
            $currentSection = $Matches[1]
            if (-not $sections.ContainsKey($currentSection)) {
                $sections[$currentSection] = @{}
            }
        }
        elseif ($trimmed -match "^([^;=]+?)\s*=\s*([^;]*?)($|;|►)") {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($value -eq "") { continue }
            $sections[$currentSection][$key] = $value
        }
    }
    return $sections
}

# ========== KAYIT DEFTERİ YARDIMCILARI ==========
function Set-RegistryValue {
    param($Path, $Name, $Value, $Type = "DWord")
    if ($DryRun) {
        Write-Host "[DRYRUN] Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type" -ForegroundColor Cyan
        return
    }
    try {
        if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        Write-Log "Registry: $Path\$Name = $Value ($Type)" -Type "INFO"
    } catch {
        Write-Log "Registry hatasi: $($_.Exception.Message)" -Type "ERROR"
    }
}

# ========== ANA FONKSİYONLAR ==========
function Apply-TaskbarSettings {
    param($Settings)
    Write-Host "`n[Görev Çubuğu Ayarları]" -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $map = @{
        "Taskbar_Setting_1_" = @{ Name = "Start_ShowRecentApps"; Value = 0 }
        "Taskbar_Setting_2_" = @{ Name = "Start_ShowSuggestedApps"; Value = 0 }
        "Taskbar_Setting_3_" = @{ Name = "Start_TrackProgs"; Value = 0 }
        "Taskbar_Setting_4_" = @{ Name = "Start_ShowAppSuggestions"; Value = 0 }
        "Taskbar_Setting_5_" = @{ Name = "PeopleBand"; Value = 0 }
        "Taskbar_Setting_6_" = @{ Name = "SearchboxTaskbarMode"; Value = 0 }
        "Taskbar_Setting_7_" = @{ Name = "TaskbarWidget"; Value = 0 }
        "Taskbar_Setting_8_" = @{ Name = "TaskbarWidget"; Value = 0 }
        "Taskbar_Setting_9_" = @{ Name = "ShowCortanaButton"; Value = 0 }
        "Taskbar_Setting_10_" = @{ Name = "TaskbarMn"; Value = 0 }
        "Taskbar_Setting_12_" = @{ Name = "TaskbarAl"; Value = 0 }
        "Taskbar_Setting_13_" = @{ Name = "ShowTaskViewButton"; Value = 0 }
        "Taskbar_Setting_14_" = @{ Name = "Start_ShowSuggestedApps"; Value = 0 }
        "Taskbar_Setting_15_" = @{ Name = "Start_ShowAppSuggestions"; Value = 0 }
        "Taskbar_Setting_16_" = @{ Name = "ShowCopilotButton"; Value = 0 }
        "Taskbar_Setting_17_" = @{ Name = "Start_ShowAccountNotifications"; Value = 0 }
        "Taskbar_Setting_18_" = @{ Name = "TaskbarEndTask"; Value = 1 }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                Set-RegistryValue -Path $path -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-ExplorerSettings {
    param($Settings)
    Write-Host "`n[Dosya Gezgini Ayarları]" -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $map = @{
        "Explorer_Setting_1_" = @{ Name = "DisablePreviewDesktop"; Value = 1 }
        "Explorer_Setting_2_" = @{ Name = "EnableLongPaths"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" }
        "Explorer_Setting_3_" = @{ Name = "LinkResolveIgnoreLinkInfo"; Value = 1 }
        "Explorer_Setting_4_" = @{ Name = "TaskbarAcrylicOpacity"; Value = 0 }
        "Explorer_Setting_5_" = @{ Name = "OpenWithStore"; Value = 0 }
        "Explorer_Setting_6_" = @{ Name = "OpenWithWebSearch"; Value = 0 }
        "Explorer_Setting_7_" = @{ Name = "ShowOfficeOnlineFiles"; Value = 0 }
        "Explorer_Setting_9_" = @{ Name = "LaunchTo"; Value = 1 }
        "Explorer_Setting_10_" = @{ Name = "ShowCopyDetails"; Value = 1 }
        "Explorer_Setting_11_" = @{ Name = "HideFileExt"; Value = 0 }
        "Explorer_Setting_12_" = @{ Name = "ShowSuperHidden"; Value = 1 }
        "Explorer_Setting_13_" = @{ Name = "Hidden"; Value = 1 }
        "Explorer_Setting_14_" = @{ Name = "ShowDesktopIcons"; Value = 1 }
        "Explorer_Setting_15_" = @{ Name = "EnableStartupSound"; Value = 0 }
        "Explorer_Setting_16_" = @{ Name = "AltTabSettings"; Value = 0 }
        "Explorer_Setting_17_" = @{ Name = "NoPrintContextMenu"; Value = 1 }
        "Explorer_Setting_20_" = @{ Name = "ShowOfficeFiles"; Value = 0 }
        "Explorer_Setting_21_" = @{ Name = "SystemUsesLightTheme"; Value = 0 }
        "Explorer_Setting_22_" = @{ Name = "TaskbarAnimations"; Value = 0 }
        "Explorer_Setting_23_" = @{ Name = "UseCompactMode"; Value = 1 }
        "Explorer_Setting_24_" = @{ Name = "ClassicContextMenu"; Value = 1 }
        "Explorer_Setting_25_" = @{ Name = "SnapAssist"; Value = 0 }
        "Explorer_Setting_30_" = @{ Name = "CursorScheme"; Value = "Windows Default" }
        "Explorer_Setting_31_" = @{ Name = "AppsUseLightTheme"; Value = 0 }
        "Explorer_Setting_34_" = @{ Name = "CursorScheme"; Value = "Windows Black" }
        "Explorer_Setting_35_" = @{ Name = "ShowHome"; Value = 0 }
        "Explorer_Setting_36_" = @{ Name = "ShowGallery"; Value = 0 }
        "Explorer_Setting_37_" = @{ Name = "SettingsNotifications"; Value = 0 }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                $p = if ($map[$key].ContainsKey("Path")) { $map[$key].Path } else { $path }
                Set-RegistryValue -Path $p -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-PrivacySettings {
    param($Settings)
    Write-Host "`n[Gizlilik Ayarları]" -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $map = @{
        "Privacy_Setting_1_" = @{ Name = "SubscribedContent-338393Enabled"; Value = 0 }
        "Privacy_Setting_2_" = @{ Name = "SubscribedContent-338388Enabled"; Value = 0 }
        "Privacy_Setting_3_" = @{ Name = "SubscribedContent-338389Enabled"; Value = 0 }
        "Privacy_Setting_4_" = @{ Name = "SubscribedContent-338390Enabled"; Value = 0 }
        "Privacy_Setting_5_" = @{ Name = "SubscribedContent-338391Enabled"; Value = 0 }
        "Privacy_Setting_6_" = @{ Name = "SubscribedContent-338392Enabled"; Value = 0 }
        "Privacy_Setting_7_" = @{ Name = "SubscribedContent-338393Enabled"; Value = 0 }
        "Privacy_Setting_8_" = @{ Name = "SubscribedContent-338394Enabled"; Value = 0 }
        "Privacy_Setting_9_" = @{ Name = "SubscribedContent-338395Enabled"; Value = 0 }
        "Privacy_Setting_10_" = @{ Name = "SubscribedContent-338396Enabled"; Value = 0 }
        "Privacy_Setting_11_" = @{ Name = "ActivityFeedEnabled"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_12_" = @{ Name = "ShowRecentFiles"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_13_" = @{ Name = "SendInputData"; Value = 0; Path = "HKCU:\Software\Microsoft\InputPersonalization" }
        "Privacy_Setting_14_" = @{ Name = "FeedbackFrequency"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feedback" }
        "Privacy_Setting_15_" = @{ Name = "ImproveWriting"; Value = 0; Path = "HKCU:\Software\Microsoft\InputPersonalization" }
        "Privacy_Setting_16_" = @{ Name = "MicrosoftExperiments"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_17_" = @{ Name = "NvidiaCEIP"; Value = 0; Path = "HKLM:\Software\NVIDIA Corporation\CEIP" }
        "Privacy_Setting_18_" = @{ Name = "SendBrowsingData"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_19_" = @{ Name = "LanguageAccess"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_20_" = @{ Name = "AdvertisingId"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" }
        "Privacy_Setting_21_" = @{ Name = "AppInventory"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_22_" = @{ Name = "SendMediaStats"; Value = 0; Path = "HKCU:\Software\Microsoft\MediaPlayer\Preferences" }
        "Privacy_Setting_23_" = @{ Name = "HotspotReporting"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_24_" = @{ Name = "OnlineSpeechRecognition"; Value = 0; Path = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" }
        "Privacy_Setting_25_" = @{ Name = "DiagnosticData"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" }
        "Privacy_Setting_26_" = @{ Name = "HideRecentFiles"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_27_" = @{ Name = "SkypeContacts"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_28_" = @{ Name = "CrossDevice"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_29_" = @{ Name = "HandwritingData"; Value = 0; Path = "HKCU:\Software\Microsoft\InputPersonalization" }
        "Privacy_Setting_30_" = @{ Name = "PaidWifi"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_31_" = @{ Name = "HotspotWifi"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_32_" = @{ Name = "SpeechRecognition"; Value = 0; Path = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" }
        "Privacy_Setting_33_" = @{ Name = "DocumentTracking"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_34_" = @{ Name = "RecentQuickAccess"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_35_" = @{ Name = "RecentDocumentHistory"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_36_" = @{ Name = "RecentJumplist"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_37_" = @{ Name = "OnlineTips"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_38_" = @{ Name = "DeviceStatus"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_39_" = @{ Name = "Hotspot20"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_40_" = @{ Name = "SyncProvider"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_41_" = @{ Name = "ComponentLog"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_42_" = @{ Name = "DeltaPackage"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_43_" = @{ Name = "ComponentBackup"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_44_" = @{ Name = "WfpDiagLog"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_45_" = @{ Name = "Autocorrect"; Value = 0; Path = "HKCU:\Software\Microsoft\InputPersonalization" }
        "Privacy_Setting_46_" = @{ Name = "SpellCheck"; Value = 0; Path = "HKCU:\Software\Microsoft\InputPersonalization" }
        "Privacy_Setting_47_" = @{ Name = "CrossDeviceAppOpen"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_48_" = @{ Name = "SearchHistory"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_49_" = @{ Name = "HelpTips"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_50_" = @{ Name = "AppInstallNotify"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_51_" = @{ Name = "InkPersonalization"; Value = 0; Path = "HKCU:\Software\Microsoft\InputPersonalization" }
        "Privacy_Setting_52_" = @{ Name = "LocationAccess"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_53_" = @{ Name = "AccountInfo"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_54_" = @{ Name = "DeliveryOptimization"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" }
        "Privacy_Setting_55_" = @{ Name = "FindMyDevice"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_56_" = @{ Name = "DeviceMetadata"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_57_" = @{ Name = "Telemetry"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" }
        "Privacy_Setting_58_" = @{ Name = "WER"; Value = 0; Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" }
        "Privacy_Setting_59_" = @{ Name = "BTLogging"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_60_" = @{ Name = "CloudConsumer"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_61_" = @{ Name = "AppNotifications"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_62_" = @{ Name = "CEIP"; Value = 0; Path = "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" }
        "Privacy_Setting_63_" = @{ Name = "RemoteHelp"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\RemoteHelp" }
        "Privacy_Setting_64_" = @{ Name = "RemoteHelpDiagnostics"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\RemoteHelp" }
        "Privacy_Setting_65_" = @{ Name = "RemoteMessenger"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\RemoteHelp" }
        "Privacy_Setting_66_" = @{ Name = "CortanaHistory"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" }
        "Privacy_Setting_67_" = @{ Name = "SearchBoxHistory"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" }
        "Privacy_Setting_68_" = @{ Name = "CompatAssist"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_69_" = @{ Name = "BackgroundApps"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Privacy_Setting_70_" = @{ Name = "Recall"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall" }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                $p = if ($map[$key].ContainsKey("Path")) { $map[$key].Path } else { $path }
                Set-RegistryValue -Path $p -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-OptimizationSettings {
    param($Settings)
    Write-Host "`n[Optimizasyon Ayarlari]" -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $map = @{
        "Optimization_Setting_1_" = @{ Name = "TaskbarStartDelay"; Value = 0 }
        "Optimization_Setting_2_" = @{ Name = "GameMode"; Value = 0; Path = "HKCU:\Software\Microsoft\GameBar" }
        "Optimization_Setting_3_" = @{ Name = "FullscreenOptimizations"; Value = 0; Path = "HKCU:\System\GameConfigStore" }
        "Optimization_Setting_4_" = @{ Name = "HardwareAcceleratedGPU"; Value = 1; Path = "HKCU:\System\GameConfigStore" }
        "Optimization_Setting_5_" = @{ Name = "BackgroundApps"; Value = 0; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" }
        "Optimization_Setting_6_" = @{ Name = "MaintenanceDisabled"; Value = 1; Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" }
        "Optimization_Setting_7_" = @{ Name = "PowerThrottling"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power" }
        "Optimization_Setting_8_" = @{ Name = "QuietHours"; Value = 1; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings" }
        "Optimization_Setting_9_" = @{ Name = "PagefileCombine"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" }
        "Optimization_Setting_10_" = @{ Name = "UltimatePerformance"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power" }
        "Optimization_Setting_11_" = @{ Name = "CoreParking"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power" }
        "Optimization_Setting_12_" = @{ Name = "HungAppTimeout"; Value = 0; Path = "HKCU:\Control Panel\Desktop" }
        "Optimization_Setting_13_" = @{ Name = "SSDOptimization"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" }
        "Optimization_Setting_14_" = @{ Name = "SvchostOptimize"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" }
        "Optimization_Setting_15_" = @{ Name = "CPUMatch"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" }
        "Optimization_Setting_16_" = @{ Name = "HPET"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" }
        "Optimization_Setting_18_" = @{ Name = "NTFSCompression"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" }
        "Optimization_Setting_19_" = @{ Name = "MSI_Mode"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" }
        "Optimization_Setting_21_" = @{ Name = "FileListRefresh"; Value = 1; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" }
        "Optimization_Setting_22_" = @{ Name = "AeroSnapSpeed"; Value = 1; Path = "HKCU:\Control Panel\Desktop" }
        "Optimization_Setting_23_" = @{ Name = "IconCacheSize"; Value = 8192; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Type = "String" }
        "Optimization_Setting_24_" = @{ Name = "CPUPlanning"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" }
        "Optimization_Setting_25_" = @{ Name = "TaskbarPreviewSpeed"; Value = 1; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" }
        "Optimization_Setting_26_" = @{ Name = "MemoryDefault"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" }
        "Optimization_Setting_27_" = @{ Name = "Debugger"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                $p = if ($map[$key].ContainsKey("Path")) { $map[$key].Path } else { $path }
                $t = if ($map[$key].ContainsKey("Type")) { $map[$key].Type } else { "DWord" }
                Set-RegistryValue -Path $p -Name $map[$key].Name -Value $map[$key].Value -Type $t
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-InternetSettings {
    param($Settings)
    Write-Host "`n[Internet Ayarlari]" -ForegroundColor Yellow
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    $map = @{
        "Internet_Setting_1_" = @{ Name = "QosPacer"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Psched" }
        "Internet_Setting_2_" = @{ Name = "LimitedNetwork"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc" }
        "Internet_Setting_3_" = @{ Name = "Neagle"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" }
        "Internet_Setting_4_" = @{ Name = "NetworkScan"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Network" }
        "Internet_Setting_5_" = @{ Name = "NegativeDNSCache"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache" }
        "Internet_Setting_6_" = @{ Name = "NetworkOptimization"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" }
        "Internet_Setting_7_" = @{ Name = "CongestionControl"; Value = 0; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" }
        "Internet_Setting_8_" = @{ Name = "RSS"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                $p = if ($map[$key].ContainsKey("Path")) { $map[$key].Path } else { $path }
                Set-RegistryValue -Path $p -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-SearchSettings {
    param($Settings)
    Write-Host "`n[Arama Ayarlari]" -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $map = @{
        "Search_Setting_1_" = @{ Name = "IndexEncryptedFiles"; Value = 0 }
        "Search_Setting_2_" = @{ Name = "SearchInternet"; Value = 0 }
        "Search_Setting_3_" = @{ Name = "AdultContent"; Value = 0 }
        "Search_Setting_4_" = @{ Name = "CloudSearch"; Value = 0 }
        "Search_Setting_5_" = @{ Name = "InternetSearch"; Value = 0 }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                Set-RegistryValue -Path $path -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-SecuritySettings {
    param($Settings)
    Write-Host "`n[Guvenlik Ayarlari]" -ForegroundColor Yellow
    $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    $map = @{
        "Security_Setting_3_" = @{ Name = "NoAutoRun"; Value = 1 }
        "Security_Setting_9_" = @{ Name = "DisableRemoteRegistry"; Value = 1; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurePipeServers\winreg" }
        "Security_Setting_10_" = @{ Name = "PasswordlessLogin"; Value = 1; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Authentication" }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                $p = if ($map[$key].ContainsKey("Path")) { $map[$key].Path } else { $path }
                Set-RegistryValue -Path $p -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-FeatureSettings {
    param($Settings)
    Write-Host "`n[Ozellik Ayarlari]" -ForegroundColor Yellow
    $map = @{
        "Feature_Setting_1_" = @{ Path = "HKCU:\Control Panel\Accessibility\StickyKeys"; Name = "Flags"; Value = "506" }
        "Feature_Setting_2_" = @{ Path = "HKCU:\Control Panel\Accessibility\FilterKeys"; Name = "Flags"; Value = "506" }
        "Feature_Setting_3_" = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"; Name = "HiberbootEnabled"; Value = 0 }
        "Feature_Setting_4_" = @{ Path = "HKCU:\Software\Microsoft\Windows Photo Viewer"; Name = "Enabled"; Value = 1 }
        "Feature_Setting_5_" = @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "EnableLUA"; Value = 0 }
        "Feature_Setting_6_" = @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "ConsentPromptBehaviorAdmin"; Value = 0 }
        "Feature_Setting_7_" = @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed"; Value = 0 }
        "Feature_Setting_8_" = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"; Name = "AutoReboot"; Value = 0 }
        "Feature_Setting_9_" = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"; Name = "TimeStamp"; Value = 0 }
        "Feature_Setting_10_" = @{ Path = "HKCU:\Software\Microsoft\Xbox"; Name = "GameDVR"; Value = 0 }
        "Feature_Setting_11_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableTroubleshooting"; Value = 0 }
        "Feature_Setting_12_" = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"; Name = "fDenyTSConnections"; Value = 1 }
        "Feature_Setting_13_" = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "AutoRepair"; Value = 0 }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                Set-RegistryValue -Path $map[$key].Path -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-UpdateSettings {
    param($Settings)
    Write-Host "`n[Guncelleme Ayarlari]" -ForegroundColor Yellow
    $map = @{
        "Update_Setting_1_" = @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager"; Name = "ShippedWithReserves"; Value = 0 }
        "Update_Setting_2_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DisableWindowsUpdate"; Value = 1; Type = "String" }
        "Update_Setting_3_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"; Name = "SearchOrderConfig"; Value = 0 }
        "Update_Setting_4_" = @{ Path = "HKCU:\Software\Microsoft\Speech"; Name = "AutoUpdate"; Value = 0 }
        "Update_Setting_5_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"; Name = "AutoDownload"; Value = 0 }
        "Update_Setting_6_" = @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Storage"; Name = "DiskPrediction"; Value = 0 }
        "Update_Setting_7_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DeferFeatureUpdates"; Value = 1 }
        "Update_Setting_8_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps"; Name = "AutoUpdate"; Value = 0 }
        "Update_Setting_9_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "AutoInstallMinorUpdates"; Value = 0 }
        "Update_Setting_10_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "WakeUp"; Value = 0 }
        "Update_Setting_11_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "DownloadOnMetered"; Value = 0 }
        "Update_Setting_12_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "UpgradeNotifications"; Value = 0 }
        "Update_Setting_13_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "ShutdownOptions"; Value = 0 }
        "Update_Setting_14_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "AutoRestart"; Value = 0 }
        "Update_Setting_15_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "RestartNotifications"; Value = 0 }
        "Update_Setting_16_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceMetadata"; Name = "MetadataEnabled"; Value = 0 }
        "Update_Setting_17_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "UpdateNotifications"; Value = 0 }
        "Update_Setting_18_" = @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications"; Name = "KeepMeUpdated"; Value = 0 }
        "Update_Setting_19_" = @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchUpdate"; Value = 0 }
        "Update_Setting_20_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "MicrosoftAppUpdates"; Value = 0 }
        "Update_Setting_21_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"; Name = "AppScan"; Value = 0 }
        "Update_Setting_22_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"; Name = "PreviewUpdates"; Value = 0 }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                $t = if ($map[$key].ContainsKey("Type")) { $map[$key].Type } else { "DWord" }
                Set-RegistryValue -Path $map[$key].Path -Name $map[$key].Name -Value $map[$key].Value -Type $t
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-TaskschdSettings {
    param($Settings)
    Write-Host "`n[Gorev Zamanlayici Ayarlari]" -ForegroundColor Yellow
    $map = @{
        "Taskschd_Setting_1_" = "\Microsoft\Windows\DevHome\DevHomeUpdate"
        "Taskschd_Setting_2_" = "\Microsoft\Windows\UpdateOrchestrator\IA"
        "Taskschd_Setting_3_" = "\Microsoft\Windows\UpdateOrchestrator\LXP"
        "Taskschd_Setting_4_" = "\Microsoft\Windows\UpdateOrchestrator\MACUpdate"
        "Taskschd_Setting_5_" = "\Microsoft\Windows\UpdateOrchestrator\OutlookUpdate"
        "Taskschd_Setting_6_" = "\Microsoft\Windows\UpdateOrchestrator\TFLUpdate"
        "Taskschd_Setting_7_" = "\Microsoft\Windows\UpdateOrchestrator\EdgeUpdate"
        "Taskschd_Setting_8_" = "\Microsoft\Windows\UpdateOrchestrator\CrossDeviceUpdate"
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                if ($DryRun) {
                    Write-Host "[DRYRUN] Disable-ScheduledTask $($map[$key])" -ForegroundColor Cyan
                } else {
                    try {
                        Disable-ScheduledTask -TaskName $map[$key] -ErrorAction Stop
                        Write-Host "  [OK] $key devre disi birakildi" -ForegroundColor Green
                        Write-Log "Task disabled: $($map[$key])" -Type "INFO"
                    } catch {
                        Write-Host "  [SKIP] $key bulunamadi" -ForegroundColor Gray
                        Write-Log "Task not found: $($map[$key])" -Type "WARNING"
                    }
                }
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-ComponentSettings {
    param($Settings)
    Write-Host "`n[Bilesen Ayarlari]" -ForegroundColor Yellow
    $map = @{
        "Component_Setting_2_" = "Microsoft-Edge"
        "Component_Setting_3_" = "EdgeWebView2"
        "Component_Setting_4_" = "OneDrive"
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                if ($DryRun) {
                    Write-Host "[DRYRUN] Remove-WindowsPackage $($map[$key])" -ForegroundColor Cyan
                } else {
                    Write-Host "  [OK] $key (manuel kaldirilmali)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-ChangeAppSettings {
    param($Settings)
    Write-Host "`n[Uygulama Devredisi Birakma]" -ForegroundColor Yellow
    $map = @{
        "Change_App_1_" = @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"; Name = "DisableAntiSpyware"; Value = 1 }
        "Change_App_2_" = @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode"; Value = 0 }
        "Change_App_3_" = @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoStartMenu"; Value = 1 }
        "Change_App_4_" = @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "DisableBingApps"; Value = 1 }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                Set-RegistryValue -Path $map[$key].Path -Name $map[$key].Name -Value $map[$key].Value
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-SpecialSettings {
    param($Settings)
    Write-Host "`n[Ozel Ayarlar]" -ForegroundColor Yellow
    $map = @{
        "Special_Setting_1_" = @{ Path = "HKCU:\Control Panel\Desktop"; Name = "JPEGQuality"; Value = 60; Type = "String" }
        "Special_Setting_2_" = @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = 0; Type = "String" }
        "Special_Setting_3_" = @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseHoverTime"; Value = 1000; Type = "String" }
    }
    foreach ($key in $map.Keys) {
        if ($Settings.ContainsKey($key)) {
            $val = $Settings[$key]
            if ($val -eq "1") {
                Set-RegistryValue -Path $map[$key].Path -Name $map[$key].Name -Value $map[$key].Value -Type $map[$key].Type
                Write-Host "  [OK] $key uygulandi" -ForegroundColor Green
            } else {
                Write-Host "  [SKIP] $key (0)" -ForegroundColor Gray
            }
        }
    }
}

function Apply-Services {
    param($Services)
    Write-Host "`n[Hizmet Yonetimi]" -ForegroundColor Yellow
    foreach ($svc in $Services) {
        if ($DryRun) {
            Write-Host "[DRYRUN] Set-Service $svc -StartupType Disabled" -ForegroundColor Cyan
            continue
        }
        try {
            $s = Get-Service -Name $svc -ErrorAction Stop
            if ($s) {
                Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop
                Stop-Service -Name $svc -Force -ErrorAction Stop
                Write-Host "  [OK] $svc durduruldu ve devre disi birakildi" -ForegroundColor Green
                Write-Log "Service disabled: $svc" -Type "INFO"
            }
        } catch {
            Write-Host "  [SKIP] $svc bulunamadi veya zaten devre disi" -ForegroundColor Gray
            Write-Log "Service not found: $svc" -Type "WARNING"
        }
    }
}

function Remove-Apps {
    param($Apps)
    Write-Host "`n[Uygulama Kaldirma]" -ForegroundColor Yellow
    foreach ($app in $Apps) {
        if ($DryRun) {
            Write-Host "[DRYRUN] winget uninstall `"$app`"" -ForegroundColor Cyan
            continue
        }
        try {
            $result = winget uninstall "$app" --silent 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] $app kaldirildi" -ForegroundColor Green
                Write-Log "App removed: $app" -Type "INFO"
            } else {
                Write-Host "  [FAIL] $app kaldirilamadi" -ForegroundColor Red
                Write-Log "App removal failed: $app" -Type "ERROR"
            }
        } catch {
            Write-Host "  [FAIL] $app kaldirilamadi" -ForegroundColor Red
            Write-Log "App removal error: $app - $($_.Exception.Message)" -Type "ERROR"
        }
    }
}

function Clean-Temp {
    Write-Host "`n[Geçici Dosya Temizligi]" -ForegroundColor Yellow
    $folders = @(
        "$env:TEMP",
        "$env:SystemRoot\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:APPDATA\Microsoft\Windows\Recent"
    )
    $total = 0
    foreach ($f in $folders) {
        if (Test-Path $f) {
            if ($DryRun) {
                Write-Host "[DRYRUN] Remove-Item $f\* -Recurse -Force" -ForegroundColor Cyan
                continue
            }
            try {
                $size = (Get-ChildItem $f -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                Remove-Item "$f\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  [OK] $f temizlendi ($([math]::Round($size/1MB, 2)) MB)" -ForegroundColor Green
                $total += $size
            } catch {
                Write-Host "  [SKIP] $f temizlenemedi" -ForegroundColor Gray
            }
        }
    }
    if (-not $DryRun) {
        try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
        Write-Host "  [OK] Geri donusum kutusu temizlendi" -ForegroundColor Green
        if (Test-Path "C:\Windows\Prefetch") {
            Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Prefetch temizlendi" -ForegroundColor Green
        }
        Write-Host "  [OK] Toplam $([math]::Round($total/1MB, 2)) MB temizlendi" -ForegroundColor Green
        Write-Log "Temizlik tamamlandi: $([math]::Round($total/1MB, 2)) MB" -Type "INFO"
    }
}

# ========== ANA PROGRAM ==========
function Main {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  $SCRIPT_NAME v$SCRIPT_VERSION                                     ║" -ForegroundColor Cyan
    Write-Host "║  Windows Sistem Optimizasyon ve Temizlik Araci                   ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRun) {
        Write-Host "[DRYRUN MODU] Hicbir degisiklik yapilmayacak." -ForegroundColor Yellow
    }

    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    $iniPath = Join-Path $scriptPath "settings.ini"

    try {
        $config = Get-IniContent -Path $iniPath
    } catch {
        Write-Log "Hata: settings.ini okunamadi!" -Type "ERROR"
        Read-Host "Devam etmek icin Enter'a basin..."
        exit 1
    }

    $general = $config["General"]
    $skipService = if ($general.ContainsKey("Skip_Service_")) { $general["Skip_Service_"] -eq "1" } else { $false }
    $processClear = if ($general.ContainsKey("Process_Clear_")) { $general["Process_Clear_"] -eq "1" } else { $true }

    # Temizlik
    if ($processClear) { Clean-Temp } else { Write-Host "[SKIP] Temizlik atlandi" -ForegroundColor Yellow }

    # Ayarlar
    $settings = $config["General"]
    Apply-TaskbarSettings -Settings $settings
    Apply-ExplorerSettings -Settings $settings
    Apply-PrivacySettings -Settings $settings
    Apply-OptimizationSettings -Settings $settings
    Apply-InternetSettings -Settings $settings
    Apply-SearchSettings -Settings $settings
    Apply-SecuritySettings -Settings $settings
    Apply-FeatureSettings -Settings $settings
    Apply-UpdateSettings -Settings $settings
    Apply-TaskschdSettings -Settings $settings
    Apply-ComponentSettings -Settings $settings
    Apply-ChangeAppSettings -Settings $settings
    Apply-SpecialSettings -Settings $settings

    # Servisler
    if (-not $skipService) {
        $services = @()
        if ($config.ContainsKey("Service_Manager")) {
            foreach ($key in $config["Service_Manager"].Keys) {
                $services += $config["Service_Manager"][$key]
            }
        }
        Apply-Services -Services $services
    } else {
        Write-Host "[SKIP] Servis yonetimi atlandi" -ForegroundColor Yellow
    }

    # Uygulama Kaldirma
    $apps = @()
    if ($config.ContainsKey("General")) {
        foreach ($key in $config["General"].Keys) {
            if ($key -match "^RemoveApp") {
                $apps += $config["General"][$key]
            }
        }
    }
    if ($apps.Count -gt 0) {
        Remove-Apps -Apps $apps
    }

    Write-Host ""
    Write-Host "[OK] Tum islemler tamamlandi!" -ForegroundColor Green
    Write-Log "Tum islemler tamamlandi" -Type "INFO"
    Read-Host "Devam etmek icin Enter'a basin..."
}

# ========== PROGRAMI BASLAT ==========
Main