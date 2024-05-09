#Requires AutoHotkey v2.0
#Include KBLTool.ahk

class KBLSwitcher {
    __New(defaultLayoutIndex, setting) {
        this.layoutIndex := defaultLayoutIndex
        this.setting := setting
    }

    NextLayout() {
        ; KBLTool.GetCurrentIMEStatus()
        layoutCount := this.setting.Layouts.Length
        this.layoutIndex := Mod(this.layoutIndex + 1, layoutCount)
        layoutSetting := this.setting.Layouts[this.layoutIndex]
        KBLTool.SetKBL(layoutSetting.Name, layoutSetting.DefaultState)
    }

    FindSimilarLayoutIndex(name, state) {
        mostSimilar := -1
        for i, layout in this.setting.Layouts {
            if layout.Name == name {
                if (mostSimilar == -1)
                    mostSimilar := i
                if (state == layout.DefaultState)
                    return i
            }
        }
        return mostSimilar
    }

    FixLayout() {
        ; TODO 如果当前 State 为 0x0，且与默认不同，则尝试切换到默认状态，但是好像检测不了当前的 State 都是 1
    }

}