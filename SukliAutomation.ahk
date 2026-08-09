; ============================================================
; SUKLI AUTOMATION - FINAL (MANUAL RESOLUTION SELECTION)
; ============================================================
; - User selects 1366 or 1920 in the GUI
; - Script uses the corresponding image folder
; - Ignores window size for folder selection
; - No auto-detect (reduces confusion)
; ============================================================

#NoEnv
#SingleInstance, Force
SetWorkingDir %A_ScriptDir%
SetBatchLines, 10ms
CoordMode, Pixel, Relative
CoordMode, Mouse, Relative
CoordMode, ToolTip, Relative

; ============================================================
; CONFIGURATION
; ============================================================
ConfigFile := A_ScriptDir . "\sukli_config.ini"
LogFile := A_ScriptDir . "\sukli_log.csv"
WinTitle := "Roblox"
ImageVariation := 70
macroRunning := false
CurrentRoute := "Balagtas"
lastDetectionTime := 0
detectionCooldown := 2000
isProcessing := false
g_StopRequested := false

; --- Resolution override (must be 1366 or 1920) ---
global UserSelectedRes := "1920"

; --- Profile system ---
CurrentProfile := "default"
SettingsFileName := A_ScriptDir . "\default.ini"

; --- Pre-computed search areas ---
global g_DestSearch := {x1:0, y1:0, x2:0, y2:0}
global g_PaymentSearch := {x1:0, y1:0, x2:0, y2:0}
global g_CountSearch := {x1:0, y1:0, x2:0, y2:0}

; --- Reference resolution (used for scaling) ---
RefWidth := 1920
RefHeight := 1080

; --- Image folders ---
ImageDir := ""
ButtonDir := ""

; --- Current window size ---
CurrentWinW := 0
CurrentWinH := 0

; Auto-Fallback globals
g_FallbackPickup := ""
g_FallbackDest := ""
g_FallbackPay := ""
g_FallbackPax := 0
g_FallbackPaxType := ""

; ============================================================
; CREATE FOLDERS
; ============================================================
if !FileExist(A_ScriptDir . "\sukli_images_1366") {
    FileCreateDir, %A_ScriptDir%\sukli_images_1366
    FileCreateDir, %A_ScriptDir%\sukli_images_1920
    FileCreateDir, %A_ScriptDir%\sukli_buttons_1366
    FileCreateDir, %A_ScriptDir%\sukli_buttons_1920
    MsgBox, 64, Folders Created, Folders created:`n- sukli_images_1366\`n- sukli_images_1920\`n- sukli_buttons_1366\`n- sukli_buttons_1920\`n`nPlace images in the folder matching your screen resolution.
}

; ============================================================
; READ CONFIG
; ============================================================
if (FileExist(ConfigFile)) {
    IniRead, regularFare, %ConfigFile%, Fares, Regular, 13
    IniRead, studentFare, %ConfigFile%, Fares, Student, 11
    IniRead, seniorFare, %ConfigFile%, Fares, Senior, 11
    IniRead, extraFare, %ConfigFile%, Fares, Extra, 2
    IniRead, minUnits, %ConfigFile%, Fares, MinimumUnits, 4
    IniRead, ImageVariation, %ConfigFile%, Settings, ImageVariation, 70
    IniRead, CurrentRoute, %ConfigFile%, Settings, Route, Balagtas
} else {
    MsgBox, 16, Error, sukli_config.ini not found!
    ExitApp
}

; ============================================================
; READ IMAGE SECTIONS
; ============================================================
ReadIniSection(file, section) {
    result := {}
    IniRead, content, %file%, %section%
    Loop, Parse, content, `n, `r
    {
        if (A_LoopField = "")
            continue
        pos := InStr(A_LoopField, "=")
        if (pos = 0)
            continue
        key := Trim(SubStr(A_LoopField, 1, pos - 1))
        val := Trim(SubStr(A_LoopField, pos + 1))
        result[key] := val
    }
    return result
}

; ============================================================
; DYNAMIC ROUTE DATA LOADER  ; === REFACTOR ===
; ============================================================
RouteData := {}
IniRead, routeContent, %ConfigFile%, Routes
Loop, Parse, routeContent, `n, `r
{
    if (A_LoopField = "")
        continue
    pos := InStr(A_LoopField, "=")
    if (pos = 0)
        continue
    routeName := Trim(SubStr(A_LoopField, 1, pos - 1))
    destString := Trim(SubStr(A_LoopField, pos + 1))
    
    ; Create an array of destinations for this route
    destArray := []
    Loop, Parse, destString, `,
    {
        destArray.Push(Trim(A_LoopField))
    }
    RouteData[routeName] := destArray
}

; --- Destination / Payment / Count images are read from INI (unchanged) ---
DestinationImages := ReadIniSection(ConfigFile, "Destinations")
PaymentImages := ReadIniSection(ConfigFile, "PaymentImages")
StudentCountImages := ReadIniSection(ConfigFile, "PassengerCountsStudent")
SeniorCountImages := ReadIniSection(ConfigFile, "PassengerCountsSenior")
RegularCountImages := ReadIniSection(ConfigFile, "PassengerCounts")

; ============================================================
; BUTTON POSITIONS
; ============================================================
DenomPositions := {}
Denominations := [50, 20, 10, 5, 1]
for i, denom in Denominations {
    IniRead, savedX, %ConfigFile%, DenomPositions, %denom%_x, NONE
    IniRead, savedY, %ConfigFile%, DenomPositions, %denom%_y, NONE
    if (savedX != "NONE" and savedY != "NONE")
        DenomPositions[denom] := {x: savedX, y: savedY}
}

CheckButtonPos := {}
ResetButtonPos := {}
TakeButtonPos := {}
IniRead, checkX, %ConfigFile%, ButtonPositions, check_x, NONE
IniRead, checkY, %ConfigFile%, ButtonPositions, check_y, NONE
if (checkX != "NONE" and checkY != "NONE")
    CheckButtonPos := {x: checkX, y: checkY}
IniRead, resetX, %ConfigFile%, ButtonPositions, reset_x, NONE
IniRead, resetY, %ConfigFile%, ButtonPositions, reset_y, NONE
if (resetX != "NONE" and resetY != "NONE")
    ResetButtonPos := {x: resetX, y: resetY}
IniRead, takeX, %ConfigFile%, ButtonPositions, take_x, NONE
IniRead, takeY, %ConfigFile%, ButtonPositions, take_y, NONE
if (takeX != "NONE" and takeY != "NONE")
    TakeButtonPos := {x: takeX, y: takeY}

; ============================================================
; END OF AUTO-EXECUTE
; ============================================================
return

; ============================================================
; SELECT IMAGE FOLDER (MANUAL OVERRIDE)
; ============================================================
SelectImageFolder() {
    global ImageDir, ButtonDir, RefWidth, RefHeight, UserSelectedRes

    if (UserSelectedRes = "1366") {
        bestMatch := 1366
    } else {
        bestMatch := 1920
    }

    RefWidth := bestMatch
    RefHeight := Round(bestMatch * 9 / 16)

    ImageDir := A_ScriptDir . "\sukli_images_" . bestMatch . "\"
    ButtonDir := A_ScriptDir . "\sukli_buttons_" . bestMatch . "\"

    if !FileExist(ImageDir) {
        MsgBox, 48, Warning, Image folder not found: %ImageDir%`nPlease capture images at %RefWidth%x%RefHeight%.
        return false
    }

    Loop, %ImageDir%*.png, 0, 0
    {
        return true
    }
    MsgBox, 48, Warning, No images found in %ImageDir%`nPlease capture images at %RefWidth%x%RefHeight%.
    return false
}

; ============================================================
; CALCULATE ALL POSITIONS
; ============================================================
CalculatePositions(WinW, WinH) {
    global g_DestSearch, g_PaymentSearch, g_CountSearch
    global CurrentWinW, CurrentWinH

    CurrentWinW := WinW
    CurrentWinH := WinH

    g_DestSearch.x1 := 0
    g_DestSearch.x2 := WinW
    g_DestSearch.y1 := Round(WinH * 0.1)
    g_DestSearch.y2 := Round(WinH * 0.7)

    g_PaymentSearch.x1 := Round(WinW * 0.40)
    g_PaymentSearch.x2 := Round(WinW * 0.95)
    g_PaymentSearch.y1 := Round(WinH * 0.1)
    g_PaymentSearch.y2 := Round(WinH * 0.7)

    g_CountSearch.x1 := g_PaymentSearch.x1
    g_CountSearch.x2 := g_PaymentSearch.x2
    g_CountSearch.y1 := g_PaymentSearch.y1
    g_CountSearch.y2 := g_PaymentSearch.y2
}

; ============================================================
; HELPER FUNCTIONS
; ============================================================
UpdateStatus(status) {
    GuiControl, MainGui:, MainDetect, %status%
}

RobustImageSearch(ByRef foundX, ByRef foundY, X1, Y1, X2, Y2, imgFile) {
    global ImageVariation
    if (!FileExist(imgFile))
        return 1
    Sleep, 5
    ImageSearch, foundX, foundY, X1, Y1, X2, Y2, *%ImageVariation% %imgFile%
    return ErrorLevel
}

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

; ============================================================
; DESTINATION SEARCH (FULL WINDOW)
; ============================================================
SearchDestination(imgFile) {
    global g_DestSearch
    if (!FileExist(imgFile))
        return [0,0,false]
    if (RobustImageSearch(foundX, foundY, g_DestSearch.x1, g_DestSearch.y1, g_DestSearch.x2, g_DestSearch.y2, imgFile) = 0)
        return [foundX, foundY, true]
    return [0,0,false]
}

; ============================================================
; SMART SEARCH (3 levels)
; ============================================================
SmartImageSearch(imgFile) {
    global g_PaymentSearch, CurrentWinW, CurrentWinH
    if (!FileExist(imgFile))
        return [0,0,false]

    if (RobustImageSearch(foundX, foundY, g_PaymentSearch.x1, g_PaymentSearch.y1, g_PaymentSearch.x2, g_PaymentSearch.y2, imgFile) = 0)
        return [foundX, foundY, true]

    x1 := Round(CurrentWinW * 0.30)
    x2 := Round(CurrentWinW * 0.65)
    if (RobustImageSearch(foundX, foundY, x1, g_PaymentSearch.y1, x2, g_PaymentSearch.y2, imgFile) = 0)
        return [foundX, foundY, true]

    x1 := Round(CurrentWinW * 0.60)
    x2 := CurrentWinW
    if (RobustImageSearch(foundX, foundY, x1, g_PaymentSearch.y1, x2, g_PaymentSearch.y2, imgFile) = 0)
        return [foundX, foundY, true]

    return [0,0,false]
}

; ============================================================
; CHECK ALIAS FUNCTIONS
; ============================================================
CheckAliasDest(aliasList) {
    global ImageDir
    matches := []
    Loop, Parse, aliasList, `,
    {
        aliasFile := Trim(A_LoopField)
        if (aliasFile = "")
            continue
        imgFile := ImageDir . aliasFile
        if (!FileExist(imgFile))
            continue
        result := SearchDestination(imgFile)
        if (result[3]) {
            matches.Push({name: aliasFile, x: result[1]})
        }
    }
    return matches
}

