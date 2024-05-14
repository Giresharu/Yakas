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
    ; static GlobalState := ""

    static Initialize() {
        KBLManager.GetProcessesState()
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
    }

    static GetProcessesState() {
        KBLManager.GlobalState := ProcessState("Global", ProcessSetting.DefualtKBL.Name, ProcessSetting.DefualtKBL.State, false)
        for i, p in ProcessSetting.ProcessSettings {
            KBLManager.ProcessStates[p.Name] := ProcessState(p.Name, p.DefaultKBL.Name, p.DefaultKBL.State, p.AlwaysRecorveToDefault)
        }
    }

    static OnWinActived(hWnd) {
        if (!WinExist(hWnd))
            return

        path := WinGetProcessPath(hWnd)
        name := WinGetProcessName(hWnd)
        if (KBLManager.runningProcess.Has(path) || KBLManager.runningProcess.Has(name)) {
            ; 当同路径进程已经打开时，会获取路径为 key 的状态
            ; 否则，获取同名进程的状态
            ; 非进程独立键盘模式下，不要为未配置进程创建状态记录（状态记录仅用于获取默认键盘配置）
            KBLManager.TryGetProcessState(path, name, &processState, !ProcessSetting.StandAlong)
            if (processState.AlwaysRecorveToDefault) {
                processState.RecoverToDefualt()
            }
            ; 只有进程独立键盘模式下，或者进程有总是恢复默认键盘的要求时，才设置键盘
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
        result := KBLManager.TryGetProcessState(path, name, &processState, !ProcessSetting.StandAlong)
        if (!result) {
            key := path
            kbl := KBLManager.GlobalState.CurrentLayout
        } else {
            key := result == 1 ? path : name
            kbl := processState.CurrentLayout
        }

        KBLManager.runningProcess[key] := WinGetPID(hWnd)
        KBLTool.SetKBL(hWnd, kbl.Name, kbl.State)

        ProcessWaitClose(KBLManager.runningProcess[key])
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

    static TryGetProcessState(key1, key2 := "", &refProcessState := "", needCreate := true) {
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

    static NextKBL(hotkey) {
        hWnd := WinGetID("A")
        hotkey := Trim(hotkey, '~')
        SwitchSetting := KBLSwitchSetting[hotkey]
        path := WinGetProcessPath(hWnd)
        name := WinGetProcessName(hWnd)

        ; 非独立进程键盘模式下使用全局状态
        result := KBLManager.TryGetProcessState(name, path, &processState, !ProcessSetting.StandAlong)
        if (result == 0)
            processState := KBLManager.GlobalState

        index := processState.PrevioursSwitch == hotkey ? processState.PrevioursSwitchIndex : KBLManager.FindSimilarKBL(SwitchSetting.Layouts, hWnd)

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