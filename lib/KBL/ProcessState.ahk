#Include KeyboardLayout.ahk

class ProcessState {
    RegExStates := 0
    ; RegExWindows := 0


    __New(title, defualtKBL, defualtState, defaultChangeStateDelay, alwaysRecorveToDefault) {
        this.Title := title
        this.DefualtLayout := KeyboardLayout(defualtKBL, defualtState, defaultChangeStateDelay)
        this.DefualtLayout.PrevioursSwitchIndex := 0
        this.DefualtLayout.CapsLockState := 0
        this.DefualtLayout.PrevioursSwitch := ""
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.alwaysRecorveToDefault := alwaysRecorveToDefault
    }

    __Item[winTitle] =>
        this.RegExStates[this.RegExWindows[winTitle]]


    Update(key, SwitchIndex, name, state, changeStateDelay) {
        ; this.PrevioursSwitch := key
        ; this.PrevioursSwitchIndex := SwitchIndex
        this.CurrentLayout.Set(name, state, changeStateDelay, key, SwitchIndex)
    }

    AddRegExState(state) {
        if (this.RegExStates == 0)
            this.RegExStates := Map()
        this.RegExStates[state.Title] := state
    }

    TryGetRegExState(regEx, &state) {
        ; 如果 regEx 为 0 ，则直接返回该进程的状态
        if (!regEx) {
            state := this
            return true
        }

        if (this.RegExStates && this.RegExStates.Has(regEx)) {
            state := this.RegExStates[regEx]
            return true
        }
        return false

    }

    RecoverToDefualtValue() {
        this.CurrentLayout.Set(this.DefualtLayout.Name, this.DefualtLayout.ImeState, this.DefualtLayout.ChangeStateDelay, "", 0, 0)
    }

    RecoverToDefualt() {
        this.CurrentLayout := this.DefualtLayout.Clone()
    }


    CompareStateWith(otherState, ignoreCapsLock := false) {
        if (this.CurrentLayout.Name != otherState.CurrentLayout.Name)
            return false
        if (this.CurrentLayout.ImeState != otherState.CurrentLayout.ImeState)
            return false
        if (ignoreCapsLock == false && this.CurrentLayout.CapsLockState != otherState.CurrentLayout.CapsLockState)
            return false

        return true
    }
}