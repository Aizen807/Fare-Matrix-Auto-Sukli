; ============================================================
; SUKLI AUTOMATION v2.0 - Image Detection for Passenger Types
; ============================================================
; 
; HOW IT WORKS:
;   1. Detects sukli screen using PIXEL COLOR
;   2. Detects passenger type using IMAGE DETECTION:
;      - "Student" or "Studyante" text -> Student
;      - "Senior" text -> Senior
;      - Neither found -> Regular (default)
;   3. Uses images for: reset_arrow.png, check_button.png,
;      type_student.png, type_senior.png
;   4. Calculates fare and sukli automatically
;   5. Performs the sukli using COORDINATES
;
; IMAGES NEEDED (4 TOTAL):
;   - reset_arrow.png   (red arrow button)
;   - check_button.png  (check/sukli button)
;   - type_student.png  ("Student" or "Studyante" text)
;   - type_senior.png   ("Senior" text)
; ============================================================

#NoEnv
#SingleInstance, Force
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen

; ============================================================
; GUI - Status Window
; ============================================================
Gui, New, +AlwaysOnTop +ToolWindow, Sukli Automation
Gui, Add, Text, x10 y10 w200 h20 vStatusText, Status: Ready
Gui, Add, Text, x10 y35 w200 h20 vInfoText, Press F2 to start
Gui, Add, Text, x10 y60 w200 h20 vDetectText, Waiting for sukli screen...
Gui, Add, Button, x10 y85 w80 h25 gStartMacro, Start (F2)
Gui, Add, Button, x100 y85 w80 h25 gStopMacro, Stop (F4)
Gui, Add, Button, x190 y85 w80 h25 gCalibrate, Calibrate
Gui, Show, w280 h120, Sukli Automation
return

StartMacro:
    Gosub, F2_Action
return

StopMacro:
    Gosub, F4_Action
return

Calibrate:
    Gosub, CalibratePositions
return

; ============================================================
; READ CONFIGURATION
; ============================================================
ConfigFile := A_ScriptDir . "\sukli_config.ini"

; Default values
ScreenWidth := 1920
ScreenHeight := 1080
RouteName := "Balagtas"

; Detection settings
SukliColor := 0xFFFFFF
ColorTolerance := 10
DetectionInterval := 500

; Read config
if (FileExist(ConfigFile)) {
    IniRead, tempWidth, %ConfigFile%, Settings, ScreenWidth, 1920
    IniRead, tempHeight, %ConfigFile%, Settings, ScreenHeight, 1080
    IniRead, tempRoute, %ConfigFile%, Settings, Route, Balagtas
    IniRead, tempColor, %ConfigFile%, Settings, SukliColor, 0xFFFFFF
    IniRead, tempTolerance, %ConfigFile%, Settings, ColorTolerance, 10
    ScreenWidth := tempWidth
    ScreenHeight := tempHeight
    RouteName := tempRoute
    SukliColor := tempColor
    ColorTolerance := tempTolerance
} else {
    MsgBox, 16, Error, sukli_config.ini not found!`nPlease create it first.
    ExitApp
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
; SUKLI DENOMINATIONS
; ============================================================
Denominations := [50, 20, 10, 5, 1]

; ============================================================
; DENOMINATION BUTTON POSITIONS
; ============================================================
DenomPositions := {}
DenomPositions[50] := { x: 0.30, y: 0.40 }
DenomPositions[20] := { x: 0.40, y: 0.40 }
DenomPositions[10] := { x: 0.50, y: 0.40 }
DenomPositions[5]  := { x: 0.60, y: 0.40 }
DenomPositions[1]  := { x: 0.70, y: 0.40 }

; ============================================================
; VARIABLES
; ============================================================
macroRunning := false
WinTitle := "Roblox"
ImageDir := A_ScriptDir . "\sukli_images\"

; ============================================================
; FUNCTIONS
; ============================================================

; ColorMatch - Checks if two colors match within tolerance
ColorMatch(color1, color2, tolerance) {
    r1 := (color1 >> 16) & 0xFF
    g1 := (color1 >> 8) & 0xFF
    b1 := color1 & 0xFF
    
    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF
    
    diff := Abs(r1 - r2) + Abs(g1 - g2) + Abs(b1 - b2)
    return (diff <= tolerance * 3)
}

; UpdateGUI - Updates the status window
UpdateGUI(status, info, detect := "") {
    GuiControl,, StatusText, Status: %status%
    GuiControl,, InfoText, %info%
    if (detect != "") {
        GuiControl,, DetectText, %detect%
    }
}

; PlaySound - Plays feedback sounds
PlaySound(freq, duration) {
    SoundBeep, %freq%, %duration%
}

; ============================================================
; HOTKEYS
; ============================================================

; F1: Select Route
F1::
    InputBox, userRoute, Route Selection, Enter route (Balagtas, Guiguinto, or Malolos):, , 300, 150
    if ErrorLevel return
    if (userRoute != "Balagtas" and userRoute != "Guiguinto" and userRoute != "Malolos") {
        MsgBox, 16, Error, Invalid route!`nChoose: Balagtas, Guiguinto, or Malolos.
        return
    }
    IniWrite, %userRoute%, %ConfigFile%, Settings, Route
    RouteName := userRoute
    UpdateGUI("Ready", "Route set to " . RouteName, "Press F2 to start")
    PlaySound(1000, 150)
