; ============================================================
; SUKLI AUTOMATION - Full Auto-Detection
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

; Default values
ScreenWidth := 1920
ScreenHeight := 1080
RouteName := "Balagtas"

; Read config
if (FileExist(ConfigFile)) {
    IniRead, tempWidth, %ConfigFile%, Settings, ScreenWidth, 1920
    IniRead, tempHeight, %ConfigFile%, Settings, ScreenHeight, 1080
    IniRead, tempRoute, %ConfigFile%, Settings, Route, Balagtas
    ScreenWidth := tempWidth
    ScreenHeight := tempHeight
    RouteName := tempRoute
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
    MsgBox, 64, Success, Route set to %userRoute%!`nScript will now reload.
    Sleep, 500
    Reload
return

; F2: Toggle macro ON/OFF
F2::
    macroRunning := !macroRunning
    if (macroRunning) {
        TrayTip, Sukli Automation, Macro STARTED`nRoute: %RouteName%`nMonitoring for sukli screen..., 3
        SetTimer, CheckSukliScreen, 500
    } else {
        TrayTip, Sukli Automation, Macro STOPPED, 3
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
    TrayTip, Sukli Automation, Roblox resized to %ScreenWidth%x%ScreenHeight%, 3
    SoundBeep, 1000, 200
return

; F4: Emergency Stop
F4::
    macroRunning := false
    SetTimer, CheckSukliScreen, Off
    TrayTip, Sukli Automation, EMERGENCY STOP!, 2
    SoundBeep, 500, 300
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
    ; DETECT SUKLI SCREEN (Pixel Color)
    ; ============================================================
    ; REPLACE 0xFFFFFF with your actual color
    SukliCheckX := WinX + Round(WinW * 0.50)
    SukliCheckY := WinY + Round(WinH * 0.30)
    PixelGetColor, pixelColor, SukliCheckX, SukliCheckY, RGB

    if (pixelColor = 0xFFFFFF) {
        TrayTip, Sukli Automation, Sukli screen detected!, 2
        SukliScreenDetected(WinX, WinY, WinW, WinH)
    }
return

; ============================================================
; SUKLI SCREEN DETECTED
; ============================================================
SukliScreenDetected(WinX, WinY, WinW, WinH) {
    global

    ; ============================================================
    ; STEP 1: CLICK RESET BUTTON
    ; ============================================================
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%reset_arrow.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
        TrayTip, Sukli Automation, Reset clicked!, 2
    }

    ; ============================================================
    ; STEP 2: GET PASSENGER DETAILS
    ; ============================================================

    ; Destination
    MsgBox, 64, Step 1 of 4, Enter Destination:`n1. Bagumbayan/San Jose`n2. Matungao`n3. Panginay Guiguinto`n4. Panginay Balagtas`n5. Wawa`n6. Tuktukan`n7. Maysantol`n8. San Nicolas`n9. Pitpitan`n10. Mambog`n11. Matimbo`n12. Panasahan`n13. Bagna`n14. Atlag`n15. San Juan/Sto. Rosario

    InputBox, destChoice, Destination, Enter destination number (1-15):, , 200, 150
    if ErrorLevel return

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
        MsgBox, 16, Error, Invalid destination!
        return
    }

    ; Passenger count
    InputBox, paxCount, Passenger Count, Enter number of passengers (1-10):, , 200, 150
    if ErrorLevel return
    if (paxCount < 1 or paxCount > 10) {
        MsgBox, 16, Error, Invalid passenger count! (1-10)
        return
    }

    ; Passenger type
    MsgBox, 64, Step 3 of 4, Enter Passenger Type:`n1. Regular`n2. Student`n3. Senior

    InputBox, typeChoice, Passenger Type, Enter type (1-3):, , 200, 150
    if ErrorLevel return
    if (typeChoice < 1 or typeChoice > 3) {
        MsgBox, 16, Error, Invalid passenger type!
        return
    }
    typeMap := ["Regular", "Student", "Senior"]
    passengerType := typeMap[typeChoice]

    ; Payment
    MsgBox, 64, Step 4 of 4, Enter Payment Amount:`n20, 50, 100, 200, 500, 1000

    InputBox, payment, Payment, Enter payment amount:, , 200, 150
    if ErrorLevel return
    if (payment != "20" and payment != "50" and payment != "100" and payment != "200" and payment != "500" and payment != "1000") {
        MsgBox, 16, Error, Invalid payment!`nUse: 20, 50, 100, 200, 500, or 1000
        return
    }

    ; ============================================================
    ; STEP 3: CALCULATE
    ; ============================================================
    barangays := RouteData[RouteName]
    if (barangays = "") {
        MsgBox, 16, Error, Route not found!
        return
    }

    destIndex := 0
    Loop, % barangays.Length() {
        if (barangays[A_Index] = destination) {
            destIndex := A_Index
            break
        }
    }
    if (destIndex = 0) {
        MsgBox, 16, Error, Destination not on this route!
        return
    }

    if (passengerType = "Student") {
        baseFare := studentFare
    } else if (passengerType = "Senior") {
        baseFare := seniorFare
    } else {
        baseFare := regularFare
    }

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

    sukliBreakdown := CalculateBreakdown(sukli)

    ; ============================================================
    ; STEP 4: CONFIRM
    ; ============================================================
    MsgBox, 68, Sukli Automation - Confirm,
    (LTrim
        Route: %RouteName%
        Destination: %destination% (Unit %destIndex%)
        Passengers: %paxCount%
        Type: %passengerType%
        Payment: ₱%payment%
        Total Fare: ₱%totalFare%
        Sukli: ₱%sukli%
        Breakdown: %sukliBreakdown%
    )

    IfMsgBox, No
        return

    ; ============================================================
    ; STEP 5: PERFORM SUKLI
    ; ============================================================
    PerformSukli(WinX, WinY, WinW, WinH, sukliBreakdown)

    ; ============================================================
    ; STEP 6: CLICK CHECK BUTTON
    ; ============================================================
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%check_button.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
        SoundBeep, 1000, 200
        TrayTip, Sukli Automation, Sukli complete! ✅, 3
    } else {
        TrayTip, Sukli Automation, Check button not found!, 3
    }
}

; ============================================================
; CALCULATE SUKLI BREAKDOWN
; ============================================================
CalculateBreakdown(amount) {
    global Denominations

    breakdown := ""
    remaining := amount

    for index, denom in Denominations {
        count := floor(remaining / denom)
        if (count > 0) {
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
; PERFORM SUKLI
; ============================================================
PerformSukli(WinX, WinY, WinW, WinH, breakdown) {
    global

    Sleep, 500

    StringSplit, denomArray, breakdown, `,

    Loop, % denomArray0 {
        denom := denomArray%A_Index%

        if DenomPositions.HasKey(denom) {
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
