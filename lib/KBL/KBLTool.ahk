#Requires AutoHotkey v2.0

#Include KeyboardLayout.ahk

class KBLTool {
    static KBLCodes := Map()
    static ImmGetDefaultIMEWnd := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "imm32", "Ptr"), "AStr", "ImmGetDefaultIMEWnd", "Ptr") ; 获取 ImmGetDefaultIMEWnd 函数的指针
    static GetWindowThreadProcessId := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "User32", "Ptr"), "AStr", "GetWindowThreadProcessId", "Ptr")
    static GetKeyboardLayout := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "User32", "Ptr"), "AStr", "GetKeyboardLayout", "Ptr")
    static imm32 := DllCall("LoadLibrary", "Str", "imm32.dll", "Ptr")

    static Initialize() {
        KBLTool.KBLCodes := KBLTool.GetAllKBLs()
    }

    ; 获取支持的键盘布局
    static GetAllKBLs() {
        kblCodes := Map()
        errorCodes := Array()

        ; 从注册表查找已经安装的所有键盘布局
        loop reg, "HKEY_CURRENT_USER\Keyboard Layout\Preload", "V" {
            languageCode := RegRead()

            try {
                ; 查询键盘布局名字并添加进 KBLCodes
                key := KBLTool.LangIdToName(languageCode)
                kblCodes[key] := "0x" languageCode
            } catch {
                ; 如果出现了未知的键盘布局则记录下来
                errorCodes.Push(languageCode)
            }
        }

        ; 提示未知键盘
        if (errorCodes.Length > 0) {
            str := ""
            for code in errorCodes {
                str := str "`n" code
            }
            MsgBox("`n注册表 HKEY_CURRENT_USER\Keyboard Layout\Preload 中包含未知的键盘布局代码:" str " `n请将此错误提交至仓库 Issue。`n程序将在无视此键盘布局的情况下运行。", "未知的键盘布局代码", 32)
            ; TODO 自动打开 Issue 页面按钮
            ; TODO 提供按键忽略当前未知的键盘布局，下次在 Loop 时直接跳过
        }
        return kblCodes
    }

    ; 从当前窗口获取 IME 窗口句柄
    static GetIMEWinId(hWnd) {
        hWnd := KBLTool.CheckUWPWinId(hWnd)
        IMEWinId := DllCall(KBLTool.ImmGetDefaultIMEWnd, "Uint", hWnd, "Uint")
        return IMEWinId
    }

    static GetCurrentKBL(hWnd) {
        DetectHiddenWindows True
        ; 这里如果判断了UWP会导致调整日文键盘状态失败，虽然不明白为什么
        ; WinId := KBLTool.CheckUWPWinId(WinId)
        threadId := DllCall(KBLTool.GetWindowThreadProcessId, "Ptr", hWnd, "Uint", 0)
        kbl := DllCall(KBLTool.GetKeyboardLayout, "Uint", threadId, "UInt")

        imeWinId := KBLTool.GetIMEWinId(hWnd)
        state := SendMessage(0x283, 0x001, 0, , "ahk_id " DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hWnd, "Uint"))

        DetectHiddenWindows false

        name := KBLTool.LangIdToName(Format('0x{:08x}', kbl & 0x3FFF))
        return KeyboardLayout(name, state)
        ; return Format('0x{:08x}', kbl & 0x3FFF)
    }

    static LangIdToName(langId) =>
        KBLTool.%"_" StrReplace(langId, "0x")%


    static CheckUWPWinId(hWnd) {
        ; 如果是 UWP 则用另外的方法获取 ID
        if WinGetProcessName(hWnd) == "ApplicationFrameHost.exe" {
            childPID := ''

            pid := WinGetPID(hWnd)

            for c in WinGetControls(hWnd)
                DllCall(KBLTool.GetWindowThreadProcessId, "Ptr", c, "UintP", childPID)
            until childPID != pid

            ; DetectHiddenWindows true
            hWnd := WinExist("ahk_pid" childPID)
        }

        return hWnd
    }

    ; 设置键盘布局
    static SetKBL(hWnd, language, state := 0) {
        try {
            code := KBLTool.KBLCodes[language]
        } catch Error as e {
            MsgBox("未发现键盘布局" language " , 本机上似乎没有这个语言的键盘布局。", "未发现键盘布局", 16)
            throw e
        }

        hWnd := KBLTool.GetIMEWinId(hWnd)

        ;TODO 考虑自动上屏如何实现
        errorLever := SendMessage(0x50, , code, , hWnd, , , , 1000)

        ; 设置 IME 的状态
        if (errorLever != "FAIL") {
            Sleep(25)
            errorLevel := SendMessage(0x283, 0x002, state, , hWnd, , , , 1000)
            errorLevel := SendMessage(0x283, 0x006, state, , hWnd, , , , 1000)
        }
        return errorLever
    }
    ;TODO 指定要切换的 IME ，以便一个 KBL 中有不同的 IME 如 五笔与拼音

    static _00000036 := "af"
    static _00000436 := "af-ZA"
    static _0000001C := "sq"
    static _0000041C := "sq-AL"
    static _00000484 := "gsw-FR"
    static _0000005E := "am"
    static _0000045E := "am-ET"
    static _00000001 := "ar"
    static _00001401 := "ar-DZ"
    static _00003C01 := "ar-BH"
    static _00000C01 := "ar-EG"
    static _00000801 := "ar-IQ"
    static _00002C01 := "ar-JO"
    static _00003401 := "ar-KW"
    static _00003001 := "ar-LB"
    static _00001001 := "ar-LY"
    static _00001801 := "ar-MA"
    static _00002001 := "ar-OM"
    static _00004001 := "ar-QA"
    static _00000401 := "ar-SA"
    static _00002801 := "ar-SY"
    static _00001C01 := "ar-TN"
    static _00003801 := "ar-AE"
    static _00002401 := "ar-YE"
    static _0000002B := "hy"
    static _0000042B := "hy-AM"
    static _0000004D := "as"
    static _0000044D := "as-IN"
    static _0000002C := "az"
    static _0000742C := "az-Cyrl"
    static _0000082C := "az-Cyrl-AZ"
    static _0000782C := "az-Latn"
    static _0000042C := "az-Latn-AZ"
    static _00000045 := "bn"
    static _00000845 := "bn-BD"
    static _0000006D := "ba"
    static _0000046D := "ba-RU"
    static _0000002D := "eu"
    static _0000042D := "eu-ES"
    static _00000023 := "be"
    static _00000423 := "be-BY"
    static _00000445 := "bn-IN"
    static _0000781A := "bs"
    static _0000641A := "bs-Cyrl"
    static _0000201A := "bs-Cyrl-BA"
    static _0000681A := "bs-Latn"
    static _0000141A := "bs-Latn-BA"
    static _0000007E := "br"
    static _0000047E := "br-FR"
    static _00000002 := "bg"
    static _00000402 := "bg-BG"
    static _00000055 := "my"
    static _00000455 := "my-MM"
    static _00000003 := "ca"
    static _00000403 := "ca-ES"
    static _0000005F := "tzm"
    static _0000045F := "tzm-Arab-MA"
    static _00007C5F := "tzm-Latn"
    static _0000085F := "tzm-Latn-DZ"
    static _0000785F := "tzm-Tfng"
    static _0000105F := "tzm-Tfng-MA"
    static _00000092 := "ku"
    static _00007C92 := "ku-Arab"
    static _00000492 := "ku-Arab-IQ"
    static _0000005C := "chr"
    static _00007C5C := "chr-Cher"
    static _0000045C := "chr-Cher-US"
    static _00007804 := "zh"
    static _00000004 := "zh-Hans"
    static _00000804 := "zh-CN"
    static _00001004 := "zh-SG"
    static _00007C04 := "zh-Hant"
    static _00000C04 := "zh-HK"
    static _00001404 := "zh-MO"
    static _00000404 := "zh-TW"
    static _00000083 := "co"
    static _00000483 := "co-FR"
    static _0000001A := "hr"
    static _0000101A := "hr-BA"
    static _0000041A := "hr-HR"
    static _00000005 := "cs"
    static _00000405 := "cs-CZ"
    static _00000006 := "da"
    static _00000406 := "da-DK"
    static _00000065 := "dv"
    static _00000465 := "dv-MV"
    static _00000013 := "nl"
    static _00000813 := "nl-BE"
    static _00000413 := "nl-NL"
    static _00000C51 := "dz-BT"
    static _00000066 := "bin"
    static _00000466 := "bin-NG"
    static _00000009 := "en"
    static _00000C09 := "en-AU"
    static _00002809 := "en-BZ"
    static _00001009 := "en-CA"
    static _00002409 := "en-029"
    static _00003C09 := "en-HK"
    static _00004009 := "en-IN"
    static _00003809 := "en-ID"
    static _00001809 := "en-IE"
    static _00002009 := "en-JM"
    static _00004409 := "en-MY"
    static _00001409 := "en-NZ"
    static _00003409 := "en-PH"
    static _00004809 := "en-SG"
    static _00001C09 := "en-ZA"
    static _00002C09 := "en-TT"
    static _00004C09 := "en-AE"
    static _00000809 := "en-GB"
    static _00000409 := "en-US"
    static _00003009 := "en-ZW"
    static _00000025 := "et"
    static _00000425 := "et-EE"
    static _00000038 := "fo"
    static _00000438 := "fo-FO"
    static _00000064 := "fil"
    static _00000464 := "fil-PH"
    static _0000000B := "fi"
    static _0000040B := "fi-FI"
    static _0000000C := "fr"
    static _0000080C := "fr-BE"
    static _00002C0C := "fr-CM"
    static _00000C0C := "fr-CA"
    static _00001C0C := "fr-029"
    static _0000300C := "fr-CI"
    static _0000040C := "fr-FR"
    static _00003C0C := "fr-HT"
    static _0000140C := "fr-LU"
    static _0000340C := "fr-ML"
    static _0000180C := "fr-MC"
    static _0000380C := "fr-MA"
    static _0000200C := "fr-RE"
    static _0000280C := "fr-SN"
    static _0000100C := "fr-CH"
    static _0000240C := "fr-CD"
    static _00000067 := "ff"
    static _00007C67 := "ff-Latn"
    static _00000467 := "ff-Latn-NG"
    static _00000867 := "ff-Latn-SN"
    static _00000056 := "gl"
    static _00000456 := "gl-ES"
    static _00000037 := "ka"
    static _00000437 := "ka-GE"
    static _00000007 := "de"
    static _00000C07 := "de-AT"
    static _00000407 := "de-DE"
    static _00001407 := "de-LI"
    static _00001007 := "de-LU"
    static _00000807 := "de-CH"
    static _00000008 := "el"
    static _00000408 := "el-GR"
    static _00000074 := "gn"
    static _00000474 := "gn-PY"
    static _00000047 := "gu"
    static _00000447 := "gu-IN"
    static _00000068 := "ha"
    static _00007C68 := "ha-Latn"
    static _00000468 := "ha-Latn-NG"
    static _00000075 := "haw"
    static _00000475 := "haw-US"
    static _0000000D := "he"
    static _0000040D := "he-IL"
    static _00000039 := "hi"
    static _00000439 := "hi-IN"
    static _0000000E := "hu"
    static _0000040E := "hu-HU"
    static _00000069 := "ibb"
    static _00000469 := "ibb-NG"
    static _0000000F := "is"
    static _0000040F := "is-IS"
    static _00000070 := "ig"
    static _00000470 := "ig-NG"
    static _00000021 := "id"
    static _00000421 := "id-ID"
    static _0000005D := "iu"
    static _00007C5D := "iu-Latn"
    static _0000085D := "iu-Latn-CA"
    static _0000785D := "iu-Cans"
    static _0000045D := "iu-Cans-CA"
    static _0000003C := "ga"
    static _0000083C := "ga-IE"
    static _00000034 := "xh"
    static _00000434 := "xh-ZA"
    static _00000035 := "zu"
    static _00000435 := "zu-ZA"
    static _00000010 := "it"
    static _00000410 := "it-IT"
    static _00000810 := "it-CH"
    static _00000011 := "ja"
    static _00000411 := "ja-JP"
    static _0000006F := "kl"
    static _0000046F := "kl-GL"
    static _0000004B := "kn"
    static _0000044B := "kn-IN"
    static _00000071 := "kr"
    static _00000471 := "kr-Latn-NG"
    static _00000060 := "ks"
    static _00000460 := "ks-Arab"
    static _00001000 := "ks-Arab-IN"
    static _00000860 := "ks-Deva-IN"
    static _0000003F := "kk"
    static _0000043F := "kk-KZ"
    static _00000053 := "km"
    static _00000453 := "km-KH"
    static _00000087 := "rw"
    static _00000487 := "rw-RW"
    static _00000041 := "sw"
    static _00000441 := "sw-KE"
    static _00000057 := "kok"
    static _00000457 := "kok-IN"
    static _00000012 := "ko"
    static _00000412 := "ko-KR"
    static _00000040 := "ky"
    static _00000440 := "ky-KG"
    static _00000086 := "quc"
    static _00007C86 := "quc-Latn"
    static _00000486 := "quc-Latn-GT"
    static _00000054 := "lo"
    static _00000454 := "lo-LA"
    static _00000076 := "la"
    static _00000476 := "la-VA"
    static _00000026 := "lv"
    static _00000426 := "lv-LV"
    static _00000027 := "lt"
    static _00000427 := "lt-LT"
    static _00007C2E := "dsb"
    static _0000082E := "dsb-DE"
    static _0000006E := "lb"
    static _0000046E := "lb-LU"
    static _0000002F := "mk"
    static _0000042F := "mk-MK"
    static _0000003E := "ms"
    static _0000083E := "ms-BN"
    static _0000043E := "ms-MY"
    static _0000004C := "ml"
    static _0000044C := "ml-IN"
    static _0000003A := "mt"
    static _0000043A := "mt-MT"
    static _00000058 := "mni"
    static _00000458 := "mni-IN"
    static _00000081 := "mi"
    static _00000481 := "mi-NZ"
    static _0000007A := "arn"
    static _0000047A := "arn-CL"
    static _0000004E := "mr"
    static _0000044E := "mr-IN"
    static _0000007C := "moh"
    static _0000047C := "moh-CA"
    static _00000050 := "mn"
    static _00007850 := "mn-Cyrl"
    static _00000450 := "mn-MN"
    static _00007C50 := "mn-Mong"
    static _00000850 := "mn-Mong-CN"
    static _00000C50 := "mn-Mong-MN"
    static _00000061 := "ne"
    static _00000861 := "ne-IN"
    static _00000461 := "ne-NP"
    static _0000003B := "se"
    static _00000014 := "no"
    static _00007C14 := "nb"
    static _00000414 := "nb-NO"
    static _00007814 := "nn"
    static _00000814 := "nn-NO"
    static _00000082 := "oc"
    static _00000482 := "oc-FR"
    static _00000048 := "or"
    static _00000448 := "or-IN"
    static _00000072 := "om"
    static _00000472 := "om-ET"
    static _00000079 := "pap"
    static _00000479 := "pap-029"
    static _00000063 := "ps"
    static _00000463 := "ps-AF"
    static _00000029 := "fa"
    static _0000008C := "fa"
    static _0000048C := "fa-AF"
    static _00000429 := "fa-IR"
    static _00000015 := "pl"
    static _00000415 := "pl-PL"
    static _00000016 := "pt"
    static _00000416 := "pt-BR"
    static _00000816 := "pt-PT"
    static _000005FE := "qps-ploca"
    static _000009FF := "qps-plocm"
    static _00000901 := "qps-Latn-x-sh"
    static _00000501 := "qps-ploc"
    static _00000046 := "pa"
    static _00007C46 := "pa-Arab"
    static _00000446 := "pa-IN"
    static _00000846 := "pa-Arab-PK"
    static _0000006B := "quz"
    static _0000046B := "quz-BO"
    static _0000086B := "quz-EC"
    static _00000C6B := "quz-PE"
    static _00000018 := "ro"
    static _00000818 := "ro-MD"
    static _00000418 := "ro-RO"
    static _00000017 := "rm"
    static _00000417 := "rm-CH"
    static _00000019 := "ru"
    static _00000819 := "ru-MD"
    static _00000419 := "ru-RU"
    static _00000085 := "sah"
    static _00000485 := "sah-RU"
    static _0000703B := "smn"
    static _00007C3B := "smj"
    static _0000743B := "sms"
    static _0000783B := "sma"
    static _0000243B := "smn-FI"
    static _0000103B := "smj-NO"
    static _0000143B := "smj-SE"
    static _00000C3B := "se-FI"
    static _0000043B := "se-NO"
    static _0000083B := "se-SE"
    static _0000203B := "sms-FI"
    static _0000183B := "sma-NO"
    static _00001C3B := "sma-SE"
    static _0000004F := "sa"
    static _0000044F := "sa-IN"
    static _00000091 := "gd"
    static _00000491 := "gd-GB"
    static _00007C1A := "sr"
    static _00006C1A := "sr-Cyrl"
    static _00001C1A := "sr-Cyrl-BA"
    static _0000301A := "sr-Cyrl-ME"
    static _00000C1A := "sr-Cyrl-CS"
    static _0000281A := "sr-Cyrl-RS"
    static _0000701A := "sr-Latn"
    static _0000181A := "sr-Latn-BA"
    static _00002C1A := "sr-Latn-ME"
    static _0000081A := "sr-Latn-CS"
    static _0000241A := "sr-Latn-RS"
    static _00000030 := "st"
    static _00000430 := "st-ZA"
    static _0000006C := "nso"
    static _0000046C := "nso-ZA"
    static _00000032 := "tn"
    static _00000832 := "tn-BW"
    static _00000432 := "tn-ZA"
    static _00000059 := "sd"
    static _00007C59 := "sd-Arab"
    static _00000459 := "sd-Deva-IN"
    static _00000859 := "sd-Arab-PK"
    static _0000005B := "si"
    static _0000045B := "si-LK"
    static _0000001B := "sk"
    static _0000041B := "sk-SK"
    static _00000024 := "sl"
    static _00000424 := "sl-SI"
    static _00000077 := "so"
    static _00000477 := "so-SO"
    static _0000000A := "es"
    static _00002C0A := "es-AR"
    static _0000400A := "es-BO"
    static _0000340A := "es-CL"
    static _0000240A := "es-CO"
    static _0000140A := "es-CR"
    static _00005C0A := "es-CU"
    static _00001C0A := "es-DO"
    static _0000300A := "es-EC"
    static _0000440A := "es-SV"
    static _0000100A := "es-GT"
    static _0000480A := "es-HN"
    static _0000580A := "es-419"
    static _0000080A := "es-MX"
    static _00004C0A := "es-NI"
    static _0000180A := "es-PA"
    static _00003C0A := "es-PY"
    static _0000280A := "es-PE"
    static _0000500A := "es-PR"
    static _00000C0A := "es-ES"
    static _0000040A := "es-ES_tradnl"
    static _0000540A := "es-US"
    static _0000380A := "es-UY"
    static _0000200A := "es-VE"
    static _0000001D := "sv"
    static _0000081D := "sv-FI"
    static _0000041D := "sv-SE"
    static _00000084 := "gsw"
    static _0000005A := "syr"
    static _0000045A := "syr-SY"
    static _00000028 := "tg"
    static _00007C28 := "tg-Cyrl"
    static _00000428 := "tg-Cyrl-TJ"
    static _00000049 := "ta"
    static _00000449 := "ta-IN"
    static _00000849 := "ta-LK"
    static _00000044 := "tt"
    static _00000444 := "tt-RU"
    static _0000004A := "te"
    static _0000044A := "te-IN"
    static _0000001E := "th"
    static _0000041E := "th-TH"
    static _00000051 := "bo"
    static _00000451 := "bo-CN"
    static _00000073 := "ti"
    static _00000873 := "ti-ER"
    static _00000473 := "ti-ET"
    static _0000001F := "tr"
    static _0000041F := "tr-TR"
    static _00000042 := "tk"
    static _00000442 := "tk-TM"
    static _00000022 := "uk"
    static _00000422 := "uk-UA"
    static _0000002E := "hsb"
    static _0000042E := "hsb-DE"
    static _00000020 := "ur"
    static _00000820 := "ur-IN"
    static _00000420 := "ur-PK"
    static _00000080 := "ug"
    static _00000480 := "ug-CN"
    static _00000043 := "uz"
    static _00007843 := "uz-Cyrl"
    static _00000843 := "uz-Cyrl-UZ"
    static _00007C43 := "uz-Latn"
    static _00000443 := "uz-Latn-UZ"
    static _00000803 := "ca-ES-valencia"
    static _00000033 := "ve"
    static _00000433 := "ve-ZA"
    static _0000002A := "vi"
    static _0000042A := "vi-VN"
    static _00000052 := "cy"
    static _00000452 := "cy-GB"
    static _00000062 := "fy"
    static _00000462 := "fy-NL"
    static _00000088 := "wo"
    static _00000488 := "wo-SN"
    static _00000031 := "ts"
    static _00000431 := "ts-ZA"
    static _00000078 := "ii"
    static _00000478 := "ii-CN"
    static _0000003D := "yi"
    static _0000043D := "yi-001"
    static _0000006A := "yo"
    static _0000046A := "yo-NG"

}