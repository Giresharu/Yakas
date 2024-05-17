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
            ; 有的输入法前 4 位字符可能不是 0000，导致识别不到语言，应该替换成 0000
            languageCode := SubStr(RegRead(), 5)
            try {
                ; 查询键盘布局名字并添加进 KBLCodes
                key := KBLTool.LangIdToName(languageCode)
                kblCodes[key] := languageCode
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

    static GetCurrentKBL(hWnd) {
        temp := A_DetectHiddenWindows
        A_DetectHiddenWindows := true

        threadId := DllCall(KBLTool.GetWindowThreadProcessId, "Ptr", hWnd, "Uint", 0)
        kbl := DllCall(KBLTool.GetKeyboardLayout, "Uint", threadId, "UInt")

        if (WinActive(hWnd)) {
            ptrSize := !A_PtrSize ? 4 : A_PtrSize
            cbSize := 4 + 4 + (PtrSize * 6) + 16	; DWORD*2+HWND*6+RECT
            stGTI := Buffer(cbSize, 0)
            NumPut("UInt", cbSize, stGTI.Ptr, 0)   ;   DWORD   cbSize;
            hWnd := DllCall("GetGUIThreadInfo", "Uint", 0, "Uint", stGTI.Ptr)
                ? NumGet(stGTI.Ptr, 8 + PtrSize, "Uint") : hwnd
        }

        state := SendMessage(0x283, 0x001, , , DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd))


        A_DetectHiddenWindows := temp
        name := KBLTool.LangIdToName(Format('{:04x}', kbl & 0x3FFF))
        return KeyboardLayout(name, state)
    }

    static LangIdToName(langId) =>
        KBLTool.%"_" langId%

    static SetKBLing := false
    ; 设置键盘布局
    static SetKBL(hWnd, language, state := 0) {
        if (KBLTool.SetKBLing) {
            return
        }
        KBLTool.SetKBLing := true
        try {
            code := KBLTool.KBLCodes[language]
            code := "0x" code code
        } catch Error as e {
            MsgBox("未发现键盘布局" language " , 本机上似乎没有这个语言的键盘布局。", "未发现键盘布局", 16)
            throw e
        }
        temp := A_DetectHiddenWindows
        A_DetectHiddenWindows := true
        Thread "NoTimers"

        ; 自动上屏
        if (WinExist("ahk_class PalmInputUICand")) {
            SendInput("{Enter}")
        }

        if (WinActive(hWnd)) {
            ptrSize := !A_PtrSize ? 4 : A_PtrSize
            cbSize := 4 + 4 + (PtrSize * 6) + 16	; DWORD*2+HWND*6+RECT
            stGTI := Buffer(cbSize, 0)
            NumPut("UInt", cbSize, stGTI.Ptr, 0)   ;   DWORD   cbSize;
            hWnd := DllCall("GetGUIThreadInfo", "Uint", 0, "Uint", stGTI.Ptr)
                ? NumGet(stGTI.Ptr, 8 + PtrSize, "Uint") : hwnd
        }

        ; DllCall("SendMessage"
        ;     , "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd)
        ;     , "UInt", 0x50
        ;     , "Int", 0
        ;     , "Int", code)
        SendMessage(0x50, , code, , DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd))

        Sleep(53)

        ; 这俩不用 DllCall 来调用的话，需要 Sleep 更久才可以真的改变输入法状态，非常的神奇
        DllCall("SendMessage"
            , "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd)
            , "UInt", 0x0283      ;Message : WM_IME_CONTROL
            , "Int", 0x002       ;wParam  : IMC_SETCONVERSIONMODE
            , "Int", state)   ;lParam  : CONVERSIONMODE
        DllCall("SendMessage"
            , "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd)
            , "UInt", 0x0283      ;Message : WM_IME_CONTROL
            , "Int", 0x006       ;wParam  : IMC_SETCONVERSIONMODE
            , "Int", 1)   ;lParam  : CONVERSIONMODE

        ; SendMessage(0x283, 0x6, 1, , DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd))
        ; SendMessage(0x283, 0x2, state, , DllCall("imm32\ImmGetDefaultIMEWnd", "Uint", hwnd))

        Thread "NoTimers", false
        A_DetectHiddenWindows := temp
        KBLTool.SetKBLing := false

    }

    static _0036 := "af"
    static _0436 := "af-ZA"
    static _001C := "sq"
    static _041C := "sq-AL"
    static _0484 := "gsw-FR"
    static _005E := "am"
    static _045E := "am-ET"
    static _0001 := "ar"
    static _1401 := "ar-DZ"
    static _3C01 := "ar-BH"
    static _0C01 := "ar-EG"
    static _0801 := "ar-IQ"
    static _2C01 := "ar-JO"
    static _3401 := "ar-KW"
    static _3001 := "ar-LB"
    static _1001 := "ar-LY"
    static _1801 := "ar-MA"
    static _2001 := "ar-OM"
    static _4001 := "ar-QA"
    static _0401 := "ar-SA"
    static _2801 := "ar-SY"
    static _1C01 := "ar-TN"
    static _3801 := "ar-AE"
    static _2401 := "ar-YE"
    static _002B := "hy"
    static _042B := "hy-AM"
    static _004D := "as"
    static _044D := "as-IN"
    static _002C := "az"
    static _742C := "az-Cyrl"
    static _082C := "az-Cyrl-AZ"
    static _782C := "az-Latn"
    static _042C := "az-Latn-AZ"
    static _0045 := "bn"
    static _0845 := "bn-BD"
    static _006D := "ba"
    static _046D := "ba-RU"
    static _002D := "eu"
    static _042D := "eu-ES"
    static _0023 := "be"
    static _0423 := "be-BY"
    static _0445 := "bn-IN"
    static _781A := "bs"
    static _641A := "bs-Cyrl"
    static _201A := "bs-Cyrl-BA"
    static _681A := "bs-Latn"
    static _141A := "bs-Latn-BA"
    static _007E := "br"
    static _047E := "br-FR"
    static _0002 := "bg"
    static _0402 := "bg-BG"
    static _0055 := "my"
    static _0455 := "my-MM"
    static _0003 := "ca"
    static _0403 := "ca-ES"
    static _005F := "tzm"
    static _045F := "tzm-Arab-MA"
    static _7C5F := "tzm-Latn"
    static _085F := "tzm-Latn-DZ"
    static _785F := "tzm-Tfng"
    static _105F := "tzm-Tfng-MA"
    static _0092 := "ku"
    static _7C92 := "ku-Arab"
    static _0492 := "ku-Arab-IQ"
    static _005C := "chr"
    static _7C5C := "chr-Cher"
    static _045C := "chr-Cher-US"
    static _7804 := "zh"
    static _0004 := "zh-Hans"
    static _0804 := "zh-CN"
    static _1004 := "zh-SG"
    static _7C04 := "zh-Hant"
    static _0C04 := "zh-HK"
    static _1404 := "zh-MO"
    static _0404 := "zh-TW"
    static _0083 := "co"
    static _0483 := "co-FR"
    static _001A := "hr"
    static _101A := "hr-BA"
    static _041A := "hr-HR"
    static _0005 := "cs"
    static _0405 := "cs-CZ"
    static _0006 := "da"
    static _0406 := "da-DK"
    static _0065 := "dv"
    static _0465 := "dv-MV"
    static _0013 := "nl"
    static _0813 := "nl-BE"
    static _0413 := "nl-NL"
    static _0C51 := "dz-BT"
    static _0066 := "bin"
    static _0466 := "bin-NG"
    static _0009 := "en"
    static _0C09 := "en-AU"
    static _2809 := "en-BZ"
    static _1009 := "en-CA"
    static _2409 := "en-029"
    static _3C09 := "en-HK"
    static _4009 := "en-IN"
    static _3809 := "en-ID"
    static _1809 := "en-IE"
    static _2009 := "en-JM"
    static _4409 := "en-MY"
    static _1409 := "en-NZ"
    static _3409 := "en-PH"
    static _4809 := "en-SG"
    static _1C09 := "en-ZA"
    static _2C09 := "en-TT"
    static _4C09 := "en-AE"
    static _0809 := "en-GB"
    static _0409 := "en-US"
    static _3009 := "en-ZW"
    static _0025 := "et"
    static _0425 := "et-EE"
    static _0038 := "fo"
    static _0438 := "fo-FO"
    static _0064 := "fil"
    static _0464 := "fil-PH"
    static _000B := "fi"
    static _040B := "fi-FI"
    static _000C := "fr"
    static _080C := "fr-BE"
    static _2C0C := "fr-CM"
    static _0C0C := "fr-CA"
    static _1C0C := "fr-029"
    static _300C := "fr-CI"
    static _040C := "fr-FR"
    static _3C0C := "fr-HT"
    static _140C := "fr-LU"
    static _340C := "fr-ML"
    static _180C := "fr-MC"
    static _380C := "fr-MA"
    static _200C := "fr-RE"
    static _280C := "fr-SN"
    static _100C := "fr-CH"
    static _240C := "fr-CD"
    static _0067 := "ff"
    static _7C67 := "ff-Latn"
    static _0467 := "ff-Latn-NG"
    static _0867 := "ff-Latn-SN"
    static _0056 := "gl"
    static _0456 := "gl-ES"
    static _0037 := "ka"
    static _0437 := "ka-GE"
    static _0007 := "de"
    static _0C07 := "de-AT"
    static _0407 := "de-DE"
    static _1407 := "de-LI"
    static _1007 := "de-LU"
    static _0807 := "de-CH"
    static _0008 := "el"
    static _0408 := "el-GR"
    static _0074 := "gn"
    static _0474 := "gn-PY"
    static _0047 := "gu"
    static _0447 := "gu-IN"
    static _0068 := "ha"
    static _7C68 := "ha-Latn"
    static _0468 := "ha-Latn-NG"
    static _0075 := "haw"
    static _0475 := "haw-US"
    static _000D := "he"
    static _040D := "he-IL"
    static _0039 := "hi"
    static _0439 := "hi-IN"
    static _000E := "hu"
    static _040E := "hu-HU"
    static _0069 := "ibb"
    static _0469 := "ibb-NG"
    static _000F := "is"
    static _040F := "is-IS"
    static _0070 := "ig"
    static _0470 := "ig-NG"
    static _0021 := "id"
    static _0421 := "id-ID"
    static _005D := "iu"
    static _7C5D := "iu-Latn"
    static _085D := "iu-Latn-CA"
    static _785D := "iu-Cans"
    static _045D := "iu-Cans-CA"
    static _003C := "ga"
    static _083C := "ga-IE"
    static _0034 := "xh"
    static _0434 := "xh-ZA"
    static _0035 := "zu"
    static _0435 := "zu-ZA"
    static _0010 := "it"
    static _0410 := "it-IT"
    static _0810 := "it-CH"
    static _0011 := "ja"
    static _0411 := "ja-JP"
    static _006F := "kl"
    static _046F := "kl-GL"
    static _004B := "kn"
    static _044B := "kn-IN"
    static _0071 := "kr"
    static _0471 := "kr-Latn-NG"
    static _0060 := "ks"
    static _0460 := "ks-Arab"
    static _1000 := "ks-Arab-IN"
    static _0860 := "ks-Deva-IN"
    static _003F := "kk"
    static _043F := "kk-KZ"
    static _0053 := "km"
    static _0453 := "km-KH"
    static _0087 := "rw"
    static _0487 := "rw-RW"
    static _0041 := "sw"
    static _0441 := "sw-KE"
    static _0057 := "kok"
    static _0457 := "kok-IN"
    static _0012 := "ko"
    static _0412 := "ko-KR"
    static _0040 := "ky"
    static _0440 := "ky-KG"
    static _0086 := "quc"
    static _7C86 := "quc-Latn"
    static _0486 := "quc-Latn-GT"
    static _0054 := "lo"
    static _0454 := "lo-LA"
    static _0076 := "la"
    static _0476 := "la-VA"
    static _0026 := "lv"
    static _0426 := "lv-LV"
    static _0027 := "lt"
    static _0427 := "lt-LT"
    static _7C2E := "dsb"
    static _082E := "dsb-DE"
    static _006E := "lb"
    static _046E := "lb-LU"
    static _002F := "mk"
    static _042F := "mk-MK"
    static _003E := "ms"
    static _083E := "ms-BN"
    static _043E := "ms-MY"
    static _004C := "ml"
    static _044C := "ml-IN"
    static _003A := "mt"
    static _043A := "mt-MT"
    static _0058 := "mni"
    static _0458 := "mni-IN"
    static _0081 := "mi"
    static _0481 := "mi-NZ"
    static _007A := "arn"
    static _047A := "arn-CL"
    static _004E := "mr"
    static _044E := "mr-IN"
    static _007C := "moh"
    static _047C := "moh-CA"
    static _0050 := "mn"
    static _7850 := "mn-Cyrl"
    static _0450 := "mn-MN"
    static _7C50 := "mn-Mong"
    static _0850 := "mn-Mong-CN"
    static _0C50 := "mn-Mong-MN"
    static _0061 := "ne"
    static _0861 := "ne-IN"
    static _0461 := "ne-NP"
    static _003B := "se"
    static _0014 := "no"
    static _7C14 := "nb"
    static _0414 := "nb-NO"
    static _7814 := "nn"
    static _0814 := "nn-NO"
    static _0082 := "oc"
    static _0482 := "oc-FR"
    static _0048 := "or"
    static _0448 := "or-IN"
    static _0072 := "om"
    static _0472 := "om-ET"
    static _0079 := "pap"
    static _0479 := "pap-029"
    static _0063 := "ps"
    static _0463 := "ps-AF"
    static _0029 := "fa"
    static _008C := "fa"
    static _048C := "fa-AF"
    static _0429 := "fa-IR"
    static _0015 := "pl"
    static _0415 := "pl-PL"
    static _0016 := "pt"
    static _0416 := "pt-BR"
    static _0816 := "pt-PT"
    static _05FE := "qps-ploca"
    static _09FF := "qps-plocm"
    static _0901 := "qps-Latn-x-sh"
    static _0501 := "qps-ploc"
    static _0046 := "pa"
    static _7C46 := "pa-Arab"
    static _0446 := "pa-IN"
    static _0846 := "pa-Arab-PK"
    static _006B := "quz"
    static _046B := "quz-BO"
    static _086B := "quz-EC"
    static _0C6B := "quz-PE"
    static _0018 := "ro"
    static _0818 := "ro-MD"
    static _0418 := "ro-RO"
    static _0017 := "rm"
    static _0417 := "rm-CH"
    static _0019 := "ru"
    static _0819 := "ru-MD"
    static _0419 := "ru-RU"
    static _0085 := "sah"
    static _0485 := "sah-RU"
    static _703B := "smn"
    static _7C3B := "smj"
    static _743B := "sms"
    static _783B := "sma"
    static _243B := "smn-FI"
    static _103B := "smj-NO"
    static _143B := "smj-SE"
    static _0C3B := "se-FI"
    static _043B := "se-NO"
    static _083B := "se-SE"
    static _203B := "sms-FI"
    static _183B := "sma-NO"
    static _1C3B := "sma-SE"
    static _004F := "sa"
    static _044F := "sa-IN"
    static _0091 := "gd"
    static _0491 := "gd-GB"
    static _7C1A := "sr"
    static _6C1A := "sr-Cyrl"
    static _1C1A := "sr-Cyrl-BA"
    static _301A := "sr-Cyrl-ME"
    static _0C1A := "sr-Cyrl-CS"
    static _281A := "sr-Cyrl-RS"
    static _701A := "sr-Latn"
    static _181A := "sr-Latn-BA"
    static _2C1A := "sr-Latn-ME"
    static _081A := "sr-Latn-CS"
    static _241A := "sr-Latn-RS"
    static _0030 := "st"
    static _0430 := "st-ZA"
    static _006C := "nso"
    static _046C := "nso-ZA"
    static _0032 := "tn"
    static _0832 := "tn-BW"
    static _0432 := "tn-ZA"
    static _0059 := "sd"
    static _7C59 := "sd-Arab"
    static _0459 := "sd-Deva-IN"
    static _0859 := "sd-Arab-PK"
    static _005B := "si"
    static _045B := "si-LK"
    static _001B := "sk"
    static _041B := "sk-SK"
    static _0024 := "sl"
    static _0424 := "sl-SI"
    static _0077 := "so"
    static _0477 := "so-SO"
    static _000A := "es"
    static _2C0A := "es-AR"
    static _400A := "es-BO"
    static _340A := "es-CL"
    static _240A := "es-CO"
    static _140A := "es-CR"
    static _5C0A := "es-CU"
    static _1C0A := "es-DO"
    static _300A := "es-EC"
    static _440A := "es-SV"
    static _100A := "es-GT"
    static _480A := "es-HN"
    static _580A := "es-419"
    static _080A := "es-MX"
    static _4C0A := "es-NI"
    static _180A := "es-PA"
    static _3C0A := "es-PY"
    static _280A := "es-PE"
    static _500A := "es-PR"
    static _0C0A := "es-ES"
    static _040A := "es-ES_tradnl"
    static _540A := "es-US"
    static _380A := "es-UY"
    static _200A := "es-VE"
    static _001D := "sv"
    static _081D := "sv-FI"
    static _041D := "sv-SE"
    static _0084 := "gsw"
    static _005A := "syr"
    static _045A := "syr-SY"
    static _0028 := "tg"
    static _7C28 := "tg-Cyrl"
    static _0428 := "tg-Cyrl-TJ"
    static _0049 := "ta"
    static _0449 := "ta-IN"
    static _0849 := "ta-LK"
    static _0044 := "tt"
    static _0444 := "tt-RU"
    static _004A := "te"
    static _044A := "te-IN"
    static _001E := "th"
    static _041E := "th-TH"
    static _0051 := "bo"
    static _0451 := "bo-CN"
    static _0073 := "ti"
    static _0873 := "ti-ER"
    static _0473 := "ti-ET"
    static _001F := "tr"
    static _041F := "tr-TR"
    static _0042 := "tk"
    static _0442 := "tk-TM"
    static _0022 := "uk"
    static _0422 := "uk-UA"
    static _002E := "hsb"
    static _042E := "hsb-DE"
    static _0020 := "ur"
    static _0820 := "ur-IN"
    static _0420 := "ur-PK"
    static _0080 := "ug"
    static _0480 := "ug-CN"
    static _0043 := "uz"
    static _7843 := "uz-Cyrl"
    static _0843 := "uz-Cyrl-UZ"
    static _7C43 := "uz-Latn"
    static _0443 := "uz-Latn-UZ"
    static _0803 := "ca-ES-valencia"
    static _0033 := "ve"
    static _0433 := "ve-ZA"
    static _002A := "vi"
    static _042A := "vi-VN"
    static _0052 := "cy"
    static _0452 := "cy-GB"
    static _0062 := "fy"
    static _0462 := "fy-NL"
    static _0088 := "wo"
    static _0488 := "wo-SN"
    static _0031 := "ts"
    static _0431 := "ts-ZA"
    static _0078 := "ii"
    static _0478 := "ii-CN"
    static _003D := "yi"
    static _043D := "yi-001"
    static _006A := "yo"
    static _046A := "yo-NG"

}