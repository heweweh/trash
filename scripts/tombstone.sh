#!/bin/bash

function tombstone
{
    local INNER_C_R_FILE=$1
    local INNER_SYMBOLS_PATH=$2
    local INNER_LIMIT=$TOMBSTONE_LIMIT

    if [ ! -r "$INNER_C_R_FILE" ] ; then
        echo "error: need a readable file of crash repot"
        return 1
    fi

    if [ ! -d "$INNER_SYMBOLS_PATH" ] ; then

        INNER_SYMBOLS_PATH=$(get_abs_build_var TARGET_OUT_UNSTRIPPED)
        if [ -d "$INNER_SYMBOLS_PATH" ] ; then
            echo "warning: using local symbol path. "
            echo "  (which is $INNER_SYMBOLS_PATH)"
        else
            return 1
        fi
    fi

    if [ -z "$INNER_LIMIT" ] ; then
        INNER_LIMIT=32
    fi

    INNER_SYMBOLS_PATH=$(dirname $INNER_SYMBOLS_PATH/.)

    local TMPAWK=$(mktemp)
    local TMPSH=$(mktemp)

    local TMPSCPT=''
    TMPSCPT+='BEGIN{cnt=0;}'
    TMPSCPT+='{'
    TMPSCPT+='    printf "echo \"%s\"\n", $0;'
    TMPSCPT+='    if ($2 ~ /pc/) {'
    TMPSCPT+='        printf "TMP_SO_NAME=$(locate -l 1 -r %s.*%s$)\n", path, $4;'
    TMPSCPT+='        print  "if [ -r \"$TMP_SO_NAME\" ] ; then\n";'
    TMPSCPT+='        printf "    $ADDR2LINE -aCfe \"$TMP_SO_NAME\" %s\n", $3;'
    TMPSCPT+='        printf "    $NM -l -C -n -S \"$TMP_SO_NAME\" > tombstone/nm%s.data\n", $1;'
    TMPSCPT+='        printf "    $OBJDUMP -C -d \"$TMP_SO_NAME\" > tombstone/od%s.s\n", $1;'
    TMPSCPT+='        print  "fi\n";'
    TMPSCPT+='        cnt++;'
    TMPSCPT+='    }'
    TMPSCPT+='    else { '
    TMPSCPT+='        if (cnt > 0) exit;'
    TMPSCPT+='    }'
    TMPSCPT+='    if (cnt >= limit) exit;'
    TMPSCPT+='}'
    echo "$TMPSCPT" 1> $TMPAWK

    TMPSCPT=''
    TMPSCPT+='ADDR2LINE=$(find $ARM_EABI_TOOLCHAIN -name "*addr2line" -executable |head -n 1)\n'
    TMPSCPT+='NM=$(find $ARM_EABI_TOOLCHAIN -name "*nm" -executable |head -n 1)\n'
    TMPSCPT+='OBJDUMP=$(find $ARM_EABI_TOOLCHAIN -name "*objdump" -executable |head -n 1)\n'
    TMPSCPT+='if [ -x "$ADDR2LINE" -a -x "$NM" -a -x "$OBJDUMP" ] ; then\n'
    TMPSCPT+=$(awk -f $TMPAWK -v path=$INNER_SYMBOLS_PATH -v limit=$INNER_LIMIT $INNER_C_R_FILE | cat)
    TMPSCPT+='\necho ""\n'
    TMPSCPT+='fi\n'
    echo -e "$TMPSCPT" 1> $TMPSH

    if [ "$DEBUG" == "true"  ] ; then
        echo "=== DEBUG INFORMATION ==="
        echo "path:"$INNER_SYMBOLS_PATH
        echo "file:"$INNER_C_R_FILE
        echo "=== temporary awk script($TMPAWK) ==="
        cat $TMPAWK
        echo "=== temporary shell script($TMPSH) ==="
        cat $TMPSH
        echo "=== ==="
    fi

    cat $TMPSH > 1.txt
    if [ ! -d "tombstone" ] ; then
        mkdir tombstone
    fi
    . $TMPSH

    rm $TMPAWK
    rm $TMPSH
}

function tombstone_symbol_sync
{
    local REMOTE_RELEASE_URL='ftp://172.26.181.33/Release/18JTACS/APL/18cyavn_release/'
    local REMOTE_SYMBOL_FILE='_ENGALPS/symbols.tar.gz'

    if [ -z "$1" ] ;  then
        echo "error: need a tombstone file."
        return 1
    fi

    if [ ! -d "$2" ] ; then
        echo "error: need a path to extract symbol files."
        return 1
    fi

    local SUB_PATH=$(grep -e "Build fingerprint" $1 | awk -F /  '{split($3,A,":"); printf "%s_%s",$6,A[2];}')
    if [ -z "$SUB_PATH" ] ; then
        echo "error: there is no build fingerprint in this file."
        return 1
    fi

    local TOMBSTONE_SYMBOL_PATH=$(dirname $2/.)/$SUB_PATH
    local NEED_REEXTRACT=1

    if [ -d "$TOMBSTONE_SYMBOL_PATH" ] ; then
        read -p "confirm: the path that extracting to is exsits. overwrite it?[y/N]:" -n 1 CONFIRM
        echo -e "\n"
        case $CONFIRM in
            Y|y)NEED_REEXTRACT=1
                ;;
            *)  NEED_REEXTRACT=0
                echo "dowloading was skipped."
                ;;
        esac
    else
        NEED_REEXTRACT=1
        mkdir $TOMBSTONE_SYMBOL_PATH
    fi

    if [ "1" == "$NEED_REEXTRACT" ] ; then

        read -p "Please enter your storm username:" FTP_USER
        if [ -z "$FTP_USER" ] ;  then
            echo "error: need a tombstone file."
            return 1
        fi

        read -s -p "Please enter your password:" FTP_PASSWD
        echo -e "\n"
        if [ -z "$FTP_PASSWD" ] ;  then
            echo "error: need a password."
            return 1
        fi
        echo -e "\n"

        if [ "$DEBUG" == "true" ] ; then
            echo "DEBUG:"
            echo "extract to path:"$TOMBSTONE_SYMBOL_PATH
            echo "user:"$FTP_USER
            echo "passwd:"$FTP_PASSWD
        fi

        local TMP_FILE=$(mktemp "XXXXXXXX.tar.gz")
        wget \
            --ftp-user=$FTP_USER \
            --ftp-password=$FTP_PASSWD \
            --output-document=$TMP_FILE \
            ${REMOTE_RELEASE_URL}${SUB_PATH}${REMOTE_SYMBOL_FILE}

        if [ "0" != "$?" ] ; then
            rm $TMP_FILE
            echo "error: error occurs while downloading symbol file."
            return 1
        fi

        echo "extracting... please wait for a while."
        tar -xzf $TMP_FILE -C $TOMBSTONE_SYMBOL_PATH
        if [ "0" != "$?" ] ; then
            rm $TMP_FILE
            echo "error: error occurs while downloading symbol file."
            return 1
        fi
        echo "done."

        rm $TMP_FILE

    fi

    echo "Analizing file (which is $1), "
    echo "with symbol files in $TOMBSTONE_SYMBOL_PATH"
    tombstone $1 $TOMBSTONE_SYMBOL_PATH
}


