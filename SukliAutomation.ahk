; ============================================================
; SUKLI AUTOMATION v3 - GUI Edition (No Emojis)
; ============================================================
; HOTKEYS:
;   F1  - Show Main GUI
;   F2  - Toggle auto-detect macro ON/OFF
;   F3  - Force Roblox into windowed mode
;   F4  - Emergency stop
;   F5  - Manual trigger (open entry form)
;   F6  - Calibrate denomination button positions
;   F7  - Calibrate sukli-screen detection color
;   F9  - Show today's totals
; ============================================================

#NoEnv
#SingleInstance, Force
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen

; ============================================================
; READ CONFIGURATION
; ============================================================
ConfigFile := A_ScriptDir . "\sukli_config.ini"
LogFile := A_ScriptDir . "\sukli_log.csv"
ScreenWidth := 1920
ScreenHeight := 1080
RouteName := "Balagtas"
SukliColor := "0xFFFFFF"
SukliCheckRelX := 0.50
SukliCheckRelY := 0.30

if (FileExist(ConfigFile)) {
    IniRead, tempWidth, %ConfigFile%, Settings, ScreenWidth, 1920
    IniRead, tempHeight, %ConfigFile%, Settings, ScreenHeight, 1080
    IniRead, tempRoute, %ConfigFile%, Settings, Route, Balagtas
    IniRead, tempColor, %ConfigFile%, Settings, SukliColor, 0xFFFFFF
    IniRead, tempCheckX, %ConfigFile%, Settings, SukliCheckRelX, 0.50
    IniRead, tempCheckY, %ConfigFile%, Settings, SukliCheckRelY, 0.30
    ScreenWidth := tempWidth
    ScreenHeight := tempHeight
    RouteName := tempRoute
    SukliColor := tempColor
    SukliCheckRelX := tempCheckX
    SukliCheckRelY := tempCheckY
} else {
    MsgBox, 16, Error, sukli_config.ini not found!`nPlease create it first.
    ExitApp
}

; Create log file if it doesn't exist
if (!FileExist(LogFile)) {
    FileAppend, Timestamp,Route,Destination,Passengers,Type,Payment,Fare,Sukli`n, %LogFile%
}

; ============================================================
; ROUTE DATA
; ============================================================
RouteData := {}
RouteData["Balagtas"] := ["Bagumbayan/San Jose", "Matungao", "Panginay Guiguinto", "Panginay Balagtas", "Wawa"]
RouteData["Guiguinto"] := ["Bagumbayan/San Jose", "Matungao", "Tuktukan"]
RouteData["Malolos"] := ["Bagumbayan/San Jose", "Maysantol", "San Nicolas", "Pitpitan", "Mambog", "Matimbo", "Panasahan", "Bagna", "Atlag", "San Juan/Sto. Rosario"]

; ============================================================
; FARE SETTINGS
; ============================================================
regularFare := 13
studentFare := 11
seniorFare := 11
extraFare := 2
minUnits := 4

; ============================================================
; DENOMINATIONS
; ============================================================
Denominations := [50, 20, 10, 5, 1]

DenomPositions := {}
DenomPositions[50] := {x: 0.30, y: 0.40}
DenomPositions[20] := {x: 0.40, y: 0.40}
DenomPositions[10] := {x: 0.50, y: 0.40}
DenomPositions[5]  := {x: 0.60, y: 0.40}
DenomPositions[1]  := {x: 0.70, y: 0.40}

; Load calibrated positions
for i, denom in Denominations {
    IniRead, savedX, %ConfigFile%, DenomPositions, %denom%_x, NONE
    IniRead, savedY, %ConfigFile%, DenomPositions, %denom%_y, NONE
    if (savedX != "NONE" and savedY != "NONE") {
        DenomPositions[denom] := {x: savedX, y: savedY}
    }
}

; ============================================================
; VARIABLES
; ============================================================
macroRunning := false
WinTitle := "Roblox"
ImageDir := A_ScriptDir . "\sukli_images\"
g_EntryContext := {}

