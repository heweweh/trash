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
        INNER_LIMIT=10
    fi

    INNER_SYMBOLS_PATH=$(dirname $INNER_SYMBOLS_PATH/.)

    local TMPAWK=$(mktemp)
    local TMPSH=$(mktemp)

    local TMSCPT=''
    TMSCPT+='BEGIN{cnt=0;}'
    TMSCPT+='{'
    TMSCPT+='    printf "echo \"%s\"\n", $0;'
    TMSCPT+='    if ($2 ~ /pc/) {'
    TMSCPT+='        addr = $3;'
    TMSCPT+='        file = $4; '
    TMSCPT+='        printf "addr2line -a %s -e \"$(locate -l 1 -r %s.*%s$)\"\n", addr, path, file;'
    TMSCPT+='        cnt++;'
    TMSCPT+='    }'
    TMSCPT+='    if (cnt >= limit) exit;'
    TMSCPT+='}'
    echo $TMSCPT 1> $TMPAWK

    awk -f $TMPAWK -v path=$INNER_SYMBOLS_PATH -v limit=$INNER_LIMIT $INNER_C_R_FILE 1> $TMPSH

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
        echo ""
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

        echo -n "Please enter your storm username:"
        read FTP_USER
        if [ -z "$FTP_USER" ] ;  then
            echo "error: need a tombstone file."
            return 1
        fi

        echo -n "Please enter your password:"
        read -s  FTP_PASSWD
        if [ -z "$FTP_PASSWD" ] ;  then
            echo "error: need a password."
            return 1
        fi
        echo ""

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


