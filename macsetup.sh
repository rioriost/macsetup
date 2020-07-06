#!/bin/zsh

# Before executing this script, you MUST manually add Terminal.app to
# 'Accessibility'
# 'Full Disk Access'
# in the 'Privacy' tab of 'Security and Privacy' system preference.
#
# And execute following one liner to enable Terminal.app to use 'System Events', and then click "OK"
# osascript -e 'tell application "System Preferences" to activate' -e 'tell application "System Events" to tell application process "System Preferences" to keystroke "q" using command down'

# How to find pref pane id
# osascript -e "tell application \"System Preferences\"" -e "get the id of every pane " -e "end tell"
# How to find anchor
# osascript -e "tell application \"System Preferences\"" \
# -e "set the current pane to pane id \"com.apple.preference.desktopscreeneffect\"" \
# -e "get the name of every anchor of pane id \"com.apple.preference.desktopscreeneffect\"" \
# -e "end tell"

##### Settings for this script
readonly adminPass="macos_password"

readonly ocurl="https://owncloud.example.com/"
readonly ocuser="rio"
readonly ocpass="owncloud_password"
readonly ocdir="${HOME}/ownCloud"

readonly email_address="rio@example.com"
readonly email_pass="email_password"
readonly email_server="mail.example.com"

readonly desktop_pics_path="${ocdir}/4k_wallpapers"


# Instead of 'set os_version to do shell script "sw_vers -productVersion"' every time when the function is called
let macos_ver=$(sw_vers -productVersion | cut -d . -f 2)
echo "Detected macOS version is 10.${macos_ver}"
if [ $macos_ver -le 14 ]; then
    echo "This script is only for macOS 10.15 'Catalina' and later."
    exit
fi

if [ "$LANG" = "ja_JP.UTF-8" ]; then
    lang="ja"
elif [ "$LANG" = "" ]; then
    lang="en"
fi

add_permissions_to_apps(){
    echo -e "\n\e[31mAdding permissions...\e[m"
    local apps=($@)
    /usr/bin/osascript - "${macos_ver}" "${lang}" "${adminPass}" $apps << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set adminPass to item 3 of argv as string
        set privacyType to item 4 of argv as string
        set paths to {}
        repeat with i from 5 to count of argv
            set end of paths to item i of argv as string
        end repeat
        if lang = "ja" then
            set msgs to {win1:"セキュリティとプライバシー", button1:"変更するにはカギをクリックします。", button2:"パスワードを使用…", tf1:"パスワードを入力", button3:"追加", button4:"移動", button5:"開く", button6:"今すぐ終了", button7:"終了して再度開く"}
        else
            set msgs to {win1:"Security & Privacy", button1:"Click the lock to make changes.", button2:"Using Password…", tf1:"Enter password", button3:"add", button4:"Go", button5:"Open", button6:"Quit now", button7:""}
        end if
        tell application "System Preferences"
            activate
            reveal anchor privacyType of pane "com.apple.preference.security"
            delay 2
            tell application "System Events"
                tell process "System Preferences"
                    tell window (win1 of msgs)
                        if exists button (button1 of msgs) then
                            click button (button1 of msgs)
                            delay 2
                            tell sheet 1
                                if exists button (button2 of msgs) then -- TouchID
                                    click button (button2 of msgs)
                                    delay 2
                                end if
                                set focused of text field (tf1 of msgs) to true
                                keystroke adminPass & return
                            end tell
                        end if
                        delay 2
                    end tell
                    repeat with path in paths
                        tell window (win1 of msgs)
                            click (every button of group 1 of group 1 of tab group 1 whose description is (button3 of msgs))
                            delay 2
                            keystroke "/"
                            delay 2
                            tell sheet 1
                                set focused of combo box 1 of sheet 1 to true
                                set value of combo box 1 of sheet 1 to ""
                                keystroke path
                                delay 3
                                click button (button4 of msgs) of sheet 1
                                delay 3
                            end tell
                        end tell
                        if macos_ver = 15 then
                            -- Each sheet 1 are another instance of sheet
                            tell sheet 1 of window (win1 of msgs)
                                click button (button5 of msgs)
                            end tell
                        else if macos_ver = 16 then
                            tell splitter group 1 of sheet 1 of window 2
                                click button (button5 of msgs)
                            end tell
                        end if
                        delay 2
                        tell window (win1 of msgs)
                            if exists sheet 1 then
                                tell sheet 1
                                    if macos_ver = 15 then
                                        click button (button6 of msgs)
                                    else if macos_ver = 16 then
                                        click button (button7 of msgs)
                                    end if
                                end tell
                            end if
                        end tell
                        delay 2
                    end repeat
                end tell
            end tell
        end tell
        delay 2
        quit application "System Preferences"
    end run
EOF
    return_to_Terminal
}

