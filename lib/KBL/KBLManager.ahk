#Requires AutoHotkey v2.0

#Include KBLTool.ahk
#Include ProcessState.ahk
#Include ..\Gui\ToolTip.ahk
#Include ..\Hotkey\HotKeyPlus.ahk
#Include ..\Util\WinEvent.ahk
#Include ..\Util\OnProcessClose.ahk
#Include ..\Setting\KBLSwitchSetting.ahk
#Include ..\Setting\ProcessSetting.ahk
#Include ..\Setting\GlobalSetting.ahk

class KBLManager {
    static RunningProcessData := Map()
    static RunningProcessStates := Map()
    static RunningProcessSettings := Map()
    static PreviousState := 0
    static GlobalState := 0
    ; static selfPID := A_PID


    static Initialize() {
        KBLManager.GlobalState := ProcessState("Global", GlobalSetting.DefualtKBL.Name, GlobalSetting.DefualtKBL.ImeState, GlobalSetting.DefualtKBL.ChangeStateDelay, false)
        KBLManager.RegisterHotkeys()
        KBLManager.RegisterWindowHook()
    }

    ;这个似乎不会卡住，用这个来触发
    static RegisterWindowHook() {
        ; 已经激活的窗口不会触发回调，需要手动触发一次
        try OnActive(0, WinGetID("A"), 0)
        WinEvent.Active(OnActive)

        OnActive(hook, hWnd, dwmsEventTime) {
            ; 防止瞬间就被关闭的窗口触发后续代码
            if (!WinExist(hWnd))
                return

            pid := WinGetPID(hWnd)

            KBLManager.OnWinActived(hWnd)
        }
    }

    static RegisterHotkeys() {
        for i, s in KBLSwitchSetting.KBLSwitchSettings {
            key := s.Key
            condition := s.Condition
            HotkeyPlus("~" key, NextKBL, condition.NeedRelease, condition.HoldTime, condition.ReverseHold)
        }
        HotKey("~CapsLock", OnCapsLockToggled)

        OnCapsLockToggled(_) {
            try KBLManager.OnCapsLockToggled()
        }

        NextKBL(key) {
            KBLManager.NextKBL(key)
        }
    }

