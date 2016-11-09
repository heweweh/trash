# trash

Something is used to android developping.

## usage

Before import things of trash you must import `build/envsetup.sh` of android complie system,
then, import the `trash/bucket.sh`. Things in the trash should be seen in your bash.

    $. ./build/envsetup.sh`
    $lunch <TARGET>
    $. ./trash/bucket.sh

## things

Here are things in trash.

* gdbtty

    If you want to debug with serial port via gdb<-->gdbserver, it's the thing.
    At first, you should run the gdbserver on your target board.

        #gdbserver /dev/ttyM --attach PID

    And, be sure with your have the permission of 'dailout' usergroup and type :

        $gdbtty /dev/ttyN BAUD EXECFILE

    Symbol files of solibs and execfile will be loaded automatically after you got the feedback of terminal.


* and more should be comming ..