install_brew(){
    echo -e "\n\e[31mInstalling brew...\e[m"
    curl -O -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh
    local shpath="./install.sh"
    if [ ! -e $shpath ]; then
        echo -e "\n\e[31mCould not find ${shpath}!\e[m"
        exit
    fi
    chmod 755 $shpath
    expect -c "
    spawn bash -c \"${shpath} < /dev/null\"
    expect \"Password:\"
    send \"$adminPass\n\"
    interact
    "
    rm -f ${shpath}
}

sync_owncloud(){
    echo -e "\n\e[31mInstalling ownCloud client...\e[m"
    if [ -e $ocdir ]; then
        echo -e "\n\e[31mFound ownCloud installed and configured.\e[m"
        echo -e "\n\e[31mSkipped installation.\e[m"
        return
    fi
    expect -c "
    spawn /bin/bash -c \"brew cask install owncloud\"
    expect \"Password:\"
    send \"$adminPass\n\"
    interact
    "
    local ocpath="/Applications/ownCloud.app"
    if [ ! -e $ocpath ]; then
        echo -e "\n\e[31mCould not find ${ocpath}!\e[m"
        exit
    fi
    open $ocpath
    sleep 2
    /usr/bin/osascript - "${macos_ver}" "${lang}" "${ocurl}" "${ocuser}" "${ocpass}" << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set ocurl to item 3 of argv as string
        set ocuser to item 4 of argv as string
        set ocpass to item 5 of argv as string
        if lang = "ja" then
            set msgs to {window1:"ownCloud 接続ウィザード", tf1:"サーバーアドレス(V)", button1:"次へ(N) >", tf2:"ユーザー名(U)", tf3:"パスワード(P)", button2:"接続...", button3:"閉じる"}
        else
            set msgs to {window1:"ownCloud Connection Wizard", tf1:"Server Address", button1:"Next >", tf2:"Username", tf3:"Password", button2:"Connect...", button3:"Close"}
        end if
        tell application "ownCloud"
            activate
        end tell
        tell application "System Events"
            tell process "owncloud"
                tell window (window1 of msgs)
                    set focused of text field (tf1 of msgs) to true
                    keystroke ocurl
                    delay 2
                    click button (button1 of msgs)
                    delay 2
                    set focused of text field (tf2 of msgs) to true
                    keystroke ocuser
                    delay 2
                    set focused of text field (tf3 of msgs) to true
                    keystroke ocpass
                    delay 2
                    click button (button1 of msgs)
                    delay 2
                    click button (button2 of msgs)
                    delay 2
                end tell
                tell window "ownCloud"
                    click button (button3 of msgs) of group 1
                end tell
            end tell
        end tell
    end run
EOF
    return_to_Terminal
    echo -e "\n\e[31mWaiting for ownCloud synced...\e[m"
    oldsz=$(du -s ${ocdir} | awk '{print $1}')
    while; do
        sleep 1
        sz=$(du -s ${ocdir} | awk '{print $1}')
        if [ $sz = $oldsz ]; then
            break
        fi
        oldsz=$sz
    done
    echo -e "\n\e[31mownCloud synced!\e[m"
}

