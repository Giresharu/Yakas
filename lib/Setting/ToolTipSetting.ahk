#Requires AutoHotkey v2.0

#Include ..\Util\Util.ahk

class ToolTipSetting {

    __New(globalSetting, overridesSetting) {
        this.Global := globalSetting
        this.Overrides := overridesSetting
    }

    __Item[i] => this.override[i]

    static FromIni(value) {

        globalSetting := ToolTipSetting.Override.FromIni("GlobalToolTip", true)
        overridesSetting := Util.INIReadForeach(iniFile, "ToolTip", ToolTipSetting.Override.FromIni)

        return ToolTipSetting(globalSetting, overridesSetting)
    }

    ; TODO 写入 INI

    class Override {

        __New(
            text,
            textColor,
            bgColor,
            fontSize,
            fontFamily,
            fontWeight,
            fontFamilyCallback,
            duration?
        ) {
            this.Text := text
            this.TextColor := textColor
            this.BgColor := bgColor
            this.FontSize := fontSize
            this.FontFamily := fontFamily
            this.FontWeight := fontWeight
            this.FontFamilyCallback := fontFamilyCallback
            this.Duration := duration
        }

        static FromIni(value, isGlobal := false) {
            if (isGlobal) {
                text := ""
                textColor := Util.INIRead(iniFile, value, "text_color", 0x5090FFFF)
                bgColor := Util.INIRead(iniFile, value, "bg_color", 0x252525BB)
                fontSize := Util.INIRead(iniFile, value, "font_size", 12)
                fontWeight := Util.INIRead(iniFile, value, "font_weight", "bold")
                fontFamily := Util.INIRead(iniFile, value, "font_family", "Arial")
                fontFamilyCallback := Util.StrToArray(Util.INIRead(iniFile, value, "font_family_callback", "思源黑体, 微软雅黑"))
                duration := Util.INIRead(iniFile, value, "duration", "500")
            } else {
                section := "ToolTip." . value

                text := Util.INIRead(iniFile, section, "text", value) ; 如果没有定义要显示的文字，则使用 section 的二级标题作为文字
                textColor := Util.INIRead(iniFile, section, "text_color", "")
                bgColor := Util.INIRead(iniFile, section, "bg_color", "")
                fontSize := Util.INIRead(iniFile, section, "font_size", "")
                fontWeight := Util.INIRead(iniFile, section, "font_weight", "")
                fontFamily := Util.INIRead(iniFile, section, "font_family", "")
                fontFamilyCallback := Util.StrToArray(Util.INIRead(iniFile, section, "font_family_callback", ""))
                duration := Util.INIRead(iniFile, section, "duration", "")
            }

            return ToolTipSetting.Override(
                text,
                textColor,
                bgColor,
                fontSize,
                fontWeight,
                fontFamily,
                fontFamilyCallback,
                duration
            )
        }

        ; TODO 写入 INI

    }
}