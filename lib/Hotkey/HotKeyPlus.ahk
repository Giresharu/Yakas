#Include ..\Util\Guid.ahk

class HotKeyPlus {
    ; 创建一个包含长按/释放功能的热键
    ; key: 热键的字符串表示，由多个修饰键以及一个主键
    ; callBack: 热键触发时的回调函数
    ; needRelease: 是否需要释放按键才触发
    ; holdTime: 长按时间，单位毫秒，0 表示不限长按
    ; reverseHold: 反转长按，仅限短按不超时生效
    ; mainKeys: 表示影响长按判断的主要按键，在 release 的情况下默认为主键， press 的情况默认为所有按键
    ; options: 热键的选项
    __New(key, callBack, needRelease := false, holdTime := 0, reverseHold := false, mainKeys := "", options := "") {
        this.Key := key
        this.callBack := callBack
        this.needRelease := needRelease
        this.holdTime := holdTime
        this.reverseHold := reverseHold
        this.hook := InputHook('VT' holdTime / 1000)
        this.taskState := ""

        this.mainKeys := this.ParseMainKeys(mainKeys)
        ; Hotkey(key, (_) => this.CheckCondition(), options)
        Hotkey(key, (_) => this.OnPressed(), options)
        if (needRelease || holdTime > 0)
            Hotkey((mainKeys == "" ? key : mainKeys) " Up", (_) => this.OnReleased(), options)
    }

    OnPressed() {
        ; 防止长按时重复触发
        if (this.taskState == "Waitting")
            return

        this.taskState := "Waitting"

        ; press 或者 release 不需要处理后面的 hook
        if (this.holdTime <= 0) {
            ; press 直接触发
            if (!this.needRelease)
                this.UpdateState("Successed")

            return
        }

        this.hook.Start()
        this.hook.Wait()

        ; long_press
        if (!this.needRelease && this.hook.EndReason == "Timeout") {
            this.UpdateState("Successed")
        }
    }

    OnReleased() {
        ; 如果有其他主键在这个过程中被按下则不触发
        if (this.mainKeys[-1] != A_PriorKey)
            return

        ; release 直接触发
        if (this.holdTime <= 0) {
            this.UpdateState("Successed")
            return
        }

        ; 超时判断是否反转
        isSuccessed := this.reverseHold && this.hook.EndReason != "Timeout"
            || !this.reverseHold && this.hook.EndReason == "Timeout"

        this.UpdateState(isSuccessed ? "Successed" : "Canceled")
        this.hook.Stop()
    }

    ParseMainKeys(mainKeys := "") {
        ; 从字符串中解析按键
        spliteKeys := mainKeys == "" ? HotKeyPlus.SplitKeys(this.Key) : HotKeyPlus.SplitKeys(mainKeys)
        ;如果是 Release 则获取主键
        if (this.needRelease) {
            return [spliteKeys[-1]]
        }
        ;否则获取所有按键
        return spliteKeys
    }

    ; 在可更新的状况下更新状态，并处理回调
    UpdateState(newState) {
        if (this.taskState != "Waitting")
            return

        this.taskState := newState

        if (newState == "Successed") {
            excute := this.callBack
            excute()
        }

    }

    static SplitKeys(key) {
        arr := []

        ; key的格式为 N个修饰符与一个主键结合，其中修饰符可能有<或者>标注
        Util.RegExMatch(key, "(<|>)?(\+|\^|\#|\!)", &matches, &groups)
        for e in groups {
            prefix := e[1] != "" ? KBLSwitcherSetting.MarkToModifier[e[1]] : ""
            modifier := prefix KBLSwitcherSetting.MarkToModifier[e[2]]
            arr.Push(modifier)
        }

        RegExMatch(key, "\w+$", &matches)
        arr.Push(matches[0])

        return arr
    }
}