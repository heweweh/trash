for f in `/bin/ls trash/scripts/*.sh 2> /dev/null`
do
    echo "including $f"
    . $f
done
unset f