    static CapsLockHolding := 0
    static OnCapsLockToggled() {
        if (!GlobalSetting.RememberCaps || KBLManager.CapsLockHolding)
            return

        hWnd := Util.WinGetID("A")

        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name, &pid))
            return

        _processState := KBLManager.PreviousState
        startTick := A_TickCount
        while (true) {
            isCapsLockOn := GetKeyState("CapsLock", "T")
            if isCapsLockOn != _processState.CurrentLayout.CapsLockState
                break
            Sleep(1000 / 60)
            if (A_TickCount - startTick > 500)
                break
        }


        if (ToolTipSetting.EnableOnManualSwitched && _processState.CurrentLayout.CapsLockState != isCapsLockOn) {
            _processState.CurrentLayout.CapsLockState := isCapsLockOn
            ToolTipPlus(_processState.CurrentLayout.Name, _processState.CurrentLayout.ImeState, isCapsLockOn)
        }

        ; 循环检测释放，允许下次按下 CapsLock 生效
        SetTimer(WaitForRelease, 1000 / 60)
        WaitForRelease() {
            if (!GetKeyState("CapsLock", "P")) {
                SetTimer(WaitForRelease, 0)
                KBLManager.CapsLockHolding := 0
            }
        }

    }

    ; 读取进程的配置
    static ReadProcessSetting(pid, path, name) {
        ; 如果没有缓存，则从配置文件中读取
        if (!KBLManager.RunningProcessSettings.Has(pid) || !KBLManager.RunningProcessSettings[pid]) {
            KBLManager.RunningProcessSettings[pid] := ProcessSetting.ProcessSettings.Has(path)
                ? ProcessSetting[path]
                : (ProcessSetting.ProcessSettings.Has(name)
                    ? ProcessSetting[name]
                        : 0)
        }

        _processSetting := KBLManager.RunningProcessSettings[pid]
        return _processSetting
    }

    static OnWinActived(hWnd) {
        hWnd := Util.FixUWPWinID(hWnd)
        if (!KBLManager.GetWinProperties(hWnd, &winTitle, &path, &name, &pid))
            return

        OutputDebug("[ACTIVATED] winTitle: " winTitle " | class: " WinGetClass(hWnd) " | ID: " hWnd " | process: " name " | path: " path " | pid: " pid "`n")
        _processSetting := KBLManager.ReadProcessSetting(pid, path, name)

        ; 获取该窗口对应的状态是否已经存在
        result := KBLManager.TryGetState(pid, winTitle, _processSetting, &state, &regEx)
        if (!result)
            KBLManager.CreateState(pid, path, name, hWnd, winTitle, _processSetting, regEx)
        else {
            ; 如果 processState 没有变化，则不做任何处理
            if (state == KBLManager.PreviousState)
                return
            if (!GlobalSetting.StandAlong)
                KBLManager.MakePreviousStateNotGlobal()
            if (KBLManager.CheckIfNeedKeepStateValue(hWnd)) {
                OutputDebug("[ACTIVATED] 窗口 " winTitle " 位于 TrayWnd 配置中，状态复制上一个状态的值。`n")
                state.CurrentLayout := KBLManager.PreviousState.CurrentLayout.Clone()
                return
            }
            delay := state.CurrentLayout.ChangeStateDelay >= 0 ? state.CurrentLayout.ChangeStateDelay : GlobalSetting.Delay
            ; AlwaysRecorveToDefault 时，自动恢复到默认状态，并根据配置解除大写锁定
            if (state.AlwaysRecorveToDefault) {
                OutputDebug("RecoverToDefualtValue")
                capslockState := state.CurrentLayout.CapsLockState
                state.RecoverToDefualtValue()
                KBLTool.SetKBL(hWnd, state.CurrentLayout.Name, state.CurrentLayout.ImeState, delay)
                if (GlobalSetting.CleanCapsOnRecovered)
                    SetCapsLockState("Off")
                else {
                    ; 如果不需要接触大写锁定，则恢复之前的状态
                    SetCapsLockState(capslockState ? "On" : "Off")
                    state.CurrentLayout.CapsLockState := capslockState
                }
                showToolTip := ToolTipSetting.EnableOnRecoverd
            } else {
                ; if (name == "explorer.exe")
                ;     Sleep(100)

                KBLTool.SetKBL(hWnd, state.CurrentLayout.Name, state.CurrentLayout.ImeState, delay)
                SetCapsLockState(state.CurrentLayout.CapsLockState ? "On" : "Off")
                showToolTip := ToolTipSetting.EnableOnAutoSwitched
            }
            ; 当 CapsLock 与 KBL 有其一发生变化时，显示 ToolTipPlus 并改变任务栏图标
            if (showToolTip && KBLManager.PreviousState && !state.CompareStateWith(KBLManager.PreviousState))
                ToolTipPlus(state.CurrentLayout.Name, state.CurrentLayout.ImeState, state.CurrentLayout.CapsLockState)

            KBLManager.PreviousState := state
            return
        }
    }

    ; 创建该进程\窗口的状态
    static CreateState(pid, path, name, hWnd, winTitle, _processSetting, regEx) {

        ; 如果之前没有运行过该进程，则新建一个 ProcessState
        if (!KBLManager.RunningProcessData.Has(pid)) {
            OnProcessClose(pid, (proc, *) => KBLManager.OnProcessExit(proc.ID))

            KBLManager.RunningProcessData[pid] := Map()
            ; 先从进程的状态开始创建，并根据是否全局设置其 CurrentLayout 是否引用 GlobalState
            ; 没有 _processSetting 代表进程与窗口都没有配置，此时应该使用视独立与否决定使用 GLobalSetting.DefualtKBL 还是 GlobalState 的 CurentLayout
            if (_processSetting)
                KBLManager.RunningProcessStates[pid] := ProcessState(pid, _processSetting.DefaultKBL.Name, _processSetting.DefaultKBL.ImeState, _processSetting.DefaultKBL.ChangeStateDelay, _processSetting.AlwaysRecorveToDefault)
            else
                KBLManager.RunningProcessStates[pid] := ProcessState(pid, GlobalSetting.DefualtKBL.Name, GlobalSetting.DefualtKBL.ImeState, GlobalSetting.DefualtKBL.ChangeStateDelay, false)

            state := KBLManager.RunningProcessStates[pid]
            KBLManager.RefGlobalState(&state, _processSetting)
            ; 没有运行过的进程，一定会恢复默认状态，所以要恢复大写锁定
            if (GlobalSetting.CleanCapsOnRecovered) {
                state.CurrentLayout.CapsLockState := 0
            }
        }

        state := KBLManager.RunningProcessStates[pid]
        _runningProcess := KBLManager.RunningProcessData[pid]

        ; 如果有配置，查询一下配置中是否含有窗口正则
        if (_processSetting) {
            _runningProcess[winTitle] := regEx

            ; 如果匹配到正则表达式，则新建该正则的 ProcessState
            if (regEx) {
                if (state.TryGetRegExState(regEx, &_regExState)) {
                    throw "意外的错误：正则 " regEx " 在 pid " pid " 的状态中已存在，不应该进入 CreateState 才对！"
                }
                ; 读取正则的 Setting，并以创建 regExState
                _processSetting := _processSetting.RegExSettings[regEx]
                _regExState := ProcessState(regEx, _processSetting.DefaultKBL.Name, _processSetting.DefaultKBL.ImeState, _processSetting.DefaultKBL.ChangeStateDelay, _processSetting.AlwaysRecorveToDefault)
                state.AddRegExState(_regExState)
                state := _regExState
                KBLManager.RefGlobalState(&_regExState, _processSetting)
                ; 没有运行过的进程，一定会恢复默认状态，所以要恢复大写锁定
                if (GlobalSetting.CleanCapsOnRecovered) {
                    state.CurrentLayout.CapsLockState := 0
                }
            }
        }

        if (KBLManager.CheckIfNeedKeepStateValue(hWnd)) {
            OutputDebug("[CreateState] 窗口 " winTitle " 位于 TrayWnd 配置中，状态不使用默认值而改为复制上一个状态的值。`n")
            state.CurrentLayout := KBLManager.PreviousState.CurrentLayout.Clone()
            return
        }

        ; 修改键盘布局到当前的 state 的 CurrentLayout
        kbl := state.CurrentLayout
        delay := kbl.ChangeStateDelay >= 0 ? kbl.ChangeStateDelay : GlobalSetting.Delay

        KBLTool.SetKBL(hWnd, kbl.Name, kbl.ImeState, delay)
        SetCapsLockState(kbl.CapsLockState ? "On" : "Off")

        ; 如果这是第一个状态，或者状态与此前数值不同（键盘布局、状态值、大写锁定），则触发 ToolTip
        if (!KBLManager.PreviousState || !state.CompareStateWith(KBLManager.PreviousState)) {
            ToolTipPlus(kbl.Name, kbl.ImeState, kbl.CapsLockState)
        }
        KBLManager.PreviousState := state

    }

    static CheckIfNeedKeepStateValue(hWnd) {
        temp := A_DetectHiddenWindows
        A_DetectHiddenWindows := true
        ; 问题在于 Win11的 开始 和 搜索 两个菜单。当 打开开始时，会激活搜索，但是 WinExist 中不存在 搜索
        ; 所以主动激活，让其存在
        ; 如果主动激活可能会导致 Settings 窗口被激活时激活其他窗口 导致无法在非激活状态关闭 Settings
        if (!WinActive(hWnd) && WinGetProcessName(hWnd) != "SystemSettings.exe") 
            WinActivate(hWnd)
        
        result := WinExist("ahk_id" hWnd " ahk_group TrayWnd")
        A_DetectHiddenWindows := temp

        return result
    }

    ; 查询窗口在进程的设置中匹配的正则
    static WhichRegExCanMatchTitle(setting, winTitle) {
        if (setting && setting.SortedRegExSetting) {
            i := setting.SortedRegExSetting.Length
            while (i > 0) {
                regex := setting.SortedRegExSetting[i].Title
                if (RegExMatch(winTitle, regex))
                    return regex
                i--
            }
        }
        return 0
    }

    ; 让 state 的 CurrentLayout 引用 GlobalState 的 CurrentLayout
    static RefGlobalState(&state, setting) {
        if (!GlobalSetting.StandAlong) {
            ; 只要是全局模式，把 CurrentLayout 设为 Global 的引用
            state.CurrentLayout := KBLManager.GlobalState.CurrentLayout
            ; 通过是否有 Setting 以及 Setting 是否有 DefualtKBL 来判断是否应该还原到默认状态
            if (setting && setting.DefaultKBL) {
                KBLManager.MakePreviousStateNotGlobal()
                state.CurrentLayout.Set(setting.DefaultKBL.Name, setting.DefaultKBL.ImeState)
            }
        }
    }

    ; 在全局模式下，由于所有进程都是相同的 CurrentLayout 引用，所以没有办法对比数值，使用该方法可以把当前的 PreviousState 的 CurrentLayout 提取出来，变成另一个 State 用于比较
    static MakePreviousStateNotGlobal() {
        if (KBLManager.PreviousState) {
            temp := KBLManager.PreviousState.CurrentLayout.Clone()
            KBLManager.PreviousState := ProcessState("Temp", 0, 0, 0, 0)
            KBLManager.PreviousState.CurrentLayout := temp
        }
    }

    static OnProcessExit(pid) {
        ; 如未开启退出清理则当作没有退出
        OutputDebug("[Exit] pid: " pid "`n")
        if (!GlobalSetting.CleanOnProcessExit)
            return
        ; BUG 有可能会不存在该 key 的元素(已修复 待验证)
        KBLManager.RunningProcessData.Delete(pid)
        KBLManager.RunningProcessStates.Delete(pid)
        OutputDebug("[Clean Data] pid: " pid "`n")
    }

    static GetWinProperties(hWnd, &winTitle?, &processPath?, &processName?, &pid?) {
        if (!WinExist(hWnd))
            return false
        winTitle := WinGetTitle(hWnd)
        processName := WinGetProcessName(hWnd)
        processPath := WinGetProcessPath(hWnd)
        pid := WinGetPID(hWnd)

        return hWnd
    }

    ; 获取状态
    static TryGetState(pid, winTitle, setting := 0, &state?, &regEx?) {
        regEx := 0
        ; 如果进程没有运行直接返回 false
        if (!KBLManager.RunningProcessData.Has(pid)) {
            regEx := KBLManager.WhichRegExCanMatchTitle(setting, winTitle)
            return false
        }

        if (!KBLManager.RunningProcessStates.Has(pid))
            throw "意外的错误：RunningProcess 中含有 pid " pid " ，`n但 ProcessStates 中没有！"

        state := KBLManager.RunningProcessStates[pid]

        ; 如果 不存在 setting 或者 setting 中没有 RegExSettings，说明没有正则，直接返回 true
        if (!setting || !setting.RegExSettings)
            return true

        _runningProcess := KBLManager.RunningProcessData[pid]
        if (_runningProcess.Has(winTitle)) {
            ; 记录过的窗口，从进程状态中获取正则状态（不应该获取不到，如果获取不到是意外的错误）
            if (!state.TryGetRegExState(_runningProcess[winTitle], &state))
                throw "意外的错误：RunningProcess 记录的正则 " _runningProcess[winTitle] " 在 pid " pid " 的状态中不存在！"
        } else {
            ; 如果没有记录过，判断一下其是否属于某个已经新建过状态的正则，是则返回正则状态
            regEx := KBLManager.WhichRegExCanMatchTitle(setting, winTitle)
            _runningProcess[winTitle] := regEx
            return state.TryGetRegExState(regEx, &state)
        }

        return true
    }

    static NextKBL(hotkey, hWnd := 0, _processState := 0) {
        if (!hWnd)
            hWnd := Util.WinGetID("A")

        ; 任务栏无法切换，所以不要白费功夫了
        ; if (WinActive("ahk_class Shell_TrayWnd ahk_exe explorer.exe")) {
        ;     OutputDebug("[NextKBL] Ignore: 因 API 限制，在任务栏中无法正常工作。 hotkey: " hotkey "`n")
        ;     return
        ; }

        hotkey := Trim(hotkey, '~')
        SwitchSetting := KBLSwitchSetting[hotkey]

        if (!_processState) {
            pid := WinGetPID(hWnd)
            winTitle := WinGetTitle(hWnd)
            setting := KBLManager.ReadProcessSetting(pid, WinGetProcessPath(hWnd), WinGetProcessName(hWnd))
            result := KBLManager.TryGetState(pid, winTitle, setting, &_processState, &regEx)
            ; 一般来说触发 NextKBL 时，窗口应该已经存在了。但是考虑到 AHK 的蜜汁线程问题，这里还是判断一下是否有漏网之鱼
            ; if (!result) {
            ;     path := WinGetProcessPath(hWnd)
            ;     name := WinGetProcessName(hWnd)
            ;     _processState := KBLManager.CreateState(pid, path, name, hWnd, winTitle, setting, regEx)
            ; }
            ; 保险起见，还是不应该处理，直接卡掉输入最好
            if (!result) {
                OutputDebug("[NextKBL] Ignore: 当前窗口还为触发 OnWinActived 回调。 hotkey: " hotkey "`n")
                return
            }
        }

        ; 无论是否有记录的索引都要先判断一下，防止被其他方式修改过输入法
        ; BUG 因为微软 API 的 BUG （特性？），有时候 ImeState 的值与实际输入法的状态不同，所以可能会造成误判。暂时没有办法解决。
        currentKBL := KBLTool.GetCurrentKBL(hWnd)
        if (_processState.CurrentLayout.PrevioursSwitch == hotkey) {
            index := _processState.CurrentLayout.PrevioursSwitchIndex
            indexKBL := SwitchSetting.Layouts[index]
            if (currentKBL.Name == indexKBL.Name && currentKBL.ImeState == indexKBL.ImeState)
                OutputDebug("[NextKBL] 继续使用上一次的切换方案 " hotkey " ，成功获取到当前索引 " index " 。`n")
            else
                index := KBLManager.FindSimilarKBL(currentKBL, SwitchSetting.Layouts, hWnd)
            OutputDebug("[NextKBL] 继续使用上一次的切换方案 " hotkey " ，但当前索引 " index " 与当前输入法不匹配，重新获取近似索引 " index " 。`n")
        } else {
            index := KBLManager.FindSimilarKBL(currentKBL, SwitchSetting.Layouts, hWnd)
            OutputDebug("[NextKBL] " hotkey " 与上次切换方案不同，获取近似键盘布局索引为 " index " 。`n")
        }
        ; 切换到下一个键盘布局
        kblCapcity := SwitchSetting.Layouts.Length
        index := Mod(index, kblCapcity) + 1
        kbl := SwitchSetting.Layouts[index].Name
        imeState := SwitchSetting.Layouts[index].ImeState
        delay := SwitchSetting.Layouts[index].ChangeStateDelay >= 0 ? SwitchSetting.Layouts[index].ChangeStateDelay : GlobalSetting.Delay

        _processState.Update(hotkey, index, kbl, imeState, delay)
        KBLTool.SetKBL(hWnd, kbl, imeState, delay)
        OutputDebug("[NextKBL] 切换到切换方案 " hotkey " 的第 " index " 个键盘布局 " kbl " ，状态 " imeState " 。`n")

        if (GlobalSetting.CleanCapsOnSwitched) {
            _processState.CurrentLayout.CapsLockState := 0
            SetCapsLockState("Off")
            OutputDebug("[NextKBL] 清除大写锁定。`n")
        }

        if (ToolTipSetting.EnableOnManualSwitched)
            ToolTipPlus(kbl, imeState, _processState.CurrentLayout.CapsLockState)
    }

    static FindSimilarKBL(kbl, layouts, hWnd) {
        try {
            name := kbl.Name
            imeState := kbl.ImeState

            mostSimilar := 1
            for i, layout in layouts {
                if layout.Name == name {
                    if (mostSimilar == 1)
                        mostSimilar := i
                    if (imeState == layout.ImeState)
                        return i
                }
            }
            return mostSimilar
        }
        return 1
    }

}