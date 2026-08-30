if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Run official automation if present (via kernel cmdline script=...)
if [ -x /root/.automated_script.sh ]; then
    /root/.automated_script.sh
fi

# Run X live session (graphical installer)
if [ -x /usr/bin/x-live-session ]; then
    bash /usr/bin/x-live-session
fi
