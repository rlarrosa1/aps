#!/mnt/home/soft/aps/programs/x86_64/bash_4.4/bin/bash

# !/usr/bin/env bash

# This script sends the created jobs to the queue system(Slurm). Before that it checks if the job is already in the queue system or
# it has been completed successfully. You can select between send all the jobs or select a gruop of them.

. helper.sh


echo `date` Begin send_flow >> $LOG
echo `date` Begin send_flow >> $LOGERR

export order="-"
export suborder="-"

export l1=`cat $INPUTFILE|tail -n +2`

process_lines=`cd ${JOB_SOURCE};ls [1-9]*.sh|grep $PROCESS_LINE`
if test -n "$process_lines" ; then 
  l2=`cat $INPUTFILE|tail -n +2 |sed 's/[ \t]*$//' |awk -F'\n' '{print $0"_'$PROCESS_LINE'"}'|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"`
else
  unset l2
fi

export l3=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|grep $SYNC_JOB|sort -n| sed s#.sh##`

function show_help
{
        echo "-v             	verbose."
        echo "-d dir            only send directory dir."
        echo "-s script         only send script, can contain wildchars."
}

OPTIND=1  
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh"
export INFOFILE=information.out
export INFO=false
export VERBOSE=false                # ¿Sirven todas estas variables?
export CHECK_AFTER_ERR=false
export ACT_DIR=`pwd`
export LOGERR=`echo ${ACT_DIR}/error_sending.txt`

# Variables used to count the jobs that would be processed

let jobs_sent=0
let jobs_finished=0
let jobs_queued=0

let jobs_sent_total=0
let jobs_finished_total=0
let jobs_queued_total=0

# This loop will read the input parameters in the screen and it will perform the right acction depending on the parameters

while getopts "h?vd:s:i:a" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    v)  VERBOSE=true
        ;;
    d)  l1=$OPTARG
        unset l2
	unset l3
        ;;
    s)  FILTER_SCRIPTS=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if ! test -z  "$1" ; then
	echo
	echo ERROR: argument $1 unrecognized
	echo Help:
        show_help
        exit 0
fi

list_jobs=`find ${JOB_SOURCE} -iname ${FILTER_SCRIPTS} -exec basename {} \; |grep ^[1-9]| sort -n|awk -F_  '{print $1}'|uniq`
list_jobs_check=`find ${JOB_SOURCE} -iname ${FILTER_SCRIPTS} -exec basename {} \; |sort -n|awk -F_  '{print $1}'|uniq`
first_dir=`echo $l1|awk '{print $1}'`

# In the next validations we will control if there are jobs to process

if ! test -d "${first_dir}" ; then
  echo There seems to be no jobs. Before sending jobs the flow must be created using :
  echo aps_create_skeleton.sh
  exit 1
fi

if test -z "$list_jobs" ; then
  echo List of steps is empty, probably the filter is wrong.
  exit 1
fi

if test "$list_jobs" != "$list_jobs_check" ; then  
  echo Error in defined filter, it is wrong:
  echo ${FILTER_SCRIPTS}
  exit 1
fi

echo list_jobs $list_jobs

