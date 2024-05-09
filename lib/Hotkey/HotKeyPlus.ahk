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

        this.mainKeys := this.ParseMainKeys(mainKeys)
        Hotkey(key, (_) => this.CheckCondition(), options)
    }

    ParseMainKeys(mainKeys := "") {
        ; 从字符串中解析按键
        spliteKeys := mainKeys == "" ? HotKeyPlus.SplitKeys(this.Key) : HotKeyPlus.SplitKeys(mainKeys)
        ;如果是 Release 则获取主键
        if (this.needRelease) {
            return spliteKeys[-1]
        }
        ;否则获取所有按键
        return spliteKeys
    }

    ; 对单个修饰键作为主键的情况，不会正常等待release
    CheckCondition() {
        this.GUID := CreateGUID()
        this.lWin := GetKeyState("LWin", "P")
        this.rWin := GetKeyState("RWin", "P")

        this.taskState := "Waitting"

        ; 只有 HoldTime > 0 （long_press long_release short_press）才需要在这里等待判断成功或失败
        ; 不限时的 Release 在 Timeout 中自动成功
        if (this.holdTime > 0) {
            guid := this.GUID
            ;
            SetTimer(Timeout, -this.holdTime)
            if (this.reverseHold) {
                ; 反转的情况是限时释放，需要所有必要按键都释放才算成功
                ; 而等到 Timeout 则会失败
                this.WaitKeyRelease(this.mainKeys, "All")
                this.UpdateState("Successed")
            } else {
                ; 非反转的情况等到 Timeout 算成成功
                ; 但如果此前从开了任意必要按键，则会失败
                this.WaitKeyRelease(this.mainKeys, "Any")
                this.UpdateState("Canceled")
            }
        } else
            this.Timeout()

        Timeout() {
            () => this.Timeout(guid)
        }
    }

    Timeout(guid := "") {
        ; 由于 Timeout 不会自动取消，所以需要检测 GUID 判断是否已经失效
        if (guid != this.GUID)
            return

        if (this.needRelease && this.reverseHold) {
            this.UpdateState("Canceled")
            ; MsgBox("超时咯！")
            return
        }

        if (this.needRelease) {
            this.WaitKeyRelease(this.mainKeys, "All")
        }

        this.UpdateState("Successed")
    }

    ; 在可更新的状况下更新状态，并处理回调
    UpdateState(newState) {
        if (this.taskState != "Waitting")
            return

        this.taskState := newState

        if (newState == "Successed") {
            excute := this.callBack
            excute()
            ; 回调后还要防止重复触发，需要在 press 的情况下再等待一次任意键弹起
            if (!this.needRelease) {
                this.WaitKeyRelease(this.mainKeys, "Any")
            }
        }

    }

    ; 等待按键释放
    ; keys: 按键列表
    ; option: 选项
    ; "Any" - 任意按键释放
    ; "All" - 所有按键释放
    WaitKeyRelease(keys, option := "All") {
        ; 如果是单键，转换成数组才能 for
        if (Type(keys) == "String")
            keys := [keys]

        while (true) {
            shouldRelease := option != "Any" ; 不为 Any 时才能初始为 true
            for k in keys {
                if (option == "Any") {
                    if (k == "Win")
                        isKeyUp := !(this.lWin && GetKeyState("LWin"))
                            && !(this.rWin && GetKeyState("RWin"))
                    else
                        isKeyUp := !GetKeyState(k)

                    if isKeyUp {
                        ; any 时，只要检测到任意一个键没有按下，就 break
                        shouldRelease := true
                        break
                    }
                }
                ; All 则要保证所有按键都释放
                shouldRelease := shouldRelease && !GetKeyState(k)
            }
            if (shouldRelease)
                break
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