; ============================================================
; MAIN GUI
; ============================================================
MainGUI:
    Gui, MainGui:New, +AlwaysOnTop +ToolWindow, Sukli Automation v3
    Gui, MainGui:Color, 1A2415, 1A2415
    
    ; Title
    Gui, MainGui:Font, s16 cF3B22C bold, Anton
    Gui, MainGui:Add, Text, x10 y10 w260 h30 Center, Fare Matrix Auto Sukli
    Gui, MainGui:Font, s9 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y40 w260 h20 Center, Diesel N' Steel - Roblox

    ; Status Section
    Gui, MainGui:Font, s10 cF1E9D2 bold, Oswald
    Gui, MainGui:Add, Text, x10 y70 w80 h20, Status:
    Gui, MainGui:Font, s10 cF1E9D2, Oswald
    Gui, MainGui:Add, Text, x95 y70 w170 h20 vMainStatus, [X] Stopped
    
    Gui, MainGui:Font, s9 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y95 w80 h20, Route:
    Gui, MainGui:Font, s9 cF3B22C, Oswald
    Gui, MainGui:Add, Text, x95 y95 w170 h20 vMainRoute, %RouteName%
    
    Gui, MainGui:Add, Text, x10 y120 w80 h20, Detection:
    Gui, MainGui:Font, s9 c6FA05B, Oswald
    Gui, MainGui:Add, Text, x95 y120 w170 h20 vMainDetect, [..] Waiting...

    ; Separator
    Gui, MainGui:Font, s10 c3A4530, Oswald
    Gui, MainGui:Add, Text, x10 y145 w260 h2 Background3A4530, 

    ; Buttons
    Gui, MainGui:Font, s11 cFFFFFF bold, Oswald
    Gui, MainGui:Add, Button, x10 y155 w120 h35 gStartMacro vMainStartBtn, Start (F2)
    Gui, MainGui:Add, Button, x140 y155 w130 h35 gStopMacro vMainStopBtn, Stop (F4)
    
    Gui, MainGui:Font, s9 cFFFFFF, Oswald
    Gui, MainGui:Add, Button, x10 y200 w80 h30 gManualTrigger, Entry
    Gui, MainGui:Add, Button, x100 y200 w80 h30 gCalibrateDenom, Calibrate
    Gui, MainGui:Add, Button, x190 y200 w80 h30 gCalibrateColor, Color
    Gui, MainGui:Add, Button, x10 y240 w80 h30 gShowTotals, Totals
    Gui, MainGui:Add, Button, x100 y240 w80 h30 gSelectRoute, Route
    Gui, MainGui:Add, Button, x190 y240 w80 h30 gSettingsMenu, Settings

    ; Footer
    Gui, MainGui:Font, s8 c6FA05B, Oswald
    Gui, MainGui:Add, Text, x10 y280 w260 h15 Center, Press F1 to show this window
    Gui, MainGui:Font, s7 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y300 w260 h15 Center, Made by Aizen

    Gui, MainGui:Show, w280 h320, Sukli Automation v3
return

; ============================================================
; GUI BUTTON ACTIONS
; ============================================================

StartMacro:
    Gosub, F2_Action
return

StopMacro:
    Gosub, F4_Action
return

ManualTrigger:
    Gosub, F5_Action
return

CalibrateDenom:
    Gosub, F6_Action
return

CalibrateColor:
    Gosub, F7_Action
return

ShowTotals:
    Gosub, F9_Action
return

SelectRoute:
    Gosub, F1_Action
return

SettingsMenu:
    Gosub, SettingsAction
return

; ============================================================
; SETTINGS GUI
; ============================================================
SettingsAction:
    Gui, SettingsGui:New, +AlwaysOnTop +ToolWindow, Settings
    Gui, SettingsGui:Color, 1A2415, 1A2415
    Gui, SettingsGui:Font, s11 cF1E9D2 bold, Oswald
    Gui, SettingsGui:Add, Text, x10 y10 w220 h25 Center, Settings
    
    Gui, SettingsGui:Font, s9 cC9BE9E, Oswald
    Gui, SettingsGui:Add, Text, x10 y45 w80 h20, Screen Width:
    Gui, SettingsGui:Add, Edit, x100 y42 w120 h20 vSettingsWidth, %ScreenWidth%
    
    Gui, SettingsGui:Add, Text, x10 y70 w80 h20, Screen Height:
    Gui, SettingsGui:Add, Edit, x100 y67 w120 h20 vSettingsHeight, %ScreenHeight%
    
    Gui, SettingsGui:Add, Text, x10 y95 w80 h20, Detection Color:
    Gui, SettingsGui:Add, Edit, x100 y92 w120 h20 vSettingsColor, %SukliColor%
    
    Gui, SettingsGui:Add, Text, x10 y120 w80 h20, Image Folder:
    Gui, SettingsGui:Add, Edit, x100 y117 w120 h20 vSettingsImageDir, %ImageDir%
    
    Gui, SettingsGui:Font, s10 cFFFFFF, Oswald
    Gui, SettingsGui:Add, Button, x10 y155 w100 h30 gSettingsSave, Save
    Gui, SettingsGui:Add, Button, x130 y155 w100 h30 gSettingsClose, Close
    
    Gui, SettingsGui:Show, w240 h200, Settings