CheckAliasSmart(aliasList) {
    global ImageDir
    Loop, Parse, aliasList, `,
    {
        aliasFile := Trim(A_LoopField)
        if (aliasFile = "")
            continue
        imgFile := ImageDir . aliasFile
        if (!FileExist(imgFile))
            continue
        smartResult := SmartImageSearch(imgFile)
        if (smartResult[3])
            return true
    }
    return false
}

global LastPayment := ""
global LastPaxType := ""
global LastPaxCount := 0

; ============================================================
; COLLISION DETECTION
; ============================================================
DetectCollision(allMatches, threshold := 15) {
    for i, m1 in allMatches {
        for j, m2 in allMatches {
            if (i = j)
                continue
            if (m1.name != m2.name and Abs(m1.x - m2.x) <= threshold)
                return m1.name . " (X=" . m1.x . ") vs " . m2.name . " (X=" . m2.x . ")"
        }
    }
    return ""
}

; ============================================================
; AUTO DETECT
; ============================================================
AutoDetectEntry() {
    global RouteData, CurrentRoute, ImageDir, DestinationImages, PaymentImages
    global StudentCountImages, SeniorCountImages, RegularCountImages
    global g_StopRequested

    result := {pickup: "", destination: "", paxCount: 0, passengerType: "Regular", payment: "", collision: false, collisionInfo: ""}

    barangays := RouteData[CurrentRoute]
    allMatches := []
    for i, name in barangays {
        if (g_StopRequested)
            return result
        if (!DestinationImages.HasKey(name))
            continue
        aliasList := DestinationImages[name]
        matches := CheckAliasDest(aliasList)
        for idx, match in matches {
            allMatches.Push({name: name, x: match.x, alias: match.name})
        }
    }

    collisionMsg := DetectCollision(allMatches)
    if (collisionMsg != "") {
        result.collision := true
        result.collisionInfo := collisionMsg
    }

    if (allMatches.Length() > 0) {
        ; Sort by X
        for i, match in allMatches {
            for j, match2 in allMatches {
                if (match.x < match2.x) {
                    temp := allMatches[i]
                    allMatches[i] := allMatches[j]
                    allMatches[j] := temp
                }
            }
        }
        result.pickup := allMatches[1].name
        result.destination := allMatches[allMatches.Length()].name
    }

    if (g_StopRequested)
        return result

    ; --- PAYMENT ---
    if (LastPayment != "" and PaymentImages.HasKey(LastPayment)) {
        if (CheckAliasSmart(PaymentImages[LastPayment])) {
            result.payment := LastPayment
        }
    }
    if (result.payment = "") {
        for amount, aliasList in PaymentImages {
            if (amount = LastPayment)
                continue
            if (CheckAliasSmart(aliasList)) {
                result.payment := amount
                break
            }
        }
    }
    if (result.payment != "")
        LastPayment := result.payment

    if (g_StopRequested)
        return result

    ; --- PASSENGER COUNT ---
    found := false

    if (LastPaxType != "" and LastPaxCount > 0) {
        typeMap := {Regular: RegularCountImages, Student: StudentCountImages, Senior: SeniorCountImages}
        if (typeMap.HasKey(LastPaxType) and typeMap[LastPaxType].HasKey(LastPaxCount)) {
            if (CheckAliasSmart(typeMap[LastPaxType][LastPaxCount])) {
                result.paxCount := LastPaxCount + 0
                result.passengerType := LastPaxType
                found := true
            }
        }
    }

    if (!found and !g_StopRequested) {
        for count, aliasList in RegularCountImages {
            if (LastPaxType = "Regular" and count = LastPaxCount)
                continue
            if (CheckAliasSmart(aliasList)) {
                result.paxCount := count + 0
                result.passengerType := "Regular"
                found := true
                break
            }
        }
    }

    if (!found and !g_StopRequested) {
        for count, aliasList in StudentCountImages {
            if (LastPaxType = "Student" and count = LastPaxCount)
                continue
            if (CheckAliasSmart(aliasList)) {
                result.paxCount := count + 0
                result.passengerType := "Student"
                found := true
                break
            }
        }
    }

    if (!found and !g_StopRequested) {
        for count, aliasList in SeniorCountImages {
            if (LastPaxType = "Senior" and count = LastPaxCount)
                continue
            if (CheckAliasSmart(aliasList)) {
                result.paxCount := count + 0
                result.passengerType := "Senior"
                found := true
                break
            }
        }
    }

    if (found) {
        LastPaxType := result.passengerType
        LastPaxCount := result.paxCount
    }

    return result
}

; ============================================================
; CLICK BUTTONS
; ============================================================
ClickTakeButton(WinW, WinH) {
    global TakeButtonPos, ButtonDir, g_StopRequested
    if (g_StopRequested)
        return false
    if (TakeButtonPos.HasKey("x") and TakeButtonPos.HasKey("y")) {
        clickX := Round(WinW * TakeButtonPos.x)
        clickY := Round(WinH * TakeButtonPos.y)
        MouseMove, clickX, clickY, 2
        Sleep, 50
        if (g_StopRequested)
            return false
        MouseClick, left, clickX, clickY, 1, 0
        Sleep, 300
        if (g_StopRequested)
            return false
        UpdateStatus("[OK] Take button clicked")
        return true
    }
    imgFile := ButtonDir . "take_button.png"
    if (RobustImageSearch(foundX, foundY, 0, 0, WinW, WinH, imgFile) = 0) {
        if (g_StopRequested)
            return false
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 300
        if (g_StopRequested)
            return false
        UpdateStatus("[OK] Take button clicked (image)")
        return true
    } else {
        UpdateStatus("[FAIL] Take button NOT found")
        return false
    }
}

ClickResetButton(WinW, WinH) {
    global ResetButtonPos, ButtonDir, g_StopRequested
    if (g_StopRequested)
        return false
    if (ResetButtonPos.HasKey("x") and ResetButtonPos.HasKey("y")) {
        clickX := Round(WinW * ResetButtonPos.x)
        clickY := Round(WinH * ResetButtonPos.y)
        MouseMove, clickX, clickY, 2
        Sleep, 50
        if (g_StopRequested)
            return false
        MouseClick, left, clickX, clickY, 1, 0
        Sleep, 120
        if (g_StopRequested)
            return false
        UpdateStatus("[OK] Reset button clicked")
        return true
    }
    imgFile := ButtonDir . "reset_arrow.png"
    if (RobustImageSearch(foundX, foundY, 0, 0, WinW, WinH, imgFile) = 0) {
        if (g_StopRequested)
            return false
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 120
        if (g_StopRequested)
            return false
        UpdateStatus("[OK] Reset button clicked (image)")
        return true
    } else {
        UpdateStatus("[FAIL] Reset button NOT found")
        return false
    }
}

ClickCheckButton(WinW, WinH) {
    global CheckButtonPos, ButtonDir, g_StopRequested
    if (g_StopRequested)
        return false
    if (CheckButtonPos.HasKey("x") and CheckButtonPos.HasKey("y")) {
        clickX := Round(WinW * CheckButtonPos.x)
        clickY := Round(WinH * CheckButtonPos.y)
        MouseMove, clickX, clickY, 2
        Sleep, 50
        if (g_StopRequested)
            return false
        MouseClick, left, clickX, clickY, 1, 0
        Sleep, 120
        if (g_StopRequested)
            return false
        UpdateStatus("[OK] Check button clicked")
        return true
    }
    imgFile := ButtonDir . "check_button.png"
    if (RobustImageSearch(foundX, foundY, 0, 0, WinW, WinH, imgFile) = 0) {
        if (g_StopRequested)
            return false
        MouseClick, left, foundX + 10, foundY + 10, 1, 0
        Sleep, 120
        if (g_StopRequested)
            return false
        UpdateStatus("[OK] Check button clicked (image)")
        return true
    } else {
        UpdateStatus("[FAIL] Check button NOT found")
        return false
    }
}

; ============================================================
; PERFORM SUKLI – smart click logic  ; === REFACTOR ===
; ============================================================
PerformSukli(WinW, WinH, breakdown) {
    global DenomPositions, g_StopRequested
    if (g_StopRequested)
        return false
    Sleep, 350 ; Initial wait for UI to settle (longer buffer before first click)
    if (g_StopRequested)
        return false
    
    Loop, Parse, breakdown, `,
    {
        if (g_StopRequested)
            return false
        denom := A_LoopField
        if (DenomPositions.HasKey(denom)) {
            pos := DenomPositions[denom]
            
            ; Add a tiny random offset (1-3 pixels) so it's not a perfect bot click
            Random, randX, -2, 2
            Random, randY, -2, 2
            
            clickX := Round(WinW * pos.x) + randX
            clickY := Round(WinH * pos.y) + randY

            MouseMove, clickX, clickY, 2 ; Slightly slower move, lands more reliably
            Sleep, 90
            if (g_StopRequested)
                return false
            
            ; Press and Hold slightly longer (more reliable for games)
            Click, Down, %clickX%, %clickY%
            Sleep, 90
            Click, Up
            if (g_StopRequested)
                return false
            
            UpdateStatus("[DOING] P" . denom . " clicked")
            
            ; Randomize delay between clicks (250ms to 380ms) - gives the game
            ; UI time to visually register each click before the next one fires
            Random, nextDelay, 250, 380
            Sleep, %nextDelay%
            if (g_StopRequested)
                return false
        }
    }
    UpdateStatus("[OK] All denominations clicked!")
    return true
}

