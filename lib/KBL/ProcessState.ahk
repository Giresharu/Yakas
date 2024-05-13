#Include KeyboardLayout.ahk

class ProcessState {
    __New(title, defualtKBL, defualtState) {
        this.DefualtLayout := KeyboardLayout(defualtKBL, defualtState)
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
    }

    Update(key, SwitchIndex, name, state) {
        this.PrevioursSwitch := key
        this.PrevioursSwitchIndex := SwitchIndex
        this.CurrentLayout.Set(name, state)
    }


}