return

; F2: Toggle macro ON/OFF
F2::
F2_Action:
    macroRunning := !macroRunning
    if (macroRunning) {
        UpdateGUI("RUNNING", "Monitoring for sukli screen...", "Route: " . RouteName)
        PlaySound(1200, 150)
        SetTimer, CheckSukliScreen, %DetectionInterval%
    } else {
        UpdateGUI("STOPPED", "Press F2 to start", "Waiting...")
        PlaySound(800, 150)
        SetTimer, CheckSukliScreen, Off
    }
return

; F3: Force Roblox into Windowed Mode
F3::
    WinActivate, %WinTitle%
    WinWaitActive, %WinTitle%,, 3
    if ErrorLevel {
        MsgBox, 16, Error, Roblox window not found!`nMake sure Roblox is running.
        return
    }
    WinMove, %WinTitle%,, 0, 0, %ScreenWidth%, %ScreenHeight%
    WinActivate, %WinTitle%
    UpdateGUI("Ready", "Roblox resized to " . ScreenWidth . "x" . ScreenHeight, "Press F2 to start")
    PlaySound(1000, 200)
return

; F4: Emergency Stop
F4::
F4_Action:
    macroRunning := false
    SetTimer, CheckSukliScreen, Off
    UpdateGUI("STOPPED", "Emergency Stop!", "Press F2 to restart")
    PlaySound(500, 300)
return

; ============================================================
; CALIBRATE - Test and adjust denomination positions
; ============================================================
CalibratePositions:
    UpdateGUI("Calibrating", "Click the ₱50 button...", "Move mouse and press F5")
    MsgBox, 64, Calibration, Move your mouse over the ₱50 button`nand press F5 to capture its position.
    
    Hotkey, F5, CapturePosition, On
    return
    
CapturePosition:
    Hotkey, F5, Off
    MouseGetPos, mouseX, mouseY
    
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    
    if (WinW > 0 and WinH > 0) {
        relX := (mouseX - WinX) / WinW
        relY := (mouseY - WinY) / WinH
        
        IniWrite, %relX%, %ConfigFile%, DenomPositions, 50_X
        IniWrite, %relY%, %ConfigFile%, DenomPositions, 50_Y
        
        DenomPositions[50] := { x: relX, y: relY }
        
        UpdateGUI("Calibrated", "₱50 position saved", "X: " . Round(relX, 2) . " Y: " . Round(relY, 2))
        PlaySound(1200, 200)
        MsgBox, 64, Success, ₱50 button position captured!`nX: %relX%`nY: %relY%
    }
return

; ============================================================
; MAIN LOOP - Checks for Sukli Screen
; ============================================================
CheckSukliScreen:
    if (!macroRunning) {
        return
    }

    WinGet, activeID, ID, A
    WinGet, robloxID, ID, %WinTitle%
    if (activeID != robloxID) {
        return
    }

    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW < 100 or WinH < 100) {
        return
    }

    ; ============================================================
    ; DETECT SUKLI SCREEN (Pixel Color with Tolerance)
    ; ============================================================
    ; REPLACE 0xFFFFFF with your actual color
    SukliCheckX := WinX + Round(WinW * 0.50)
    SukliCheckY := WinY + Round(WinH * 0.30)
    PixelGetColor, pixelColor, SukliCheckX, SukliCheckY, RGB
    
    if (ColorMatch(pixelColor, SukliColor, ColorTolerance)) {
        UpdateGUI("DETECTED", "Sukli screen detected!", "Reading passenger info...")
        PlaySound(1500, 100)
        SukliScreenDetected(WinX, WinY, WinW, WinH)
        Sleep, 2000
    } else {
        static lastUpdate := 0
        if (A_TickCount - lastUpdate > 2000) {
            UpdateGUI("RUNNING", "Waiting for sukli screen...", "Route: " . RouteName)
            lastUpdate := A_TickCount
        }
    }
