#Requires AutoHotkey v2.0

class KeyboardLayout{
    __New(name, state) {
        this.Name := name
        this.State := state
    }

    Set(name, state){
        this.Name := name
        this.State := state
    }
}