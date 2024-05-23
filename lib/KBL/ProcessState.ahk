#Include KeyboardLayout.ahk

class ProcessState {
    WindowStates := 0

    __New(title, defualtKBL, defualtState, alwaysRecorveToDefault) {
        this.Title := title
        this.DefualtLayout := KeyboardLayout(defualtKBL, defualtState)
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
        this.alwaysRecorveToDefault := alwaysRecorveToDefault
        this.CapsLockState := 0
    }

    Update(key, SwitchIndex, name, state) {
        this.PrevioursSwitch := key
        this.PrevioursSwitchIndex := SwitchIndex
        this.CurrentLayout.Set(name, state)
    }

    AddWindow(state) {
        if (this.WindowStates == 0)
            this.WindowStates := Map()
        this.WindowStates[state.Title] := state
    }

    RecoverToDefualt() {
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
        this.CapsLockState := 0
    }

    CompareStateWith(otherState, ignoreCapsLock := false) {
        if (this.CurrentLayout.Name != otherState.CurrentLayout.Name)
            return false
        if (this.CurrentLayout.State != otherState.CurrentLayout.State)
            return false
        if (ignoreCapsLock == false && this.CapsLockState != otherState.CapsLockState)
            return false

        return true
    }
}