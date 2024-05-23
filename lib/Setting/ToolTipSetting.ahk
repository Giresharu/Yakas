#Requires AutoHotkey v2.0
#Include ..\Util\Util.ahk

class ToolTipSetting {
    static Global := ""
    static ToolTips := Map()

    static __Item[key] => ToolTipSetting.ToolTips[key]

    __New(
        text,
        captical_text,
        offset,
        textColor,
        bgColor,
        alpha,
        fontSize,
        fontFamily,
        fontStyle,
        duration,
        fadeTime
    ) {
        this.Text := text
        this.CapticalText := captical_text
        this.Offset := offset
        this.TextColor := textColor
        this.BgColor := bgColor
        this.Alpha := alpha
        this.FontSize := fontSize
        this.FontFamily := fontFamily
        this.FontStyle := fontStyle
        this.Duration := duration
        this.FadeTime := fadeTime
    }

    static Initialize(iniFile) {
        ToolTipSetting.Global := ToolTipSetting.ParseINI(iniFile, "GlobalToolTip")
        ToolTipSetting.ToolTips := ToolTipSetting.FromINI(iniFile)
    }

    static FromINI(iniFile) {
        return Util.INIReadForeach(iniFile, "ToolTip", ToolTipSetting.FromINISection)
    }

    static ParseINI(iniFile, section) {
        key := Trim(section, "ToolTip.")
        defualt := ToolTipSetting.Global

        text := Util.INIRead(iniFile, section, "text", "")

        if (!text := ToolTipSetting.ParseText(text)) {
            if (defualt == "") {
                text := Map()
                text["regular"] := key
            } else
                text := defualt.Text
        }

        capticalText := Util.INIRead(iniFile, section, "captical_text", "")

        if (!capticalText := ToolTipSetting.ParseText(capticalText)) {
            if (defualt == "")
                capticalText := text
            else
                capticalText := defualt.CapticalText
        }

        if (defualt != "") {
            offset := Util.INIRead(iniFile, section, "offset", defualt.Offset)
            textColor := Util.INIRead(iniFile, section, "text_color", defualt.TextColor)
            bgColor := Util.INIRead(iniFile, section, "bg_color", defualt.BgColor)
            alpha := Util.INIRead(iniFile, section, "alpha", defualt.Alpha)
            fontSize := Util.INIRead(iniFile, section, "font_size", defualt.FontSize)
            fontFamily := Util.INIRead(iniFile, section, "font_family", defualt.FontFamily)
            fontStyle := Util.INIRead(iniFile, section, "font_Style", defualt.FontStyle)
            duration := Util.INIRead(iniFile, section, "duration", defualt.Duration)
            fadeTime := Util.INIRead(iniFile, section, "fade_time", defualt.FadeTime)
        } else {
            offset := Util.INIRead(iniFile, section, "offset", 0)
            textColor := Util.INIRead(iniFile, section, "text_color", "0xFFF")
            bgColor := Util.INIRead(iniFile, section, "bg_color", "0x000")
            alpha := Util.INIRead(iniFile, section, "alpha", "200")
            fontSize := Util.INIRead(iniFile, section, "font_size", "16")
            fontFamily := Util.INIRead(iniFile, section, "font_family", "Arial")
            fontStyle := Util.INIRead(iniFile, section, "font_Style", "")
            duration := Util.INIRead(iniFile, section, "duration", "750")
            fadeTime := Util.INIRead(iniFile, section, "fade_time", "750")
        }

        return ToolTipSetting(text, capticalText, offset, textColor, bgColor, alpha, fontSize, fontFamily, fontStyle, duration, fadeTime)
    }

    static ParseText(text) {
        if (text == "")
            return 0
        textMap := Map()
        texts := Util.StrToArray(text, ",")
        for i, t in texts {
            ts := StrSplit(t, ":", " ")
            if (ts.Length < 2) {
                textMap["regular"] := t
                continue
            }
            textMap[Integer(ts[1])] := ts[2]
        }
        return textMap
    }

    static FromINISection(iniFile, value, dic, key) {
        section := "ToolTip." value
        dic[key] := ToolTipSetting.ParseINI(iniFile, section)
    }

    GetText(state, capslock) {
        if (capslock)
            return this.GetCapticalText(state)
        if (this.Text.Has(state))
            return this.Text[state]
        else
            return this.Text["regular"]
    }

    GetCapticalText(state) {
        if (this.CapticalText.Has(state))
            return this.CapticalText[state]
        else
            return this.CapticalText["regular"]
    }

}