return

SettingsSave:
    Gui, SettingsGui:Submit
    IniWrite, %SettingsWidth%, %ConfigFile%, Settings, ScreenWidth
    IniWrite, %SettingsHeight%, %ConfigFile%, Settings, ScreenHeight
    IniWrite, %SettingsColor%, %ConfigFile%, Settings, SukliColor
    ScreenWidth := SettingsWidth
    ScreenHeight := SettingsHeight
    SukliColor := SettingsColor
    Gui, SettingsGui:Destroy
    MsgBox, 64, Success, Settings saved!`nScript will now reload.
    Sleep, 500
    Reload
return

SettingsClose:
    Gui, SettingsGui:Destroy
return

; ============================================================
; HOTKEYS
; ============================================================

; F1: Show Main GUI
F1::
    Gosub, MainGUI
return

; F1_Action: Select Route
F1_Action:
    Gui, RouteGui:New, +AlwaysOnTop +ToolWindow, Select Route
    Gui, RouteGui:Color, 1A2415, 1A2415
    Gui, RouteGui:Font, s11 cF1E9D2 bold, Oswald
    Gui, RouteGui:Add, Text, x10 y10 w180 h25 Center, Select Route
    Gui, RouteGui:Font, s9 cC9BE9E, Oswald
    Gui, RouteGui:Add, Text, x10 y40 w180 h20 Center, Choose your route:
    Gui, RouteGui:Font, s10 cF1E9D2, Oswald
    Gui, RouteGui:Add, DropDownList, vRouteChoice w180 gRoutePreview, Balagtas|Guiguinto|Malolos
    Gui, RouteGui:Add, Text, x10 y90 w180 h40 Center vRoutePreviewText, Balagtas: 5 barangays
    Gui, RouteGui:Font, s10 cFFFFFF, Oswald
    Gui, RouteGui:Add, Button, x10 y135 w85 h30 gRouteOK, OK
    Gui, RouteGui:Add, Button, x105 y135 w85 h30 gRouteCancel, Cancel
    Gui, RouteGui:Show, w200 h180, Select Route
return

RoutePreview:
    Gui, RouteGui:Submit, NoHide
    routeNames := []
    routeNames["Balagtas"] := "Balagtas: 5 barangays"
    routeNames["Guiguinto"] := "Guiguinto: 3 barangays"
    routeNames["Malolos"] := "Malolos: 10 barangays"
    GuiControl,, RoutePreviewText, % routeNames[RouteChoice]
return

RouteOK:
    Gui, RouteGui:Submit
    IniWrite, %RouteChoice%, %ConfigFile%, Settings, Route
    RouteName := RouteChoice
    GuiControl, MainGui:, MainRoute, %RouteName%
    Gui, RouteGui:Destroy
    TrayTip, Sukli Automation, Route set to %RouteChoice%, 2
return

RouteCancel:
    Gui, RouteGui:Destroy
return

; F2: Toggle macro ON/OFF
F2::
F2_Action:
    macroRunning := !macroRunning
    if (macroRunning) {
        GuiControl, MainGui:, MainStatus, [*] Running
        GuiControl, MainGui:, MainStartBtn, Running...
        GuiControl, MainGui:, MainDetect, [..] Monitoring...
        TrayTip, Sukli Automation, Macro STARTED`nRoute: %RouteName%, 2
        SetTimer, CheckSukliScreen, 500
    } else {
        GuiControl, MainGui:, MainStatus, [X] Stopped
        GuiControl, MainGui:, MainStartBtn, Start (F2)
        GuiControl, MainGui:, MainDetect, [..] Waiting...
        TrayTip, Sukli Automation, Macro STOPPED, 2
        SetTimer, CheckSukliScreen, Off
    }
return

