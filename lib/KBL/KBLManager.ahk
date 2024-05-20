#Requires AutoHotkey v2.0

#Include KBLTool.ahk
#Include ProcessState.ahk
#Include ..\Hotkey\HotKeyPlus.ahk
#Include ..\Util\WinEvent.ahk
#Include ..\Setting\KBLSwitchSetting.ahk
#Include ..\Setting\ProcessSetting.ahk

class KBLManager {
    static runningProcess := Map()
    static ProcessStates := Map()
    static PreviousState := ""

    static Initialize() {
        KBLManager.InitProcessesState()
        KBLManager.RegisterHotkeys()

        hWnd := WinGetID("A")
        SetTimer(() => KBLManager.OnWinActived(hWnd), -1) ; 手动触发一次当前窗口，防止漏过
        WinEvent.Active((h, w, d) => KBLManager.OnWinActived(w))
    }

    static RegisterHotkeys() {
        for i, s in KBLSwitchSetting.KBLSwitchSettings {
            key := s.Key
            condition := s.Condition

            HotkeyPlus("~" key, (k) => KBLManager.NextKBL(k), condition.NeedRelease, condition.HoldTime, condition.ReverseHold)
        }
        HotKey("~CapsLock", (_) => KBLManager.OnCapsLockToggled())
    }

