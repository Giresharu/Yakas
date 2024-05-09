class ConfigGui {
    __New(){
        static
        ; this.GetAllKeyboardLayouts()
        Gui, Add, Edit, vDefault
        Gui, Show
        Return
    }

    OnChange() {
        MsgBox, "Hello World"
    }



}
