<# :
@echo off
chcp 65001 >nul
rem === Yaapu TX16S Installer (Hybrid Batch-PowerShell) ===
setlocal
set "POWERSHELL_BAT_ARGS=%*"
if defined POWERSHELL_BAT_ARGS set "POWERSHELL_BAT_ARGS=%POWERSHELL_BAT_ARGS:"=\"%"
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression -Command ([io.file]::ReadAllText('%~f0'))"
exit /b
#>

# ==============================================================================
# PowerShell Core Script Starts Here
# ==============================================================================
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem

$ESC = [char]27
$ZIP_NAME = "yaapu.zip"
$ZIP_URL  = "https://github.com/yaapu/FrskyTelemetryScript/archive/master.zip"
$EX_DIR   = "FrskyTelemetryScript-master"
$W        = 96 # 화면 너비 고정
$CREDIT_ROW = 33 # 하단 크레딧 줄 위치

# 콘솔 창 크기 고정 및 초기화
$Host.UI.RawUI.WindowTitle = "Yaapu Telemetry Auto Installer - FALCONSHOP"
try {
    $size = $Host.UI.RawUI.WindowSize
    $size.Width  = $W + 2
    $size.Height = 35
    $Host.UI.RawUI.WindowSize = $size
    $buf = $Host.UI.RawUI.BufferSize
    $buf.Width = $W + 2
    $buf.Height = 300
    $Host.UI.RawUI.BufferSize = $buf
} catch {}
[Console]::CursorVisible = $false

