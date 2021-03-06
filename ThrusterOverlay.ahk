;Credit goes to Tariq Porter for the GDI+ wrapper, and Marius Șucan for extending it with many useful functions
;v0.93 on 2019-10-16

#SingleInstance force
SetTitleMatchMode 1
#MaxThreadsPerHotkey 3
SetFormat, float, 03  ; Omit decimal point from axis position percentages.

#Include <Gdip_All> ;this is expected to be in a "Lib" folder
#Include <MouseDelta>

;-----------------------------Notes
; This script will draw 4 overlay graphics to depict thruster and rotation values that are being driven by joysticks/gamepads, or keys.
; Mouse inputs are currently not tracked.
; If you want to change what input values are driving each of the graphics, please see the DrawAllGraphics function and swap the argument values around.
; Press Alt-P to toggle whether the graphics are displayed or not.




;---------------------- START OF CONFIG SECTION

;Some general variables 
global bUseMouse := true ;set to false if you do not use the mouse axis for pitch/yaw/roll inputs
global bMouseXIsYaw := true ;true if mouse X axis controls yaw, false for roll

global bDisplayTitleBar := false ;if you want to see an actual window for the overlay

global bDisplayLeftOverlays := true
global bDisplayRightOverlays := true

global canvasWidth := A_ScreenWidth
global canvasHeight := 380         ;you may want to increase this if you increase the size of the graphics
global canvasY := A_ScreenHeight - canvasHeight - 48 

;-----------------Device and Key Mapping. Use an empty/blank value if you don't have particular mappings
;Thrust Keys. Should be string values
mappedVerticalDownKey := "j"
mappedVertialUpKey := "k"
mappedLateralLeftKey := 
mappedLateralRightKey := 
mappedForwardKey := 
mappedBackKey := 

;Rotation Keys
mappedYawLeftKey := 
mappedYawRightKey := 
mappedRollLeftKey := 
mappedRollRightKey := 
mappedPitchUpKey := 
mappedPitchDownKey := 

;Joystick/Gamepad Mappings. Stick nums should be integer values, and the axis should be strings in the form of "JoyX", "JoyY", etc
JoystickNum_thrust := 2
JoystickNum_lateral := 2
JoystickNum_vertical := 2

JoystickNum_pitch := 3
JoystickNum_yaw := 3
JoystickNum_roll := 3

mappedLateralAxis := "JoyX"
mappedThrustAxis := "JoyY"
mappedVertialAxis := "JoyZ"

mappedYawAxis := "JoyX"
mappedPitchAxis := "JoyY"
mappedRollAxis := "JoyZ"

;-------------------Set your desired colors and transparency
global transparency := "CC" ;00 for fully transparent / ff for fully opaque
global transparencyMarkers := "af"
global colorPrimary := "03b2e1"
global colorSecondary := "002f3b"
global colorBackground := "000000"
global colorMarkers := "fffdad"


;-------------------Position/Size Variables for the 2D overlays
global overlayRadius := 60
global overlayDiameter := 2*overlayRadius

global overlayThruster2DX := 40
global overlayThruster2DY := canvasHeight - overlayDiameter - 40

global overlayRotation2DX := canvasWidth - overlayDiameter - 40
global overlayRotation2DY := overlayThruster2DY

global overlayTextYOffset := 50 ;***Increase this value if the rotated text isn't low enough (lame workaround for now)


;--------------------Position/Size Variables for the 1D overlays
global overlay1DShort := 20				 ; used for the width on vertical running overlay, and used for the height on horizontal running overlay
global overlay1DLong := overlayDiameter  ; used for the width on horizontal running overlay, and used for the height on vertical running overlay

global overlayThruster1DX := overlayThruster2DX
global overlayThruster1DY := overlayThruster2DY - overlay1DLong - 60

global overlayRotation1DX := overlayRotation2DX
global overlayRotation1DY := overlayRotation2DY - overlay1DShort - 60


;--------------------Size Variables for the value markers
global dotRadius := 8
global dotDiameter := dotRadius * 2


;--------------------Styling variables for the axis labels
global textFont = "Arial"
global textSize := 17


;---------------------- END OF CONFIG SECTION. Do not make changes below this point unless
; you wish to alter the basic functionality of the script.

global pPenPrimary
global pPenSecondary

global pBrushPrimary
global pBrushBackground
global pBrushMarker

global bShowingOverlays := true

global mouseQueue := []
global curMouseX := 0
global curMouseY := 0

