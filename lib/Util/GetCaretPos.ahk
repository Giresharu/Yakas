/**
 * Gets the position of the caret with UIA, Acc or CaretGetPos.
 * Credit: plankoe (https://www.reddit.com/r/AutoHotkey/comments/ysuawq/get_the_caret_location_in_any_program/)
 * @param X Value is set to the screen X-coordinate of the caret
 * @param Y Value is set to the screen Y-coordinate of the caret
 * @param W Value is set to the width of the caret
 * @param H Value is set to the height of the caret
 */
GetCaretPos(&X?, &Y?, &W?, &H?) {

    ; UIA caret
    static IUIA := ComObject("{e22ad333-b25f-460c-83d0-0581107395c9}", "{34723aff-0c9d-49d0-9896-7ab52df8cd8a}")
    try {
        ComCall(8, IUIA, "ptr*", &FocusedEl := 0) ; GetFocusedElement
        /*
        	The current implementation uses only TextPattern GetSelections and not TextPattern2 GetCaretRange.
        	This is because TextPattern2 is less often supported, or sometimes reports being implemented
        	but in reality is not. The only downside to using GetSelections is that when text
        	is selected then caret position is ambiguous. Nevertheless, in those cases it most
        	likely doesn't matter much whether the caret is in the beginning or end of the selection.
        
        	If GetCaretRange is needed then the following code implements that:
        	ComCall(16, FocusedEl, "int", 10024, "ptr*", &patternObject:=0), ObjRelease(FocusedEl) ; GetCurrentPattern. TextPattern2 = 10024
        	if patternObject {
        		ComCall(10, patternObject, "int*", &IsActive:=1, "ptr*", &caretRange:=0), ObjRelease(patternObject) ; GetCaretRange
        		ComCall(10, caretRange, "ptr*", &boundingRects:=0), ObjRelease(caretRange) ; GetBoundingRectangles
        		if (Rect := ComValue(0x2005, boundingRects)).MaxIndex() = 3 { ; VT_ARRAY | VT_R8
        			X:=Round(Rect[0]), Y:=Round(Rect[1]), W:=Round(Rect[2]), H:=Round(Rect[3])
        			return
        		}
        	}
        */
        ComCall(16, FocusedEl, "int", 10014, "ptr*", &patternObject := 0), ObjRelease(FocusedEl) ; GetCurrentPattern. TextPattern = 10014
        if patternObject {
            ComCall(5, patternObject, "ptr*", &selectionRanges := 0), ObjRelease(patternObject) ; GetSelections
            ComCall(4, selectionRanges, "int", 0, "ptr*", &selectionRange := 0) ; GetElement
            ComCall(10, selectionRange, "ptr*", &boundingRects := 0), ObjRelease(selectionRange), ObjRelease(selectionRanges) ; GetBoundingRectangles
            if (Rect := ComValue(0x2005, boundingRects)).MaxIndex() = 3 { ; VT_ARRAY | VT_R8
                X := Round(Rect[0]), Y := Round(Rect[1]), W := Round(Rect[2]), H := Round(Rect[3])
                return
            }
        }
    }

    ; Acc caret
    static _ := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")
    try {
        idObject := 0xFFFFFFF8 ; OBJID_CARET
        if DllCall("oleacc\AccessibleObjectFromWindow", "ptr", WinExist("A"), "uint", idObject &= 0xFFFFFFFF
            , "ptr", -16 + NumPut("int64", idObject == 0xFFFFFFF0 ? 0x46000000000000C0 : 0x719B3800AA000C81, NumPut("int64", idObject == 0xFFFFFFF0 ? 0x0000000000020400 : 0x11CF3C3D618736E0, IID := Buffer(16)))
            , "ptr*", oAcc := ComValue(9, 0)) = 0 {
            x := Buffer(4), y := Buffer(4), w := Buffer(4), h := Buffer(4)
            oAcc.accLocation(ComValue(0x4003, x.ptr, 1), ComValue(0x4003, y.ptr, 1), ComValue(0x4003, w.ptr, 1), ComValue(0x4003, h.ptr, 1), 0)
            X := NumGet(x, 0, "int"), Y := NumGet(y, 0, "int"), W := NumGet(w, 0, "int"), H := NumGet(h, 0, "int")
            if (X | Y) != 0
                return
        }
    }

    /*
    	This implementation prefers CaretGetPos > Acc > UIA. This is mostly due to speed differences
    	between the methods and statistically it seems more likely that the UIA method is required the
    	least (Chromium apps support Acc as well).
    */
    ; Default caret
    savedCaret := A_CoordModeCaret
    CoordMode "Caret", "Screen"
    CaretGetPos(&X, &Y)
    CoordMode "Caret", savedCaret
    if IsInteger(X) && (X | Y) != 0 {
        W := 4, H := 20
        return
    }
}