# QuickEdit 모드 OFF (마우스로 창을 클릭하면 멈추는 현상 방지)
try {
    if (-not ("ConsoleQuickEdit" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ConsoleQuickEdit {
    const int  STD_INPUT_HANDLE      = -10;
    const uint ENABLE_EXTENDED_FLAGS = 0x0080;
    const uint ENABLE_QUICK_EDIT     = 0x0040;
    const uint ENABLE_MOUSE_INPUT    = 0x0010;
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")]
    static extern bool GetConsoleMode(IntPtr h, out uint mode);
    [DllImport("kernel32.dll")]
    static extern bool SetConsoleMode(IntPtr h, uint mode);
    public static void Disable() {
        IntPtr h = GetStdHandle(STD_INPUT_HANDLE);
        uint mode;
        if (GetConsoleMode(h, out mode)) {
            mode &= ~ENABLE_QUICK_EDIT;
            mode &= ~ENABLE_MOUSE_INPUT;
            mode |=  ENABLE_EXTENDED_FLAGS;
            SetConsoleMode(h, mode);
        }
    }
}
'@
    }
    [ConsoleQuickEdit]::Disable()
} catch {}

# 언어 선택 전까지 사용할 기본 크레딧(영문)
$CREDIT = "YAAPU AUTO INSTALLER  /  COPYRIGHT BY FALCONSHOP KOREA"

# ==============================================================================
# TUI Engine & UI Helper Functions
# ==============================================================================

# 한글 2칸, 영문 1칸 폭을 정확히 계산하는 함수
function Get-DisplayLength($str) {
    if ([string]::IsNullOrEmpty($str)) { return 0 }
    $len = 0
    foreach ($c in $str.ToCharArray()) {
        $code = [int]$c
        if (($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0x1100 -and $code -le 0x11FF) -or
            ($code -ge 0x3130 -and $code -le 0x318F)) {
            $len += 2
        } else {
            $len += 1
        }
    }
    return $len
}

# 계산된 폭을 바탕으로 빈칸을 채워주는 함수
function Pad-DisplayRight($str, $totalLen) {
    $disp = Get-DisplayLength $str
    if ($totalLen -gt $disp) {
        return $str + (" " * ($totalLen - $disp))
    }
    return $str
}

# 로고 출력 (YAAPU 배너 + 그라데이션, 가운데 정렬) + 하단 크레딧
function Draw-Logo {
    $logo = @(
        "██╗   ██╗ █████╗  █████╗ ██████╗ ██╗   ██╗",
        "╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗██║   ██║",
        " ╚████╔╝ ███████║███████║██████╔╝██║   ██║",
        "  ╚██╔╝  ██╔══██║██╔══██║██╔═══╝ ██║   ██║",
        "   ██║   ██║  ██║██║  ██║██║     ╚██████╔╝",
        "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝      ╚═════╝ "
    )
    $inner = $W - 2

    Write-Host ""
    Write-Host ("┌" + ("─" * $inner) + "┐") -ForegroundColor DarkGray
    Write-Host ("│" + (" " * $inner) + "│") -ForegroundColor DarkGray

    foreach ($line in $logo) {
        $len = $line.Length
        $leftPad  = [Math]::Floor(($inner - $len) / 2)
        $rightPad = $inner - $len - $leftPad
        Write-Host ("│" + (" " * $leftPad)) -ForegroundColor DarkGray -NoNewline
        $gradLine = ""
        for ($i=0; $i -lt $len; $i++) {
            $ratio = if ($len -gt 1) { $i / ($len - 1) } else { 0 }
            $r = [math]::Round(0 + (255 - 0) * $ratio)
            $g = [math]::Round(150 + (50 - 150) * $ratio)
            $b = [math]::Round(255 + (150 - 255) * $ratio)
            $gradLine += "$ESC[38;2;$r;$g;${b}m" + $line[$i]
        }
        $gradLine += "$ESC[0m"
        [Console]::Write($gradLine)
        Write-Host ((" " * $rightPad) + "│") -ForegroundColor DarkGray
    }

    Write-Host ("│" + (" " * $inner) + "│") -ForegroundColor DarkGray
    Write-Host ("└" + ("─" * $inner) + "┘") -ForegroundColor DarkGray

    # 하단 중앙 크레딧 한 줄
    $crLen = Get-DisplayLength $CREDIT
    $crPad = [Math]::Max(0, [Math]::Floor(($W - $crLen) / 2))
    [Console]::SetCursorPosition(0, $CREDIT_ROW)
    Write-Host ((" " * $crPad) + $CREDIT) -ForegroundColor DarkGray -NoNewline
}

# 메뉴 출력 (한글 깨짐 완벽 방지)
function Show-Menu {
    param($Title, $Options, $Footer = "", $Lead = @())
    $selected = 0
    $dashCount = $W - (Get-DisplayLength $Title) - 5
    while ($true) {
        [Console]::SetCursorPosition(0, 11)
        foreach ($ln in $Lead) { Write-Host (Pad-DisplayRight $ln $W) -ForegroundColor Gray }
        Write-Host ("┌─ $Title " + ("─" * $dashCount) + "┐") -ForegroundColor Cyan
        Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Cyan

        for ($i = 0; $i -lt $Options.Length; $i++) {
            Write-Host "│ " -ForegroundColor Cyan -NoNewline
            $textInner = Pad-DisplayRight $Options[$i] ($W - 12)
            if ($i -eq $selected) {
                Write-Host " > " -ForegroundColor Yellow -NoNewline
                Write-Host "(●) " -ForegroundColor Cyan -NoNewline
                Write-Host $textInner -BackgroundColor Yellow -ForegroundColor Black -NoNewline
            } else {
                Write-Host "   (○) " -ForegroundColor DarkGray -NoNewline
                Write-Host $textInner -ForegroundColor White -NoNewline
            }
            Write-Host " │" -ForegroundColor Cyan
        }

        Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Cyan
        Write-Host ("└" + ("─" * ($W - 2)) + "┘") -ForegroundColor Cyan
        Write-Host (Pad-DisplayRight $Footer $W) -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
        if ($key -eq 38) { $selected = [Math]::Max(0, $selected - 1) }
        if ($key -eq 40) { $selected = [Math]::Min($Options.Length - 1, $selected + 1) }
        if ($key -eq 13) { return $selected }
        if ($key -eq 27) { [Console]::CursorVisible = $true; exit }
    }
}

function Draw-ProgressBox {
    param($Title, $Status, $Percent)
    [Console]::SetCursorPosition(0, 11)
    $dashCount = $W - (Get-DisplayLength $Title) - 5
    Write-Host ("┌─ $Title " + ("─" * $dashCount) + "┐") -ForegroundColor Cyan
    Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Cyan

    $statusPadded = Pad-DisplayRight $Status ($W - 6)
    Write-Host ("│  " + $statusPadded + "  │") -ForegroundColor White
    Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Cyan

    $barLen = $W - 10
    $filled = [Math]::Floor(($Percent / 100) * $barLen)
    $empty  = $barLen - $filled
    $barStr = ("█" * $filled) + ("░" * $empty)

    Write-Host "│ " -ForegroundColor Cyan -NoNewline
    Write-Host $barStr -ForegroundColor Green -NoNewline
    Write-Host (" {0,4}% " -f $Percent) -ForegroundColor Yellow -NoNewline
    Write-Host "│" -ForegroundColor Cyan

    Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Cyan
    Write-Host ("└" + ("─" * ($W - 2)) + "┘") -ForegroundColor Cyan
    Write-Host (" " * $W)
}

# 남은 입력 이벤트를 비우고 키 한 번을 대기 (즉시 종료 버그 방지)
function Wait-AnyKey {
    try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 치명적 오류를 빨간 글씨로 보여주고 키 입력을 기다림
function Show-Fatal($msg) {
    [Console]::CursorVisible = $true
    Write-Host ""
    Write-Host $msg -ForegroundColor Red
    Write-Host ""
    $exitTxt = if ($S) { $S.exit_msg } else { "    Press any key to exit..." }
    Write-Host $exitTxt -ForegroundColor DarkGray
    Wait-AnyKey
}

# 복사 중단 화면
function Abort-Copy {
    Clear-Host; Draw-Logo
    [Console]::SetCursorPosition(0, 13)
    Write-Host ("    " + $S.copy_aborted) -ForegroundColor Yellow
    Write-Host ""
    Write-Host $S.exit_msg -ForegroundColor DarkGray
    Wait-AnyKey
    [Console]::CursorVisible = $true
    exit
}

# EdgeTX yml 파일을 BOM 없는 UTF-8 로 저장 (CRLF 유지)
function Write-Utf8NoBom($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ==============================================================================
# 다국어 문자열 테이블 (KO / EN)
# ==============================================================================
$STRINGS = @{
    KO = @{
        credit         = "YAAPU 자동 설치 프로그램 / FALCONSHOP.CO.KR 에서 제작하였습니다."
        footer_nav     = "   [ ↑ / ↓ ] 이동      [ Enter ] 선택      [ ESC ] 종료"
        model_title    = "조종기 모델 선택"
        model_mk3      = "TX16S MK3  (5인치, 800x480 / ExpressLRS 내장)"
        model_mk2      = "TX16S MK2  (4.3인치, 480x272 / 4in1 또는 ExpressLRS)"
        confirm_title  = "설치 진행 확인"
        confirm_proceed= "진행 (설치 시작)"
        confirm_cancel = "취소"
        confirm_footer = "   이 폴더에 Yaapu 파일을 받아 SD카드로 설치합니다 : "
        cancelled      = "취소되었습니다."
        prep_title     = "파일 준비"
        dl_connect     = "GitHub에서 최신 Yaapu 연결 중..."
        dl_progress    = "GitHub에서 최신 Yaapu 다운로드 중... ({0} MB / 약 177 MB)"
        dl_done        = "다운로드 완료!"
        dl_fail        = " [에러] 다운로드 실패. 인터넷 연결을 확인하세요."
        ex_title       = "압축 해제"
        ex_start       = "필요한 파일만 스마트 압축 해제 중..."
        ex_progress    = "압축 해제 중... ({0} / {1})"
        ex_done        = "압축 해제 완료!"
        ex_skip        = "이미 압축이 풀려 있어 건너뜁니다."
        ex_fail        = " [에러] 압축 해제 실패. {0} 파일을 지우고 다시 실행하세요."
        drv_title      = "SD카드 드라이브 선택"
        drv_label      = "이동식 디스크"
        drv_refresh    = "[ 새로고침 ] (SD 카드를 방금 꽂은 경우)"
        drv_footer     = "   [방향키]로 SD카드를 선택하세요. 목록에 없으면 새로고침을 누르세요."
        lbl_copy       = "[복사]"
        lbl_done       = "[완료]"
        comp_title     = "설치 완료!"
        comp_success   = "Yaapu 텔레메트리가 SD카드에 성공적으로 복사되었습니다."
        comp_saved     = "(안내 파일 저장됨: {0})"
        notes_title    = "[ 다시 설치 / 업데이트 ]"
        note_reinstall = "받은 파일을 그대로 두고 다시 실행하면 재다운로드 없이 재설치됩니다."
        note_update    = "최신 버전: {0} 와 {1} 폴더를 지운 뒤 다시 실행하세요."
        exit_msg       = "    아무 키나 누르면 종료됩니다..."
        guide_file     = "Yaapu 설정 방법.txt"
        usb1           = "   1) 조종기 전원을 켜세요"
        usb2           = "   2) 조종기 상단의 USB 단자를 PC 와 연결하세요"
        usb3           = "   3) 조종기에서 USB Storage (SD) 를 선택하세요"
        copy_hint      = "   일시정지: 아무 키       중단: ESC 키"
        paused         = "  [ 일시정지 ] 계속하려면 아무 키, 중단하려면 ESC 를 누르세요"
        copy_aborted   = "복사를 중단했습니다. SD카드 연결을 확인한 뒤 다시 실행하세요."
        copy_fail      = " [에러] 복사 실패. SD카드(USB) 연결과 남은 용량을 확인한 뒤 다시 실행하세요."
        mdl_ask_title  = "드론 모델 설정 (선택)"
        mdl_ask_yes    = "예 - 아두파일럿 드론 모델도 설치"
        mdl_ask_no     = "아니오 - Yaapu만 설치하고 마침"
        mdl_ask_footer = "   ELRS 아두파일럿 드론용 모델과 Yaapu 설정을 조종기에 추가합니다."
        mdl_sel_title  = "대상 모델 선택"
        mdl_sel_footer = "   덮어쓸 모델을 고르거나, 새 슬롯을 만드세요.   [ESC] 취소"
        mdl_recent     = "현재 모델"
        mdl_newslot    = "[ 새 모델 슬롯 만들기 ] (기존 모델은 안 건드림)"
        mdl_back       = "[ 뒤로 ]"
        mdl_factory    = "새 조종기는 여기를 선택하세요"
        mdl_ow_title   = "덮어쓰기 확인"
        mdl_ow_yes     = "예, 이 슬롯을 Drone 모델로 교체"
        mdl_ow_no      = "아니오 (취소)"
        mdl_ow_footer  = "   {0} 슬롯이 'Drone' 모델로 바뀝니다. 기존 파일은 .bak 으로 백업됩니다."
        mdl_no_edgetx  = "[건너뜀] SD카드에서 EdgeTX 모델 폴더(\MODELS)를 찾지 못했습니다."
        mdl_title      = "드론 모델 설치"
        mdl_working    = "모델 / 설정 파일을 복사하고 부팅 모델을 지정하는 중..."
        mdl_done       = "드론 모델 설치 완료!"
    }
    EN = @{
        credit         = "YAAPU AUTO INSTALLER / COPYRIGHT BY FALCONSHOP KOREA"
        footer_nav     = "   [ ↑ / ↓ ] Move      [ Enter ] Select      [ ESC ] Exit"
        model_title    = "Select Radio Model"
        model_mk3      = "TX16S MK3  (5-inch, 800x480 / ExpressLRS built-in)"
        model_mk2      = "TX16S MK2  (4.3-inch, 480x272 / 4in1 or ExpressLRS)"
        confirm_title  = "Confirm Installation"
        confirm_proceed= "Proceed (start install)"
        confirm_cancel = "Cancel"
        confirm_footer = "   Yaapu files will be installed to the SD card from : "
        cancelled      = "Cancelled."
        prep_title     = "Preparing Files"
        dl_connect     = "Connecting to GitHub for the latest Yaapu..."
        dl_progress    = "Downloading the latest Yaapu... ({0} MB / approx. 177 MB)"
        dl_done        = "Download complete!"
        dl_fail        = " [Error] Download failed. Check your internet connection."
        ex_title       = "Extracting Files"
        ex_start       = "Extracting only the required files..."
        ex_progress    = "Extracting... ({0} / {1})"
        ex_done        = "Extraction complete!"
        ex_skip        = "Already extracted, skipping."
        ex_fail        = " [Error] Extraction failed. Delete {0} and run again."
        drv_title      = "Select SD Card Drive"
        drv_label      = "Removable Disk"
        drv_refresh    = "[ Refresh ] (if you just inserted the SD card)"
        drv_footer     = "   Use arrow keys to pick your SD card. Press Refresh if it's not listed."
        lbl_copy       = "[Copy]"
        lbl_done       = "[Done]"
        comp_title     = "Installation Complete!"
        comp_success   = "Yaapu telemetry has been copied to the SD card successfully."
        comp_saved     = "(Guide saved: {0})"
        notes_title    = "[ Reinstall / Update ]"
        note_reinstall = "Keep the files and just run again to reinstall without re-downloading."
        note_update    = "To update: delete {0} and the {1} folder, then run again."
        exit_msg       = "    Press any key to exit..."
        guide_file     = "Yaapu Setup Guide.txt"
        usb1           = "   1) Turn on the radio"
        usb2           = "   2) Connect the radio's top USB port to your PC"
        usb3           = "   3) On the radio, choose USB Storage (SD)"
        copy_hint      = "   Pause: any key       Stop: ESC"
        paused         = "  [ PAUSED ] press any key to resume, or ESC to stop"
        copy_aborted   = "Copying stopped. Check the SD card connection and run again."
        copy_fail      = " [Error] Copy failed. Check the SD card (USB) connection and free space, then run again."
        mdl_ask_title  = "Drone Model Setup (optional)"
        mdl_ask_yes    = "Yes - also install the ArduPilot drone model"
        mdl_ask_no     = "No - finish with Yaapu only"
        mdl_ask_footer = "   Adds an ELRS ArduPilot drone model and Yaapu config to the radio."
        mdl_sel_title  = "Select Target Model"
        mdl_sel_footer = "   Pick a model to overwrite, or create a new slot.   [ESC] Cancel"
        mdl_recent     = "current model"
        mdl_newslot    = "[ Create new model slot ] (existing models untouched)"
        mdl_back       = "[ Back ]"
        mdl_factory    = "new radio: pick this"
        mdl_ow_title   = "Confirm Overwrite"
        mdl_ow_yes     = "Yes, replace this slot with the Drone model"
        mdl_ow_no      = "No (cancel)"
        mdl_ow_footer  = "   {0} will become the 'Drone' model. The old file is backed up as .bak."
        mdl_no_edgetx  = "[Skipped] EdgeTX MODELS folder not found on the SD card."
        mdl_title      = "Drone Model Install"
        mdl_working    = "Copying model & config and setting the boot model..."
        mdl_done       = "Drone model installed!"
    }
}

# ==============================================================================
# Main Logic
# ==============================================================================
try {

# 0. 언어 선택
Clear-Host
Draw-Logo
$langFooter = "   [ ↑ / ↓ ] 이동 / Move      [ Enter ] 선택 / Select      [ ESC ] 종료 / Exit"
$langIdx = Show-Menu "Language / 언어 선택" @("한국어  (Korean)", "English") $langFooter
$LANG = if ($langIdx -eq 0) { "KO" } else { "EN" }
$S = $STRINGS[$LANG]
$CREDIT = $S.credit

# 1. 모델 선택
Clear-Host; Draw-Logo
$models = @($S.model_mk3, $S.model_mk2)
$modelIdx = Show-Menu $S.model_title $models $S.footer_nav
$MODEL = if ($modelIdx -eq 0) { "MK3" } else { "MK2" }
$SRCRES = if ($MODEL -eq "MK3") { "c800x480" } else { "c480x272" }

# 2. 진행 여부 확인
Clear-Host; Draw-Logo
$confirmFooter = $S.confirm_footer + "$PWD"
$confirmIdx = Show-Menu $S.confirm_title @($S.confirm_proceed, $S.confirm_cancel) $confirmFooter
if ($confirmIdx -ne 0) {
    Clear-Host; Draw-Logo
    [Console]::SetCursorPosition(0, 13)
    Write-Host ("    " + $S.cancelled) -ForegroundColor Yellow
    [Console]::CursorVisible = $true
    Start-Sleep 2
    exit
}

# 3. 다운로드 (실시간 Chunk 방식 - 멈춤 현상 완벽 해결)
Clear-Host; Draw-Logo
if (-not (Test-Path $ZIP_NAME)) {
    Draw-ProgressBox $S.prep_title $S.dl_connect 0
    try {
        $req = [System.Net.HttpWebRequest]::Create($ZIP_URL)
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $res = $req.GetResponse()
        $stream = $res.GetResponseStream()
        $fs = New-Object System.IO.FileStream("$PWD\$ZIP_NAME", [System.IO.FileMode]::Create)
        $buffer = New-Object byte[] 8192
        $readBytes = 0
        $targetBytes = 177 * 1024 * 1024 # 약 177MB 기준
        $lastPct = -1

        while (($count = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fs.Write($buffer, 0, $count)
            $readBytes += $count
            $pct = [Math]::Min(99, [Math]::Floor(($readBytes / $targetBytes) * 100))
            if ($pct -ne $lastPct) {
                $mb = [Math]::Round($readBytes / 1MB, 1)
                Draw-ProgressBox $S.prep_title ($S.dl_progress -f $mb) $pct
                $lastPct = $pct
            }
        }
        $fs.Close(); $stream.Close(); $res.Close()
        Draw-ProgressBox $S.prep_title $S.dl_done 100
        Start-Sleep -Seconds 1
    } catch {
        try { $fs.Close() } catch {}
        Remove-Item $ZIP_NAME -ErrorAction SilentlyContinue
        Show-Fatal $S.dl_fail
        exit 1
    }
}

# 4. 압축 해제 (선택한 모델에 필요한 폴더가 이미 있으면 건너뜀)
$exBase = "$PWD\$EX_DIR\OTX_ETX"
$needPaths = @(
    "$exBase\$SRCRES\SD\SCRIPTS",
    "$exBase\$SRCRES\SD\WIDGETS",
    "$exBase\color_common\SD\IMAGES"
)
$alreadyExtracted = (@($needPaths | Where-Object { Test-Path $_ }).Count -eq $needPaths.Count)

if ($alreadyExtracted) {
    Draw-ProgressBox $S.ex_title $S.ex_skip 100
    Start-Sleep -Seconds 1
} else {
    Draw-ProgressBox $S.ex_title $S.ex_start 0
    if (-not (Test-Path $EX_DIR)) { New-Item -ItemType Directory -Path $EX_DIR | Out-Null }
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead("$PWD\$ZIP_NAME")
        $totalEntries = $zip.Entries.Count
        $extracted = 0
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -match "^$EX_DIR/OTX_ETX/($SRCRES|color_common)/SD/(SCRIPTS|WIDGETS|IMAGES)/") {
                $destPath = Join-Path $PWD $entry.FullName
                $dir = Split-Path $destPath
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
                if ($entry.Name -ne "") {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
                }
            }
            $extracted++
            if ($extracted % 50 -eq 0) {
                $pct = [Math]::Min(100, [Math]::Floor(($extracted / $totalEntries) * 100))
                Draw-ProgressBox $S.ex_title ($S.ex_progress -f $extracted, $totalEntries) $pct
            }
        }
        $zip.Dispose()
        Draw-ProgressBox $S.ex_title $S.ex_done 100
        Start-Sleep -Seconds 1
    } catch {
        try { $zip.Dispose() } catch {}
        Show-Fatal ($S.ex_fail -f $ZIP_NAME)
        exit 1
    }
}

# 5. SD 카드 드라이브 선택
while ($true) {
    Clear-Host; Draw-Logo
    $drives = @(Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter })
    $driveOptions = @()
    foreach ($d in $drives) {
        $label = if ($d.FileSystemLabel) { $d.FileSystemLabel } else { $S.drv_label }
        $sizeGB = [Math]::Round($d.Size / 1GB, 1)
        $driveOptions += "[ $($d.DriveLetter):\ ]  $label ($sizeGB GB)"
    }
    $driveOptions += $S.drv_refresh

    $drvIdx = Show-Menu $S.drv_title $driveOptions $S.drv_footer @($S.usb1, $S.usb2, $S.usb3, "")

    if ($drvIdx -lt $drives.Count) {
        $DEST_DRV = "$($drives[$drvIdx].DriveLetter):\"
        break
    }
}

# 6. 대시보드 파일 복사 (픽셀 매칭 레이아웃 적용)
Clear-Host; Draw-Logo
$srcBase = "$PWD\$EX_DIR\OTX_ETX"
$copyPaths = @(
    @{ Src = "$srcBase\$SRCRES\SD\SCRIPTS"; Dest = "$DEST_DRV\SCRIPTS" },
    @{ Src = "$srcBase\$SRCRES\SD\WIDGETS"; Dest = "$DEST_DRV\WIDGETS" },
    @{ Src = "$srcBase\color_common\SD\IMAGES"; Dest = "$DEST_DRV\IMAGES" }
)

$allFiles = @()
foreach ($p in $copyPaths) {
    if (Test-Path $p.Src) {
        $allFiles += Get-ChildItem -Path $p.Src -File -Recurse | Select-Object FullName, @{Name="Dest";Expression={$_.FullName.Replace($p.Src, $p.Dest)}}
    }
}

$totalFiles = $allFiles.Count
$copied = 0
$listCache = New-Object System.Collections.Generic.List[string]
for ($i=0; $i -lt 6; $i++) { $listCache.Add("") }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try { $Host.UI.RawUI.FlushInputBuffer() } catch {}

foreach ($file in $allFiles) {
    # 일시정지 / 중단 처리 (복사 중 키 입력 감지)
    # 키를 떼는 KeyUp 이벤트가 뒤늦게 들어와도 멈추지 않도록, 논블로킹으로 읽고
    # KeyDown(키 누름)일 때만 일시정지로 처리한다.
    if ($Host.UI.RawUI.KeyAvailable) {
        $ev = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
        if ($ev.KeyDown) {
            if ($ev.VirtualKeyCode -eq 27) { Abort-Copy }
            [Console]::SetCursorPosition(0, 23)
            Write-Host (Pad-DisplayRight $S.paused $W) -ForegroundColor Yellow
            while ($true) {
                $rev = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
                if ($rev.KeyDown) {
                    if ($rev.VirtualKeyCode -eq 27) { Abort-Copy }
                    break
                }
            }
            [Console]::SetCursorPosition(0, 23)
            Write-Host (" " * $W)
        }
    }

    $destDir = Split-Path $file.Dest
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }

    [Console]::SetCursorPosition(0, 11)
    Write-Host ("┌─ List " + ("─" * 46) + "┬─ Info " + ("─" * 33) + "┐") -ForegroundColor Cyan

    $shortName = Split-Path $file.Dest -Leaf
    $dirName = (Split-Path (Split-Path $file.Dest) -Leaf) + "/$shortName"
    if ($dirName.Length -gt 44) { $dirName = "..." + $dirName.Substring($dirName.Length - 41) }

    $listCache.RemoveAt(0)
    $listCache.Add($dirName)

    for ($i=0; $i -lt 6; $i++) {
        Write-Host "│ " -ForegroundColor Cyan -NoNewline

        $listPadded = Pad-DisplayRight $listCache[$i] 44
        if ($i -eq 5) {
            Write-Host "$($S.lbl_copy) " -ForegroundColor Yellow -NoNewline
            Write-Host $listPadded -ForegroundColor White -NoNewline
        } else {
            Write-Host "$($S.lbl_done) " -ForegroundColor Green -NoNewline
            Write-Host $listPadded -ForegroundColor DarkGray -NoNewline
        }
        Write-Host " │ " -ForegroundColor Cyan -NoNewline

        $infoText = ""
        if ($i -eq 0) { $infoText = "Target: $DEST_DRV" }
        if ($i -eq 1) { $infoText = "Source: Local ZIP" }
        if ($i -eq 2) {
            $speed = if ($sw.Elapsed.TotalSeconds -gt 0) { ($copied / $sw.Elapsed.TotalSeconds) } else { 0 }
            $infoText = "Speed:  {0:N0} files/s" -f $speed
        }
        if ($i -eq 3) { $infoText = "Files:  $copied / $totalFiles" }
        if ($i -eq 4) { $infoText = "Status: Copying files..." }

        $infoPadded = Pad-DisplayRight $infoText 39
        if ($i -eq 2) { Write-Host $infoPadded -ForegroundColor Yellow -NoNewline }
        elseif ($i -eq 4) { Write-Host $infoPadded -ForegroundColor Cyan -NoNewline }
        else { Write-Host $infoPadded -ForegroundColor White -NoNewline }

        Write-Host "│" -ForegroundColor Cyan
    }
    Write-Host ("└" + ("─" * 53) + "┴" + ("─" * 40) + "┘") -ForegroundColor Cyan

    $pct = if ($totalFiles -gt 0) { [Math]::Floor(($copied / $totalFiles) * 100) } else { 100 }
    $barLen = 86
    $filled = [Math]::Floor(($pct / 100) * $barLen)
    $barStr = ("█" * $filled) + ("░" * ($barLen - $filled))

    Write-Host ("┌─ Gauge " + ("─" * 86) + "┐") -ForegroundColor Cyan
    Write-Host "│ " -ForegroundColor Cyan -NoNewline
    Write-Host $barStr -ForegroundColor Magenta -NoNewline
    Write-Host (" {0,4}% " -f $pct) -ForegroundColor White -NoNewline
    Write-Host "│" -ForegroundColor Cyan
    Write-Host ("└" + ("─" * 94) + "┘") -ForegroundColor Cyan
    Write-Host (Pad-DisplayRight $S.copy_hint $W) -ForegroundColor DarkGray

    try {
        Copy-Item -Path $file.FullName -Destination $file.Dest -Force
    } catch {
        Show-Fatal $S.copy_fail
        exit 1
    }
    $copied++
}

