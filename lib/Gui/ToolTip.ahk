#Requires AutoHotkey v2.0
#Include ..\Setting\ToolTipSetting.ahk
#Include ..\Util\GetCaretPos.ahk

ToolTipPlus(kbl, state, capslock) {
    static timer := ""
    static alpha := 255
    static myGui := Gui("-SysMenu +ToolWindow +AlwaysOnTop -Caption -DPIScale +E0x20")

    if (timer != "") {
        SetTimer(timer, 0)
        myGui.Destroy()
        myGui := Gui("-SysMenu +ToolWindow +AlwaysOnTop -Caption -DPIScale +E0x20")
    }
    
    setting := ToolTipSetting[kbl]

    size := setting.FontSize
    boxSize := size * 2.75
    roundSize := size
    offset := setting.Offset
    alpha := setting.Alpha

    myGui.BackColor := setting.bgColor
    myGui.SetFont("c" setting.textColor " s" size " " setting.fontStyle " q5", setting.FontFamily)
    textControl := myGui.Add("Text", "+Center vText", setting.GetText(state, capslock))
    textControl.GetPos(, , &w, &h)

    x := (boxSize - w) * 0.5
    y := (boxSize - h) * 0.5 - offset * size
    textControl.Move(x, y)

    GetCaretPos(&x, &y)
    x := x - boxSize
    y := y - boxSize

    region := "0-0 W" boxSize " H" boxSize " R" roundSize "-" roundSize
    WinSetTransparent(alpha, myGui.Hwnd)
    WinSetRegion(region, myGui.Hwnd)
    myGui.Show("NoActivate w" boxSize " h" boxSize " x" x " y" y)

    timer := Hide
    duration := -setting.Duration

    SetTimer(timer, duration)

    Hide() {
        timer := Fadeout
        SetTimer(timer, 1000 / 170)
    }

    Fadeout() {
        static lastTick := A_TickCount

        deltaTick := A_TickCount - lastTick
        lastTick := A_TickCount

        alpha := Floor(alpha - 1 / 17 * 255)
        if (alpha <= 0) {
            alpha := 0
            return
        }
        WinSetTransparent(alpha, myGui.hWnd)
    }


}