#Requires AutoHotkey v2.0
#Include ..\Setting\ToolTipSetting.ahk
#Include ..\Util\GetCaretPos.ahk

ToolTipPlus(kbl, state, capslock) {
    static timer := ""
    static alpha := 255
    static myGui := Gui("-SysMenu +ToolWindow +AlwaysOnTop -Caption -DPIScale +E0x20")
    static RefreshRate := 60

    ChangeTray()
    if (timer != "")
        SetTimer(timer, 0)

    setting := ToolTipSetting[kbl]

    size := setting.FontSize
    boxSize := size * 2.75
    roundSize := size
    offset := setting.Offset
    alpha := setting.Alpha

    static textControl := ""
    if (textControl == "") {
        ; 一些神奇的特性，myGui 不 SetFont 的话， textControl 的 SetFont 就没有
        myGui.SetFont("c" setting.textColor " s" size " " setting.fontStyle " q5", setting.FontFamily)
        textControl := myGui.Add("Text", "+Center w" boxSize, "")
    }

    myGui.BackColor := setting.bgColor
    textControl.SetFont("c" setting.textColor " s" size " " setting.fontStyle " q5", setting.FontFamily)
    textControl.Text := setting.GetText(state, capslock)

    textControl.GetPos(, , &w, &h)

    x := (boxSize - w) * 0.5
    y := (boxSize - h) * 0.5 - offset * size
    textControl.Move(x, y)

    GetCaretPos(&x, &y)
    ; WinGetPos(&wx, &wy, &ww, &wh, "A")
    ; 没有输入控件的话则取鼠标位置
    if (x == 0 || x == "") {
        temp := A_CoordModeMouse
        A_CoordModeMouse := "Screen"
        MouseGetPos(&x, &y)
        A_CoordModeMouse := temp
    }

    ;如果超过当前窗口的范围，则自动调整位置


    x := x - boxSize
    y := y - boxSize

    ;TODO 因为副屏烧了所以暂时没有测试环境，暂时不考虑位置超出屏幕的情况的自动调整

    region := "0-0 W" boxSize " H" boxSize " R" roundSize "-" roundSize
    WinSetTransparent(alpha, myGui.Hwnd)
    WinSetRegion(region, myGui.Hwnd)
    myGui.Show("NoActivate w" boxSize " h" boxSize " x" x " y" y)

    timer := Hide

    if (setting.Duration <= 0)
        Hide()
    else
        SetTimer(timer, -setting.Duration)

    Hide() {
        timer := Fadeout
        SetTimer(timer, 1000 / RefreshRate)
    }

    Fadeout() {
        static lastTick := A_TickCount

        deltaTick := A_TickCount - lastTick
        lastTick := A_TickCount

        alpha := Floor(alpha - 1000 / RefreshRate * 255 / 100)
        if (alpha <= 0) {
            myGui.Hide()
            return
        }
        WinSetTransparent(alpha, myGui.hWnd)
    }

    ChangeTray() {
        iconPath := A_ScriptDir "\icons\"
        language := kbl "\"
        Caps := (capslock ? "Caps" : "")

        path := iconPath language Caps state ".png"
        if (!FileExist(path))
            path := iconPath language Caps ".png"
        if (!FileExist(path))
            path := iconPath language "icon.png"
        if (!FileExist(path))
            path := iconPath "icon.png"


        if (FileExist(path)) {
            TraySetIcon(path)
        }

    }

}