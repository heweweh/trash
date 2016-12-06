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