return

; ============================================================
; SUKLI SCREEN DETECTED
; ============================================================
SukliScreenDetected(WinX, WinY, WinW, WinH) {
    global
    
    UpdateGUI("DETECTED", "Processing...", "Looking for reset button")
    Sleep, 300
    
    ; ============================================================
    ; STEP 1: CLICK RESET BUTTON (Image Detection)
    ; ============================================================
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%reset_arrow.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
        UpdateGUI("DETECTED", "Reset clicked", "Proceeding...")
        PlaySound(900, 100)
    } else {
        UpdateGUI("DETECTED", "Reset not found", "Proceeding anyway...")
    }
    
    ; ============================================================
    ; STEP 2: DETECT PASSENGER TYPE (Image Detection)
    ; ============================================================
    ; Check for Student label first
    passengerType := "Regular"
    
    UpdateGUI("DETECTED", "Detecting passenger type...", "Looking for Student/Senior labels")
    Sleep, 200
    
    ; Search for Student label (English or Tagalog)
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%type_student.png
    if (ErrorLevel = 0) {
        passengerType := "Student"
        UpdateGUI("DETECTED", "Type: Student detected", "Proceeding...")
        PlaySound(1000, 100)
        Sleep, 300
    } else {
        ; Search for Senior label
        ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%type_senior.png
        if (ErrorLevel = 0) {
            passengerType := "Senior"
            UpdateGUI("DETECTED", "Type: Senior detected", "Proceeding...")
            PlaySound(1000, 100)
            Sleep, 300
        } else {
            ; No Student or Senior found = Regular
            passengerType := "Regular"
            UpdateGUI("DETECTED", "Type: Regular (default)", "Proceeding...")
        }
    }
    
    ; ============================================================
    ; STEP 3: GET PASSENGER DETAILS FROM USER
    ; ============================================================
    
    ; Destination selection
    MsgBox, 64, Step 1 of 3, Enter Destination:`n1. Bagumbayan/San Jose`n2. Matungao`n3. Panginay Guiguinto`n4. Panginay Balagtas`n5. Wawa`n6. Tuktukan`n7. Maysantol`n8. San Nicolas`n9. Pitpitan`n10. Mambog`n11. Matimbo`n12. Panasahan`n13. Bagna`n14. Atlag`n15. San Juan/Sto. Rosario
    
    InputBox, destChoice, Destination, Enter destination number (1-15):, , 200, 150
    if ErrorLevel {
        UpdateGUI("CANCELLED", "User cancelled", "Waiting...")
        return
    }
    
    ; Map destination number to name
    destMap := []
    destMap[1] := "Bagumbayan/San Jose"
    destMap[2] := "Matungao"
    destMap[3] := "Panginay Guiguinto"
    destMap[4] := "Panginay Balagtas"
    destMap[5] := "Wawa"
    destMap[6] := "Tuktukan"
    destMap[7] := "Maysantol"
    destMap[8] := "San Nicolas"
    destMap[9] := "Pitpitan"
    destMap[10] := "Mambog"
    destMap[11] := "Matimbo"
    destMap[12] := "Panasahan"
    destMap[13] := "Bagna"
    destMap[14] := "Atlag"
    destMap[15] := "San Juan/Sto. Rosario"
    
    destination := destMap[destChoice]
    if (destination = "") {
        MsgBox, 16, Error, Invalid destination choice!
        return
    }
    UpdateGUI("DETECTED", "Destination: " . destination, "Proceeding...")
    
    ; Passenger count
    InputBox, paxCount, Passenger Count, Enter number of passengers (1-10):, , 200, 150
    if ErrorLevel return
    if (paxCount < 1 or paxCount > 10) {
        MsgBox, 16, Error, Invalid passenger count! (1-10)
        return
    }
    UpdateGUI("DETECTED", "Passengers: " . paxCount, "Proceeding...")
    
    ; Show auto-detected type
    MsgBox, 64, Passenger Type Detected, Auto-detected passenger type: %passengerType%`n`nIf this is incorrect, please check your screenshots in the sukli_images folder.
    
    ; Payment amount
    MsgBox, 64, Step 3 of 3, Enter Payment Amount:`n20, 50, 100, 200, 500, 1000
    
    InputBox, payment, Payment, Enter payment amount:, , 200, 150
    if ErrorLevel return
    if (payment != "20" and payment != "50" and payment != "100" and payment != "200" and payment != "500" and payment != "1000") {
        MsgBox, 16, Error, Invalid payment amount!`nUse: 20, 50, 100, 200, 500, or 1000
        return
    }
    UpdateGUI("DETECTED", "Payment: ₱" . payment, "Calculating...")
    
    ; ============================================================
    ; STEP 4: CALCULATE FARE AND SUKLI
    ; ============================================================
    barangays := RouteData[RouteName]
    if (barangays = "") {
        MsgBox, 16, Error, Route not found! Check config.
        return
    }
    
    ; Find the destination index
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
    
    ; Get base fare based on passenger type
    if (passengerType = "Student") {
        baseFare := studentFare
    } else if (passengerType = "Senior") {
        baseFare := seniorFare
    } else {
        baseFare := regularFare
    }
    
    ; Calculate total fare
    if (destIndex > minUnits) {
        extra := destIndex - minUnits
        perPassengerFare := baseFare + (extra * extraFare)
    } else {
        perPassengerFare := baseFare
    }
    
    totalFare := perPassengerFare * paxCount
    sukli := payment - totalFare
    
    if (sukli < 0) {
        MsgBox, 16, Error, Payment is less than fare!`nFare: ₱%totalFare%`nPayment: ₱%payment%
        return
    }
    
    ; Calculate sukli breakdown
    sukliBreakdown := CalculateBreakdown(sukli)
    
    ; ============================================================
    ; STEP 5: SHOW SUMMARY AND CONFIRM
    ; ============================================================
    MsgBox, 68, Sukli Automation - Confirm,
    (LTrim
        Route: %RouteName%
        Destination: %destination% (Unit %destIndex%)
        Passengers: %paxCount%
        Type: %passengerType% (Auto-detected)
        Payment: ₱%payment%
        Total Fare: ₱%totalFare%
        Sukli: ₱%sukli%
        Breakdown: %sukliBreakdown%
        Click Order: Highest to lowest
    )
    
    IfMsgBox, No
        return
    
    UpdateGUI("EXECUTING", "Performing sukli...", "Clicking denominations")
    PlaySound(1000, 200)
    Sleep, 500
    
    ; ============================================================
    ; STEP 6: PERFORM THE SUKLI
    ; ============================================================
    PerformSukli(WinX, WinY, WinW, WinH, sukliBreakdown)
    
    ; ============================================================
    ; STEP 7: CLICK CHECK BUTTON (Image Detection)
    ; ============================================================
    UpdateGUI("EXECUTING", "Clicking check button...", "Almost done!")
    PlaySound(1200, 150)
    Sleep, 300
    
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%check_button.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
        PlaySound(1500, 200)
        UpdateGUI("COMPLETE", "Sukli complete! ✅", "Ready for next passenger")
        MsgBox, 64, Success, Sukli completed successfully! ✅
    } else {
        UpdateGUI("ERROR", "Check button not found!", "Please click manually")
        PlaySound(500, 300)
        MsgBox, 16, Error, Check button not found!`nPlease click it manually.
    }
}

