#Requires AutoHotkey v2.0

class KeyboardLayout {
    __New(name, imeState) {
        this.Name := name
        this.ImeState := imeState
        this.CapsLockState := 0
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
    }

    Set(name, imeState, previoursSwitch := "", previoursSwitchIndex := 0, capsLockState := "") {
        this.Name := name
        this.ImeState := imeState
        this.PrevioursSwitch := previoursSwitch
        this.PrevioursSwitchIndex := previoursSwitchIndex
        if (capsLockState != "")
            this.CapsLockState := capsLockState
    }
}