# ==============================================================================
# 6.5 드론 모델 설정 복사 (MK3 전용, 작업폴더에 template 파일이 있을 때만)
# ==============================================================================
$modelInstalled = $false
$mdlTargetFile  = ""
$mdlBackupFile  = ""
$templateModel  = "$PWD\model1.yml"

if ($MODEL -eq "MK3" -and (Test-Path $templateModel)) {
    $modelsDir  = Join-Path $DEST_DRV "MODELS"
    $labelsPath = Join-Path $modelsDir "labels.yml"
    $radioPath  = Join-Path (Join-Path $DEST_DRV "RADIO") "radio.yml"
    $cfgDir     = Join-Path $DEST_DRV "WIDGETS\yaapu\cfg"

    # 공장 출고(미설정) 판정용 원본 (있을 때만). 휘발성 필드(modelRegistrationID) 제거 후 비교.
    $factoryNorm = $null
    if (Test-Path "$PWD\factory_model1.yml") {
        $factoryNorm = ([System.IO.File]::ReadAllText("$PWD\factory_model1.yml", [System.Text.Encoding]::UTF8)) -replace "`r", ""
        $factoryNorm = ([regex]::Replace($factoryNorm, '(?m)^modelRegistrationID:.*$', '')).Trim()
    }

    # 현재(부팅) 모델 = radio.yml 의 currModelFilename (lastopen 보다 정확)
    $currentModel = ""
    if (Test-Path $radioPath) {
        $rtxt0 = [System.IO.File]::ReadAllText($radioPath, [System.Text.Encoding]::UTF8)
        if ($rtxt0 -match '(?m)^currModelFilename:\s*"([^"]*)"') { $currentModel = $matches[1] }
    }

    $askDone = $false
    while (-not $askDone) {
        Clear-Host; Draw-Logo
        $askIdx = Show-Menu $S.mdl_ask_title @($S.mdl_ask_yes, $S.mdl_ask_no) $S.mdl_ask_footer
        if ($askIdx -ne 0) { break }   # 아니오 -> 모델 설정 건너뜀

        if (-not (Test-Path $labelsPath)) {
            Clear-Host; Draw-Logo
            [Console]::SetCursorPosition(0, 13)
            Write-Host ("    " + $S.mdl_no_edgetx) -ForegroundColor Yellow
            Start-Sleep -Seconds 3
            break
        }

        # labels.yml 파싱 -> 모델 목록 (파일명 / 이름 / lastopen)
        $mdlList = @(); $cur = $null
        foreach ($line in (Get-Content -Path $labelsPath -Encoding UTF8)) {
            if ($line -match '^\s+([A-Za-z0-9_]+\.yml):\s*$') {
                if ($cur) { $mdlList += ,$cur }
                $cur = [pscustomobject]@{ File = $matches[1]; Name = ""; LastOpen = [int64]0; IsFactory = $false }
            } elseif ($cur -and $line -match '^\s+name:\s*"(.*)"\s*$') {
                $cur.Name = $matches[1]
            } elseif ($cur -and $line -match '^\s+lastopen:\s*(\d+)') {
                $cur.LastOpen = [int64]$matches[1]
            }
        }
        if ($cur) { $mdlList += ,$cur }

        $maxOpen = 0
        foreach ($m in $mdlList) { if ($m.LastOpen -gt $maxOpen) { $maxOpen = $m.LastOpen } }

        # 공장 출고 상태(원본과 동일) 슬롯 판정
        if ($factoryNorm) {
            foreach ($m in $mdlList) {
                $mp = Join-Path $modelsDir $m.File
                if (Test-Path $mp) {
                    $mn = ([System.IO.File]::ReadAllText($mp, [System.Text.Encoding]::UTF8)) -replace "`r", ""
                    $mn = ([regex]::Replace($mn, '(?m)^modelRegistrationID:.*$', '')).Trim()
                    if ($mn -eq $factoryNorm) { $m.IsFactory = $true }
                }
            }
        }

        # 모델 선택 메뉴 (모델들 + 새 슬롯 + 뒤로)
        $mdlOptions = @()
        foreach ($m in $mdlList) {
            $star = ""
            if ($m.IsFactory) { $star = "  * " + $S.mdl_factory }
            elseif ($currentModel -and $m.File -eq $currentModel) { $star = "  * " + $S.mdl_recent }
            elseif (-not $currentModel -and $m.LastOpen -eq $maxOpen -and $maxOpen -gt 0) { $star = "  * " + $S.mdl_recent }
            $nm = if ($m.Name) { $m.Name } else { "-" }
            $mdlOptions += ("{0}   [ {1} ]{2}" -f $m.File, $nm, $star)
        }
        $newSlotIdx = $mdlList.Count
        $backIdx    = $mdlList.Count + 1
        $mdlOptions += $S.mdl_newslot
        $mdlOptions += $S.mdl_back

        # 모델 선택 루프 (덮어쓰기 취소 시 이 메뉴로 복귀)
        $leaveSel = $false
        while (-not $leaveSel) {
            Clear-Host; Draw-Logo
            $selIdx = Show-Menu $S.mdl_sel_title $mdlOptions $S.mdl_sel_footer

            if ($selIdx -eq $backIdx) { $leaveSel = $true; break }   # 뒤로 -> 이전(설정 여부) 화면

            if ($selIdx -lt $mdlList.Count) {
                $mdlTargetFile = $mdlList[$selIdx].File
                Clear-Host; Draw-Logo
                $owIdx = Show-Menu $S.mdl_ow_title @($S.mdl_ow_yes, $S.mdl_ow_no) ($S.mdl_ow_footer -f $mdlTargetFile)
                if ($owIdx -ne 0) { continue }   # 아니오 -> 모델 선택 메뉴로 복귀
            } else {
                $maxN = 0
                Get-ChildItem -Path $modelsDir -Filter "model*.yml" -File -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.Name -match '^model(\d+)\.yml$') { $n = [int]$matches[1]; if ($n -gt $maxN) { $maxN = $n } }
                }
                $mdlTargetFile = "model$($maxN + 1).yml"
            }

            # ===== 복사 실행 =====
            Clear-Host; Draw-Logo
            Draw-ProgressBox $S.mdl_title $S.mdl_working 25
            $newLast = $maxOpen + 1
            $mdlBackupFile = ""

            # 1) 모델 파일: 기존이면 백업 후 템플릿 복사 (바이트 그대로)
            $destModelPath = Join-Path $modelsDir $mdlTargetFile
            if (Test-Path $destModelPath) {
                $mdlBackupFile = "$mdlTargetFile.bak"
                Copy-Item $destModelPath (Join-Path $modelsDir $mdlBackupFile) -Force
            }
            Copy-Item $templateModel $destModelPath -Force

            # 2) Yaapu config (drone.cfg / drone.reload)
            if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
            if (Test-Path "$PWD\drone.cfg")    { Copy-Item "$PWD\drone.cfg"    (Join-Path $cfgDir "drone.cfg")    -Force }
            if (Test-Path "$PWD\drone.reload") { Copy-Item "$PWD\drone.reload" (Join-Path $cfgDir "drone.reload") -Force }

            Draw-ProgressBox $S.mdl_title $S.mdl_working 55

            # 3) labels.yml 갱신 (백업 후, BOM 없는 UTF-8 / CRLF 유지)
            Copy-Item $labelsPath "$labelsPath.bak" -Force
            $existsInLabels = $false
            foreach ($m in $mdlList) { if ($m.File -eq $mdlTargetFile) { $existsInLabels = $true } }
            if ($existsInLabels) {
                $lines = ([System.IO.File]::ReadAllText($labelsPath, [System.Text.Encoding]::UTF8)) -split "`r`n|`n"
                $inBlock = $false; $out = @()
                foreach ($line in $lines) {
                    if ($line -match '^\s+([A-Za-z0-9_]+\.yml):\s*$') {
                        $inBlock = ($matches[1] -eq $mdlTargetFile)
                        $out += $line
                    } elseif ($inBlock -and $line -match '^(\s+)name:\s*".*"\s*$') {
                        $out += ('{0}name: "Drone"' -f $matches[1])
                    } elseif ($inBlock -and $line -match '^(\s+)lastopen:\s*\d+\s*$') {
                        $out += ('{0}lastopen: {1}' -f $matches[1], $newLast)
                    } else {
                        $out += $line
                    }
                }
                Write-Utf8NoBom $labelsPath ($out -join "`r`n")
            } else {
                $block = @(
                    ("  {0}:" -f $mdlTargetFile),
                    '    hash: "b05500003728772a"',
                    '    name: "Drone"',
                    '    mod0type: 5',
                    '    labels: "Favorites,RADIOMASTER"',
                    '    bitmap: ""',
                    ("    lastopen: {0}" -f $newLast)
                ) -join "`r`n"
                $raw = ([System.IO.File]::ReadAllText($labelsPath, [System.Text.Encoding]::UTF8)).TrimEnd("`r","`n"," ","`t")
                Write-Utf8NoBom $labelsPath ($raw + "`r`n" + $block + "`r`n")
            }

            Draw-ProgressBox $S.mdl_title $S.mdl_working 80

            # 4) radio.yml: 부팅 자동선택 (currModelFilename + manuallyEdited=1), 그 두 줄만 치환
            if (Test-Path $radioPath) {
                Copy-Item $radioPath "$radioPath.bak" -Force
                $rtext = [System.IO.File]::ReadAllText($radioPath, [System.Text.Encoding]::UTF8)
                $rtext = [regex]::Replace($rtext, '(?m)^currModelFilename:[^\r\n]*', ('currModelFilename: "{0}"' -f $mdlTargetFile))
                $rtext = [regex]::Replace($rtext, '(?m)^manuallyEdited:[^\r\n]*', 'manuallyEdited: 1')
                Write-Utf8NoBom $radioPath $rtext
            }

            Draw-ProgressBox $S.mdl_title $S.mdl_done 100
            Start-Sleep -Seconds 1
            $modelInstalled = $true
            $leaveSel = $true
            $askDone  = $true
        }
    }
}