; F3: Force Roblox into Windowed Mode
F3::
    WinActivate, %WinTitle%
    WinWaitActive, %WinTitle%,, 3
    if ErrorLevel {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    WinMove, %WinTitle%,, 0, 0, %ScreenWidth%, %ScreenHeight%
    WinActivate, %WinTitle%
    TrayTip, Sukli Automation, Roblox resized to %ScreenWidth%x%ScreenHeight%, 2
    SoundBeep, 1000, 200
return

; F4: Emergency Stop
F4::
F4_Action:
    macroRunning := false
    SetTimer, CheckSukliScreen, Off
    GuiControl, MainGui:, MainStatus, [X] Stopped
    GuiControl, MainGui:, MainStartBtn, Start (F2)
    GuiControl, MainGui:, MainDetect, [..] Waiting...
    TrayTip, Sukli Automation, EMERGENCY STOP!, 2
    SoundBeep, 500, 300
return

; F5: Manual trigger
F5::
F5_Action:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    SukliScreenDetected(WinX, WinY, WinW, WinH)
return

; F6: Calibrate denomination positions
F6::
F6_Action:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    MsgBox, 64, Calibration, For each denomination, hover your mouse over the button in Roblox and press SPACE. Press ESC anytime to cancel.

    cancelled := false
    for i, denom in Denominations {
        ToolTip, Hover over the %denom%-peso button, then press SPACE
        Loop {
            if (GetKeyState("Escape", "D")) {
                cancelled := true
                break
            }
            if (GetKeyState("Space", "D")) {
                MouseGetPos, mx, my
                relX := (mx - WinX) / WinW
                relY := (my - WinY) / WinH
                DenomPositions[denom] := {x: relX, y: relY}
                IniWrite, %relX%, %ConfigFile%, DenomPositions, %denom%_x
                IniWrite, %relY%, %ConfigFile%, DenomPositions, %denom%_y
                SoundBeep, 800, 100
                Sleep, 300
                break
            }
            Sleep, 50
        }
        if (cancelled)
            break
    }
    ToolTip
    if (cancelled)
        MsgBox, 48, Cancelled, Calibration cancelled.
    else
        MsgBox, 64, Done, Denomination positions saved!
return

; F7: Calibrate sukli color and position
F7::
F7_Action:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    MsgBox, 64, Calibration, Hover your mouse over the "Naghihintay ng sukli" text, then press SPACE. Press ESC to cancel.
    ToolTip, Hover and press SPACE to capture color and position...
    Loop {
        if (GetKeyState("Escape", "D")) {
            ToolTip
            MsgBox, 48, Cancelled, Calibration cancelled.
            return
        }
        if (GetKeyState("Space", "D")) {
            MouseGetPos, mx, my
            PixelGetColor, capturedColor, mx, my, RGB
            SukliColor := capturedColor
            SukliCheckRelX := (mx - WinX) / WinW
            SukliCheckRelY := (my - WinY) / WinH
            IniWrite, %capturedColor%, %ConfigFile%, Settings, SukliColor
            IniWrite, %SukliCheckRelX%, %ConfigFile%, Settings, SukliCheckRelX
            IniWrite, %SukliCheckRelY%, %ConfigFile%, Settings, SukliCheckRelY
            SoundBeep, 800, 100
            Sleep, 300
            break
        }
        Sleep, 50
    }
    ToolTip
    MsgBox, 64, Done, Sukli detection calibrated!`nColor: %capturedColor%`nPosition saved.
return

; F9: Show today's totals
F9::
F9_Action:
    if (!FileExist(LogFile)) {
        MsgBox, 48, No Data, No transactions logged yet.
        return
    }
    FileRead, logContent, %LogFile%
    todayStr := A_Year . "-" . A_MM . "-" . A_DD
    totalFareToday := 0
    countToday := 0
    Loop, Parse, logContent, `n
    {
        if (A_LoopField = "" or A_Index = 1)
            continue
        if (InStr(A_LoopField, todayStr)) {
            StringSplit, row, A_LoopField, `,
            totalFareToday += row7
            countToday++
        }
    }
    
    ; Show in a nice GUI
    Gui, TotalsGui:New, +AlwaysOnTop +ToolWindow, Today's Summary
    Gui, TotalsGui:Color, 1A2415, 1A2415
    Gui, TotalsGui:Font, s11 cF1E9D2 bold, Oswald
    Gui, TotalsGui:Add, Text, x10 y10 w200 h25 Center, Today's Summary
    Gui, TotalsGui:Font, s9 cC9BE9E, Oswald
    Gui, TotalsGui:Add, Text, x10 y40 w200 h20 Center, Transactions today:
    Gui, TotalsGui:Font, s14 cF3B22C bold, Anton
    Gui, TotalsGui:Add, Text, x10 y60 w200 h30 Center, %countToday%
    Gui, TotalsGui:Font, s9 cC9BE9E, Oswald
    Gui, TotalsGui:Add, Text, x10 y95 w200 h20 Center, Total fare collected:
    Gui, TotalsGui:Font, s14 c6FA05B bold, Anton
    Gui, TotalsGui:Add, Text, x10 y115 w200 h30 Center, Php%totalFareToday%
    Gui, TotalsGui:Font, s10 cFFFFFF, Oswald
    Gui, TotalsGui:Add, Button, x10 y155 w200 h30 gTotalsClose, Close
    Gui, TotalsGui:Show, w220 h200, Today's Summary