    static CapsLockHolding := 0
    static OnCapsLockToggled() {
        if (!ProcessSetting.RemenberCaps || KBLManager.CapsLockHolding)
            return

        hWnd := Util.WinGetID("A")
        ; Sleep(50)

        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name))
            return

        ; 不能先获取 Global 而是先尝试获取进程
        result := KBLManager.FindProcessStateIfRunningProcess(hWnd, winTitle, path, name, &processState)

        condition := result && !processState.alwaysRecorveToDefault || !result
        condition := condition && !ProcessSetting.StandAlong

        if (condition) {
            processState := KBLManager.GlobalState
        } else if (!result) {
            mode := ProcessSetting.StandAlong ? "StandAlong" : "Global"
            throw WinGetTitle(hWnd) " processState's result is number: " result " in " mode " mode!"
        }

        ; TODO 可能会有 BUG，暂时不知道会不会有 processState.CapsLockState 与实际不符的情况，所以预防万一做一个超时检测
        startTick := A_TickCount
        while (true) {
            state := GetKeyState("CapsLock", "T")
            if state != processState.CapsLockState
                break
            Sleep(1000 / 60)
            if (A_TickCount - startTick > 500)
                throw "Check CapsLock state timeout!"
        }

        if (processState.CapsLockState != state) {
            processState.CapsLockState := state
            ;TODO 显示 ToolTip
            ToolTip(WinGetTitle(hWnd) " " (state ? "On" : "Off"))
        }

        ; 循环检测释放，允许下次按下 CapsLock 生效
        SetTimer(WaitForRelease, 1000 / 24)
        WaitForRelease() {
            if (!GetKeyState("CapsLock", "P")) {
                SetTimer(WaitForRelease, 0)
                KBLManager.CapsLockHolding := 0
            }
        }

    }

    static UpdateCapsLockState(processState, state) {

    }

    static InitProcessesState() {
        KBLManager.GlobalState := ProcessState("Global", ProcessSetting.DefualtKBL.Name, ProcessSetting.DefualtKBL.State, false)
        for i, p in ProcessSetting.ProcessSettings {
            state := KBLManager.ProcessStates[p.Title] := ProcessState(p.Title, p.DefaultKBL.Name, p.DefaultKBL.State, p.AlwaysRecorveToDefault)
            if (p.WindowSettings != 0) {
                for j, w in p.WindowSettings {
                    state.AddWindow(ProcessState(w.Title, w.DefaultKBL.Name, w.DefaultKBL.State, w.AlwaysRecorveToDefault))
                }
            }
        }
    }

    static OnWinActived(hWnd) {
        hWnd := Util.FixUWPWinID(hWnd)
        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name))
            return

        result := KBLManager.FindProcessStateIfRunningProcess(hWnd, winTitle, path, name, &processState)
        if (result) {
            ; 如果 processState 没有变化，则不做任何处理
            if (processState == KBLManager.PreviousState)
                return

            ; 当 processState 存在且 AlwaysRecorveToDefault 时，自动恢复到默认状态，并解除大写锁定
            if (result != 1 && processState.AlwaysRecorveToDefault) {
                capslockState := processState.CapsLockState
                processState.RecoverToDefualt()
                KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State)
                if (ProcessSetting.CleanCapsOnRecovered)
                    SetCapsLockState("Off")
                else {
                    SetCapsLockState(capslockState ? "On" : "Off")
                    processState.CapsLockState := capslockState
                }
                ;TODO 显示 ToolTip
                ToolTip(WinGetTitle(hWnd) " " (processState.CapsLockState ? "On" : "Off"))
            } else {
                ; 否则恢复到记录的状态
                processState := ProcessSetting.StandAlong ? processState : KBLManager.GlobalState

                KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State)

                SetCapsLockState(processState.CapsLockState ? "On" : "Off")
                ;TODO 显示 ToolTip
                ToolTip(WinGetTitle(hWnd) " " (processState.CapsLockState ? "On" : "Off"))
            }
            KBLManager.PreviousState := processState
            return
        }

        KBLManager.OnNewProcessDetected(path, name, hWnd)
    }


    static OnNewProcessDetected(path, name, hWnd) {
        ; 如果不是 ini 里预先配置的以名字作为 key 的进程，一定是以路径作为 key 的
        ; 非进程独立键盘模式下，不要为未配置进程创建状态记录，如果不存在记录，则使用全局配置

        ; result := KBLManager.TryGetProcessState(path, name, &processState)
        ; regex := ""
        ; if (!result) {
        ;     key := path
        ;     processState := KBLManager.GlobalState
        ; } else {
        ;     key := result == 1 ? path : name
        ;     KBLManager.TryGetWindowState(processState, WinGetTitle(hWnd), &processState, &regex)
        ; }
        ; kbl := processState.CurrentLayout

        winTitle := WinGetTitle(hWnd)
        result := KBLManager.TryGetWindowOrProcessState(path, name, winTitle, &_processState, &regex := "")
        ; 不论结果是 0 还是 1 ，key 都一定是路径
        key := result == 2 ? path : name
        kbl := result ? _processState.CurrentLayout : 0

        if (!ProcessSetting.StandAlong) {
            if (!result || !_processState.AlwaysRecorveToDefault) {
                _processState := KBLManager.GlobalState
                if (result)
                    _processState.CurrentLayout.Set(kbl.Name, kbl.State)
            }
        } else {
            if (!result) {
                KBLManager.ProcessStates[key] := _processState := ProcessState(key, "en-US", 0, false)
            }
        }
        kbl := _processState.CurrentLayout

        if (!KBLManager.runningProcess.Has(key))
            KBLManager.runningProcess[key] := RunningProcessInfo(WinGetPID(hWnd))
        KBLManager.runningProcess[key].AddRegEx(winTitle, regex)

        KBLTool.SetKBL(hWnd, kbl.Name, kbl.State)
        SetCapsLockState(_processState.CapsLockState ? "On" : "Off")
        ;TODO 显示 ToolTip
        ToolTip(winTitle " " (_processState.CapsLockState ? "On" : "Off"))

        KBLManager.PreviousState := _processState

        ProcessWaitClose(KBLManager.runningProcess[key].PID)
        KBLManager.OnProcessExit(key)
    }

    static OnProcessExit(key) {
        ; 部分软件的进程退出有延迟，比如 QQ ，所以有时关闭软件又立刻打开会误触发下面的代码把进程状态还原
        ; 所以如果检测到进程还在，则不做任何退出处理
        ; 这会造成不还原默认键盘的问题，但这是 Feature
        if (ProcessExist(KBLManager.runningProcess[key]))
            return

        KBLManager.runningProcess.Delete(key)

        ; 非进程独立模式下不要去做任何复原与删除
        ; 未开启退出清理也不要做任何处理
        if (!ProcessSetting.StandAlong || !ProcessSetting.CleanOnProcessExit)
            return

        ; 查询配置里有没有默认配置，有则还原，无则删除
        if (ProcessSetting.ProcessSettings.Has(key)) {
            result := KBLManager.TryGetProcessState(key, "", &processState)
            if (result)
                processState.RecoverToDefualt()

            return
        }
        KBLManager.ProcessStates.Delete(key)
    }

    ; 0: 不存在该进程的痕迹 1: 正在运行进程 2.正在运行的进程，且 key 为 name
    static FindProcessStateIfRunningProcess(hWnd, winTitle, path, name, &processState, &regex?) {
        result := 0
        regex := ""

        if (KBLManager.runningProcess.Has(path)) {
            regex := KBLManager.runningProcess[path].WindowsMatchedRegEx.Has(winTitle) ? KBLManager.runningProcess[path].WindowsMatchedRegEx[winTitle] : ""
            result := 1
        } else if (KBLManager.runningProcess.Has(name)) {
            regex := KBLManager.runningProcess[name].WindowsMatchedRegEx.Has(winTitle) ? KBLManager.runningProcess[name].WindowsMatchedRegEx[winTitle] : ""
            result := 1
        }

        ; 当同路径进程已经打开时，会获取路径为 key 的状态
        ; 否则，获取同名进程的状态
        ; 非进程独立键盘模式下，不要为未配置进程创建状态记录（状态记录仅用于获取默认键盘配置）
        if (result) {
            result := KBLManager.TryGetWindowOrProcessState(path, name, regex, &processState, &regex)
        }

        return result
    }

    static GetWinProperties(hWnd, &winTitle?, &processPath?, &processName?) {
        if (!WinExist(hWnd))
            return 0
        winTitle := WinGetTitle(hWnd)
        processName := WinGetProcessName(hWnd)
        processPath := WinGetProcessPath(hWnd)

        return hWnd
    }

    static TryGetWindowOrProcessState(path, name, title, &processState?, &regex?) {
        result := KBLManager.TryGetProcessState(path, name, &processState)
        if (result) {
            KBLManager.TryGetWindowState(processState, title, &processState, &regex)
        }
        return result
    }

    static TryGetProcessState(key1, key2 := "", &refProcessState?) {
        ; 如果有 key1 优先找 key1 ，否则找 key2 ，都没有则以 key1 新建数据
        if (KBLManager.ProcessStates.Has(key1)) {
            key := key1
            result := 1
        } else if (key2 != "" && KBLManager.ProcessStates.Has(key2)) {
            key := key2
            result := 2
            ; } else if (needCreate) {
            ;     key := key1
            ;     KBLManager.ProcessStates[key] := ProcessState(key, "en-US", 0, false)
            ;     result := 1
        } else {
            return 0
        }

        refProcessState := KBLManager.ProcessStates[key]
        return result
    }

    static TryGetWindowState(processState, title, &windowState?, &RegExPattern?) {
        if (title == "" || processState.WindowStates == 0)
            return 0

        if (processState.WindowStates.Has(title)) {
            windowState := processState.WindowStates[title]
            RegExPattern := title
            return 1
        }

        for i, w in processState.WindowStates {
            if (RegExMatch(title, w.Title)) {
                windowState := w
                RegExPattern := w.Title
                return 1
            }
        }
        return 0
    }

    static NextKBL(hotkey) {
        hWnd := Util.WinGetID("A")
        hotkey := Trim(hotkey, '~')
        SwitchSetting := KBLSwitchSetting[hotkey]
        path := WinGetProcessPath(hWnd)
        name := WinGetProcessName(hWnd)

        ; 非独立进程键盘模式下使用全局状态
        result := KBLManager.TryGetProcessState(name, path, &processState)
        if (result == 0 || !ProcessSetting.StandAlong)
            processState := KBLManager.GlobalState

        if (processState.PrevioursSwitch == hotkey) {
            index := processState.PrevioursSwitchIndex
            expectedKbl := processState.CurrentLayout
            kbl := KBLTool.GetCurrentKBL(hWnd)
            if (expectedKbl.Name != kbl.Name || expectedKbl.State != kbl.State) {
                index := KBLManager.FindSimilarKBL(SwitchSetting.Layouts, hWnd)
            }
        } else
            index := KBLManager.FindSimilarKBL(SwitchSetting.Layouts, hWnd)

        kblCapcity := SwitchSetting.Layouts.Length
        index := Mod(index, kblCapcity) + 1
        kbl := SwitchSetting[index].Name
        state := SwitchSetting[index].DefaultState

        processState.Update(hotkey, index, kbl, state)
        KBLTool.SetKBL(hWnd, kbl, state)
        if (ProcessSetting.CleanCapsOnSwitched) {
            processState.CapsLockState := 0
            SetCapsLockState("Off")
        }
        ;TODO 显示 ToolTip
        ToolTip(WinGetTitle(hWnd) " " (processState.CapsLockState ? "On" : "Off"))

    }

    static FindSimilarKBL(layouts, hWnd) {
        kbl := KBLTool.GetCurrentKBL(hWnd)
        name := kbl.Name
        state := kbl.State

        mostSimilar := 1
        for i, layout in layouts {
            if layout.Name == name {
                if (mostSimilar == 1)
                    mostSimilar := i
                if (state == layout.DefaultState)
                    return i
            }
        }
        return mostSimilar
    }
}

class RunningProcessInfo {
    PID := 0
    WindowsMatchedRegEx := Map()

    __New(pid) {
        this.PID := pid
    }

    AddRegEx(title, regex) {
        this.WindowsMatchedRegEx[title] := regex
    }

}