install_Library_files(){
    echo -e "\n\e[31mSetting Library files...\e[m"
    local librarypath=${ocdir}/Library/
    if [ ! -e $librarypath ]; then
        echo -e "\n\e[31mCould not find ${librarypath}!\e[m"
        return
    fi
    rsync -av ${librarypath} ${HOME}/Library/
}

install_bundle(){
    echo -e "\n\e[31mRunning brew file...\e[m"
    local brewfilepath=${ocdir}/Settings/Brewfile
    if [ ! -e $brewfilepath ]; then
        echo -e "\n\e[31mCould not find ${brewfilepath}!\e[m"
        exit
    fi
    mkdir /usr/local/share/man/man8
    echo $adminPass | sudo -S chown -R $(whoami) /usr/local/share/man/man8
    chmod u+w /usr/local/share/man/man8
    brew install argon/mas/mas
    brew install rcmdnk/file/brew-file
    mkdir -p ${HOME}/.config/brewfile
    cp ${brewfilepath} ${HOME}/.config/brewfile/Brewfile
    # TODO: Need to catch error to retry
    brew file install
}

configure_macos(){
    echo -e "\n\e[31mConfiguring System Preferences...\e[m"
    local domain=""
    # システム環境設定
    domain="com.apple.systempreferences"
    #デスクトップとスクリーンセーバ
    defaults write ${domain} DSKDesktopPrefPane -dict UserFolderPaths "<array><string>${desktop_pics_path}</string></array>"
    
    # Dock
    domain="com.apple.dock"
    # Dock が表示されるまでの待ち時間を無効化
    defaults write ${domain} autohide-delay -float 0
    # "自動的に非表示"をオン
    defaults write ${domain} autohide -bool true

    # Bluetooth
    domain="com.apple.BluetoothAudioAgent"
    # Bluetooth ヘッドフォン・ヘッドセットの音質を向上させる
    defaults write ${domain} "Apple Bitpool Min (editable)" -int 40

    # プリンタとスキャナ
    local dnssd_pr=$(lpinfo -v | grep dnssd | awk '{print $2}')
    #lpadmin

    # キーボード
    domain="NSGlobalDomain"
    # キーのリピート
    defaults write ${domain} KeyRepeat -int 2
    # リピート入力認識までの時間
    defaults write ${domain} InitialKeyRepeat -int 15
    # コントロール間のフォーカス移動をキーボードで操作
    defaults write ${domain} AppleKeyboardUIMode -int 2
    domain="com.apple.symbolichotkeys"
    # Spotlight検索を表示:無効化
    defaults write ${domain} AppleSymbolicHotKeys -dict-add 61 "<dict><key>enabled</key><false/></dict>"
    #前の入力ソースを選択:[command] + [space]
    defaults write ${domain} AppleSymbolicHotKeys -dict-add 60 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>"
    #Jedit等のショートカット割り当て
    /usr/libexec/PlistBuddy -c 'Delete NSServicesStatus:"(null) - Workを開く - runWorkflowAsService"' ${HOME}/Library/Preferences/pbs.plist 2>/dev/null
    defaults write pbs NSServicesStatus -dict-add '"(null) - Workを開く - runWorkflowAsService"' '{key_equivalent = "@^w";}'
    /usr/libexec/PlistBuddy -c 'Delete NSServicesStatus:"(null) - Jeditを起動 - runWorkflowAsService"' ${HOME}/Library/Preferences/pbs.plist 2>/dev/null
    defaults write pbs NSServicesStatus -dict-add '"(null) - Jeditを起動 - runWorkflowAsService"' '{key_equivalent = "@^j";}'
    /usr/libexec/PlistBuddy -c 'Delete NSServicesStatus:"(null) - Safariを起動 - runWorkflowAsService"' ${HOME}/Library/Preferences/pbs.plist 2>/dev/null
    defaults write pbs NSServicesStatus -dict-add '"(null) - Safariを起動 - runWorkflowAsService"' '{key_equivalent = "@^s";}'
    /usr/libexec/PlistBuddy -c 'Delete NSServicesStatus:"(null) - Mailを起動 - runWorkflowAsService"' ${HOME}/Library/Preferences/pbs.plist 2>/dev/null
    defaults write pbs NSServicesStatus -dict-add '"(null) - Mailを起動 - runWorkflowAsService"' '{key_equivalent = "@^m";}'
    /usr/libexec/PlistBuddy -c 'Delete NSServicesStatus:"(null) - Terminalを起動 - runWorkflowAsService"' ${HOME}/Library/Preferences/pbs.plist 2>/dev/null
    defaults write pbs NSServicesStatus -dict-add '"(null) - Terminalを起動 - runWorkflowAsService"' '{key_equivalent = "@~^t";}'

    # マウス
    domain="NSGlobalDomain"
    defaults write ${domain} com.apple.mouse.scaling -float 1
    defaults write ${domain} com.apple.scrollwheel.scaling -float 0.75

    # トラックパッド
    domain="com.apple.AppleMultitouchTrackpad"
    defaults write ${domain} Clicking -int 1

    # 省エネルギー
    echo -e $adminPass | sudo -S pmset displaysleep 60
    echo -e $adminPass | sudo -S pmset sleep 0

    # 日付と時刻
    domain="com.apple.menuextra.clock"
    defaults write ${domain} DateFormat -string 'M月d日(EEE)  H:mm:ss'

    # メニューバーアイテム
    defaults write com.apple.systemuiserver menuExtras -array "/System/Library/CoreServices/Menu Extras/Bluetooth.menu" "/System/Library/CoreServices/Menu Extras/Displays.menu" "/System/Library/CoreServices/Menu Extras/Volume.menu" "/System/Library/CoreServices/Menu Extras/Timemachine.menu"

    killall SystemUIServer
}