return

TotalsClose:
    Gui, TotalsGui:Destroy
return

; ============================================================
; MAIN LOOP
; ============================================================
CheckSukliScreen:
    if (!macroRunning)
        return

    WinGet, activeID, ID, A
    WinGet, robloxID, ID, %WinTitle%
    if (activeID != robloxID)
        return

    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW < 100 or WinH < 100)
        return

    SukliCheckX := WinX + Round(WinW * SukliCheckRelX)
    SukliCheckY := WinY + Round(WinH * SukliCheckRelY)
    PixelGetColor, pixelColor, %SukliCheckX%, %SukliCheckY%, RGB

    if (pixelColor = SukliColor) {
        GuiControl, MainGui:, MainDetect, [OK] Sukli Detected!
        SukliScreenDetected(WinX, WinY, WinW, WinH)
        GuiControl, MainGui:, MainDetect, [..] Monitoring...
    }
return

; ============================================================
; SUKLI ENTRY FORM (GUI)
; ============================================================
SukliScreenDetected(WinX, WinY, WinW, WinH) {
    global RouteData, RouteName, ImageDir, g_EntryContext

    ; Click reset button
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%reset_arrow.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
    }

    barangays := RouteData[RouteName]
    destListStr := ""
    for i, name in barangays {
        destListStr .= name . "|"
    }

    g_EntryContext := {WinX: WinX, WinY: WinY, WinW: WinW, WinH: WinH}

    Gui, EntryGui:New, +AlwaysOnTop +ToolWindow, Sukli Entry
    Gui, EntryGui:Color, 1A2415, 1A2415
    Gui, EntryGui:Font, s11 cF1E9D2 bold, Oswald
    Gui, EntryGui:Add, Text, x10 y10 w260 h25 Center, Sukli Entry - %RouteName%
    
    Gui, EntryGui:Font, s9 cC9BE9E, Oswald
    Gui, EntryGui:Add, Text, x10 y40 w80 h20, Destination:
    Gui, EntryGui:Font, s10 cF1E9D2, Oswald
    Gui, EntryGui:Add, DropDownList, vDestChoice w160, %destListStr%
    
    Gui, EntryGui:Font, s9 cC9BE9E, Oswald
    Gui, EntryGui:Add, Text, x10 y70 w80 h20, Passengers:
    Gui, EntryGui:Font, s10 cF1E9D2, Oswald
    Gui, EntryGui:Add, Edit, vPaxCount w60 Number, 1
    Gui, EntryGui:Add, UpDown, Range1-10, 1
    
    Gui, EntryGui:Font, s9 cC9BE9E, Oswald
    Gui, EntryGui:Add, Text, x10 y100 w80 h20, Type:
    Gui, EntryGui:Font, s10 cF1E9D2, Oswald
    Gui, EntryGui:Add, Radio, vTypeRegular Checked group x10 y120, Regular
    Gui, EntryGui:Add, Radio, vTypeStudent x+10, Student
    Gui, EntryGui:Add, Radio, vTypeSenior x+10, Senior
    
    Gui, EntryGui:Font, s9 cC9BE9E, Oswald
    Gui, EntryGui:Add, Text, x10 y155 w80 h20, Payment:
    Gui, EntryGui:Font, s10 cF1E9D2, Oswald
    Gui, EntryGui:Add, DropDownList, vPaymentChoice w100, 20|50|100|200|500|1000
    
    Gui, EntryGui:Font, s10 cFFFFFF bold, Oswald
    Gui, EntryGui:Add, Button, x10 y185 w125 h35 gEntrySubmit, Confirm
    Gui, EntryGui:Add, Button, x145 y185 w125 h35 gEntryCancel, Cancel
    
    Gui, EntryGui:Show, w280 h240, Sukli Entry
    WinWaitClose, Sukli Entry
}