# ==============================================================================
# 7-8(드론). 모델까지 설치한 경우 전용 안내 (txt 저장 + 화면 출력)
# ==============================================================================
if ($modelInstalled) {
    $GuideFile = $S.guide_file
    $guideText = @()
    if ($LANG -eq "KO") {
        $guideText += "============================================"
        $guideText += " Yaapu + 드론 모델 - TX16S MK3 (ExpressLRS)"
        $guideText += "============================================"
        $guideText += ""
        $guideText += " 조종기를 켜면 'Drone' 모델로 시작합니다. (슬롯: $mdlTargetFile)"
        if ($mdlBackupFile) { $guideText += " 기존 모델 백업: MODELS\$mdlBackupFile" }
        $guideText += " Yaapu 설정(Enable CRSF / Disable sounds)은 자동 적용되었습니다."
        $guideText += ""
        $guideText += "[ 조종기(TX) 설정 ]"
        $guideText += " SYS > ExpressLRS : Telem Ratio = 1:2, Packet Rate = 333Hz"
        $guideText += " 야푸 소리를 듣고 싶으면 : SYS > Yaapu config > Disable all sounds = no"
        $guideText += ""
        $guideText += "[ ArduPilot 설정 ]"
        $guideText += " RC_OPTIONS : 8960"
        $guideText += " FLTMODE_CH : 6   (ELRS는 CH5가 2단이라 비행모드를 CH6=SE에 둠)"
        $guideText += "============================================"
    } else {
        $guideText += "============================================"
        $guideText += " Yaapu + Drone Model - TX16S MK3 (ExpressLRS)"
        $guideText += "============================================"
        $guideText += ""
        $guideText += " On power-up the radio starts on the 'Drone' model. (slot: $mdlTargetFile)"
        if ($mdlBackupFile) { $guideText += " Old model backed up: MODELS\$mdlBackupFile" }
        $guideText += " Yaapu config (Enable CRSF / Disable sounds) was applied automatically."
        $guideText += ""
        $guideText += "[ Radio (TX) settings ]"
        $guideText += " SYS > ExpressLRS : Telem Ratio = 1:2, Packet Rate = 333Hz"
        $guideText += " To hear Yaapu sounds : SYS > Yaapu config > Disable all sounds = no"
        $guideText += ""
        $guideText += "[ ArduPilot settings ]"
        $guideText += " RC_OPTIONS : 8960"
        $guideText += " FLTMODE_CH : 6   (ELRS CH5 is 2-pos, so flight mode is on CH6=SE)"
        $guideText += "============================================"
    }
    $guideText | Out-File -FilePath "$PWD\$GuideFile" -Encoding UTF8

    $g_boot    = if ($LANG -eq "KO") { "조종기를 켜면 'Drone' 모델로 시작합니다.  (슬롯: $mdlTargetFile)" } else { "On power-up the radio starts on the 'Drone' model.  (slot: $mdlTargetFile)" }
    $g_backup  = if ($LANG -eq "KO") { "기존 모델은 백업되었습니다: MODELS\$mdlBackupFile" } else { "Old model backed up: MODELS\$mdlBackupFile" }
    $g_applied = if ($LANG -eq "KO") { "Yaapu 설정(Enable CRSF / Disable sounds)은 자동 적용되었습니다." } else { "Yaapu config (Enable CRSF / Disable sounds) applied automatically." }
    $g_txhdr   = if ($LANG -eq "KO") { "[ 조종기(TX) 설정 ]" } else { "[ Radio (TX) settings ]" }
    $g_sound   = if ($LANG -eq "KO") { "야푸 소리를 듣고 싶으면 : SYS > Yaapu config > Disable all sounds = no" } else { "To hear Yaapu sounds : SYS > Yaapu config > Disable all sounds = no" }
    $g_aphdr   = if ($LANG -eq "KO") { "[ ArduPilot 설정 ]" } else { "[ ArduPilot settings ]" }
    $g_fltmode = if ($LANG -eq "KO") { "FLTMODE_CH : 6   (ELRS는 CH5가 2단이라 비행모드를 CH6=SE에 둠)" } else { "FLTMODE_CH : 6   (ELRS CH5 is 2-pos, flight mode on CH6=SE)" }

    Clear-Host; Draw-Logo
    [Console]::SetCursorPosition(0, 11)
    $dashCount = $W - (Get-DisplayLength $S.comp_title) - 5
    Write-Host ("┌─ $($S.comp_title) " + ("─" * $dashCount) + "┐") -ForegroundColor Green
    Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Green
    Write-Host ("│  " + (Pad-DisplayRight $g_boot ($W - 5)) + " │") -ForegroundColor White
    if ($mdlBackupFile) { Write-Host ("│  " + (Pad-DisplayRight $g_backup ($W - 5)) + " │") -ForegroundColor DarkGray }
    Write-Host ("│  " + (Pad-DisplayRight $g_applied ($W - 5)) + " │") -ForegroundColor Cyan
    Write-Host ("│  " + (Pad-DisplayRight ($S.comp_saved -f $GuideFile) ($W - 5)) + " │") -ForegroundColor DarkGray
    Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Green
    Write-Host ("│  " + (Pad-DisplayRight $g_txhdr ($W - 5)) + " │") -ForegroundColor Yellow
    Write-Host ("│   " + (Pad-DisplayRight "SYS > ExpressLRS : Telem Ratio = 1:2, Packet Rate = 333Hz" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│   " + (Pad-DisplayRight $g_sound ($W - 6)) + " │") -ForegroundColor White
    Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Green
    Write-Host ("│  " + (Pad-DisplayRight $g_aphdr ($W - 5)) + " │") -ForegroundColor Yellow
    Write-Host ("│   " + (Pad-DisplayRight "RC_OPTIONS : 8960" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│   " + (Pad-DisplayRight $g_fltmode ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("└" + ("─" * ($W - 2)) + "┘") -ForegroundColor Green
    Write-Host $S.exit_msg -ForegroundColor DarkGray

    Wait-AnyKey
    [Console]::CursorVisible = $true
    exit
}

# 7. 설정 안내 파일(txt) 작성
$GuideFile = $S.guide_file
$guideText = @()
if ($LANG -eq "KO") {
    if ($MODEL -eq "MK3") {
        $guideText += "============================================"
        $guideText += " Yaapu 설정 방법 - TX16S MK3 (ExpressLRS)"
        $guideText += "============================================"
        $guideText += ""
        $guideText += "[ 1. 조종기(TX) 설정 ]"
        $guideText += ""
        $guideText += " SYS > ExpressLRS"
        $guideText += "     Telem Ratio  = 1:2"
        $guideText += "     Packet Rate  = 333Hz"
        $guideText += ""
        $guideText += " SYS > Yaapu config"
        $guideText += "     Enable CRSF        : yes"
        $guideText += "     Disable all sounds : yes"
        $guideText += "        ( yes = 음소거. 소리를 들으려면 기본값 no 로 둘 것 )"
        $guideText += ""
        $guideText += "[ 2. ArduPilot 설정 ]"
        $guideText += ""
        $guideText += "     RC_OPTIONS : 8960"
        $guideText += "============================================"
    } else {
        $guideText += "============================================"
        $guideText += " Yaapu 설정 방법 - TX16S MK2"
        $guideText += "============================================"
        $guideText += ""
        $guideText += " MK2 는 사용하는 RF 모듈에 따라 설정이 다릅니다."
        $guideText += " 본인 모듈에 맞는 항목만 따르세요."
        $guideText += ""
        $guideText += "----- [ ExpressLRS 모듈인 경우 ] -----"
        $guideText += " [TX] SYS > ExpressLRS : Telem Ratio = 1:2, Packet Rate = 333Hz"
        $guideText += " [TX] SYS > Yaapu config : Enable CRSF = yes, Disable all sounds = yes"
        $guideText += "        ( yes = 음소거. 소리를 들으려면 기본값 no )"
        $guideText += " [ArduPilot] RC_OPTIONS : 8960"
        $guideText += ""
        $guideText += "----- [ 4in1 (FrSky) 모듈인 경우 ] -----"
        $guideText += " [ArduPilot] SERIALx_PROTOCOL : 10 (FrSky SPort Passthrough)"
        $guideText += " [ArduPilot] SERIALx_OPTIONS  : 7"
        $guideText += " [ArduPilot] RSSI_TYPE        : 3"
        $guideText += "        ( x = 텔레메트리 배선이 연결된 시리얼 포트 번호 )"
        $guideText += "============================================"
    }
    $guideText += ""
    $guideText += "[ 다시 설치 / 업데이트 ]"
    $guideText += " 받은 파일을 그대로 두고 다시 실행하면 재다운로드 없이 재설치됩니다."
    $guideText += " 최신 버전은 $ZIP_NAME 와 $EX_DIR 폴더를 지운 뒤 다시 실행하세요."
} else {
    if ($MODEL -eq "MK3") {
        $guideText += "============================================"
        $guideText += " Yaapu Setup Guide - TX16S MK3 (ExpressLRS)"
        $guideText += "============================================"
        $guideText += ""
        $guideText += "[ 1. Radio (TX) settings ]"
        $guideText += ""
        $guideText += " SYS > ExpressLRS"
        $guideText += "     Telem Ratio  = 1:2"
        $guideText += "     Packet Rate  = 333Hz"
        $guideText += ""
        $guideText += " SYS > Yaapu config"
        $guideText += "     Enable CRSF        : yes"
        $guideText += "     Disable all sounds : yes"
        $guideText += "        ( yes = mute. set to default no to hear sounds )"
        $guideText += ""
        $guideText += "[ 2. ArduPilot settings ]"
        $guideText += ""
        $guideText += "     RC_OPTIONS : 8960"
        $guideText += "============================================"
    } else {
        $guideText += "============================================"
        $guideText += " Yaapu Setup Guide - TX16S MK2"
        $guideText += "============================================"
        $guideText += ""
        $guideText += " MK2 settings depend on your RF module."
        $guideText += " Follow only the section that matches your module."
        $guideText += ""
        $guideText += "----- [ If ExpressLRS module ] -----"
        $guideText += " [TX] SYS > ExpressLRS : Telem Ratio = 1:2, Packet Rate = 333Hz"
        $guideText += " [TX] SYS > Yaapu config : Enable CRSF = yes, Disable all sounds = yes"
        $guideText += "        ( yes = mute. set to default no to hear sounds )"
        $guideText += " [ArduPilot] RC_OPTIONS : 8960"
        $guideText += ""
        $guideText += "----- [ If 4in1 (FrSky) module ] -----"
        $guideText += " [ArduPilot] SERIALx_PROTOCOL : 10 (FrSky SPort Passthrough)"
        $guideText += " [ArduPilot] SERIALx_OPTIONS  : 7"
        $guideText += " [ArduPilot] RSSI_TYPE        : 3"
        $guideText += "        ( x = the serial port your telemetry wire uses )"
        $guideText += "============================================"
    }
    $guideText += ""
    $guideText += "[ Reinstall / Update ]"
    $guideText += " Keep the files and run again to reinstall without re-downloading."
    $guideText += " To update, delete $ZIP_NAME and the $EX_DIR folder, then run again."
}
$guideText | Out-File -FilePath "$PWD\$GuideFile" -Encoding UTF8

# 8. 완료 화면 출력
Clear-Host; Draw-Logo
[Console]::SetCursorPosition(0, 11)
$dashCount = $W - (Get-DisplayLength $S.comp_title) - 5
Write-Host ("┌─ $($S.comp_title) " + ("─" * $dashCount) + "┐") -ForegroundColor Green
Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Green
Write-Host ("│  " + (Pad-DisplayRight $S.comp_success ($W - 5)) + " │") -ForegroundColor White
Write-Host ("│  " + (Pad-DisplayRight ($S.comp_saved -f $GuideFile) ($W - 5)) + " │") -ForegroundColor DarkGray

if ($MODEL -eq "MK3") {
    $h1 = if ($LANG -eq "KO") { "[ 1. 조종기(TX) 설정 - MK3 ExpressLRS 기준 ]" } else { "[ 1. Radio (TX) settings - MK3 ExpressLRS ]" }
    $muteNote = if ($LANG -eq "KO") { "( yes = 음소거. 소리를 들으려면 기본값 no )" } else { "( yes = mute. set to default no to hear sounds )" }
    $h2 = if ($LANG -eq "KO") { "[ 2. ArduPilot 설정 ]" } else { "[ 2. ArduPilot settings ]" }
    Write-Host ("│  " + (Pad-DisplayRight $h1 ($W - 5)) + " │") -ForegroundColor Yellow
    Write-Host ("│   " + (Pad-DisplayRight "SYS > ExpressLRS" ($W - 6)) + " │") -ForegroundColor White
    Write-Host ("│       " + (Pad-DisplayRight "Telem Ratio  = 1:2" ($W - 10)) + " │") -ForegroundColor Cyan
    Write-Host ("│       " + (Pad-DisplayRight "Packet Rate  = 333Hz" ($W - 10)) + " │") -ForegroundColor Cyan
    Write-Host ("│   " + (Pad-DisplayRight "SYS > Yaapu config" ($W - 6)) + " │") -ForegroundColor White
    Write-Host ("│       " + (Pad-DisplayRight "Enable CRSF        : yes" ($W - 10)) + " │") -ForegroundColor Cyan
    Write-Host ("│       " + (Pad-DisplayRight "Disable all sounds : yes" ($W - 10)) + " │") -ForegroundColor Cyan
    Write-Host ("│          " + (Pad-DisplayRight $muteNote ($W - 13)) + " │") -ForegroundColor DarkGray
    Write-Host ("│  " + (Pad-DisplayRight $h2 ($W - 5)) + " │") -ForegroundColor Yellow
    Write-Host ("│       " + (Pad-DisplayRight "RC_OPTIONS : 8960" ($W - 10)) + " │") -ForegroundColor Cyan
} else {
    $h1     = if ($LANG -eq "KO") { "[ ExpressLRS 모듈인 경우 ]" } else { "[ If ExpressLRS module ]" }
    $h2     = if ($LANG -eq "KO") { "[ 4in1 (FrSky) 모듈인 경우 ]" } else { "[ If 4in1 (FrSky) module ]" }
    $intro1 = if ($LANG -eq "KO") { "MK2는 사용하는 RF 모듈에 따라 설정이 다릅니다." } else { "MK2 settings depend on your RF module." }
    $intro2 = if ($LANG -eq "KO") { "본인 모듈에 맞는 항목만 따르세요." } else { "Follow only the section that matches your module." }
    $muteNote = if ($LANG -eq "KO") { "( yes = 음소거. 소리를 들으려면 기본값 no )" } else { "( yes = mute. set to default no to hear sounds )" }
    $portNote = if ($LANG -eq "KO") { "( x = 텔레메트리 배선이 연결된 시리얼 포트 번호 )" } else { "( x = the serial port your telemetry wire uses )" }
    Write-Host ("│  " + (Pad-DisplayRight $intro1 ($W - 5)) + " │") -ForegroundColor White
    Write-Host ("│  " + (Pad-DisplayRight $intro2 ($W - 5)) + " │") -ForegroundColor White
    Write-Host ("│  " + (Pad-DisplayRight $h1 ($W - 5)) + " │") -ForegroundColor Yellow
    Write-Host ("│   " + (Pad-DisplayRight "SYS > ExpressLRS : Telem Ratio = 1:2, Packet Rate = 333Hz" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│   " + (Pad-DisplayRight "SYS > Yaapu config : Enable CRSF = yes, Disable all sounds = yes" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│          " + (Pad-DisplayRight $muteNote ($W - 13)) + " │") -ForegroundColor DarkGray
    Write-Host ("│   " + (Pad-DisplayRight "ArduPilot : RC_OPTIONS = 8960" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│  " + (Pad-DisplayRight $h2 ($W - 5)) + " │") -ForegroundColor Yellow
    Write-Host ("│   " + (Pad-DisplayRight "ArduPilot : SERIALx_PROTOCOL = 10, SERIALx_OPTIONS = 7" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│   " + (Pad-DisplayRight "ArduPilot : RSSI_TYPE = 3" ($W - 6)) + " │") -ForegroundColor Cyan
    Write-Host ("│          " + (Pad-DisplayRight $portNote ($W - 13)) + " │") -ForegroundColor DarkGray
}

Write-Host ("│" + (" " * ($W - 2)) + "│") -ForegroundColor Green
Write-Host ("│  " + (Pad-DisplayRight $S.notes_title ($W - 5)) + " │") -ForegroundColor Yellow
Write-Host ("│   " + (Pad-DisplayRight $S.note_reinstall ($W - 6)) + " │") -ForegroundColor DarkGray
Write-Host ("│   " + (Pad-DisplayRight ($S.note_update -f $ZIP_NAME, $EX_DIR) ($W - 6)) + " │") -ForegroundColor DarkGray
Write-Host ("└" + ("─" * ($W - 2)) + "┘") -ForegroundColor Green
Write-Host $S.exit_msg -ForegroundColor DarkGray

Wait-AnyKey
[Console]::CursorVisible = $true

}
catch {
    Show-Fatal ("[Error] " + $_.Exception.Message)
    exit 1
}
finally {
    [Console]::CursorVisible = $true
}