maximize_display_resolution(){
    echo -e "\n\e[31mMaximizing display resolution...\e[m"
    /usr/bin/osascript - "${macos_ver}" "${lang}" << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        if lang = "ja" then
            set msgs to {radio1:"変更", radio2:"スペースを最大化"}
        else
            set msgs to {radio1:"Scaled", radio2:"Most Space"}
        end if
        run application "System Preferences"
        tell application "System Preferences"
            activate
            reveal anchor "displaysDisplayTab" of pane "com.apple.preference.displays"
            delay 2
        end tell
        tell application "System Events" to tell process "System Preferences" to tell 1st window
            set isScaled to value of radio button (radio1 of msgs) of tab group 1
            if isScaled = 0 then
                click radio button (radio1 of msgs) of tab group 1
                tell radio group 1 of group 1 of tab group 1
                    if exists (every radio button whose description is (radio2 of msgs))
                        click (every radio button whose description is (radio2 of msgs))
                    end if
                end tell
            end if
        end tell
        quit application "System Preferences"
    end run
EOF
    return_to_Terminal
}

configure_apps(){
    echo -e "\n\e[31mConfiguring applications...\e[m"
    local domain=""
    # Crash Reporter
    domain="com.apple.CrashReporter"
    # クラッシュレポートを無効化する
    defaults write ${domain} DialogType -string "none"

    # Desktop Service
    domain="com.apple.desktopservices"
    # ネットワークストレージに .DS_Store ファイルを作成しない
    defaults write ${domain} DSDontWriteNetworkStores -bool true    
    # USBメモリに .DS_Store ファイルを作成しない
    defaults write ${domain} DSDontWriteUSBStores -bool true

    # Finder
    # ~/Library ディレクトリの表示
    chflags nohidden ~/Library
    domain="NSGlobalDomain"
    # 全ての拡張子のファイルを表示
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    domain="com.apple.finder"
    # 検索時にデフォルトでカレントディレクトリを検索
    defaults write ${domain} FXDefaultSearchScope -string "SCcf"
    # 拡張子変更時の警告を無効化
    defaults write ${domain} FXEnableExtensionChangeWarning -bool false
    # クイックルックでテキストを選択可能にする
    defaults write ${domain} QLEnableTextSelection -bool true
    # ステータスバーを表示
    defaults write ${domain} ShowStatusBar -bool true
    # ステータスバーを表示
    defaults write ${domain} ShowSideBar -bool true
    # ゴミ箱を空にする前の警告を無効化
    defaults write ${domain} WarnOnEmptyTrash -bool false
    # 新規ウインドウをownCloudにする
    defaults write ${domain} NewWindowTarget -string "PfLo"
    defaults write ${domain} NewWindowTargetPath -string "file://${HOME}/ownCloud/"
    # カラム表示にする
    defaults write ${domain} FXPreferredViewStyle -string "clmv"
    # Desktopアイコンを名前順に表示
    /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy name" ${HOME}/Library/Preferences/com.apple.finder.plist

    # Safari
    open /Applications/Safari.app
    killall Safari
    domain="${HOME}/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"
    # ダウンロード後、"安全な"ファイルを開く：無効
    defaults write ${domain} AutoOpenSafeDownloads -bool false
    # Webサイトの完全なアドレスを表示
    defaults write ${domain} ShowFullURLInSmartSearchField -bool true
    # ステータスバーを表示
    defaults write ${domain} ShowOverlayStatusBar -bool true
    # タブバーを表示
    defaults write ${domain} AlwaysShowTabBar -bool true
    # 常にタブで開く
    defaults write ${domain} TabCreationPolicy -int 2
    # お気に入りバーを表示
    defaults write ${domain} "ShowFavoritesBar-v2" -bool true
    # メニューバーに"開発"メニューを表示
    defaults write ${domain} IncludeDevelopMenu -bool true

    # Launch Service
    #domain="com.apple.LaunchServices"
    # 未確認のアプリケーションを実行する際のダイアログを無効にする
    #defaults write ${domain} LSQuarantine -bool false

    # Screen Captcha
    domain="com.apple.screencapture"
    # 影をなくす
    defaults write ${domain} disable-shadow -bool true
    # ファイル名:"ScreenShots"
    defaults write ${domain} name "ScreenShots"
    # 保存形式:PNG
    defaults write ${domain} type -string "png"
    # 保存場所
    defaults write ${domain} location -string "${HOME}/Desktop"

    # Jedit Omega
    domain="jp.co.artman21.JeditOmega"
    # 環境設定をiCloud上で同期する
    defaults write ${domains} JZiCloudSync -bool true

    # Terminal
    domain="com.apple.Terminal"
    # UTF-8 のみを使用する
    defaults write ${domain} StringEncodings -array 4
    # az-completiond
    mkdir ${HOME}/.azure
    curl -o ${HOME}/.azure/az.completion https://raw.githubusercontent.com/Azure/azure-cli/dev/az.completion
    # zprofile: Sourcing .zprofile requires compaudit and compaudit requires sourcing... only I can do is "chmod /usr/local/share" before sourcing
    ln -s ${ocdir}/Settings/zprofile ${HOME}/.zprofile
    chmod 755 /usr/local/share /usr/local/share/zsh /usr/local/share/zsh/site-functions
    source ${HOME}/.zprofile
    # bin files
    local binpath="${ocdir}/bin/"
    if [ -e $binpath ]; then
        chmod 755 ${binpath}*
    fi
}

