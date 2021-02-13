#!/usr/bin/env bash

# This script will create a directory per sample in addition to other directories for unification phase.
# Inside of that directories we will find other scripts needed for the program created by the templates
# specified by the user in JOB_SOURCE enviroment variable.


# Definition of LOG variables
export DIRS=`echo "${BASH_SOURCE%/*}/"`
export LOG=$PWD/works.log
export LOGERR=$PWD/works_trace.err

echo `date` to create files in `pwd` >> $LOG

# The next function is used to show a menu of the different options to the user in case it is needed

function show_help
{
        echo "-s script         Only copy given script, it can contain wildchars."
        echo "-d directory      Only create files in given directory."
        echo "-i outfile        Writes in outfile info from the output of the scripts, using job.info to extract it."
}

# Initializing some variables

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh*"
export INFO=false
export VERBOSE=false

# This loop will read the input parameters in the screen and it will perform the right acction depending on the parameters

while getopts "h?vd:s:i:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    v)  VERBOSE=true
        ;;
    d)  l1=$OPTARG
        unset l2
        ;;
    s)  FILTER_SCRIPTS=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

# With the next command, helper.hs is executed and all the validations, fuctions and other features allocated in that script
# will be executed

. ${DIRS}/helper.sh

# Checking the enviroment variable $EXPERIMENT and if it is properly populated. If not the flow will end.

if ! grep -w "${EXPERIMENT}" ini*.sh |grep " EXPERIMENT=" ; then
	echo ERROR : current dir does not contain an init file for experiment ${EXPERIMENT}
	exit 2
fi

# aps_flo_check.sh is other script which will do some validations and, in case of error, a message will appear in the terminal with
# the details and the process will end.

if ! aps_flow_check.sh ; then 
  echo Please, correct the errors before creating the flow files.
  exit 1
fi

let npac=1

pushd .

# The next loop checks the number of colums in our input data file

let index=1
for i in `head -1 $INPUTFILE` ; do 
  arr[${index}]=$i
  let index=${index}+1
done

# In the next variable will save the list of template scripts allocated in the variable $JOB_SOURCE

script_list=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|sort -n`

PROCESS_LINE_JOBS=`echo $script_list|grep $PROCESS_LINE`

# The next loop will create the jobs, folders and necesary files to execute the experiment

for job in $script_list ; do
  # checks if this script process all the line at the same time
  if echo $job| grep $PROCESS_LINE > /dev/null ; then
    cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | while read i2 ; do 
     let index=1
     for sam in `echo $i2|tr "·" " "` ; do
      sample[${index}]=$sam
      let index=${index}+1
     done
     export tmp=`echo $i2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
     export i=`echo ${tmp}_${PROCESS_LINE}`
     pushd . > /dev/null
     mkdir $i > /dev/null 2> /dev/null
     cd $i
     export order="-"
     export suborder="-"
     export DEPEND=""
     export act_order=`echo $job|tr "_" " "|awk '{print $1}'`
     export act_suborder=`echo $job|tr "_" " "|awk '{print $2}'`
     cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#REFERENCE_GENOME#$REFERENCE_GENOME#g |sed s#DATA_ORIGIN#${DATA_ORIGIN}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
      # changes the strings that are the names of the columns of the input file for their samples
     for idx in `seq 1 ${#arr[@]}` ; do
      sed -i s#${arr[${idx}]}#${sample[${idx}]}#g ${job}
     done
     echo `date` multisample job file for $job in $i created >> $LOG
     echo `date` multisample job file for $job in $i created 
     chmod +x ${job}
     let npac=${npac}+1
     popd > /dev/null
    done
  # checks if this script process all the data at the same time, so it needs the output of all previous jobs
  elif echo $job| grep $SYNC_JOB > /dev/null ; then
    pushd . > /dev/null
    i=`echo $job|sed s/.sh//`
    mkdir $i > /dev/null 2> /dev/null
    cd $i
    cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#REFERENCE_GENOME#$REFERENCE_GENOME#g |sed s#DATA_ORIGIN#${DATA_ORIGIN}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
    echo `date` sync job file for $job in $i created >> $LOG
    echo `date` sync job file for $job in $i created 
    chmod +x ${job}
    let npac=${npac}+1
    popd > /dev/null
    if echo $script_list | grep PROCESS_LINE; then
     while read i2 ; do
      export tmp=`echo $i2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
      export i=`echo ${tmp}_${PROCESS_LINE}`
      export l2=`echo $l2 $i`
     done < <(cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"|grep - )
    else
     unset l2
    fi
    for i in `cat $INPUTFILE|tr -s "\t" " "|sed 's/[ \t]*$//'|tail -n +2` $l2 ; do
      pushd . > /dev/null
      mkdir $i > /dev/null 2> /dev/null
      cd $i
      echo "job sync is needed at this point" > ${job}
      echo " SBATCH needed for detecting it is an script " >> ${job}
      grep CHECK ${REAL_JOB_SOURCE}/$job >> ${job}
      popd > /dev/null
    done
   else
    for i in `cat $INPUTFILE|tr -s "\t" " "|sed 's/[ \t]*$//'|tail -n +2`; do
      pushd . > /dev/null
      mkdir $i > /dev/null 2> /dev/null
      cd $i
      export order="-"
      export suborder="-"
      export DEPEND=""
      export act_order=`echo $job|tr "_" " "|awk '{print $1}'`
      export act_suborder=`echo $job|tr "_" " "|awk '{print $2}'`
      cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#REFERENCE_GENOME#$REFERENCE_GENOME#g |sed s#DATA_ORIGIN#${DATA_ORIGIN}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
      for idx in `seq 1 ${#arr[@]}` ; do
        sed -i s#${arr[${idx}]}#${sample[${idx}]}#g ${job}
      done
      echo `date` file for $job in $i created >> $LOG
      echo `date` file for $job in $i created 
      chmod +x ${job}
      let npac=${npac}+1
      popd > /dev/null
    done
fi

done

popd
echo `date` $npac files created >> $LOG
