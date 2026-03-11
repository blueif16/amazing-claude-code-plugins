#!/bin/bash
# Cross-platform notification helper for CloudMate scripts.
# Source this file or copy the notify() function into scripts that use osascript.
#
# Usage:
#   source ~/.cc/notify.sh
#   notify "CloudMate" "PR merged successfully"
#
# Detection order:
#   1. WSL → PowerShell toast notification (visible in Windows Action Center)
#   2. Linux desktop → notify-send (GNOME/KDE/etc)
#   3. macOS → osascript
#   4. Fallback → echo to stderr (always works)

notify() {
    local title="${1:-CloudMate}"
    local message="${2:-}"

    # WSL: use PowerShell toast via BurntToast or basic balloon
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # Try BurntToast first (install: Install-Module -Name BurntToast)
        powershell.exe -NoProfile -Command "
            if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
                New-BurntToastNotification -Text '$title','$message' -Sound 'Default'
            } else {
                [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
                \$b = New-Object System.Windows.Forms.NotifyIcon
                \$b.Icon = [System.Drawing.SystemIcons]::Information
                \$b.BalloonTipTitle = '$title'
                \$b.BalloonTipText = '$message'
                \$b.Visible = \$true
                \$b.ShowBalloonTip(3000)
                Start-Sleep -Seconds 4
                \$b.Dispose()
            }
        " 2>/dev/null &
        return 0
    fi

    # Linux desktop: notify-send
    if command -v notify-send &>/dev/null; then
        notify-send "$title" "$message" 2>/dev/null &
        return 0
    fi

    # macOS: osascript
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null &
        return 0
    fi

    # Fallback: terminal
    echo "[$title] $message" >&2
}
