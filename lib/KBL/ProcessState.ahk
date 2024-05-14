#Include KeyboardLayout.ahk

class ProcessState {
    __New(title, defualtKBL, defualtState, alwaysRecorveToDefault) {
        this.Title := title
        this.DefualtLayout := KeyboardLayout(defualtKBL, defualtState)
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
        this.alwaysRecorveToDefault := alwaysRecorveToDefault
    }

    Update(key, SwitchIndex, name, state) {
        this.PrevioursSwitch := key
        this.PrevioursSwitchIndex := SwitchIndex
        this.CurrentLayout.Set(name, state)
    }

    RecoverToDefualt(){
        this.CurrentLayout := this.DefualtLayout.Clone()
        this.PrevioursSwitch := ""
        this.PrevioursSwitchIndex := 0
    }
}