unset DEPENDarr
declare -A DEPENDarr
unset DEPENDtouse
declare -A DEPENDtouse
echo `date` Begin send flow >> $LOGERR
for i in $list_jobs ; do
# resets squeue cache
  echo -n Launching step $i ". "
  for ele in $l1 $l2 $l3 ; do
    rm $CACHE_SQUEUE_FILE 2> /dev/null
    pushd . > /dev/null
    if ! cd ${ele} 2> /dev/null ; then 
      continue
    fi
    let idx=1    
    for job in `ls ${FILTER_SCRIPTS}|grep ^${i}_`  ; do
      if grep "#SBATCH" $job > /dev/null ; then
        # The process checks if the jobs exits in the queue system
        if work_exists $ele `echo $job|sed s/.sh//`  ; then
  	    DEPENDarr[${ele},${i}]=`echo ${DEPENDarr[${ele},${i}]} "${ADD_DEPEND}"`
	      let jobs_queued=$jobs_queued+1
        # In case the jobs does not exist in the queue system, then 
        # we check if the job have finished successfully
        else
          if (! work_done_successfully $ele $job > /dev/null ) ; then
  	       output_file $ele $job 
            if ( test "x${OUTPUT_FILE}" == "x" ) || (test "x$FORCE" == "xtrue" ); then
	           prev_step=`previous_step $job`
	           if (echo ${job} |grep ${SYNC_JOB} > /dev/null ) ; then
		          DEPEND=`echo ${DEPENDtouse[@]}`
	           elif (echo ${job} |grep ${PROCESS_LINE} > /dev/null ) ; then	            
	          	DEPEND=`echo ${DEPENDtouse[@]}`
	           else
		          DEPEND=${DEPENDtouse[${ele},${prev_step}]}
		          for K in "${!DEPENDtouse[@]}"; do 
		           if (echo $K|grep $SYNC_JOB > /dev/null) || (echo $K|grep $PROCESS_LINE > /dev/null)  ; then
                echo SYNC INFO depend: ${prev_step} ele: ${K}  dep: ${DEPENDtouse[$K]} >> $LOG
		            DEPEND=`echo $DEPEND ${DEPENDtouse[$K]}`
		           fi
		          done
 	          fi
           # If there is a dependencie between jobs we will create it
	         DEPEND=`echo $DEPEND|tr " " ":"`
            if test -z "$DEPEND" && ( test "$i" -gt 1 ) ; then 
              echo ----- Creating dependencies job: $job i: $i >> $LOG
              create_dependencies $i $job $ele
	            export DEPEND=${ADD_DEPEND}
	            unset ADD_DEPEND
	          else
		         echo Known dependencies in job $job : $DEPEND  >> $LOG
            fi
	          if ! (echo ${job} |grep ${SYNC_JOB} > /dev/null ) || ( echo ${ele} | grep ${SYNC_JOB} > /dev/null ) ; then   
              send $job $ele
		          let jobs_sent=$jobs_sent+1
    	        rm $CACHE_SQUEUE_FILE 2> /dev/null
              if test "x$ADD_DEPEND" == "x" ; then
	  	         echo `date` ERROR sending job $job $i
	    	       exit 1
	            fi
	           DEPENDarr[${ele},${i}]=`echo ${DEPENDarr[${ele},${i}]} "${ADD_DEPEND}"`
	           let idx=$idx+1
            fi 
	        else 
	         echo `date` ERROR: Incorrect finish, but output file exists: rm ${ele}/${OUTPUT_FILE}
	         echo rm ${ele}/${OUTPUT_FILE} >> $LOGERR
	         echo rm ${ele}/${OUTPUT_FILE}|sed s/.out$/.err/ >> $LOGERR
 	         echo If there are several errors, it is better to check the workflow using:
	         echo aps_check_all.sh
	         exit 1
	        fi
        else
	       let jobs_finished=$jobs_finished+1
        fi
      fi
    fi
  done
 popd > /dev/null
done

unset DEPENDtouse
declare -A DEPENDtouse

for key in "${!DEPENDarr[@]}"
 do
   DEPENDtouse["$key"]="${DEPENDarr["$key"]}"
 done
 unset DEPENDarr
 declare -A DEPENDarr
 echo In step $i : jobs sent: $jobs_sent, jobs already finished: $jobs_finished, already queued: $jobs_queued
 let jobs_finished_total=$jobs_finished_total+$jobs_finished
 let jobs_sent_total=$jobs_sent_total+$jobs_sent
 let jobs_queued_total=$jobs_queued_total+$jobs_queued
 let jobs_sent=0
 let jobs_queued=0
 let jobs_finished=0
done

echo In total: jobs sent: $jobs_sent_total, jobs already queued: $jobs_queued_total, already finished: $jobs_finished_total

