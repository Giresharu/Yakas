#Requires AutoHotkey v2.0

#Include KBLTool.ahk
#Include ProcessState.ahk
#Include ..\Gui\ToolTip.ahk
#Include ..\Hotkey\HotKeyPlus.ahk
#Include ..\Util\WinEvent.ahk
#Include ..\Setting\KBLSwitchSetting.ahk
#Include ..\Setting\ProcessSetting.ahk
#Include ..\Setting\GlobalSetting.ahk

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
        if (!GlobalSetting.RemenberCaps || KBLManager.CapsLockHolding)
            return

        hWnd := Util.WinGetID("A")
        ; Sleep(50)

        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name))
            return

        ; 不能先获取 Global 而是先尝试获取进程
        result := KBLManager.FindProcessStateIfRunningProcess(hWnd, winTitle, path, name, &processState)

        condition := result && !processState.alwaysRecorveToDefault || !result
        condition := condition && !GlobalSetting.StandAlong

        if (condition) {
            processState := KBLManager.GlobalState
        } else if (!result) {
            mode := GlobalSetting.StandAlong ? "StandAlong" : "Global"
            throw WinGetTitle(hWnd) " processState's result is number: " result " in " mode " mode!"
        }

        ; TODO 可能会有 BUG
        startTick := A_TickCount
        while (true) {
            state := GetKeyState("CapsLock", "T")
            if state != processState.CapsLockState
                break
            Sleep(1000 / 60)
            if (A_TickCount - startTick > 500)
                break
        }

        if (processState.CapsLockState != state) {
            processState.CapsLockState := state
            ToolTipPlus(processState.CurrentLayout.Name, processState.CurrentLayout.State, state)
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

    static InitProcessesState() {
        KBLManager.GlobalState := ProcessState("Global", GlobalSetting.DefualtKBL.Name, GlobalSetting.DefualtKBL.State, false)
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
            if (name != "explorer.exe" && processState == KBLManager.PreviousState)
                return

            ; AlwaysRecorveToDefault 时，自动恢复到默认状态，并解除大写锁定
            if (processState.AlwaysRecorveToDefault) {
                capslockState := processState.CapsLockState
                processState.RecoverToDefualt()
                KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State, GlobalSetting.Lag)
                if (GlobalSetting.CleanCapsOnRecovered)
                    SetCapsLockState("Off")
                else {
                    SetCapsLockState(capslockState ? "On" : "Off")
                    processState.CapsLockState := capslockState
                }

            } else {
                KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State, GlobalSetting.Lag)
                SetCapsLockState(processState.CapsLockState ? "On" : "Off")
            }
            ; 当 CapsLock 与 KBL 有其一发生变化时，显示 ToolTip
            if (KBLManager.PreviousState != "") {
                if (!processState.CompareStateWith(KBLManager.PreviousState))
                    ToolTipPlus(processState.CurrentLayout.Name, processState.CurrentLayout.State, processState.CapsLockState)
            }
            KBLManager.PreviousState := processState
            return
        }

        KBLManager.OnNewProcessDetected(path, name, hWnd)
    }


    static OnNewProcessDetected(path, name, hWnd) {
        winTitle := WinGetTitle(hWnd)
        result := KBLManager.TryGetWindowOrProcessState(path, name, winTitle, &_processState, &regex := "")
        ; 不论结果是 0 还是 1 ，key 都一定是路径
        key := result != 2 ? path : name
        kbl := result ? _processState.CurrentLayout : 0

        ; 如果不存在进程状态，则新建一个
        if (!result) {
            KBLManager.ProcessStates[key] := _processState := ProcessState(key, GlobalSetting.DefualtKBL.Name, GlobalSetting.DefualtKBL.State, false)
        }

        if (!GlobalSetting.StandAlong) {
            ; 只要是全局模式，把 CurrentLayer 设为 Global 的引用，从此修改该进程的 CurrentLayer 就会影响全局的 CurrentLayer
            _processState.CurrentLayout := KBLManager.GlobalState.CurrentLayout
            ; 如果之前就有进程状态，则用之前的状态的键盘覆盖当前键盘的值（用于首次打开切换键盘）
            if (result) {
                ; 为了防止这里修改导致刚还是全局状态的 PreviousState.CurrentLayer 被修改，使得后面没法比较，这里先新建一个假的 PreviousState，存储当前的 CurrentLayer
                temp := KBLManager.PreviousState.CurrentLayout.Clone()
                KBLManager.PreviousState := ProcessState("Temp", 0, 0, 0)
                KBLManager.PreviousState.CurrentLayout := temp
                _processState.CurrentLayout.Set(kbl.Name, kbl.State)
            }
        }

        kbl := _processState.CurrentLayout

        ; 在运行列表中记录 PID，并记录窗口标题及其对应的正则表达式
        if (!KBLManager.runningProcess.Has(key))
            KBLManager.runningProcess[key] := RunningProcessInfo(WinGetPID(hWnd))
        KBLManager.runningProcess[key].AddRegEx(winTitle, regex)

        KBLTool.SetKBL(hWnd, kbl.Name, kbl.State, GlobalSetting.Lag)
        SetCapsLockState(_processState.CapsLockState ? "On" : "Off")

        if (KBLManager.PreviousState == "" || !_processState.CompareStateWith(KBLManager.PreviousState)) {
            ToolTipPlus(_processState.CurrentLayout.Name, _processState.CurrentLayout.State, _processState.CapsLockState)
        }
        KBLManager.PreviousState := _processState

        ProcessWaitClose(KBLManager.runningProcess[key].PID)
        KBLManager.OnProcessExit(key)
    }

    static OnProcessExit(key) {
        ; 部分软件的进程退出有延迟，比如 QQ ，所以有时关闭软件又立刻打开会误触发下面的代码把进程状态还原
        ; 所以如果检测到进程还在，则不做任何退出处理
        ; 这会造成不还原默认键盘的问题，但这是 Feature
        if (ProcessExist(KBLManager.runningProcess[key].PID))
            return

        KBLManager.runningProcess.Delete(key)

        ; 非进程独立模式下不要去做任何复原与删除
        ; 未开启退出清理也不要做任何处理
        if (!GlobalSetting.StandAlong || !GlobalSetting.CleanOnProcessExit)
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

        if (WinActive("ahk_class Shell_TrayWnd ahk_exe explorer.exe")) {
            ToolTip("因为 WM_INPUTLANGUAGECHANGEQUEST 的限制，无法在聚焦任务栏时切换键盘。")
            SetTimer(ToolTip, 1000)
            return
        }

        hotkey := Trim(hotkey, '~')
        SwitchSetting := KBLSwitchSetting[hotkey]
        path := WinGetProcessPath(hWnd)
        name := WinGetProcessName(hWnd)

        result := KBLManager.TryGetProcessState(name, path, &processState)

        if (processState.PrevioursSwitch == hotkey) {
            index := processState.PrevioursSwitchIndex
            expectedKbl := processState.CurrentLayout
        } else
            index := KBLManager.FindSimilarKBL(SwitchSetting.Layouts, hWnd)

        kblCapcity := SwitchSetting.Layouts.Length
        index := Mod(index, kblCapcity) + 1
        kbl := SwitchSetting[index].Name
        state := SwitchSetting[index].DefaultState

        processState.Update(hotkey, index, kbl, state)
        KBLTool.SetKBL(hWnd, kbl, state, GlobalSetting.Lag)

        if (GlobalSetting.CleanCapsOnSwitched) {
            processState.CapsLockState := 0
            SetCapsLockState("Off")
        }

        ToolTipPlus(kbl, state, processState.CapsLockState)
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