mouseTracker := new MouseDelta("MouseEventHandler")



Initialize()

GetKeyState, joy_info, %JoystickNumber%JoyInfo

SetTimer, mainLoop,16 ; Rate of 60Hz
MainLoop:

	;reset variables
	lateralVal := 0.0
	thrustVal := 0.0
	verticalVal := 0.0
	pitchVal := 0.0
	yawVal := 0.0
	rollVal := 0.0


	;****Get the thruster axis values
	if(JoystickNum_lateral and mappedLateralAxis) {
		GetKeyState, lateralVal, %JoystickNum_lateral%%mappedLateralAxis%
		lateralVal := Round(2*(lateralVal/100 - 0.5), 2)
	}
	
	if(JoystickNum_thrust and mappedThrustAxis) {
		GetKeyState, thrustVal, %JoystickNum_thrust%%mappedThrustAxis%
		thrustVal := Round(2*(thrustVal/100 - 0.5), 2)
	}
	
	if(JoystickNum_vertical and mappedVertialAxis) {
		GetKeyState, verticalVal, %JoystickNum_vertical%%mappedVertialAxis%
		verticalVal := Round(-2*(verticalVal/100 - 0.5), 2)
	}
	
	;***Get the rotation axis values
	if(JoystickNum_pitch and mappedPitchAxis) {
		GetKeyState, pitchVal, %JoystickNum_pitch%%mappedPitchAxis%
		pitchVal := Round(2*(pitchVal/100 - 0.5), 2)
		
	}
	
	if(JoystickNum_yaw and mappedYawAxis) {
		GetKeyState, yawVal, %JoystickNum_yaw%%mappedYawAxis%
		yawVal := Round(2*(yawVal/100 - 0.5), 2)
	}

	if(JoystickNum_roll and mappedRollAxis) {
		GetKeyState, rollVal, %JoystickNum_roll%%mappedRollAxis%
		rollVal := Round(2*(rollVal/100 - 0.5), 2)
	}
	
	
	
	;Get mouse input values.
	;Mouse input supercedes joystick inputs
	if(bUseMouse) {
		mouseDeltaX := 0
		mouseDeltaY := 0
		mouseXFloat := 0.0
		mouseYFloat := 0.0
		HandleMouseEventQueue(mouseDeltaX, mouseDeltaY)
		TranslateMouseValues(mouseDeltaX, mouseDeltaY, mouseXFloat, mouseYFloat)		
		
		if(mouseXFloat != 0.0) {
			if(bMouseXIsYaw) {
				yawVal := mouseXFloat
			}
			else {
				rollVal := mouseXFloat
			}
		}
		if(mouseYFloat != 0.0) {
			pitchVal := mouseYFloat
		}
	}
	
	
	;Key values ultimately supercede other input devices
	;***Get the thruster key values
	DownKey := GetKeyState(mappedVerticalDownKey)
	UpKey := GetKeyState(mappedVertialUpKey)
	LeftKey := GetKeyState(mappedLateralLeftKey)
	RightKey := GetKeyState(mappedLateralRightKey)
	ForwardKey := GetKeyState(mappedForwardKey)
	BackKey := GetKeyState(mappedBackKey)	
	
	If (DownKey and !UpKey) {
		verticalVal := 1.0
	}
	else if(UpKey and !DownKey) {
		verticalVal := -1.0
	}
	
	if(LeftKey and !RightKey) {
		lateralVal := -1.0
	}
	else if(RightKey and !LeftKey) {
		lateralVal := 1.0
	}
	
	if(ForwardKey and !BackKey) {
		thrustVal := -1.0
	}
	else if(BackKey and !ForwardKey) {
		thrustVal := 1.0
	}
	
	;Get the rotation key values
	RollLeftKey := GetKeyState(mappedRollLeftKey)
	RollRightKey := GetKeyState(mappedRollRightKey)
	YawLeftKey := GetKeyState(mappedYawLeftKey)
	YawRightKey := GetKeyState(mappedYawRightKey)
	PitchUpKey := GetKeyState(mappedPitchUpKey)
	PitchDownKey := GetKeyState(mappedPitchDownKey)	

	If (RollLeftKey and !RollRightKey) {
		rollVal := -1.0
	}
	else if(RollRightKey and !RollLeftKey) {
		rollVal := 1.0
	}

	
	if(YawLeftKey and !YawRightKey) {
		yawVal := -1.0
	}
	else if(YawRightKey and !YawLeftKey) {
		yawVal := 1.0
	}

	
	if(PitchUpKey and !PitchDownKey) {
		pitchVal := -1.0
	}
	else if(PitchDownKey and !PitchUpKey) {
		pitchVal := 1.0
	}

	DrawAllGraphics(lateralVal, thrustVal, verticalVal, yawVal, pitchVal, rollVal)

