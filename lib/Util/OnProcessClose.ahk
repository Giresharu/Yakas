#Requires AutoHotkey v2.0

/*
OnProcessClose:
  Registers *callback* to be called when the process identified by *proc*
  exits, or after *timeout* milliseconds if it has not exited.
@arg proc - A process handle as either an Integer or an object with `.ptr`.
@arg callback - A function with signature `callback(handle, timedOut)`.\
  `handle` is a ProcessHandle with properties `ID`, `ExitCode` and `Ptr` (process handle).\
  `timedOut` is true if the wait timed out, otherwise false.
@arg timeout - The timeout in milliseconds. If omitted or -1, the wait
  never times out. If 0, the callback is called immediately.
@returns {RegisteredWait} - Optionally use the `Unregister()` method
  of the returned object to unregister the callback.
*/
OnProcessClose(proc, callback, timeout?) {
    if !(proc is Integer || proc := ProcessExist(proc))
        throw ValueError("Invalid PID or process name", -1, proc)
    if !proc := DllCall("OpenProcess", "uint", 0x101000, "int", false, "uint", proc, "ptr")
        throw OSError()
    return RegisterWaitCallback(ProcessHandle(proc), callback, timeout?)
}

class ProcessHandle {
    __new(handle) {
        this.ptr := handle
    }
    __delete() => DllCall("CloseHandle", "ptr", this)
    ID => DllCall("GetProcessId", "ptr", this)
    ExitCode {
        get {
            if !DllCall("GetExitCodeProcess", "ptr", this, "uint*", &exitCode := 0)
                throw OSError()
            return exitCode
        }
    }
}

/*
RegisterWaitCallback:
  Register *callback* to be called when *handle* is signaled, or after
  *timeout* milliseconds if it has not been signaled.
@arg handle - A process handle or any other handle type supported by
  RegisterWaitForSingleObject(). This can be an Integer or an object
  with a `.ptr` property.
@arg callback - A function with signature `callback(handle, timedOut)`,
  where `timedOut` is true if the wait timed out, otherwise false.
@arg timeout - The timeout in milliseconds. If omitted or -1, the wait
  never times out. If 0, the callback is called immediately.
@returns {RegisteredWait} - Optionally use the `Unregister()` method
  of the returned object to unregister the wait (cancel the callback).
*/
RegisterWaitCallback(handle, callback, timeout := -1) {
    static waitCallback, postMessageW, wnd, nmsg := 0x5743
    if !IsSet(waitCallback) {
        if A_PtrSize = 8 {
            NumPut("int64", 0x8BCAB60F44C18B48, "int64", 0x498B48C18B4C1051, "int64", 0x20FF4808, waitCallback := Buffer(24))
            DllCall("VirtualProtect", "ptr", waitCallback, "ptr", 24, "uint", 0x40, "uint*", 0)
        }
        else {
            NumPut("int64", 0x448B50082444B60F, "int64", 0x70FF0870FF500824, "int64", 0x0008C2D0FF008B04, waitCallback := Buffer(24))
            DllCall("VirtualProtect", "ptr", waitCallback, "ptr", 24, "uint", 0x40, "uint*", 0)
        }
        postMessageW := DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "user32", "ptr"), "astr", "PostMessageW", "ptr")
        wnd := Gui(), DllCall("SetParent", "ptr", wnd.hwnd, "ptr", -3) ; HWND_MESSAGE = -3
        OnMessage(nmsg, messaged, 255)
    }
    NumPut("ptr", postMessageW, "ptr", wnd.hwnd, "uptr", nmsg, param := RegisteredWait())
    NumPut("ptr", ObjPtr(param), param, A_PtrSize * 3)
    param.callback := callback, param.handle := handle
    if !DllCall("RegisterWaitForSingleObject", "ptr*", &waitHandle := 0, "ptr", handle
        , "ptr", waitCallback, "ptr", param, "uint", timeout, "uint", 8)
        throw OSError()
    param.waitHandle := waitHandle, param.locked := ObjPtrAddRef(param)
    return param
    static messaged(wParam, lParam, nmsg, hwnd) {
        if hwnd = wnd.hwnd {
            local param := ObjFromPtrAddRef(NumGet(wParam + A_PtrSize * 3, "ptr"))
            (param.callback)(param.handle, lParam)
            param._unlock()
        }
    }
}

class RegisteredWait extends Buffer {
    static prototype.waitHandle := 0, prototype.locked := 0
    __new() => super.__new(A_PtrSize * 5, 0)
    __delete() => this.Unregister()
    _unlock() {
        (p := this.locked) && (this.locked := 0, ObjRelease(p))
    }
    Unregister() {
        wh := this.waitHandle, this.waitHandle := 0
        (wh) && DllCall("UnregisterWaitEx", "ptr", wh, "ptr", -1)
        this._unlock()
    }
}

/*
#include <windows.h>
struct Param {
    decltype(&PostMessageW) pm;
    HWND wnd;
    UINT msg;
};
VOID CALLBACK WaitCallback(Param *param, BOOLEAN waitFired) {
    param->pm(param->wnd, param->msg, (WPARAM)param, (LPARAM)waitFired);
}
---- 64-bit
00000	48 8b c1		 mov	 rax, rcx
00003	44 0f b6 ca		 movzx	 r9d, dl
00007	8b 51 10		 mov	 edx, DWORD PTR [rcx+16]
0000a	4c 8b c1		 mov	 r8, rcx
0000d	48 8b 49 08		 mov	 rcx, QWORD PTR [rcx+8]
00011	48 ff 20		 rex_jmp QWORD PTR [rax]
---- 32-bit
00000	0f b6 44 24 08	 movzx	 eax, BYTE PTR _waitFired$[esp-4]
00005	50				 push	 eax
00006	8b 44 24 08		 mov	 eax, DWORD PTR _param$[esp]
0000a	50				 push	 eax
0000b	ff 70 08		 push	 DWORD PTR [eax+8]
0000e	ff 70 04		 push	 DWORD PTR [eax+4]
00011	8b 00			 mov	 eax, DWORD PTR [eax]
00013	ff d0			 call	 eax
00015	c2 08 00		 ret	 8
*/