EntrySubmit:
    Gui, EntryGui:Submit
    Gui, EntryGui:Destroy

    if (TypeStudent = 1)
        passengerType := "Student"
    else if (TypeSenior = 1)
        passengerType := "Senior"
    else
        passengerType := "Regular"

    destination := DestChoice
    paxCount := PaxCount
    payment := PaymentChoice

    global g_EntryContext, RouteData, RouteName, regularFare, studentFare, seniorFare, extraFare, minUnits, ImageDir, LogFile
    WinX := g_EntryContext.WinX
    WinY := g_EntryContext.WinY
    WinW := g_EntryContext.WinW
    WinH := g_EntryContext.WinH

    barangays := RouteData[RouteName]
    destIndex := 0
    Loop, % barangays.Length() {
        if (barangays[A_Index] = destination) {
            destIndex := A_Index
            break
        }
    }
    if (destIndex = 0) {
        MsgBox, 16, Error, Destination not found on this route!
        return
    }

    if (passengerType = "Student")
        baseFare := studentFare
    else if (passengerType = "Senior")
        baseFare := seniorFare
    else
        baseFare := regularFare

    if (destIndex > minUnits)
        perPassengerFare := baseFare + ((destIndex - minUnits) * extraFare)
    else
        perPassengerFare := baseFare

    totalFare := perPassengerFare * paxCount
    sukli := payment - totalFare

    if (sukli < 0) {
        MsgBox, 16, Error, Payment is less than fare!`nFare: Php%totalFare%`nPayment: Php%payment%
        return
    }

    sukliBreakdown := CalculateBreakdown(sukli)

    ; Confirmation Dialog
    MsgBox, 68, Confirm Sukli,
    (LTrim
        Route: %RouteName%
        Destination: %destination% (Unit %destIndex%)
        Passengers: %paxCount%
        Type: %passengerType%
        Payment: Php%payment%
        Total Fare: Php%totalFare%
        Sukli: Php%sukli%
        Breakdown: %sukliBreakdown%
    )
    IfMsgBox, No
        return

    ; Perform the sukli
    PerformSukli(WinX, WinY, WinW, WinH, sukliBreakdown)

    ; Click check button
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%check_button.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
        SoundBeep, 1000, 200
        TrayTip, Sukli Automation, Sukli complete!, 3
    } else {
        TrayTip, Sukli Automation, Check button not found!`nPlease click manually., 3
    }

    ; Log the transaction
    FormatTime, ts,, yyyy-MM-dd HH:mm:ss
    FileAppend, %ts%,%RouteName%,%destination%,%paxCount%,%passengerType%,%payment%,%totalFare%,%sukli%`n, %LogFile%
    
    ; Update the GUI with the transaction
    GuiControl, MainGui:, MainDetect, [OK] Sukli Complete!
    Sleep, 1000
    GuiControl, MainGui:, MainDetect, [..] Monitoring...
return

EntryCancel:
    Gui, EntryGui:Destroy
return

; ============================================================
; FUNCTIONS
; ============================================================

CalculateBreakdown(amount) {
    global Denominations
    breakdown := ""
    remaining := amount

    for index, denom in Denominations {
        count := Floor(remaining / denom)
        if (count > 0) {
            Loop, %count% {
                if (breakdown != "")
                    breakdown .= ","
                breakdown .= denom
            }
            remaining -= count * denom
        }
    }
    return breakdown
}

PerformSukli(WinX, WinY, WinW, WinH, breakdown) {
    global DenomPositions
    Sleep, 500
    StringSplit, denomArray, breakdown, `,
    Loop, %denomArray0% {
        denom := denomArray%A_Index%
        if (DenomPositions.HasKey(denom)) {
            pos := DenomPositions[denom]
            clickX := WinX + Round(WinW * pos.x)
            clickY := WinY + Round(WinH * pos.y)
            MouseClick, left, clickX, clickY, 1, 0
            Sleep, 300
        }
    }
}

; ============================================================
; RELOAD
; ============================================================
Reload:
    Run, %A_ScriptFullPath%
    ExitApp
return

; ============================================================
; GUI CLOSE HANDLERS
; ============================================================
MainGuiClose:
    Gui, MainGui:Destroy
    ExitApp
return

SettingsGuiClose:
    Gui, SettingsGui:Destroy
return

RouteGuiClose:
    Gui, RouteGui:Destroy
return

TotalsGuiClose:
    Gui, TotalsGui:Destroy
return