; ============================================================
; PROCESS TRANSACTION
; ============================================================
ProcessTransaction(pickup, dest, pax, pType, pay, WinW, WinH) {
    global RouteData, CurrentRoute, regularFare, studentFare, seniorFare, extraFare, minUnits, LogFile, g_StopRequested
    if (g_StopRequested)
        return false

    barangays := RouteData[CurrentRoute]
    pickupIndex := 0
    destIndex := 0
    foundPickup := false
    foundDest := false

    for i, name in barangays {
        if (name = pickup) {
            pickupIndex := i
            foundPickup := true
        }
        if (name = dest) {
            destIndex := i
            foundDest := true
        }
    }
    if (!foundPickup or !foundDest) {
        UpdateStatus("[FAIL] Pickup or Drop-off not found on route!")
        return
    }

    unitsCount := Abs(destIndex - pickupIndex) + 1
    extra := Max(0, unitsCount - minUnits)

    baseFare := (pType = "Student") ? studentFare : ((pType = "Senior") ? seniorFare : regularFare)
    perPaxFare := baseFare + (extra * extraFare)

    totalFare := perPaxFare * pax
    sukli := pay - totalFare

    if (sukli < 0) {
        UpdateStatus("[FAIL] Payment P" . pay . " < Fare P" . totalFare)
        return
    }

    sukliBreakdown := CalculateBreakdown(sukli)

    UpdateStatus("[OK] " . pickup . " → " . dest . " | " . pax . " " . pType . " | P" . pay . " | Fare: P" . totalFare . " | Sukli: P" . sukli)

    Sleep, 120
    if (!PerformSukli(WinW, WinH, sukliBreakdown) or g_StopRequested)
        return false

    Sleep, 120
    if (g_StopRequested or !ClickCheckButton(WinW, WinH))
        return false

    if (g_StopRequested)
        return false

    FormatTime, ts,, yyyy-MM-dd HH:mm:ss
    FileAppend, %ts%`,%CurrentRoute%`,%pickup%→%dest%`,%pax%`,%pType%`,%pay%`,%totalFare%`,%sukli%`n, %LogFile%
    UpdateStatus("[OK] DONE! P" . sukli . " sukli")
    Sleep, 800
    return true
}

