

function gdbtty
{
    local OUT_ROOT=$(get_abs_build_var PRODUCT_OUT)
    local OUT_SYMBOLS=$(get_abs_build_var TARGET_OUT_UNSTRIPPED)
    local OUT_SO_SYMBOLS=$(get_abs_build_var TARGET_OUT_SHARED_LIBRARIES_UNSTRIPPED)
    local OUT_EXE_SYMBOLS=$(get_abs_build_var TARGET_OUT_EXECUTABLES_UNSTRIPPED)
    local PREBUILTS=$(get_abs_build_var ANDROID_PREBUILTS)
    local GDB_CLIENT_CMDS=gdbtty.cmds

    if [ "$OUT_ROOT" -a "$PREBUILTS" ]; then

        local TERM="$1"
        if [ "$TERM" ] ; then
            TERM=$1
        else
            echo "error: need a terminal device name"
            return
        fi

        local BAUD="$2"
        if [[ "$BAUD" =~ ^[0-9]+$ ]] ; then
            BAUD=$2
        else
            echo "error: need a baud-rate setting"
            return
        fi


        local EXE="$3"
        if [ "$EXE" ] ; then
            EXE=$3
        else
            echo "error: need a process name with symbols"
            return
        fi

        echo "Tips:"
        echo ""
        echo " If you haven't done so already, do this first on the device:"
        echo "     gdbserver /dev/tty[N] /system/bin/$EXE"
        echo " or"
        echo "     gdbserver /dev/tty[N] --attach PID"
        echo ""
        echo " If you got a 'Permission denied' prompt while open $TERM,"
        echo " try to get a right permission with add you user to dialout :"
        echo "     sudo adduser $(who | awk '{if(1==NR)print $1 }') dialout"
        echo " AND logout or change the access permission immediately : "
        echo "     sudo chmod a+rw $TERM"
        echo ""

        echo >|"$OUT_ROOT/$GDB_CLIENT_CMDS" "set solib-absolute-prefix $OUT_SYMBOLS"
        echo >>"$OUT_ROOT/$GDB_CLIENT_CMDS" "set solib-search-path $OUT_SO_SYMBOLS"
        echo >>"$OUT_ROOT/$GDB_CLIENT_CMDS" "target remote $TERM"
        echo >>"$OUT_ROOT/$GDB_CLIENT_CMDS" ""

        local EXEC_EABI_GDB=$(find $ARM_EABI_TOOLCHAIN -name "*gdb")

        # echo " you parameters:"
        # echo "   prebuilts             :$PREBUILTS"
        # echo "   solib-absolute-prefix :$OUT_SYMBOLS"
        # echo "   solib-search-path     :$OUT_SO_SYMBOLS"
        # echo "   gdb commands          :$OUT_ROOT/$GDB_CLIENT_CMDS"
        # echo "   gdb binary            :$EXEC_EABI_GDB"

        if [ -x "$EXEC_EABI_GDB" ] ; then
            $EXEC_EABI_GDB -q -b $BAUD -x "$OUT_ROOT/$GDB_CLIENT_CMDS" "$OUT_EXE_SYMBOLS/$EXE"
        fi
    else
        echo "Unable to determine build system output dir."
    fi

}

