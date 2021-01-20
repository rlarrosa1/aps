#!/usr/bin/env bash

export DIRS=`echo "${BASH_SOURCE%/*}/"`
export LOG=$PWD/works.log
export LOGERR=$PWD/works_trace.err

echo `date` to create files in `pwd` >> $LOG

function show_help
{
        echo "-s script         Only copy given script, it can contain wildchars."
        echo "-d directory      Only create files in given directory."
        echo "-i outfile        Writes in outfile info from the output of the scripts, using job.info to extract it."
}

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh*"
export INFO=false
export VERBOSE=false

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


. ${DIRS}/helper.sh

if ! grep -w "${EXPERIMENT}" ini*.sh |grep " EXPERIMENT=" ; then
	echo ERROR : current dir does not contain an init file for experiment ${EXPERIMENT}
	exit 2
fi

if ! aps_flow_check.sh ; then 
  echo Please, correct the errors before creating the flow files.
  exit 1
fi

let npac=1

pushd .

let index=1
for i in `head -1 $INPUTFILE` ; do 
  arr[${index}]=$i
  let index=${index}+1
done

script_list=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|sort -n`

PROCESS_LINE_JOBS=`echo $script_list|grep $PROCESS_LINE`

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
      export orden="-"
      export suborden="-"
      export DEPEND=""
      export orden_act=`echo $job|tr "_" " "|awk '{print $1}'`
      export suborden_act=`echo $job|tr "_" " "|awk '{print $2}'`
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
# TODO : fill  job so it processes all previous samples
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
      export orden="-"
      export suborden="-"
      export DEPEND=""
      export orden_act=`echo $job|tr "_" " "|awk '{print $1}'`
      export suborden_act=`echo $job|tr "_" " "|awk '{print $2}'`
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