; ============================================================
; DIAGNOSTIC
; ============================================================
DiagnosticDetect(WinW, WinH) {
    global RouteData, CurrentRoute, ImageDir, DestinationImages, PaymentImages
    global StudentCountImages, SeniorCountImages, RegularCountImages
    global ImageVariation, RefWidth, RefHeight, CurrentWinW, CurrentWinH

    result_pickup := ""
    result_dest := ""
    result_payment := ""
    result_pax := 0
    result_type := "Regular"
    allMatches := []

    debug := ""

    debug := debug . "Route: " . CurrentRoute . "`n"
    debug := debug . "Window Size: " . WinW . "x" . WinH . "`n"
    debug := debug . "Reference: " . RefWidth . "x" . RefHeight . "`n"
    debug := debug . "Image Folder: " . ImageDir . "`n"
    debug := debug . "Scale: " . Round(WinW/RefWidth, 2) . "x" . Round(WinH/RefHeight, 2) . "`n"
    debug := debug . "ImageVariation: " . ImageVariation . "`n`n"
    debug := debug . "--- DETECTION RESULTS ---`n"

    barangays := RouteData[CurrentRoute]

    debug := debug . "`nDESTINATIONS (Pickup = leftmost, Drop-off = rightmost):`n"
    for i, name in barangays {
        if (!DestinationImages.HasKey(name))
            continue
        aliasList := DestinationImages[name]
        matches := CheckAliasDest(aliasList)
        for idx, match in matches {
            allMatches.Push({name: name, x: match.x})
        }
    }
    if (allMatches.Length() > 0) {
        for i, m1 in allMatches {
            for j, m2 in allMatches {
                if (m1.x < m2.x) {
                    temp := allMatches[i]
                    allMatches[i] := allMatches[j]
                    allMatches[j] := temp
                }
            }
        }
        result_pickup := allMatches[1].name
        result_dest := allMatches[allMatches.Length()].name
        debug := debug . "  [OK] PICKUP: " . result_pickup . " (X=" . allMatches[1].x . ")`n"
        debug := debug . "  [OK] DROP-OFF: " . result_dest . " (X=" . allMatches[allMatches.Length()].x . ")`n"

        collisionMsg := DetectCollision(allMatches)
        if (collisionMsg != "") {
            debug := debug . "  [!] WARNING - POSSIBLE FALSE MATCH: " . collisionMsg . "`n"
            debug := debug . "      Two different destinations matched almost the same spot.`n"
            debug := debug . "      This usually means ImageVariation is too high, lower it.`n"
        }
    } else {
        debug := debug . "  [FAIL] NONE FOUND`n"
    }

    debug := debug . "`nPAYMENTS:`n"
    foundPayment := false
    for amount, aliasList in PaymentImages {
        Loop, Parse, aliasList, `,
        {
            aliasFile := Trim(A_LoopField)
            if (aliasFile = "")
                continue
            imgFile := ImageDir . aliasFile
            if (!FileExist(imgFile))
                continue
            smartResult := SmartImageSearch(imgFile)
            if (smartResult[3]) {
                result_payment := amount
                foundPayment := true
                debug := debug . "  [OK] FOUND: P" . amount . " at X=" . smartResult[1] . "`n"
                break
            }
        }
        if (foundPayment)
            break
    }
    if (!foundPayment) {
        debug := debug . "  [FAIL] NONE FOUND`n"
    }

    debug := debug . "`nPASSENGER COUNTS:`n"
    foundPax := false
    for count, aliasList in StudentCountImages {
        Loop, Parse, aliasList, `,
        {
            aliasFile := Trim(A_LoopField)
            if (aliasFile = "")
                continue
            imgFile := ImageDir . aliasFile
            if (!FileExist(imgFile))
                continue
            smartResult := SmartImageSearch(imgFile)
            if (smartResult[3]) {
                result_pax := count + 0
                result_type := "Student"
                foundPax := true
                debug := debug . "  [OK] FOUND: " . count . " " . result_type . "`n"
                break
            }
        }
        if (foundPax)
            break
    }
    if (!foundPax) {
        for count, aliasList in SeniorCountImages {
            Loop, Parse, aliasList, `,
            {
                aliasFile := Trim(A_LoopField)
                if (aliasFile = "")
                    continue
                imgFile := ImageDir . aliasFile
                if (!FileExist(imgFile))
                    continue
                smartResult := SmartImageSearch(imgFile)
                if (smartResult[3]) {
                    result_pax := count + 0
                    result_type := "Senior"
                    foundPax := true
                    debug := debug . "  [OK] FOUND: " . count . " " . result_type . "`n"
                    break
                }
            }
            if (foundPax)
                break
        }
    }
    if (!foundPax) {
        for count, aliasList in RegularCountImages {
            Loop, Parse, aliasList, `,
            {
                aliasFile := Trim(A_LoopField)
                if (aliasFile = "")
                    continue
                imgFile := ImageDir . aliasFile
                if (!FileExist(imgFile))
                    continue
                smartResult := SmartImageSearch(imgFile)
                if (smartResult[3]) {
                    result_pax := count + 0
                    result_type := "Regular"
                    foundPax := true
                    debug := debug . "  [OK] FOUND: " . count . " " . result_type . "`n"
                    break
                }
            }
            if (foundPax)
                break
        }
    }
    if (!foundPax) {
        debug := debug . "  [FAIL] NONE FOUND`n"
    }

    debug := debug . "`n=== FINAL RESULT ===`n"
    if (result_pickup = "") {
        debug := debug . "Pickup:     [FAIL] NONE`n"
    } else {
        debug := debug . "Pickup:     [OK] " . result_pickup . "`n"
    }
    if (result_dest = "") {
        debug := debug . "Drop-off:   [FAIL] NONE`n"
    } else {
        debug := debug . "Drop-off:   [OK] " . result_dest . "`n"
    }
    if (result_payment = "") {
        debug := debug . "Payment:     [FAIL] NONE`n"
    } else {
        debug := debug . "Payment:     [OK] P" . result_payment . "`n"
    }
    if (result_pax = 0) {
        debug := debug . "Passenger:   [FAIL] NONE`n"
    } else {
        debug := debug . "Passenger:   [OK] " . result_pax . " " . result_type . "`n"
    }

    allFound := (result_pickup != "" and result_dest != "" and result_payment != "" and result_pax != 0)
    if (allFound) {
        debug := debug . "`nSTATUS: [OK] ALL DETECTED - Ready for auto!`n"
    } else {
        debug := debug . "`nSTATUS: [FAIL] MISSING - Check which items are NONE above`n"
    }

    return debug
}

; ============================================================
; PROFILE SELECTION
; ============================================================
SelectItem:
    Gui, Submit, NoHide
    SettingsFileName := A_ScriptDir . "\" . DropItem . ".ini"
    CurrentProfile := DropItem
return

; ============================================================
; CHANGE RESOLUTION (dropdown)
; ============================================================
ChangeResolution:
    Gui, Submit, NoHide
    global UserSelectedRes
    UserSelectedRes := ResChoice
    SelectImageFolder()
    UpdateStatus("[OK] Resolution set to: " . UserSelectedRes)
return

; ============================================================
; SAVE PROFILE
; ============================================================
SaveProfile:
    Gui, Submit, NoHide
    global UserSelectedRes
    if (DropItem = "")
        SettingsFileName := A_ScriptDir . "\default.ini"
    else
        SettingsFileName := A_ScriptDir . "\" . DropItem . ".ini"

    FileAppend, , %SettingsFileName%

    IniWrite, %ImageVariation%, %SettingsFileName%, Settings, ImageVariation
    IniWrite, %CurrentRoute%, %SettingsFileName%, Settings, Route
    IniWrite, %UserSelectedRes%, %SettingsFileName%, Settings, Resolution

    for i, denom in Denominations {
        if (DenomPositions.HasKey(denom)) {
            IniWrite, % DenomPositions[denom].x, %SettingsFileName%, DenomPositions, %denom%_x
            IniWrite, % DenomPositions[denom].y, %SettingsFileName%, DenomPositions, %denom%_y
        }
    }

    IniWrite, % TakeButtonPos.x, %SettingsFileName%, ButtonPositions, take_x
    IniWrite, % TakeButtonPos.y, %SettingsFileName%, ButtonPositions, take_y
    IniWrite, % ResetButtonPos.x, %SettingsFileName%, ButtonPositions, reset_x
    IniWrite, % ResetButtonPos.y, %SettingsFileName%, ButtonPositions, reset_y
    IniWrite, % CheckButtonPos.x, %SettingsFileName%, ButtonPositions, check_x
    IniWrite, % CheckButtonPos.y, %SettingsFileName%, ButtonPositions, check_y

    Gui, -AlwaysOnTop
    MsgBox, 0x40040, Saved, Profile saved as %SettingsFileName%!
    Gui, +AlwaysOnTop
