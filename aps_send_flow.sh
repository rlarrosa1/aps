#!/mnt/home/soft/aps/programs/x86_64/bash_4.4/bin/bash

# !/usr/bin/env bash

#export PATH=/mnt/home/soft/aps/programs/x86_64/bash_4.4/bin/:$PATH


. helper.sh


echo `date` Begin send_flow >> $LOG
echo `date` Begin send_flow >> $LOGERR

export orden="-"
export suborden="-"

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
export VERBOSE=false
export CHECK_AFTER_ERR=false
export ACT_DIR=`pwd`
export LOGERR=`echo ${ACT_DIR}/error_sending.txt`

let nerrors=0
let unexec=0
let nchecks=0

let jobs_sent=0
let jobs_finished=0
let jobs_queued=0

let jobs_sent_total=0
let jobs_finished_total=0
let jobs_queued_total=0

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
#echo BB ele: $ele i:$i
    rm $CACHE_SQUEUE_FILE 2> /dev/null
    pushd . > /dev/null
    if ! cd ${ele} 2> /dev/null ; then 
      continue
    fi
    let idx=1

    # en el dir $ele lanza todos los que toquen
    for job in `ls ${FILTER_SCRIPTS}|grep ^${i}_`  ; do
      if grep "#SBATCH" $job > /dev/null ; then
# primero mira si ya existe en el sistema de colas
        if existe_trabajo $ele `echo $job|sed s/.sh//`  ; then
  	  DEPENDarr[${ele},${i}]=`echo ${DEPENDarr[${ele},${i}]} "${ADD_DEPEND}"`
	  let jobs_queued=$jobs_queued+1

   #     echo job $job exists DEPEND= ${ADD_DEPEND} $DEPENDarr[$idx]
   # si no existe mira si ya ha terminado correctamente
        else
          if (! trabajo_terminado_correctamente $ele $job > /dev/null ) ; then
  	    trabajo_con_fichero_salida $ele $job 
            if ( test "x${OUTPUT_FILE}" == "x" ) || (test "x$FORCE" == "xtrue" ); then
	      prev_step=`previous_step $job`
#echo prev_step= $prev_step : $job >> $LOG
	      if (echo ${job} |grep ${SYNC_JOB} > /dev/null ) ; then
#		for j in "${DEPENDtouse[@]}"; do
#		  DEPEND=`echo $DEPEND "$j"` 
#		done
#echo en SYNC : $job >> $LOG
		DEPEND=`echo ${DEPENDtouse[@]}`
	      elif (echo ${job} |grep ${PROCESS_LINE} > /dev/null ) ; then
	# por ahora dependen de todos 
#		for j in "${DEPENDtouse[@]}"; do
#		  DEPEND=`echo $DEPEND "$j"` 
#		  echo job : $job depend: $DEPEND  j: $j
#		done
#echo en PROCESS_LINE $JOB >> $LOG
		DEPEND=`echo ${DEPENDtouse[@]}`
	      else
#echo INFO : ${prev_step} ele: ${ele}  dep: ${DEPENDtouse[${ele},${prev_step}]} >> $LOG
		DEPEND=${DEPENDtouse[${ele},${prev_step}]}
		for K in "${!DEPENDtouse[@]}"; do 
		  if (echo $K|grep $SYNC_JOB > /dev/null) || (echo $K|grep $PROCESS_LINE > /dev/null)  ; then
 echo SYNC INFO depend: ${prev_step} ele: ${K}  dep: ${DEPENDtouse[$K]} >> $LOG
		    DEPEND=`echo $DEPEND ${DEPENDtouse[$K]}`
		  fi
		done
 	      fi
#echo BB3 JJ1 i:$i 
	      DEPEND=`echo $DEPEND|tr " " ":"`
              if test -z "$DEPEND" && ( test "$i" -gt 1 ) ; then
#echo BB4 i:$i 
                echo ----- LLamar a crea_dependencias $orden_act job: $job i: $i >> $LOG
                crea_dependencias $i $job $ele
	        export DEPEND=${ADD_DEPEND}
	        unset ADD_DEPEND
	      else
		echo las dependencias ya se conocen en job $job : $DEPEND  >> $LOG
              fi
	      if ! (echo ${job} |grep ${SYNC_JOB} > /dev/null ) || ( echo ${ele} | grep ${SYNC_JOB} > /dev/null ) ; then  
#echo BB5 i:$i 
                envia $job $ele
#echo BB6 i:$i 
		let jobs_sent=$jobs_sent+1
    	        rm $CACHE_SQUEUE_FILE 2> /dev/null
                if test "x$ADD_DEPEND" == "x" ; then
	  	   echo `date` ERROR enviando job $job $i
	    	   exit 1
	        fi
#echo BB7 i:$i 
	        DEPENDarr[${ele},${i}]=`echo ${DEPENDarr[${ele},${i}]} "${ADD_DEPEND}"`
#echo assign ${ele},${i} depend : ${DEPENDarr[${ele},${i}]}
	        let idx=$idx+1
              fi 
#echo BB JJ i:$i 
	    else 
	      echo `date` ERROR: incorrect finish, but output file exists: rm ${ele}/${OUTPUT_FILE}
	      echo rm ${ele}/${OUTPUT_FILE} >> $LOGERR
	      echo rm ${ele}/${OUTPUT_FILE}|sed s/.out$/.err/ >> $LOGERR
 	      echo If there are several errors, it is better to check the workflow using:
	      echo aps_check_all.sh
	      exit 1
	    fi
          else
#	    echo job $i $job already finished fine 
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