return

OverlayWindowGuiEscape:
OverlayWindowGuiClose:
	EndDrawGDIP()
	Gui OverlayWindow: Destroy
	mouseTracker.Delete()
	mouseTracker := ""	
	
	ExitApp
Return


;Setup GDI+ objects
Initialize()
{
	global
	
	if(bUseMouse) {
		mouseTracker.SetState(true) ;turn on mouse tracking
	}
	
	If !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}	

	
	;Create the main container window
	Gui OverlayWindow: New, hWndhMap -DPIScale +OwnDialogs
	Gui, Color, EEAA99
	Gui +LastFound
	WinSet, TransColor, EEAA99
	yOffset := A_ScreenHeight - canvasHeight - 48
	
	if(bDisplayTitleBar) {
		Gui +Caption
	}
	else {
		canvasY := canvasY + 25 ;adjustment since we won't have a title bar
		Gui +AlwaysOnTop
		Gui -Caption
	}
	
	Gui Show, NA y%canvasY% w%canvasWidth% h%canvasHeight%, OverlayWindow

	; Create a layered window (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
	;Gui, 1: -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs
	Gui, 1: -Caption +E0x80000 +LastFound +ToolWindow +OwnDialogs +ParentOverlayWindow

	; Show the window
	Gui, 1: Show, NA

	; Get a handle to this window we have created in order to update it later
	hwnd1 := WinExist()
		
	
	
	
	Gdip_SetSmoothingMode(G, 4)	
	
	;Setup Brush/Pen objects
	pPenPrimary := Gdip_CreatePen("0x" transparency colorPrimary, 1)
	pPenSecondary := Gdip_CreatePen("0x" transparency colorSecondary, 2)
	
	pBrushPrimary := Gdip_BrushCreateSolid("0x" transparency colorPrimary)
	pBrushBackground := Gdip_BrushCreateSolid("0x" transparency colorBackground)
	pBrushMarker := Gdip_BrushCreateSolid("0x" transparencyMarkers colorMarkers )
	
	pPenShadow := Gdip_CreatePen("0x" transparency colorBackground, 4)
	
	StartDrawGDIP()
	
	

}




MouseEventHandler(MouseID, deltaXCur := 0, deltaYCur := 0)
{
	curTime := A_TickCount
	
	newVector := new mouseVector(deltaXCur, deltaYCur, curTime)	
	mouseQueue.insert(newVector)
}

HandleMouseEventQueue(ByRef recentXDelta, ByRef recentYDelta)
{
	recentXDelta := 0
	recentYDelta := 0

	Loop, % mouseQueue.MaxIndex() {
		curVector := mouseQueue.Remove(1)
		timeSince := A_TickCount - curVector.timeStamp
		
		if(timeSince <= 100) { ;only consider somewhat recent mouse events
			recentXDelta += curVector.xVector
			recentYDelta += curVector.yVector
		}
	}
	
	;Limit the absolute values to a max of 50
	if(recentXDelta < -50) {
		recentXDelta := -50
	}
	else if(recentXDelta > 50) {
		recentXDelta := 50
	}
	
	if(recentYDelta < -50 ) {
		recentYDelta := -50
	}
	else if(recentYDelta > 50) {
		recentYDelta := 50
	}

}

