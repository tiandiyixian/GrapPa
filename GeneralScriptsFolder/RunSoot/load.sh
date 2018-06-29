#!/bin/bash
#Created by Giacomo Iadarola
#v1.0 - 22/05/18

function UsageInfo {
    echo "USAGE: ./load.sh [ -dgf PATH_DB_GRAPH_FOLDER ] [ -graph2vec TOOLNAME ]"
    echo -e "If '-dgf' not set, needs to be set DB_GRAPH_FOLDER in Config.txt!"
    echo -e "\t-graph2vec TOOLNAME: print graph on file as input format for TOOLNAME (see Readme for available TOOLNAME options)"
    echo -e "TOOLNAME list separated by semicolon : (Example: -graph2vec struc2vec:CGMM )"
    exit
}

function progrBar {
    #[##################################################] (100%)
    PAR=$1
    TOT=$2
    echo -e "\033[3A"
    echo "PROGRESS: $PAR out of $TOT"
    PER=$(bc <<< "scale = 2; ($PAR / $TOT) * 100")
    TEMPPER=$( echo $PER | cut -d'.' -f1)
    COUNT=0
    echo -ne "["
    while [ "$TEMPPER" -gt "0" ]; do
        TEMPPER=$(($TEMPPER-2))
        echo -ne "#"
        COUNT=$(($COUNT+1))
    done
    COUNT=$((50-$COUNT))
    for (( c=1; c<$COUNT; c++ )); do
        echo -ne "-"
    done  
    echo -ne "] ($PER%)"
    if ! [ -z "$PIDRUN" ]; then
        TIMERUN=$( ps -o etime= -p "$PIDRUN" )
        echo -ne " TIME:$TIMERUN"
    fi
    echo ""
}

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

rm -rf $SCRIPTPATH/loadBackup
mkdir $SCRIPTPATH/loadBackup
if [ -f $SCRIPTPATH/loadErrors.txt ]; then
    mv $SCRIPTPATH/loadErrors.txt $SCRIPTPATH/loadBackup/loadErrors.txt
fi
if [ -f $SCRIPTPATH/loadLog.txt ]; then
    mv $SCRIPTPATH/loadLog.txt $SCRIPTPATH/loadBackup/loadLog.txt
fi

if [ ! -f config.txt ]; then
    echo "ERROR! File config.txt not found! Exiting..."
    exit
fi

DB_GRAPH_FOLDER=$(cat config.txt | grep "DB_GRAPH_FOLDER" | cut -d"=" -f2)
CLASS_FOLDER=$(cat config.txt | grep "CLASS_FOLDER" | cut -d"=" -f2)
JAVA7_HOME=$(cat config.txt | grep "JAVA7_HOME" | cut -d"=" -f2)
SOOT_JAR=$(cat config.txt | grep "SOOT_JAR" | cut -d"=" -f2)
PROJECT_FOLDER=$(cat config.txt | grep "PROJECT_FOLDER" | cut -d"=" -f2)

if [ ! -d "$PROJECT_FOLDER" ]; then
    echo "ERROR: Set the PROJECT_FOLDER variable in config.txt! Exiting..."
    exit
elif [ ! -d "$DB_GRAPH_FOLDER" ]; then
    echo "ERROR: Set the DB_GRAPH_FOLDER variable in config.txt! Exiting..."
    exit
elif [ ! -d "$DB_GRAPH_FOLDER/original" ] || [ ! -d "$DB_GRAPH_FOLDER/mutated" ]; then
    echo "ERROR: The DB_GRAPH_FOLDER does not contain subfolders 'original' and 'mutated'! Exiting..."
    exit
elif [ ! -d "$JAVA7_HOME" ]; then
    echo "ERROR: Set the JAVA7_HOME variable in config.txt! Exiting..."
    exit
elif [ ! -f "$SOOT_JAR" ]; then
    echo "ERROR: Set the SOOT_JAR variable in config.txt! Exiting..."
    exit
fi