return

; ============================================================
; LOAD PROFILE
; ============================================================
LoadProfile:
    if !FileExist(SettingsFileName) {
        MsgBox, 0x40030, Error, Profile %SettingsFileName% not found!
        return
    }

    IniRead, ImageVariation, %SettingsFileName%, Settings, ImageVariation, 70
    IniRead, CurrentRoute, %SettingsFileName%, Settings, Route, Balagtas
    IniRead, lUserSelectedRes, %SettingsFileName%, Settings, Resolution, 1920

    for i, denom in Denominations {
        IniRead, savedX, %SettingsFileName%, DenomPositions, %denom%_x, NONE
        IniRead, savedY, %SettingsFileName%, DenomPositions, %denom%_y, NONE
        if (savedX != "NONE" and savedY != "NONE")
            DenomPositions[denom] := {x: savedX, y: savedY}
    }

    IniRead, takeX, %SettingsFileName%, ButtonPositions, take_x, NONE
    IniRead, takeY, %SettingsFileName%, ButtonPositions, take_y, NONE
    if (takeX != "NONE" and takeY != "NONE")
        TakeButtonPos := {x: takeX, y: takeY}

    IniRead, resetX, %SettingsFileName%, ButtonPositions, reset_x, NONE
    IniRead, resetY, %SettingsFileName%, ButtonPositions, reset_y, NONE
    if (resetX != "NONE" and resetY != "NONE")
        ResetButtonPos := {x: resetX, y: resetY}

    IniRead, checkX, %SettingsFileName%, ButtonPositions, check_x, NONE
    IniRead, checkY, %SettingsFileName%, ButtonPositions, check_y, NONE
    if (checkX != "NONE" and checkY != "NONE")
        CheckButtonPos := {x: checkX, y: checkY}

    GuiControl,, ImageVariation, %ImageVariation%
    GuiControl, ChooseString, RouteChoice, %CurrentRoute%
    GuiControl, ChooseString, ResChoice, %lUserSelectedRes%
    global UserSelectedRes := lUserSelectedRes

    SelectImageFolder()

    Gui, -AlwaysOnTop
    MsgBox, 0x40040, Loaded, Profile %SettingsFileName% loaded!
    Gui, +AlwaysOnTop

    Gosub, ChangeRoute
return

; ============================================================
; RUN DIAGNOSTIC
; ============================================================
RunDiagnostic:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        WinGet, robloxID, ID, ahk_class Roblox
        if (robloxID = "") {
            MsgBox, 16, Error, Roblox window not found!
            return
        }
        WinGetPos, WinX, WinY, WinW, WinH, ahk_id %robloxID%
        if (WinW = "") {
            MsgBox, 16, Error, Roblox window not found!
            return
        }
    }

    if !SelectImageFolder() {
        MsgBox, 48, Warning, No images found for selected resolution. Please capture images.
        return
    }

    CalculatePositions(WinW, WinH)
    UpdateStatus("[DIAG] Running diagnostic...")
    Sleep, 200

    debugOutput := DiagnosticDetect(WinW, WinH)

    MsgBox, 64, Diagnostic Results, %debugOutput%

    UpdateStatus("[DIAG] Done - Check popup for results")
return

; ============================================================
; CHANGE ROUTE
; ============================================================
ChangeRoute:
    Gui, MainGui:Submit, NoHide
    CurrentRoute := RouteChoice
    IniWrite, %CurrentRoute%, %ConfigFile%, Settings, Route
    UpdateStatus("[OK] Route changed to: " . CurrentRoute)
return

; ============================================================
; MAIN LOGIC + AUTO-FALLBACK (CONTINUOUS POLLING - LIKE F8)
; ============================================================
SukliScreenDetected(WinW, WinH) {
    global lastDetectionTime, detectionCooldown, g_FallbackPickup, g_FallbackDest, g_FallbackPay
    global g_StopRequested, LastPayment, LastPaxType, LastPaxCount

    if (g_StopRequested)
        return

    currentTime := A_TickCount
    if (currentTime - lastDetectionTime < detectionCooldown)
        return
    lastDetectionTime := currentTime

    CalculatePositions(WinW, WinH)

    ; --- CLEAR CACHE – forces a fresh scan like F8 ---
    LastPayment := ""
    LastPaxType := ""
    LastPaxCount := 0

    UpdateStatus("[STEP 1] Detecting (polling until UI loads)...")
    detectStartTime := A_TickCount
    ; F8 accepts one completed scan.  Do the same for F2: a second full
    ; ImageSearch pass at 1920px can exceed the old five-second budget.
    maxWaitMs := 15000
    detected := {pickup: "", destination: "", paxCount: 0, passengerType: "Regular", payment: "", collision: false}
    allFound := false

    while (A_TickCount - detectStartTime < maxWaitMs) {
        if (g_StopRequested)
            return

        Sleep, 300
        detected := AutoDetectEntry()

        ; Update status with current findings (just like F8 Diag does)
        pickupStr := detected.pickup ? detected.pickup : "?"
        destStr := detected.destination ? detected.destination : "?"
        paxStr := detected.paxCount ? detected.paxCount : "?"
        payStr := detected.payment ? "P" . detected.payment : "?"
        UpdateStatus("[POLLING] Pickup:" . pickupStr . " → Drop:" . destStr . " | Pax:" . paxStr . " " . detected.passengerType . " | Pay:" . payStr)

        if (detected.collision) {
            UpdateStatus("[WARNING] Collision: " . detected.collisionInfo)
            ; Don't break on collision, let it retry. If it persists, fallback.
            continue
        }

        ; Check if this poll is complete (no missing field)
        if (detected.pickup = "" or detected.destination = "" or detected.payment = "" or detected.paxCount = 0) {
            continue
        }

        ; A complete, non-colliding result is enough.  This matches F8's
        ; diagnostic acceptance rule, which reports a single complete scan.
        allFound := true
        break
    }

    if (g_StopRequested)
        return

    ; If we still have a collision after the loop, handle it
    if (detected.collision) {
        UpdateStatus("[SAFETY] Collision detected (" . detected.collisionInfo . "). Opening Manual Fallback...")
        SoundBeep, 500, 300
        Sleep, 500
        g_FallbackPickup := detected.pickup
        g_FallbackDest := detected.destination
        g_FallbackPay := detected.payment
        g_FallbackPax := detected.paxCount
        g_FallbackPaxType := detected.passengerType
        Gosub, ManualEntryFallback
        return
    }

    ; If we still don't have all values after 5 seconds, fallback
    if (!allFound) {
        UpdateStatus("[FAIL] Missing values after 5 seconds. Opening Manual Fallback...")
        Sleep, 500
        g_FallbackPickup := detected.pickup
        g_FallbackDest := detected.destination
        g_FallbackPay := detected.payment
        g_FallbackPax := detected.paxCount
        g_FallbackPaxType := detected.passengerType
        Gosub, ManualEntryFallback
        return
    }

    UpdateStatus("[STEP 2] Resetting...")
    ClickResetButton(WinW, WinH)
    Sleep, 150

    ProcessTransaction(detected.pickup, detected.destination, detected.paxCount, detected.passengerType, detected.payment, WinW, WinH)
}

