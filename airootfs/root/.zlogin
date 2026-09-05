if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

# Run official automation if present (via kernel cmdline script=...)
if [ -x /root/.automated_script.sh ]; then
    /root/.automated_script.sh
fi

# Instalador x (texto) cuando no hay automatizacion via script=.
if [ "$(tty)" = "/dev/tty1" ] && ! grep -Fqa 'script=' /proc/cmdline; then
    if [ -x /root/x-installer/installer.sh ]; then
        bash /root/x-installer/installer.sh
    fi
fi
