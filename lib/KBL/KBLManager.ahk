#Requires AutoHotkey v2.0

#Include KBLTool.ahk
#Include ProcessState.ahk
#Include ..\Hotkey\HotKeyPlus.ahk
#Include ..\Util\WinEvent.ahk
#Include ..\Setting\KBLSwitchSetting.ahk

class KBLManager {
    static process := Map()
    static ProcessStates := Map()

    static Initialize(fps := 12) {
        KBLManager.ProcessStates := KBLManager.GetProcessesState()
        ; TODO 根据配置注册热键到 HotKeyPlus

        key := KBLSwitchSetting["LShift"].Key
        condition := KBLSwitchSetting["LShift"].Condition

        HotkeyPlus("~" key, (key) => KBLManager.NextKBL(key)
            , condition.NeedRelease, condition.HoldTime, condition.ReverseHold)

        key := KBLSwitchSetting["RShift"].Key
        condition := KBLSwitchSetting["RShift"].Condition

        HotkeyPlus("~" key, (key) => KBLManager.NextKBL(key)
            , condition.NeedRelease, condition.HoldTime, condition.ReverseHold)

        hWnd := WinGetID("A")
        SetTimer(() => KBLManager.OnWinActived(hWnd), -1) ; 手动触发一次当前窗口，防止漏过
        WinEvent.Active((h, w, d) => KBLManager.OnWinActived(w))
    }


    static GetProcessesState() {
        ; TODO 读取配置文件（单独设置的进程配置）
        return Map()
    }

    static OnWinActived(hWnd) {
        if (!WinExist(hWnd)) {
            ToolTip hWnd
            return
        }

        processName := WinGetProcessName(hWnd)

        if (!KBLManager.process.Has(processName))
            KBLManager.OnNewProcessDetected(processName, hWnd)

    }


    static OnNewProcessDetected(processName, hWnd) {
        state := KBLManager.GetProcessState(processName)

        ; 修改 process 的 KBL
        kbl := state.DefualtLayout
        KBLManager.process[processName] := 1
        KBLTool.SetKBL(hWnd, kbl.Name, kbl.State)

        ProcessWaitClose(processName)
        KBLManager.OnProcessExit(processName)
    }

    static OnProcessExit(processName) {
        KBLManager.process.Delete(processName)
        ;TODO 查询配置里有没有默认配置，有则还原，无则删除
        KBLManager.ProcessStates.Delete(processName)
    }

    static GetProcessState(processName) {
        ; 如果进程没有记录过则新建一个记录
        ; TODO 读取默认配置（没有配置使用的全局默认KBL）
        if (!KBLManager.ProcessStates.Has(processName))
            KBLManager.ProcessStates[processName] := ProcessState(processName, "zh-CN", 1025)

        return KBLManager.ProcessStates[processName]
    }

    static NextKBL(key) {
        hWnd := WinGetID("A")
        key := Trim(key, '~')
        SwitchSetting := KBLSwitchSetting[key]
        processName := WinGetProcessName(hWnd)
        processState := KBLManager.GetProcessState(processName)

        index := processState.PrevioursSwitch == key ? processState.PrevioursSwitchIndex : KBLManager.FindSimilarKBL(SwitchSetting.Layouts, hWnd)

        kblCapcity := SwitchSetting.Layouts.Length
        index := Mod(index, kblCapcity) + 1
        kbl := SwitchSetting[index].Name
        state := SwitchSetting[index].DefaultState

        processState.Update(key, index, kbl, state)
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