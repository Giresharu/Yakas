#Requires AutoHotkey v2.0

class KeyboardLayout {
    __New(name, state) {
        this.Name := name
        this.State := state
        this.CapsLockState := 0
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
    }

    Set(name, state, previoursSwitch := "", previoursSwitchIndex := 0, capsLockState := "") {
        this.Name := name
        this.State := state
        this.PrevioursSwitch := previoursSwitch
        this.PrevioursSwitchIndex := previoursSwitchIndex
        if (capsLockState != "")
            this.CapsLockState := capsLockState
    }
}