import_terminal_profile(){
    echo -e "\n\e[31mImporting Terminal.app profile...\e[m"
    local profile_path=$1
    if [ ! -e $profile_path ]; then
        echo -e "\n\e[31mCould not find ${profile_path}!\e[m"
        return
    fi
    profile_name=$(basename ${profile_path} | cut -d. -f1)
    default_profile=$(defaults read com.apple.terminal "Default Window Settings")
    if [ "$profile_name" = "$default_profile" ]; then
        echo -e "\n\e[31m'${profile_name}' has been already set.\e[m"
        return
    fi
    /usr/bin/osascript - "${macos_ver}" "${lang}" "$profile_path" "$profile_name" << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set ppath to item 3 of argv as string
        set pname to item 4 of argv as string
        if lang = "ja" then
            set msgs to {button1:"プロファイル", window1:"プロファイル", menuitem1:"読み込む…", sheet1:"開く", button2:"デフォルト"}
        else
            set msgs to {button1:"Profiles", window1:"Profiles", menuitem1:"Import...", sheet1:"Open", button2:"Default"}
        end if
        tell application "System Events"
            tell process "Terminal"
                keystroke "," using command down
                tell 1st window
                    tell toolbar 1
                        click button (button1 of msgs)
                    end tell
                end tell
                delay 2
                tell window (window1 of msgs)
                    tell group 1
                        click menu button 1
                        delay 1
                        tell menu 1 of menu button 1
                            click menu item (menuitem1 of msgs) 
                        end tell
                    end tell
                    delay 2
                    keystroke "/"
                    delay 2
                    tell sheet 1
                        set focused of combo box 1 of sheet 1 to true
                        set value of combo box 1 of sheet 1 to ""
                        keystroke ppath
                        delay 2
                        keystroke return
                        delay 2
                        keystroke return
                        delay 2
                    end tell
                    set focused of group 1 to true
                    delay 2
                    keystroke pname
                    delay 2
                    tell group 1
                        click button (button2 of msgs)
                    end tell
                end tell
                keystroke "w" using command down
            end tell
        end tell
    end run
EOF
}