; ============================================================
; CHECK SCREEN LOOP – optimized anchor search  ; === REFACTOR ===
; ============================================================
CheckSukliScreen:
    if (!macroRunning or g_StopRequested or isProcessing)
        return
    
    isProcessing := true
    
    ; 1. Check if Roblox is active first
    WinGet, activeID, ID, A
    WinGet, robloxID, ID, %WinTitle%
    if (activeID != robloxID) {
        isProcessing := false
        return
    }

    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    
    ; 2. ANCHOR SEARCH: Only look for the "Take" button or "Sukli Header"
    ; This is the only image search that runs constantly (every 200ms)
    sukliImg := ImageDir . "sukli_screen.png"
    takeImg := ButtonDir . "take_button.png"
    
    if (RobustImageSearch(foundX, foundY, 0, 0, WinW, WinH, sukliImg) = 0) {
        ; ONLY if the screen is confirmed open, we do the heavy detection
        SukliScreenDetected(WinW, WinH)
    }
    else if (RobustImageSearch(foundX, foundY, 0, 0, WinW, WinH, takeImg) = 0) {
        UpdateStatus("[STEP 0] Take button found!")
        ClickTakeButton(WinW, WinH)
    }
    
    isProcessing := false
return

; ============================================================
; FAILSAFE TIMER
; ============================================================
SetTimer, FailsafeTimer, 15000
FailsafeTimer:
    if (macroRunning and isProcessing) {
        UpdateStatus("[FAILSAFE] Macro stuck - restarting...")
        Gosub, StopMacro
        Sleep, 200
        Gosub, StartMacro
    }
return

; ============================================================
; CALIBRATION HOTKEYS
; ============================================================
CalibrateDenom:
F6_Action:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    CalculatePositions(WinW, WinH)
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
                WinGetPos, winX, winY, winW, winH, %WinTitle%
                relX := (mx - winX) / winW
                relY := (my - winY) / winH
                DenomPositions[denom] := {x: relX, y: relY}
                IniWrite, %relX%, %ConfigFile%, DenomPositions, %denom%_x
                IniWrite, %relY%, %ConfigFile%, DenomPositions, %denom%_y
                SoundBeep, 800, 100
                Sleep, 150
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

CalibrateButtons:
F7_Action:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    CalculatePositions(WinW, WinH)
    MsgBox, 64, Calibration, Calibrate TAKE, CHECK (green), and RESET (red) buttons.`n`nHover over each button and press SPACE. Press ESC to cancel.

    ToolTip, Hover over the TAKE button, then press SPACE
    cancelled := false
    Loop {
        if (GetKeyState("Escape", "D")) {
            cancelled := true
            break
        }
        if (GetKeyState("Space", "D")) {
            MouseGetPos, mx, my
            WinGetPos, winX, winY, winW, winH, %WinTitle%
            relX := (mx - winX) / winW
            relY := (my - winY) / winH
            TakeButtonPos := {x: relX, y: relY}
            IniWrite, %relX%, %ConfigFile%, ButtonPositions, take_x
            IniWrite, %relY%, %ConfigFile%, ButtonPositions, take_y
            SoundBeep, 800, 100
            Sleep, 150
            break
        }
        Sleep, 50
    }
    if (cancelled) {
        ToolTip
        MsgBox, 48, Cancelled, Calibration cancelled.
        return
    }

    ToolTip, Hover over the RED RESET button, then press SPACE
    Loop {
        if (GetKeyState("Escape", "D")) {
            cancelled := true
            break
        }
        if (GetKeyState("Space", "D")) {
            MouseGetPos, mx, my
            WinGetPos, winX, winY, winW, winH, %WinTitle%
            relX := (mx - winX) / winW
            relY := (my - winY) / winH
            ResetButtonPos := {x: relX, y: relY}
            IniWrite, %relX%, %ConfigFile%, ButtonPositions, reset_x
            IniWrite, %relY%, %ConfigFile%, ButtonPositions, reset_y
            SoundBeep, 800, 100
            Sleep, 150
            break
        }
        Sleep, 50
    }
    if (cancelled) {
        ToolTip
        MsgBox, 48, Cancelled, Calibration cancelled.
        return
    }

    ToolTip, Hover over the GREEN CHECK button, then press SPACE
    Loop {
        if (GetKeyState("Escape", "D")) {
            cancelled := true
            break
        }
        if (GetKeyState("Space", "D")) {
            MouseGetPos, mx, my
            WinGetPos, winX, winY, winW, winH, %WinTitle%
            relX := (mx - winX) / winW
            relY := (my - winY) / winH
            CheckButtonPos := {x: relX, y: relY}
            IniWrite, %relX%, %ConfigFile%, ButtonPositions, check_x
            IniWrite, %relY%, %ConfigFile%, ButtonPositions, check_y
            SoundBeep, 800, 100
            Sleep, 150
            break
        }
        Sleep, 50
    }
    ToolTip
    if (cancelled)
        MsgBox, 48, Cancelled, Calibration cancelled.
    else
        MsgBox, 64, Done, Take, Check, and Reset button positions saved!
return

; ============================================================
; MANUAL TEST
; ============================================================
ManualTest:
    WinGetPos, WinX, WinY, WinW, WinH, %WinTitle%
    if (WinW = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }
    SelectImageFolder()
    CalculatePositions(WinW, WinH)
    UpdateStatus("[TEST] Manual trigger...")
    SukliScreenDetected(WinW, WinH)
return

; ============================================================
; GUI
; ============================================================
MainGUI:
    Gui, MainGui:New, +AlwaysOnTop +ToolWindow, Sukli Automation - Manual Resolution
    Gui, MainGui:Color, 1A2415, 1A2415
    Gui, MainGui:Font, s16 cF3B22C bold, Anton
    Gui, MainGui:Add, Text, x10 y10 w280 h30 Center, Fare Matrix Auto Sukli
    Gui, MainGui:Font, s9 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y40 w280 h20 Center, Manual Resolution Selection

    Gui, MainGui:Font, s10 cF1E9D2 bold, Oswald
    Gui, MainGui:Add, Text, x10 y70 w80 h20, Status:
    Gui, MainGui:Font, s10 cF1E9D2, Oswald
    Gui, MainGui:Add, Text, x95 y70 w185 h20 vMainStatus, [X] Stopped

    Gui, MainGui:Font, s9 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y95 w80 h20, Route:
    Gui, MainGui:Font, s9 cF3B22C, Oswald
    Gui, MainGui:Add, DropDownList, x95 y95 w185 h20 vRouteChoice gChangeRoute, Balagtas|Guiguinto|Malolos
    GuiControl, ChooseString, RouteChoice, %CurrentRoute%

    Gui, MainGui:Add, Text, x10 y120 w80 h20, Detection:
    Gui, MainGui:Font, s9 c6FA05B, Oswald
    Gui, MainGui:Add, Text, x95 y120 w185 h20 vMainDetect, [..] Waiting...

    ; --- Resolution Selection (manual only) ---
    Gui, MainGui:Font, s9 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y145 w80 h20, Resolution:
    Gui, MainGui:Font, s9 cF1E9D2, Oswald
    Gui, MainGui:Add, DropDownList, x95 y145 w185 h20 vResChoice gChangeResolution, 1366|1920
    GuiControl, ChooseString, ResChoice, 1920

    ; --- Profile section ---
    Gui, MainGui:Font, s9 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y175 w80 h20, Profile:
    Gui, MainGui:Font, s9 cF1E9D2, Oswald
    Gui, MainGui:Add, DropDownList, x95 y175 w185 h20 vDropItem gSelectItem, default
    Gui, MainGui:Add, Button, x10 y205 w130 h30 gLoadProfile, Load Profile
    Gui, MainGui:Add, Button, x150 y205 w130 h30 gSaveProfile, Save Profile

    Gui, MainGui:Font, s11 cFFFFFF bold, Oswald
    Gui, MainGui:Add, Button, x10 y245 w130 h35 gStartMacro vMainStartBtn, Start (F2)
    Gui, MainGui:Add, Button, x150 y245 w130 h35 gStopMacro, Stop (F4)

    Gui, MainGui:Font, s10 cFFFFFF bold, Oswald
    Gui, MainGui:Add, Button, x10 y285 w270 h32 gManualEntry, Manual Entry (F9)

    Gui, MainGui:Font, s9 cFFFFFF, Oswald
    Gui, MainGui:Add, Button, x10 y323 w270 h28 gForceWindowedMode, Fix Window Size (F3)

    Gui, MainGui:Add, Button, x10 y355 w65 h30 gManualTest, Test
    Gui, MainGui:Add, Button, x80 y355 w65 h30 gCalibrateDenom, Denoms
    Gui, MainGui:Add, Button, x150 y355 w65 h30 gCalibrateButtons, Buttons
    Gui, MainGui:Add, Button, x220 y355 w40 h30 gRunDiagnostic, Diag
    Gui, MainGui:Add, Button, x265 y355 w30 h30 gReloadScript, R

    Gui, MainGui:Font, s8 c6FA05B, Oswald
    Gui, MainGui:Add, Text, x10 y395 w280 h15 Center, F3=Fix Window | F6=Denoms | F7=Buttons | F8=Diag | F9=Manual

    Gui, MainGui:Font, s7 cC9BE9E, Oswald
    Gui, MainGui:Add, Text, x10 y415 w280 h15 Center, Press F1 to show this window

    Gui, MainGui:Show, w300 h445, Sukli Automation - Manual Resolution

    Loop, %A_ScriptDir%\*.ini
    {
        StringTrimRight, fileName, A_LoopFileName, 4
        GuiControl,, DropItem, %fileName%
    }
    GuiControl, ChooseString, DropItem, default

    SelectImageFolder()
