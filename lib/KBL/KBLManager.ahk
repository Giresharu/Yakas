#Requires AutoHotkey v2.0

#Include KBLTool.ahk
#Include ProcessState.ahk
#Include ..\Hotkey\HotKeyPlus.ahk
#Include ..\Util\WinEvent.ahk
#Include ..\Setting\KBLSwitchSetting.ahk
#Include ..\Setting\ProcessSetting.ahk

;TODO 解决任务栏切换输入法导致任务栏浮动的问题
class KBLManager {
    static runningProcess := Map()
    static ProcessStates := Map()

    static Initialize() {
        KBLManager.InitProcessesState()
        KBLManager.RegisterHotkeys()

        hWnd := UTIL.WinGetID("A")
        SetTimer(() => KBLManager.OnWinActived(hWnd), -1) ; 手动触发一次当前窗口，防止漏过
        WinEvent.Active((h, w, d) => KBLManager.OnWinActived(w))
    }

    static RegisterHotkeys() {
        for i, s in KBLSwitchSetting.KBLSwitchSettings {
            key := s.Key
            condition := s.Condition

            HotkeyPlus("~" key, (k) => KBLManager.NextKBL(k), condition.NeedRelease, condition.HoldTime, condition.ReverseHold)
        }
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
        if (!WinExist(hWnd))
            return

        winTitle := WinGetTitle(hWnd)
        ; TODO 单独用一个变量记录上一个窗口，当点击任务栏时快切换任务栏的输入法
        ; TODO 不用了，改用AHK图标来代替输入法图标，防止任务栏乱动
        path := WinGetProcessPath(hWnd)
        name := WinGetProcessName(hWnd)

        result := false
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
            KBLManager.TryGetProcessState(path, name, &processState, ProcessSetting.StandAlong)
            KBLManager.TryGetWindowState(processState, regex, &processState)

            if (processState.AlwaysRecorveToDefault) {
                processState.RecoverToDefualt()
            }

            if (ProcessSetting.StandAlong || processState.AlwaysRecorveToDefault) {
                KBLTool.SetKBL(hWnd, processState.CurrentLayout.Name, processState.CurrentLayout.State)
            }
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
            kbl := KBLManager.GlobalState.CurrentLayout
        } else {
            key := result == 1 ? path : name
            KBLManager.TryGetWindowState(processState, WinGetTitle(hWnd), &processState, &regex)
            kbl := processState.CurrentLayout
        }

        if (!KBLManager.runningProcess.Has(key))
            KBLManager.runningProcess[key] := RunningProcessInfo(WinGetPID(hWnd))
        KBLManager.runningProcess[key].AddRegEx(WinGetTitle(hWnd), regex)

        KBLTool.SetKBL(hWnd, kbl.Name, kbl.State)
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
        result := KBLManager.TryGetProcessState(name, path, &processState, !ProcessSetting.StandAlong)
        if (result == 0)
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