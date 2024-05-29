#Include KeyboardLayout.ahk

class ProcessState {
    WindowStates := 0

    __New(title, defualtKBL, defualtState, alwaysRecorveToDefault) {
        this.Title := title
        this.DefualtLayout := KeyboardLayout(defualtKBL, defualtState)
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.DefualtLayout.PrevioursSwitch := ""
        this.DefualtLayout.PrevioursSwitchIndex := 0
        this.DefualtLayout.CapsLockState := 0

        this.alwaysRecorveToDefault := alwaysRecorveToDefault
    }

    Update(key, SwitchIndex, name, state) {
        ; this.PrevioursSwitch := key
        ; this.PrevioursSwitchIndex := SwitchIndex
        this.CurrentLayout.Set(name, state, key, SwitchIndex)
    }

    AddWindow(state) {
        if (this.WindowStates == 0)
            this.WindowStates := Map()
        this.WindowStates[state.Title] := state
    }

    RecoverToDefualtValue() {
        this.CurrentLayout.Set(this.DefualtLayout.Name, this.DefualtLayout.State, "", 0, 0)
    }
    
    RecoverToDefualt() {
        this.CurrentLayout := this.DefualtLayout.Clone()
    }


    CompareStateWith(otherState, ignoreCapsLock := false) {
        if (this.CurrentLayout.Name != otherState.CurrentLayout.Name)
            return false
        if (this.CurrentLayout.State != otherState.CurrentLayout.State)
            return false
        if (ignoreCapsLock == false && this.CurrentLayout.CapsLockState != otherState.CurrentLayout.CapsLockState)
            return false

        return true
    }
}