add_folder_action(){
    local target_folder=$1
    local action=$2
    local faname=$(basename $target_folder)
    echo -e "\n\e[31mAdding folder action to $faname...\e[m"
    /usr/bin/osascript - "${macos_ver}" "${lang}" "${faname}" "${target_folder}" "${action}" << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set faname to item 3 of argv as string
        set target_folder to item 4 of argv as string
        set action_name to item 5 of argv as string
        if lang = "ja" then
            set msgs to {proc1:"フォルダアクション設定", box1:"フォルダアクションを使用"}
        else
            set msgs to {proc1:"Folder Action Setup", box1:"Enable Folder Actions"}
        end if
        tell application "System Events"
            set existing_script_path to the POSIX path of every script of (every folder action where its path contains (target_folder) and enabled of scripts contains true)
            set existing_script_name to (do shell script "basename '" & existing_script_path & "'")
            if action_name = existing_script_name then
                return "Folder Action has been already set."
            end if
        end tell
        run application "Folder Actions Setup"
        tell application "Folder Actions Setup"
            activate
            tell application "System Events"
                tell process "Folder Actions Setup"
                    if exists menu bar item (proc1 of msgs) of menu bar 1 then
                        if value of checkbox (box1 of msgs) of window (proc1 of msgs) = 0 then
                            click checkbox (box1 of msgs) of window (proc1 of msgs)
                        end if
                    end if
                    delay 2
                end tell
                make new folder action at end of folder actions with properties {enabled:true, name:faname, path:target_folder}
                tell folder action faname to make new script at end of scripts with properties {name:action_name}
            end tell 
        end tell
        delay 2
        quit application "Folder Actions Setup"
    end run
EOF
    return_to_Terminal
}

