; ============================================================
; SUKLI AUTOMATION - Full Auto-Detection
; ============================================================
; Reads from the game screen:
;   - Destination (e.g., "San Jose - Wawa")
;   - Passenger Count (e.g., "Isa", "Dalawa")
;   - Passenger Type (Regular/Student/Senior)
;   - Payment Amount (e.g., ₱100)
;
; Calculates fare and sukli automatically!
; Clicks highest denomination FIRST!
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
; LOAD ROUTE DATA
; ============================================================
RouteData := {}
IniRead, routeSection, %ConfigFile%, Routes
Loop, Parse, routeSection, `n, `r
{
    if (A_LoopField = "") {
        continue
    }
    StringSplit, parts, A_LoopField, =
    if (parts0 >= 2) {
        routeName := parts1
        routeList := parts2
        barangays := []
        StringSplit, barArray, routeList, `,
        Loop, % barArray0 {
            barangays[A_Index] := Trim(barArray%A_Index%)
        }
        RouteData[routeName] := barangays
    }
}

; ============================================================
; LOAD FARE SETTINGS
; ============================================================
IniRead, regularFare, %ConfigFile%, Fares, Regular, 13
IniRead, studentFare, %ConfigFile%, Fares, Student, 11
IniRead, seniorFare, %ConfigFile%, Fares, Senior, 11
IniRead, extraFare, %ConfigFile%, Fares, Extra, 2
IniRead, minUnits, %ConfigFile%, Fares, MinimumUnits, 4

; ============================================================
; IMAGE DETECTION CONFIG
; ============================================================
ImageDir := A_ScriptDir . "\sukli_images\"

; Number images (1-10)
NumberImages := {}
Loop, 10 {
    NumberImages[A_Index] := "count_" . A_Index . ".png"
}

; Type images
TypeImages := {}
TypeImages["Regular"] := "type_regular.png"
TypeImages["Student"] := "type_student.png"
TypeImages["Senior"] := "type_senior.png"

; Payment images
PaymentImages := {}
PaymentImages["20"] := "payment_20.png"
PaymentImages["50"] := "payment_50.png"
PaymentImages["100"] := "payment_100.png"
PaymentImages["200"] := "payment_200.png"
PaymentImages["500"] := "payment_500.png"
PaymentImages["1000"] := "payment_1000.png"

; Destination images
DestinationImages := {}
IniRead, destSection, %ConfigFile%, Destinations
Loop, Parse, destSection, `n, `r
{
    if (A_LoopField = "") {
        continue
    }
    StringSplit, parts, A_LoopField, =
    if (parts0 >= 2) {
        DestinationImages[parts1] := parts2
    }
}

; ============================================================
; SUKLI DENOMINATIONS (Highest to Lowest)
; ============================================================
Denominations := [50, 20, 10, 5, 1]

; ============================================================
; DENOMINATION BUTTON POSITIONS (Percentage-based)
; ============================================================
; !!! IMPORTANT: Adjust these if your game UI is different !!!
; These are the positions where the 50, 20, 10, 5, 1 buttons appear
; X% is from the left of the Roblox window
; Y% is from the top of the Roblox window
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

DetectedDestination := ""
DetectedPassengerCount := 0
DetectedPassengerType := "Regular"
DetectedPayment := 0

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
        TrayTip, Sukli Automation, Macro STARTED`nRoute: %RouteName%, 3
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
        MsgBox, 16, Error, Roblox window not found!
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
    ; REPLACE 0xFFFFFF with the actual color of "Naghihintay ng sukli" text
    ; Use AutoHotkey's Window Spy tool to find the correct color
    ; 1. Run the script
    ; 2. Right-click the tray icon -> Open
    ; 3. Go to View -> Window Spy
    ; 4. Hover over "Naghihintay ng sukli" text in Roblox
    ; 5. Copy the color value (e.g., 0xFFFFFF)
    ; 6. Replace 0xFFFFFF below with your actual color
    ; ============================================================
    SukliCheckX := WinX + Round(WinW * 0.50)
    SukliCheckY := WinY + Round(WinH * 0.30)
    PixelGetColor, pixelColor, SukliCheckX, SukliCheckY, RGB
    
    if (pixelColor = 0xFFFFFF) {
        TrayTip, Sukli Automation, Sukli screen detected!`nReading info..., 2
        ReadAllInfo(WinX, WinY, WinW, WinH)
    }
return

; ============================================================
; READ ALL INFORMATION FROM GAME SCREEN
; ============================================================
ReadAllInfo(WinX, WinY, WinW, WinH) {
    global
    
    ; Reset detected values
    DetectedDestination := ""
    DetectedPassengerCount := 0
    DetectedPassengerType := "Regular"
    DetectedPayment := 0
    
    ; ============================================================
    ; STEP 1: CHECK FOR RESET BUTTON (Red Arrow)
    ; ============================================================
    ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%reset_arrow.png
    if (ErrorLevel = 0) {
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 500
        TrayTip, Sukli Automation, Reset clicked!, 2
    }
    
    ; ============================================================
    ; STEP 2: DETECT DESTINATION
    ; ============================================================
    for destName, destImage in DestinationImages {
        ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%%destImage%
        if (ErrorLevel = 0) {
            DetectedDestination := destName
            TrayTip, Sukli Automation, Destination: %DetectedDestination%, 2
            break
        }
    }
    
    ; ============================================================
    ; STEP 3: DETECT PASSENGER COUNT (Number 1-10)
    ; ============================================================
    Loop, 10 {
        countNum := A_Index
        countImage := NumberImages[countNum]
        ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%%countImage%
        if (ErrorLevel = 0) {
            DetectedPassengerCount := countNum
            TrayTip, Sukli Automation, Passengers: %DetectedPassengerCount%, 2
            break
        }
    }
    
    ; ============================================================
    ; STEP 4: DETECT PASSENGER TYPE
    ; ============================================================
    for typeName, typeImage in TypeImages {
        ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%%typeImage%
        if (ErrorLevel = 0) {
            DetectedPassengerType := typeName
            TrayTip, Sukli Automation, Type: %DetectedPassengerType%, 2
            break
        }
    }
    
    ; ============================================================
    ; STEP 5: DETECT PAYMENT AMOUNT
    ; ============================================================
    for paymentValue, paymentImage in PaymentImages {
        ImageSearch, foundX, foundY, WinX, WinY, WinX+WinW, WinY+WinH, %ImageDir%%paymentImage%
        if (ErrorLevel = 0) {
            DetectedPayment := paymentValue
            TrayTip, Sukli Automation, Payment: ₱%DetectedPayment%, 2
            break
        }
    }
    
    ; ============================================================
    ; STEP 6: VERIFY AND CALCULATE
    ; ============================================================
    if (DetectedDestination != "" and DetectedPassengerCount > 0 and DetectedPayment > 0) {
        ; Calculate fare
        totalFare := CalculateFare(DetectedDestination, DetectedPassengerCount, DetectedPassengerType)
        sukli := DetectedPayment - totalFare
        
        if (sukli >= 0) {
            ; Calculate sukli breakdown (highest to lowest)
            sukliBreakdown := CalculateBreakdown(sukli)
            
            ; Show detailed info in a popup
            MsgBox, 64, Sukli Automation - Info Detected,
            (LTrim
                Route: %RouteName%
                Destination: %DetectedDestination%
                Passengers: %DetectedPassengerCount%
                Type: %DetectedPassengerType%
                Payment: ₱%DetectedPayment%
                Total Fare: ₱%totalFare%
                Sukli: ₱%sukli%
                Breakdown: %sukliBreakdown%
                Click Order: Highest to lowest
            )
            
            ; ============================================================
            ; STEP 7: PERFORM THE SUKLI (Highest to Lowest)
            ; ============================================================
            PerformSukli(WinX, WinY, WinW, WinH, sukliBreakdown)
            
            ; ============================================================
            ; STEP 8: CLICK THE CHECK BUTTON
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
        } else {
            MsgBox, 16, Error, Payment is less than fare!`nFare: ₱%totalFare%`nPayment: ₱%DetectedPayment%
        }
    } else {
        MsgBox, 16, Error, Could not detect all information!`nDestination: %DetectedDestination%`nCount: %DetectedPassengerCount%`nPayment: %DetectedPayment%
    }
}

; ============================================================
; CALCULATE FARE
; ============================================================
CalculateFare(destination, passengerCount, passengerType) {
    global
    
    ; Get the barangay list for the current route
    barangays := RouteData[RouteName]
    if (barangays = "") {
        return 13
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
        return 13
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
    ; Minimum units = 4, extra = destIndex - minUnits (if positive)
    if (destIndex > minUnits) {
        extra := destIndex - minUnits
        perPassengerFare := baseFare + (extra * extraFare)
    } else {
        perPassengerFare := baseFare
    }
    
    return perPassengerFare * passengerCount
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
; PERFORM SUKLI (Coordinate-Based - Clicks Denomination Buttons)
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