TranslateMouseValues(actualXDelta, actualYDelta, ByRef displayX, ByRef displayY)
{
	global
	
	static bufferX := []
	static bufferY := []
	
	;First determine the integer values. 
	;If we don't have an actual non-zero delta, we will decay from the last values
	
	if(actualXDelta = 0 and curMouseX > 3) {
		curMouseX := curMouseX - 4
	}
	else if(actualXDelta = 0 and curMouseX < -3) {
		curMouseX := curMouseX + 4
	}
	else {
		curMouseX := actualXDelta
	}
	
	if(actualYDelta = 0 and curMouseY > 3) {
		curMouseY := curMouseY - 4
	}
	else if(actualYDelta = 0 and curMouseY < -3) {
		curMouseY := curMouseY + 4
	}
	else {
		curMouseY := actualYDelta
	}
	
	
	;Then convert the integer values to float from -1.0 to 1.0
	
	if(curMouseX <= -50) {
		displayX := -1.0
	}
	else if (curMouseX >= 50) {
		displayX := 1.0
	}
	else {
		displayX := Round(0.02 * curMouseX, 2)
	}
	
	if(curMouseY <= -50) {
		displayY := -1.0
	}
	else if (curMouseY >= 50) {
		displayY := 1.0
	}
	else {
		displayY := Round(0.02 * curMouseY, 2)
	}
	

	;To smooth out the display, we'll buffer this result and then take an average of previous ones in the buffer
	
	if(bufferX.Length() > 6) {
		bufferX.remove(1)
		bufferY.remove(1)
	}
	bufferX.insert(displayX)
	bufferY.insert(displayY)
	
	sumBufferX := 0
	sumBufferY := 0
	
	Loop % bufferX.Length() {
		sumBufferX += bufferX[A_Index]
		sumBufferY += bufferY[A_Index]	
	}
	
	averageX := Round(sumBufferX/bufferX.Length(), 2)
	averageY := Round(sumBufferY/bufferY.Length(), 2)
	
	
	
	;the average tends to be 0 when making very small changes, so don't use it for the result in these cases
	if(averageX != 0) {
		displayX := averageX
	}
	if(averageY != 0) {
		displayY := averageY
	}

	
}




;Draw the graphic overlays
DrawAllGraphics(lateralVal, thrustVal, verticalVal, yawVal, pitchVal, rollVal)
{
	ClearDrawGDIP()

	if(bShowingOverlays) {
	
		if(bDisplayLeftOverlays) {
			Draw2DOverlay(lateralVal, thrustVal, overlayThruster2DX, overlayThruster2DY, "LATERAL", "THRUST")
			Draw1DOverlayVertical(verticalVal, overlayThruster1DX, overlayThruster1DY, "VERTICAL")		
		}
	
		if(bDisplayRightOverlays) {
			Draw2DOverlay(yawVal, pitchVal, overlayRotation2DX, overlayRotation2DY, "YAW", "PITCH")
			Draw1DOverlayHorizontal(rollVal, overlayRotation1DX, overlayRotation1DY, "ROLL")		
		}
	}
	
	UpdateDrawGDIP()	
}


;Draws a 1-Dimensional overlay that runs horizontally
Draw1DOverlayHorizontal(value, xPosition, yPosition, AxisLabel)
{
	global
	
	dotX := xPosition + overlay1DLong /2 + value*overlay1DLong/2 - dotRadius
	dotY := yPosition + overlay1DShort/2 - dotRadius
	
	HorLineX := xPosition + overlay1DLong/2 + 1
	HorLineYTop := yPosition + 4
	HorLineYBot := yPosition + overlay1DShort - 4



	;Then draw the background color
	Gdip_FillRoundedRectangle(G, pBrushBackground, xPosition, yPosition, overlay1DLong, overlay1DShort, 3)

	;First draw the primary color
	Gdip_DrawRoundedRectangle(G, pPenPrimary, xPosition,yPosition ,overlay1DLong, overlay1DShort, 3)
	
	;Then draw the secondary color line
	Gdip_DrawLine(G, pPenSecondary, HorLineX, HorLineYTop, HorLineX, HorLineYBot)
	
	;Then draw the axis value marker
	Gdip_FillEllipse(G, pBrushMarker, dotX, dotY, dotDiameter, dotDiameter)
	
	;Draw the axis labels
	Gdip_DrawOrientedString(G, AxisLabel, textFont, textSize, 0, xPosition, yPosition - 30
		, overlay1DLong, 0, 0, pBrushPrimary,0,1,1)

}