add_email_address(){
    echo -e "\n\e[31mConfiguring Mail.app...\e[m"
    open "/System/Applications/Mail.app"
    sleep 2
    /usr/bin/osascript - "${macos_ver}" "${lang}" "${email_address}" "${email_pass}" "${email_server}" $(echo ${email_address} | cut -d '@' -f 1) << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set email_address to item 3 of argv as string
        set email_pass to item 4 of argv as string
        set email_server to item 5 of argv as string
        set email_user to item 6 of argv as string
        if lang = "ja" then
            set msgs to {button1:"アカウント", button2:"新規アカウント", window1:"アカウント", radio1:"その他のアカウント", tf1:"メールアドレス:", tf2:"パスワード:", tf3:"ユーザ名:", tf4:"受信用メールサーバ:", tf5:"送信用メールサーバ:", button3:"完了", text1:"このアカウントはすでに存在します。", button4:"次へ"}
        else
            set msgs to {button1:"Accounts", button2:"new account", window1:"Accounts", radio1:"Other Account", tf1:"Email Address:", tf2:"Password:", tf3:"Username", tf4:"Incoming Server:", tf5:"Outgoing Server:", button3:"Complete", text1:"", button4:"Next"}
        end if
        tell application "Mail"
            activate
        end tell
        tell application "System Events"
            tell process "Mail"
                keystroke "," using command down
                delay 2
                tell 1st window
                    tell toolbar 1
                        click button (button1 of msgs)
                    end tell
                    delay 2
                    tell group 1
                        click (every button of group 1 whose description is (button2 of msgs)) 
                    end tell
                    delay 2
                end tell
                tell window (window1 of msgs)
                    tell sheet 1
                        tell UI element 1 of row 6 of table 1 of scroll area 1
                            click (every radio button whose description is (radio1 of msgs))
                        end tell
                        delay 2
                        keystroke return
                        delay 2
                        set value of text field (tf1 of msgs) to email_address
                        delay 2
                        set focused of text field (tf2 of msgs) to true
                        keystroke email_pass
                        delay 2
                        keystroke return
                        delay 2
                        set value of text field (tf3 of msgs) to email_user
                        delay 2
                        # set value of text field (tf4 of msgs) to email_server # it should work, but doesn't work. Bug in Mail.app?
                        set focused of text field (tf4 of msgs) to true
                        keystroke email_server
                        delay 2
                        set focused of text field (tf5 of msgs) to true
                        keystroke email_server
                        delay 2
                        keystroke return
                        delay 2
                        set cnt to 0
                        repeat while (busy indicator 1 exists)
                            delay 2
                            set cnt to cnt + 1
                            if cnt = 15 then -- 30 sec
                                exit repeat
                            end if
                        end repeat
                    end tell
                    tell sheet 1 -- in Big Sur, this 'sheet 1' seems another sheet from above 'sheet 1'...
                        if exists button (button3 of msgs) then
                            click button (button3 of msgs)
                            keystroke "w" using command down
                            return
                        end if
                        if exists text (text1 of msgs) then
                            if exists button (button4 of msgs) then
                                click button (button4 of msgs)
                                if exists button (button3 of msgs) then
                                    click button (button3 of msgs)
                                    keystroke "w" using command down
                                end if
                            end if
                        end if
                    end tell
                end tell
            end tell
        end tell
    end run
EOF
    return_to_Terminal
}

configure_owncloud(){
    echo -e "\n\e[31mConfiguring ownCloud...\e[m"
    local ocprefpath="${HOME}/Library/Preferences/ownCloud/owncloud.cfg"
    killall owncloud
    cp ${ocprefpath} "${ocprefpath}.bak"
    awk '{ gsub(/newBigFolderSizeLimit=[0-9]*/,"newBigFolderSizeLimit=50000\nmonoIcons=false\n")}; {print}' "${ocprefpath}.bak" > "${ocprefpath}"
    journalpath=$(sed -n 's/^.*journalPath=\(.*\)$/\1/p' ${ocprefpath})
    echo "DELETE FROM selectivesync" | sqlite3 "${ocdir}/${journalpath}"
    open "/Applications/ownCloud.app"
}

add_login_items(){
    echo -e "\n\e[31mAdding Login Item...\e[m"
    local apps=($@)
    /usr/bin/osascript - "${macos_ver}" "${lang}" $apps << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set item_paths to {}
        repeat with i from 3 to count of argv
            set end of item_paths to item i of argv as string
        end repeat
        tell application "System Events"
            repeat with item_path in item_paths
                set item_name to (do shell script "basename" & item_path & "|cut -d. -f1")
                make login item at end with properties {name: item_name,path:item_path, hidden:false}
            end repeat
        end tell
    end run
EOF
}

