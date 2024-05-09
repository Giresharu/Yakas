;┌─────────────────────────────────────────────┐
;│ AutoHotkey Gui Class Version 2              │
;├─────────────────────────────────────────────┤
;│ © 2019 Ian Pride - New Pride Software       │
;│ Create AutoHotkey gui objects               │
;│ Features:                                   │
;│ - methods for most (all?) gui Features      │
;│ - Obejcts for Fonts and Controls            │
;│ - Font objects with 5 elements:             │
;│ - name                                      │
;│ - size                                      │
;│ - quality                                   │
;│ - weight                                    │
;│ - color                                     │
;│ - (E.g. thisObj.fonts.name)                 │
;│ - method to get control info: getControls() │
;│ - retrives objects for most (all?)          │
;│   Sub-Commands                              │
;│ - (E.g. thisObj.controls.Static1.pos.x)     │
;│                                             │
;│ getControls() will be adding the ability to │
;│ get an individual control info; coming soon │
;└─────────────────────────────────────────────┘
;┌───────┐
;│ Class │
;└───────┘
class _Gui {
    fonts := {}
    controls := {}
    controlString := this.controlv()
    controlv(){
        list =
(join`n
text|edit|updown|picture|button|
checkbox|radio|dropdownlist|
combobox|listbox|listview|treeview|
link|hotkey|datetime|monthcal|
slider|progress|groupbox|tab|
tab2|tab3|statusbar|activex|custom
)
        return list
    }
    __New(name := "",title := "") {
        this.name := name ;
        this.sub := (name?name ":":"") ;
        this.title := title ;
    }
    New(params := ""){
        Gui ,   %   this.sub this.subFunc(A_ThisFunc)
            ,   %   this.toString(params)
            ,   %   this.title
        return this.getId()
    }
    Options(params){
        Gui,% this.sub this.toString(params)
    }
    Menu(name){
        Gui,% this.sub this.subFunc(A_ThisFunc),%name%
    }
    Minimize(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Maximize(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Restore(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Default(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Flash(OFF := false){
        Gui,% this.sub this.subFunc(A_ThisFunc),% (OFF?"OFF":"")
    }
    Add(control,content := "",params := ""){
        global
        if (InStr(control,controlString)) {
            Gui ,   %   this.sub this.subFunc(A_ThisFunc)
                ,   %   control
                ,   %   this.toString(params)
                ,   %   content  
        }
    }
    Show(params := ""){
        Gui ,   %   this.sub this.subFunc(A_ThisFunc)
            ,   %   this.toString(params)
            ,   %   this.title
        return this.getId()
    }
    Submit(params := ""){
        Gui ,   %   this.sub this.subFunc(A_ThisFunc)
            ,   %   this.toString(params)
    }
    Margin(x := 0,y := 0){
		if x is integer
			xint := true
		if y is integer
			yint := true
        this.marginX := xint?x:8
		this.marginY := yint?y:8
        Gui ,   %   this.sub this.subFunc(A_ThisFunc)
            ,   %   this.marginX
            ,   %   this.marginY
    }
    Color(winClr := "",ctrlClr := ""){
        this.colorWin := winClr
        this.colorCtrl := ctrlClr
        Gui ,   %   this.sub this.subFunc(A_ThisFunc)
            ,   %   this.colorWin
            ,   %   this.colorCtrl
    }
    Font(fontName := "",params := ""){
        fontName := (    fontName        ?   fontName
                    :   this.fonts.name ?   this.fonts.name
                    :   "Segoe UI"                         ) ;
        this.fonts.name := fontName ;
        for fontI, fontO in this.toArray(params) {
            if RegExMatch(fontO,"i)^s[0-9]*$") {
                this.fonts.size := SubStr(fontO,2) ;
            }
            if RegExMatch(fontO,"i)^w[0-9]*$") {
                this.fonts.weight := SubStr(fontO,2) ;
            }
            if RegExMatch(fontO,"i)^c*") {
                this.fonts.color := SubStr(fontO,2) ;
            }
            if RegExMatch(fontO,"i)^q[0-9]*$") {
                this.fonts.quality := SubStr(fontO,2) ;
            }
        }
        Gui ,   %   this.sub this.subFunc(A_ThisFunc)
            ,   %   " s" this.fonts.size
                .   " w" this.fonts.weight
                .   " c" this.fonts.color
                .   " q" this.fonts.quality
            ,   %   this.fonts.name
    }
    Cancel(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Hide(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Destroy(){
        Gui,% this.sub this.subFunc(A_ThisFunc)
    }
    Button(x,y,w,h,txt,pHwnd,tHwnd,pParams := "",tParams := ""){
        this.Add(   "Progress",100,"x" x " y"
                .   y " w" w " h" h " Hwnd" pHwnd " " pParams)
        this.Add(   "Text",txt
                ,   "xp yp +0x200 +Center"
                .   " +BackgroundTrans w"
                .   w " h" h " Hwnd" tHwnd " " tParams)
    }
    subFunc(func){
        n := StrSplit(func,".")
        return n[n.MaxIndex()]
    }
    setFont(fontObj){
        this.fonts := fontObj
        this.Font()
    }
    toArray(arrayOrStr := "",delim := " "){
        if IsObject(arrayOrStr){
            return arrayOrStr
        }
        array := []
        loop,parse,arrayOrStr,%delim%
        {
            array.Push(A_LoopField)
        }
        return array
    }
    toString(arrayOrStr := ""){
        if IsObject(arrayOrStr){
            for idx, item in arrayOrStr {
                tmpv .= item " " ;
            }
            tmpv = %tmpv%
        } else {
            tmpv := arrayOrStr
        }
        return tmpv
    }
    getControls(){
        if (this.getId()) {
            WinGet,_ctrlList,ControlList,% "ahk_id " this.id
            if (_ctrlList != ""){
                loop,parse,_ctrlList,`n
                {   
                    if (! IsObject(this.controls[A_LoopField])) {
                        this.controls[A_LoopField] := {}
                    }
                    GuiControlGet   ,   content,% this.sub,%A_LoopField%
                                    ,   % ((SubStr(A_LoopField,1,6)="Button")?"Text":"")
                    GuiControlGet,pos,% this.sub "Pos",%A_LoopField%
                    GuiControlGet,focus,% this.sub "Focus"
                    GuiControlGet,focusv,% this.sub "FocusV"
                    GuiControlGet,enabled,% this.sub "Enabled",%A_LoopField%
                    GuiControlGet,visible,% this.sub "Visible",%A_LoopField%
                    GuiControlGet,hwnd,% this.sub "Hwnd",%A_LoopField%
                    GuiControlGet,name,% this.sub "Name",%A_LoopField%
                    this.controls[A_LoopField]["focus"] := focus ;
                    this.controls[A_LoopField]["focusv"] := focusv ;
                    this.controls[A_LoopField]["content"] := content ;
                    this.controls[A_LoopField]["pos"]   :=  {   "x":posX
                                                            ,   "y":posY
                                                            ,   "w":posW
                                                            ,   "h":posH} ;
                    this.controls[A_LoopField]["enabled"] := enabled ;
                    this.controls[A_LoopField]["visible"] := visible ;
                    this.controls[A_LoopField]["hwnd"] := hwnd ;
                    this.controls[A_LoopField]["name"] := name ;
                }
            }
            return this.controls
        }
    }
    getId(){
        this.Options("+LastFound")
        return (this.id := WinExist())
    }
}