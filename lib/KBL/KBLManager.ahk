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
        HotKey("~CapsLock", (_) => KBLManager.OnCapsLockToggled(1))
        Hotkey("~CapsLock Up", (_) => KBLManager.OnCapsLockToggled(0))
    }

    static CapsLockHolding := 0
    static OnCapsLockToggled(on) {
        if (on && KBLManager.CapsLockHolding)
            return
        KBLManager.CapsLockHolding := on

        Sleep(1000 / 24)

        hWnd := WinGetID("A")
        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name))
            return

        if (!ProcessSetting.StandAlong)
            processState := KBLManager.GlobalState
        else
            processState := KBLManager.FindProcessStateIfRunningProcess(hWnd, winTitle, path, name)

        if (processState) {
            state := GetKeyState("CapsLock", "T")
            if (processState.CapsLockState != state) {
                processState.CapsLockState := state
                ;TODO 显示 ToolTip
            }
        }

        ; 防止因为意外 Up 的触发被卡没了，隔半秒就取消按住的状态
        if (on) {
            SetTimer(() => KBLManager.CapsLockHolding = 0, -500)
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

    static FindProcessStateIfRunningProcess(hWnd, winTitle, path, name, &regex?) {
        result := 0
        regex := ""

        if (KBLManager.runningProcess.Has(path)) {
            result := KBLManager.runningProcess[path].WindowsMatchedRegEx.Has(winTitle)
            regex := result ? KBLManager.runningProcess[path].WindowsMatchedRegEx[winTitle] : ""
        } else if (KBLManager.runningProcess.Has(name)) {
            result := KBLManager.runningProcess[name].WindowsMatchedRegEx.Has(winTitle)
            regex := result ? KBLManager.runningProcess[name].WindowsMatchedRegEx[winTitle] : ""
        }

        if (result) {
            ; 当同路径进程已经打开时，会获取路径为 key 的状态
            ; 否则，获取同名进程的状态
            ; 非进程独立键盘模式下，不要为未配置进程创建状态记录（状态记录仅用于获取默认键盘配置）
            if (KBLManager.TryGetProcessState(path, name, &processState, ProcessSetting.StandAlong) != 0) {
                KBLManager.TryGetWindowState(processState, regex, &processState)
                result := processState
            }
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

    static OnWinActived(hWnd) {
        hWnd := Util.FixUWPWinID(hWnd)
        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name))
            return

        processState := KBLManager.FindProcessStateIfRunningProcess(hWnd, winTitle, path, name)
        if (processState) {
            ;TODO 这里也是 如果是同一个 processState 不应该触发，看来需要记录上一个 processState 来做比较了
            if (processState != 1 && processState.AlwaysRecorveToDefault) {
                processState.RecoverToDefualt()
                KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State)
                ; TODO if (CleanOnRecovery)
                SetCapsLockState("Off")
                ;TODO 显示 ToolTip
                return
            }

            if (!ProcessSetting.StandAlong)
                processState := KBLManager.GlobalState

            ; TODO 提取到新方法，并实现如果输入法相同则避免切换？
            ; TODO 也许不应该避免切换，那样的行为是不一致的
            ; TODO 如果是同一个 processState 则避免？？

            KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State)
            SetCapsLockState(processState.CapsLockState ? "On" : "Off")

            ;TODO 显示 ToolTip

            return
        }
        KBLManager.OnNewProcessDetected(path, name, hWnd)
    }


    static OnNewProcessDetected(path, name, hWnd) {
        ; 如果不是 ini 里预先配置的以名字作为 key 的进程，一定是以路径作为 key 的
        ; 非进程独立键盘模式下，不要为未配置进程创建状态记录，如果不存在记录，则使用全局配置
        result := KBLManager.TryGetProcessState(path, name, &processState, ProcessSetting.StandAlong)
        regex := ""
        if (!result) {
            key := path
            processState := KBLManager.GlobalState
        } else {
            key := result == 1 ? path : name
            KBLManager.TryGetWindowState(processState, WinGetTitle(hWnd), &processState, &regex)
        }
        kbl := processState.CurrentLayout

        if (!KBLManager.runningProcess.Has(key))
            KBLManager.runningProcess[key] := RunningProcessInfo(WinGetPID(hWnd))
        KBLManager.runningProcess[key].AddRegEx(WinGetTitle(hWnd), regex)

        KBLTool.SetKBL(hWnd, kbl.Name, kbl.State)
        SetCapsLockState(processState.CapsLockState ? "On" : "Off")
        ;TODO 显示 ToolTip

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
            result := KBLManager.TryGetProcessState(key, "", &processState, false)
            if (result == 1)
                processState.RecoverToDefualt()

            return
        }
        KBLManager.ProcessStates.Delete(key)
    }

    static TryGetProcessState(key1, key2 := "", &refProcessState?, needCreate := true) {
        ; 如果有 key1 优先找 key1 ，否则找 key2 ，都没有则以 key1 新建数据
        if (KBLManager.ProcessStates.Has(key1)) {
            key := key1
            result := 1
        } else if (key2 != "" && KBLManager.ProcessStates.Has(key2)) {
            key := key2
            result := 2
        } else if (needCreate) {
            key := key1
            KBLManager.ProcessStates[key] := ProcessState(key, "en-US", 0, false)
            result := 1
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
        result := KBLManager.TryGetProcessState(name, path, &processState, false)
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
        ;TODO if (CleanOnSwitch)
        processState.CapsLockState := 0
        SetCapsLockState("Off")
        ;TODO 显示 ToolTip
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