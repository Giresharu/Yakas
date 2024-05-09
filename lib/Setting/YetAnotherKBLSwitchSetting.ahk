#Requires AutoHotkey v2.0

#Include KBLSwitcherSetting.ahk
#Include ToolTipSetting.ahk

class YetAnotherKBLSwitchSetting {
    __New(KBLSwitcherSetting, toolTipSetting) {
        this.KBLSwitcher := KBLSwitcherSetting
        this.ToolTip := toolTipSetting
    }

    static FromINI(iniFile) {
        return YetAnotherKBLSwitchSetting(
            KBLSwitcherSetting.FromINI(iniFile),
            ToolTipSetting.FromINI(iniFile),
        )
    }
}