return

; ============================================================
; FORCE WINDOWED MODE (manual fallback via F3)
; ============================================================
ForceWindowedMode:
F3_Action:
    scalingPct := GetSystemScaling()
    if (scalingPct != 100) {
        msg := "Windows display scaling is set to " . scalingPct . "% (should be 100%).`nImage detection will likely fail.`nFix: Set to 100% in Display Settings.`n`nContinue anyway?"
        MsgBox, 52, Display Scaling Warning, %msg%
        IfMsgBox, No
            return
    }
    Gosub, EnsureWindowMode
return

; ============================================================
; ENSURE WINDOW MODE (resize to selected resolution)
; ============================================================
EnsureWindowMode:
    global UserSelectedRes
    targetW := (UserSelectedRes = "1366") ? 1366 : 1920
    targetH := Round(targetW * 9 / 16)

    WinActivate, %WinTitle%
    WinWaitActive, %WinTitle%,, 3
    if ErrorLevel {
        WinActivate, ahk_class Roblox
        WinWaitActive, ahk_class Roblox,, 3
        if ErrorLevel {
            MsgBox, 16, Error, Roblox window not found!
            return
        }
        WinTitle := "ahk_class Roblox"
    }

    Send, !{Enter}
    Sleep, 500

    WinMove, %WinTitle%,, 0, 0, %targetW%, %targetH%
    Sleep, 300

    WinGetPos, newX, newY, newW, newH, %WinTitle%
    if (Abs(newW - targetW) > 10 or Abs(newH - targetH) > 10) {
        MsgBox, 52, Warning, Could not set window to %targetW%x%targetH%.`nPlease manually set Roblox to windowed mode.
        return
    }

    UpdateStatus("[OK] Window forced to " . targetW . "x" . targetH)
    SoundBeep, 1000, 200
return

GetSystemScaling() {
    dpi := DllCall("User32.dll\GetDpiForSystem", "UInt")
    if (dpi = 0)
        return 100
    return Round((dpi / 96) * 100)
}

; ============================================================
; START MACRO – NO AUTO-RESIZE
; ============================================================
StartMacro:
    global g_StopRequested := false
    global ImageDir, ButtonDir, RefWidth, RefHeight

    scalingPct := GetSystemScaling()
    if (scalingPct != 100) {
        msg2 := "Scaling is " . scalingPct . "%. Set to 100% for best results.`n`nStart anyway?"
        MsgBox, 52, Display Scaling Warning, %msg2%
        IfMsgBox, No
            return
    }

    WinGetPos, chkX, chkY, chkW, chkH, %WinTitle%
    if (chkW = "" or chkH = "") {
        MsgBox, 16, Error, Roblox window not found!
        return
    }

    if !SelectImageFolder() {
        MsgBox, 16, Error, No images found for selected resolution.`nPlease capture images in the correct folder.
        return
    }

    CalculatePositions(chkW, chkH)

    macroRunning := true
    GuiControl, MainGui:, MainStatus, [*] Running
    GuiControl, MainGui:, MainStartBtn, Running...
    SetTimer, CheckSukliScreen, 200
    UpdateStatus("[..] Monitoring... - " . chkW . "x" . chkH)
return

; ============================================================
; STOP MACRO
; ============================================================
StopMacro:
    global g_StopRequested
    g_StopRequested := true
    macroRunning := false
    GuiControl, MainGui:, MainStatus, [X] Stopped
    GuiControl, MainGui:, MainStartBtn, Start (F2)
    SetTimer, CheckSukliScreen, Off
    UpdateStatus("[..] Stopped")
return

ReloadScript:
    Reload
return

