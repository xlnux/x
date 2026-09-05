if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Run official automation if present (via kernel cmdline script=...)
if [ -x /root/.automated_script.sh ]; then
    /root/.automated_script.sh
fi

# X installer (text) when there is no automation via script= or xauto=1.
if [ "$(tty)" = "/dev/tty1" ] && ! grep -Fqa 'script=' /proc/cmdline && ! grep -Fqa 'xauto=1' /proc/cmdline; then
    if [ -x /root/x-installer/installer.sh ]; then
        bash /root/x-installer/installer.sh
    fi
fi