MYCP_JAVA=".:$CLASS_FOLDER:$SOOT_JAR"
#mvn -f $PROJECT_FOLDER clean
#mvn -f $PROJECT_FOLDER compile
if [ ! -d "$CLASS_FOLDER" ]; then
    echo "ERROR: Set the CLASS_FOLDER variable in config.txt! Exiting..."
    exit
fi

if [ "$#" -eq 0 ]; then
    #IF necessary for future features
    MODE="b"
else
    MODE="b"
    myArray=( "$@" )
    n=0
    while [ $n -lt $# ]; do
        if [[ "${myArray[$n]}" == "-dgf" ]]; then
            n=$(($n+1))
            DB_GRAPH_FOLDER="${myArray[$n]}"
            n=$(($n+1))
            if [ ! -d "$DB_GRAPH_FOLDER" ]; then
                echo "ERROR: Invalid DB_GRAPH_FOLDER! Exiting..."
                exit
            elif [ ! -d "$DB_GRAPH_FOLDER/original" ] || [ ! -d "$DB_GRAPH_FOLDER/mutated" ]; then
                echo "ERROR: The DB_GRAPH_FOLDER does not contain subfolders 'original' and 'mutated'! Exiting..."
                exit
            fi
        elif [ "${myArray[$n]}" == "-graph2vec" ];then
            n=$(($n+1))
            if [ -z "${myArray[$n]}" ]; then
                UsageInfo
            else
                GRAPH2VECTOOL="-graph2vec ${myArray[$n]}"
                n=$(($n+1))
            fi
        elif [[ "${myArray[$n]}" == "-help" ]]; then
            UsageInfo
        else
            UsageInfo
        fi       
    done
fi

echo -e "STARTING load.sh SCRIPT with DB_GRAPH_FOLDER as $DB_GRAPH_FOLDER"
if [ ! -z "$GRAPH2VECTOOL" ]; then
    echo -e "GRAPH2VEC tools: $GRAPH2VECTOOL"
fi

PIDRUN=$$
echo -e "\n" #for progrBar

#Only one mode for now
if [ "$MODE" == "b" ]; then
    TOTFILE=$(($(ls $DB_GRAPH_FOLDER/original | wc -l )+$(ls $DB_GRAPH_FOLDER/mutated | wc -l )))
    PARFILE=0
    for NEDOFILE in $DB_GRAPH_FOLDER/original/*.nedo; do
        progrBar $PARFILE $TOTFILE
        if [ -f $NEDOFILE ]; then
            $JAVA7_HOME/bin/java -cp $MYCP_JAVA \
                SourceCode.LoadCPG -cp $NEDOFILE $GRAPH2VECTOOL 2>> $SCRIPTPATH/loadErrors.txt 1>> $SCRIPTPATH/loadLog.txt
        fi
        if [ -f $SCRIPTPATH/loadErrors.txt ] && [ "$(cat $SCRIPTPATH/loadErrors.txt)" ]; then
            echo "ERROR!!! Look 'loadErrors.txt' for more information, exiting..."
            exit
        else
            PARFILE=$(($PARFILE+1))
        fi
    done
    for NEDOFILE in $DB_GRAPH_FOLDER/mutated/*.nedo; do
        progrBar $PARFILE $TOTFILE
        if [ -f $NEDOFILE ]; then
            $JAVA7_HOME/bin/java -cp $MYCP_JAVA \
                SourceCode.LoadCPG -cp $NEDOFILE $GRAPH2VECTOOL 2>> $SCRIPTPATH/loadErrors.txt 1>> $SCRIPTPATH/loadLog.txt
        fi
        if [ -f $SCRIPTPATH/loadErrors.txt ] && [ "$(cat $SCRIPTPATH/loadErrors.txt)" ]; then
            echo "ERROR!!! Look 'loadErrors.txt' for more information, exiting..."
            exit
        else
            PARFILE=$(($PARFILE+1))
        fi
    done
fi

echo "ENDING load.sh SCRIPT with DB_GRAPH_FOLDER as $DB_GRAPH_FOLDER"
exit