; ============================================================
; MANUAL ENTRY (F9)
; ============================================================
ManualEntry:
    WinGet, manualGuiID, ID, Manual Sukli Entry
    WinGet, fallbackGuiID, ID, Manual Fallback
    if (manualGuiID != "" or fallbackGuiID != "") {
        if (manualGuiID != "")
            WinActivate, ahk_id %manualGuiID%
        if (fallbackGuiID != "")
            WinActivate, ahk_id %fallbackGuiID%
        return
    }

    global RouteData, CurrentRoute, PaymentImages, WinTitle, macroRunning, g_ManualPrevMacroState

    WinGetPos, meWinX, meWinY, meWinW, meWinH, %WinTitle%
    if (meWinW = "") {
        MsgBox, 16, Error, Roblox window not found!`nMake sure Roblox is running.
        return
    }

    g_ManualPrevMacroState := macroRunning
    if (macroRunning) {
        macroRunning := false
        SetTimer, CheckSukliScreen, Off
        GuiControl, MainGui:, MainStatus, [PAUSED] Manual Entry open
        GuiControl, MainGui:, MainStartBtn, Start (F2)
    }

    barangays := RouteData[CurrentRoute]
    destListStr := ""
    for i, name in barangays {
        destListStr .= name . "|"
    }

    paymentListStr := ""
    for amount, aliasList in PaymentImages {
        paymentListStr .= amount . "|"
    }

    Gui, ManualGui:New, +AlwaysOnTop +ToolWindow, Manual Sukli Entry
    Gui, ManualGui:Color, 1A2415, 1A2415
    Gui, ManualGui:Font, s14 cF1E9D2 bold, Oswald
    Gui, ManualGui:Add, Text, x10 y10 w400 h30 Center, Manual Entry - %CurrentRoute%

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y55 w100 h25, Pickup:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, DropDownList, vManualPickup x120 y55 w270 h30, %destListStr%

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y95 w100 h25, Drop-off:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, DropDownList, vManualDest x120 y95 w270 h30, %destListStr%

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y135 w100 h25, Passengers:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, Edit, vManualPax x120 y135 w60 Number, 1
    Gui, ManualGui:Add, UpDown, Range1-10, 1

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y175 w100 h25, Type:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, Radio, vManualRegular Checked group x120 y175, Regular
    Gui, ManualGui:Add, Radio, vManualStudent x210 y175, Student
    Gui, ManualGui:Add, Radio, vManualSenior x305 y175, Senior

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y215 w100 h25, Payment:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, DropDownList, vManualPay x120 y215 w120 h30, %paymentListStr%

    Gui, ManualGui:Font, s12 cFFFFFF bold, Oswald
    Gui, ManualGui:Add, Button, x15 y260 w180 h40 gManualEntrySubmit Default, Confirm (Enter)
    Gui, ManualGui:Add, Button, x210 y260 w180 h40 gManualEntryCancel, Cancel (Esc)

    Gui, ManualGui:Show, w410 h320, Manual Sukli Entry
return

; ============================================================
; AUTO-FALLBACK MANUAL ENTRY
; ============================================================
ManualEntryFallback:
    WinGet, manualGuiID, ID, Manual Sukli Entry
    WinGet, fallbackGuiID, ID, Manual Fallback
    if (manualGuiID != "" or fallbackGuiID != "") {
        if (manualGuiID != "")
            WinActivate, ahk_id %manualGuiID%
        if (fallbackGuiID != "")
            WinActivate, ahk_id %fallbackGuiID%
        return
    }

    global RouteData, CurrentRoute, PaymentImages, WinTitle, macroRunning, g_ManualPrevMacroState, g_FallbackPickup, g_FallbackDest, g_FallbackPay, g_FallbackPax, g_FallbackPaxType

    WinGetPos, meWinX, meWinY, meWinW, meWinH, %WinTitle%
    if (meWinW = "") {
        MsgBox, 16, Error, Roblox window not found!`nMake sure Roblox is running.
        g_FallbackPickup := ""
        g_FallbackDest := ""
        g_FallbackPay := ""
        g_FallbackPax := 0
        g_FallbackPaxType := ""
        return
    }

    g_ManualPrevMacroState := macroRunning
    if (macroRunning) {
        macroRunning := false
        SetTimer, CheckSukliScreen, Off
        GuiControl, MainGui:, MainStatus, [PAUSED] Manual Fallback open
        GuiControl, MainGui:, MainStartBtn, Start (F2)
    }

    barangays := RouteData[CurrentRoute]
    destListStr := ""
    for i, name in barangays {
        destListStr .= name . "|"
    }

    paymentListStr := ""
    for amount, aliasList in PaymentImages {
        paymentListStr .= amount . "|"
    }

    Gui, ManualGui:New, +AlwaysOnTop +ToolWindow, Manual Fallback - Fix Detection
    Gui, ManualGui:Color, 1A2415, 1A2415
    Gui, ManualGui:Font, s14 cF1E9D2 bold, Oswald
    Gui, ManualGui:Add, Text, x10 y10 w400 h30 Center, Manual Fallback - %CurrentRoute%

    Gui, ManualGui:Font, s10 cFF5555, Oswald
    Gui, ManualGui:Add, Text, x10 y45 w400 h25 Center, Auto-detection failed! Fix values below.

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y80 w100 h25, Pickup:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, DropDownList, vManualPickup x120 y80 w270 h30, %destListStr%
    if (g_FallbackPickup != "") {
        GuiControl, ChooseString, ManualPickup, %g_FallbackPickup%
    }

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y120 w100 h25, Drop-off:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, DropDownList, vManualDest x120 y120 w270 h30, %destListStr%
    if (g_FallbackDest != "") {
        GuiControl, ChooseString, ManualDest, %g_FallbackDest%
    }

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y160 w100 h25, Passengers:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, Edit, vManualPax x120 y160 w60 Number, 1
    Gui, ManualGui:Add, UpDown, Range1-10, 1
    if (g_FallbackPax > 0)
        GuiControl, ManualGui:, ManualPax, %g_FallbackPax%

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y200 w100 h25, Type:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, Radio, vManualRegular Checked group x120 y200, Regular
    Gui, ManualGui:Add, Radio, vManualStudent x210 y200, Student
    Gui, ManualGui:Add, Radio, vManualSenior x305 y200, Senior
    if (g_FallbackPaxType = "Student")
        GuiControl, ManualGui:, ManualStudent, 1
    else if (g_FallbackPaxType = "Senior")
        GuiControl, ManualGui:, ManualSenior, 1

    Gui, ManualGui:Font, s11 cC9BE9E, Oswald
    Gui, ManualGui:Add, Text, x15 y240 w100 h25, Payment:
    Gui, ManualGui:Font, s11 cF1E9D2, Oswald
    Gui, ManualGui:Add, DropDownList, vManualPay x120 y240 w120 h30, %paymentListStr%
    if (g_FallbackPay != "") {
        GuiControl, ChooseString, ManualPay, %g_FallbackPay%
    }

    Gui, ManualGui:Font, s12 cFFFFFF bold, Oswald
    Gui, ManualGui:Add, Button, x15 y285 w180 h40 gManualEntrySubmit Default, Confirm (Enter)
    Gui, ManualGui:Add, Button, x210 y285 w180 h40 gManualEntryCancel, Cancel (Esc)

    g_FallbackPickup := ""
    g_FallbackDest := ""
    g_FallbackPay := ""
    g_FallbackPax := 0
    g_FallbackPaxType := ""
    Gui, ManualGui:Show, w410 h345, Manual Fallback
return

; ============================================================
; MANUAL ENTRY SUBMIT
; ============================================================
ManualEntrySubmit:
    Gui, ManualGui:Submit
    Gui, ManualGui:Destroy

    if (ManualStudent = 1)
        mType := "Student"
    else if (ManualSenior = 1)
        mType := "Senior"
    else
        mType := "Regular"

    confirmMsg := "Pickup: " . ManualPickup . "`nDrop-off: " . ManualDest . "`nPassengers: " . ManualPax . "`nType: " . mType . "`nPayment: P" . ManualPay . "`n`nProceed with this sukli?"
    MsgBox, 36, Confirm Manual Entry, %confirmMsg%
    IfMsgBox, No
    {
        Gosub, ResumeAfterManualEntry
        return
    }

    global WinTitle
    WinActivate, %WinTitle%
    WinWaitActive, %WinTitle%,, 2
    Sleep, 150
    WinGetPos, curX, curY, curW, curH, %WinTitle%
    if (curW = "") {
        MsgBox, 16, Error, Roblox window disappeared!
        Gosub, ResumeAfterManualEntry
        return
    }

    SelectImageFolder()
    CalculatePositions(curW, curH)
    ProcessTransaction(ManualPickup, ManualDest, ManualPax, mType, ManualPay, curW, curH)
    Gosub, ResumeAfterManualEntry
return

; ============================================================
; RESUME MACRO AFTER MANUAL ENTRY
; ============================================================
ResumeAfterManualEntry:
    global macroRunning, g_ManualPrevMacroState
    if (g_ManualPrevMacroState) {
        macroRunning := true
        GuiControl, MainGui:, MainStatus, [*] Running
        GuiControl, MainGui:, MainStartBtn, Running...
        SetTimer, CheckSukliScreen, 200
        UpdateStatus("[..] Monitoring...")
    }
return

ManualEntryCancel:
ManualGuiClose:
    Gui, ManualGui:Destroy
    global g_FallbackPickup, g_FallbackDest, g_FallbackPay, g_FallbackPax, g_FallbackPaxType
    g_FallbackPickup := ""
    g_FallbackDest := ""
    g_FallbackPay := ""
    g_FallbackPax := 0
    g_FallbackPaxType := ""
    Gosub, ResumeAfterManualEntry
return

; ============================================================
; HOTKEYS
; ============================================================
F1::Gosub, MainGUI
F2::Gosub, StartMacro
F3::Gosub, ForceWindowedMode
F4::Gosub, StopMacro
F5::Gosub, ManualTest
F6::Gosub, CalibrateDenom
F7::Gosub, CalibrateButtons
F8::Gosub, RunDiagnostic
F9::Gosub, ManualEntry

MainGuiClose:
    Gui, MainGui:Destroy
    ExitApp
return