; ============================================================
; CALCULATE SUKLI BREAKDOWN (Highest to Lowest)
; ============================================================
CalculateBreakdown(amount) {
    global Denominations
    
    breakdown := ""
    remaining := amount
    
    ; Loop through denominations from highest to lowest
    for index, denom in Denominations {
        count := floor(remaining / denom)
        if (count > 0) {
            ; Add this denomination 'count' times to the breakdown
            loop, %count% {
                if (breakdown != "") {
                    breakdown .= ","
                }
                breakdown .= denom
            }
            remaining -= count * denom
        }
    }
    
    return breakdown
}

; ============================================================
; PERFORM SUKLI (Coordinate-Based)
; ============================================================
PerformSukli(WinX, WinY, WinW, WinH, breakdown) {
    global
    
    Sleep, 500
    
    ; Split the breakdown
    StringSplit, denomArray, breakdown, `,
    
    ; Click each denomination in order (already highest to lowest)
    Loop, % denomArray0 {
        denom := denomArray%A_Index%
        
        if DenomPositions.HasKey(denom) {
            pos := DenomPositions[denom]
            clickX := WinX + Round(WinW * pos.x)
            clickY := WinY + Round(WinH * pos.y)
            
            MouseClick, left, clickX, clickY, 1, 0
            PlaySound(800, 50)
            Sleep, 300
            
            UpdateGUI("EXECUTING", "Clicked ₱" . denom, "Progress: " . A_Index . "/" . denomArray0)
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
; GUI CLOSE
; ============================================================
GuiClose:
    ExitApp
return