set_desktop_picture(){
    echo -e "\n\e[31mSetting Desktop Picture...\e[m"
    /usr/bin/osascript - "${macos_ver}" "${lang}" $(basename $desktop_pics_path) << 'EOF'
    on run argv
        set macos_ver to item 1 of argv as integer
        set lang to item 2 of argv as string
        set dppath to item 3 of argv as string
        if lang = "ja" then
            set msgs to {cb1:"ピクチャを変更:", cb2:"ランダムな順序"}
        else
            set msgs to {cb1:"ピクチャを変更:", cb2:"ランダムな順序"}
        end if
        run application "System Preferences"
        tell application "System Preferences"
            activate
            reveal anchor "DesktopPref" of pane "com.apple.preference.desktopscreeneffect"
            delay 2
        end tell
        tell application "System Events"
            tell process "System Preferences"
                tell 1st window
                    tell tab group 1
                        tell scroll area 1
                            tell outline 1
                                repeat with aRow in rows
                                    if name of 1st UI element of aRow is dppath then
                                        select aRow
                                    end if
                                end repeat
                            end tell
                        end tell
                        tell group 1
                            tell scroll area 1
                                tell list 1
                                    tell list 1
                                        click image 1
                                    end tell
                                end tell
                            end tell
                        end tell
                        delay 2
                        click checkbox (cb1 of msgs)
                        delay 2
                        click checkbox (cb2 of msgs)
                        delay 2
                    end tell
                end tell
            end tell
        end tell
        quit application "System Preferences"
    end run
EOF
    return_to_Terminal
}

configure_global_gitignore(){
    git_path=$(which git | grep 'not found')
    if [ "$git_path" = "" ]; then
        git config --global core.excludesfile ${HOME}/.gitignore_global
        echo ".DS_Store" >> ${HOME}/.gitignore_global
    fi
}

return_to_Terminal(){
    /usr/bin/osascript - << 'EOF'
    tell application "Terminal"
        activate
    end tell
EOF
}

##### Main
# 自動化に必要なSystem EventsとFolderActionsDispathcherのプライバシー設定
add_permissions_to_apps "Privacy_AllFiles" "/System/Library/CoreServices/System Events" "/System/Library/CoreServices/FolderActionsDispatcher"

# brew本体のインストール
install_brew

# ownCloudのインストールと同期の初期化
sync_owncloud

# ~/Libraryへのファイルコピー
install_Library_files

# アプリのインストール
install_bundle

# macOS環境設定
configure_macos

# ディスプレイ解像度の最大化
maximize_display_resolution

# macOSアプリ環境設定
configure_apps

# Terminalのプロファイル設定
import_terminal_profile "${HOME}/ownCloud/Settings/Pro_Custom.terminal"

# Desktopにフォルダアクションを設定
add_folder_action "${HOME}/Desktop" "rename_screenshots.workflow"

# メールアドレスの追加
add_email_address

# ownCloudの完全な同期
configure_owncloud

# Dropbox, OneDrive, Spectacle
add_permissions_to_apps "Privacy_Accessibility" "/Applications/Dropbox.app" "/Applications/Spectacle.app"
add_login_items "Dropbox" "/Applications/Dropbox.app" "/Applications/OneDrive.app" "/Applications/Spectacle.app" "/Applications/Brewlet.app"

# デスクトップ背景
set_desktop_picture

# .gitignoreグローバル設定
configure_global_gitignore

##### 手動設定項目
# ポータルサイト（Intune）設定
# ATOKライセンス設定
# 1Password設定
# Brewlet（デベロッパー未登録、開けない）
# Dockerアカウント設定
# Dropboxアカウント設定
# Jeditライセンス設定
# Office / Teams / OneDrive設定
# Parallels Desktopライセンス設定
# Dock設定