;Draws a 1-Dimensional overlay that runs vertically
Draw1DOverlayVertical(value, xPosition, yPosition, AxisLabel)
{
	global
	
	dotX := xPosition + overlay1DShort /2 - dotRadius
	dotY := yPosition + overlay1DLong /2 + value*overlay1DLong/2 - dotRadius
	
	HorLineXLeft := xPosition + 4
	HorLineXRight := xPosition + overlay1DShort - 4
	HorLineY := yPosition + overlay1DLong/2 + 1

	;draw the background color
	Gdip_FillRoundedRectangle(G, pBrushBackground, xPosition, yPosition, overlay1DShort, overlay1DLong, 3)

	;draw the primary color
	Gdip_DrawRoundedRectangle(G, pPenPrimary, xPosition,yPosition , overlay1DShort ,overlay1DLong, 3)

	
	;Then draw the secondary color line
	Gdip_DrawLine(G, pPenSecondary, HorLineXLeft, HorLineY, HorLineXRight, HorLineY)
	
	;Then draw the axis value marker
	Gdip_FillEllipse(G, pBrushMarker, dotX, dotY, dotDiameter, dotDiameter)
	
	;Draw the axis labels
	Gdip_DrawOrientedString(G, AxisLabel, textFont, textSize, 0, xPosition + overlay1DShort + 15, yPosition + overlayTextYOffset
		, 0, overlay1DLong, 270, pBrushPrimary,0,1,1)

}


;Draw a circular 2-Dimensional overlay
Draw2DOverlay(xVal, yVal, xPosition, yPosition, xAxisLabel, yAxisLabel)
{
	global
	
	;Calculate dot position values
	xRadialLengthFactor := Round(xVal * Sqrt( 1 - 0.5*yVal**2), 2)
	yRadialLengthFactor := Round(yVal * Sqrt( 1 - 0.5*xVal**2), 2)
	dotXFinal := xPosition + overlayRadius + xRadialLengthFactor*overlayRadius - dotRadius
	dotYFinal := yPosition + overlayRadius + yRadialLengthFactor*overlayRadius - dotRadius
	
	;Calculate vertical and horizontal line position values
	VertLineX := xPosition + overlayRadius + 1
	VertLineYTop := yPosition + 8
	VertLineYBot := yPosition + overlayDiameter - 8
	HorLineXLeft := xPosition + 8
	HorLineXRight := xPosition + overlayDiameter - 8
	HorLineY := yPosition + overlayRadius + 1	


	;draw the background color
	Gdip_FillEllipse(G, pBrushBackground, xPosition, yPosition, overlayDiameter, overlayDiameter)

	;draw the primary color
	Gdip_DrawEllipse(G, pPenPrimary, xPosition, yPosition, overlayDiameter, overlayDiameter)


	;draw the secondary color lines
	Gdip_DrawLine(G, pPenSecondary, VertLineX, VertLineYTop, VertLineX, VertLineYBot)
	Gdip_DrawLine(G, pPenSecondary, HorLineXLeft, HorLineY, HorLineXRight, HorLineY)
	
	;draw the axis value markers
	Gdip_FillEllipse(G, pBrushMarker, dotXFinal, dotYFinal, dotDiameter, dotDiameter)
	
	
	
	
	;Draw the axis labels
	Gdip_DrawOrientedString(G, xAxisLabel, textFont, textSize, 0, xPosition-1, yPosition - 30
		, overlayDiameter, 0, 0, pBrushBackground, 0, 1, 1)
	Gdip_DrawOrientedString(G, xAxisLabel, textFont, textSize, 0, xPosition+1, yPosition - 30
		, overlayDiameter, 0, 0, pBrushBackground, 0, 1, 1)			
	
	
	Gdip_DrawOrientedString(G, xAxisLabel, textFont, textSize, 0, xPosition, yPosition - 30
		, overlayDiameter, 0, 0, pBrushPrimary, 0, 1, 1)
	Gdip_DrawOrientedString(G, yAxisLabel, textFont, textSize, 0, xPosition + overlayDiameter + 15, yPosition + overlayTextYOffset
		, 0, overlayDiameter, 270, pBrushPrimary, 0, 1, 1)
}


StartDrawGDIP() {
	global
	
	hbm := CreateDIBSection(canvasWidth, canvasHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)	
}


ClearDrawGDIP() {
	global
	Gdip_GraphicsClear(G)
}

UpdateDrawGDIP()
{
	global
	UpdateLayeredWindow(hwnd1, hdc, 0, 0, canvasWidth, canvasHeight)
}

EndDrawGDIP() {
	global	

	Gdip_DeletePen(pPenPrimary)
	Gdip_DeletePen(pPenSecondary)
	Gdip_DeleteBrush(pBrushPrimary)
	Gdip_DeleteBrush(pBrushBackground)
	Gdip_DeleteBrush(pBrushMarker)

	SelectObject(hdc, obm)
	DeleteObject(hbm)
	DeleteDC(hdc)
	Gdip_DeleteGraphics(G)
	Gdip_Shutdown(pToken)
}





~!p::
	bShowingOverlays := !bShowingOverlays
return