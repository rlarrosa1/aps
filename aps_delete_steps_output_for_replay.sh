# The goal of this script is delete the output files of executed jobs in order to
# replay the experiment

. helper.sh


function show_help
{
        echo " Unfinished. work in progress, don't use"
	echo 
	echo " Program to delete automatically the output files of jobs that have failed."
	echo 
        echo "-d dir            only check directory dir."
        echo "-s script         only check script."
        echo "-i suffix         writes information about the jobs, one file per script, using scriptname with suffix as the filename."
        echo "                  It uses the *.get_info scripts to extract the info."
        echo "-a                check all scripts in case of error, doesn't stops at the first error of a sample."
}

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh"
export VERBOSE=false
export DELETE_FILES="delete_files_to_replay.sh"

let nerrors=0
let unexec=0
let nchecks=0

while getopts "h?vs:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    s)  FILTER_SCRIPTS=$OPTARG
        ;;
    v)  VERBOSE=true
        ;;
    esac
done

export l1=`cat $INPUTFILE|tail -n +2`

process_lines=`cd ${JOB_SOURCE};ls [1-9]*.sh|grep $PROCESS_LINE`
if test -n "$process_lines" ; then 
  l2=`cat $INPUTFILE|tail -n +2 |sed 's/[ \t]*$//' |awk -F'\n' '{print $0"_'$PROCESS_LINE'"}'|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"`
else
  unset l2
fi

export l3=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|grep $SYNC_JOB|sort -n| sed s#.sh##`

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

echo \# `date` Begin deletion > $DELETED_FILES


rm $CACHE_SQUEUE_FILE 2> /dev/null

for i in $l1 $l2 $l3 ; do
  pushd . > /dev/null
  if ! cd $i 2> /dev/null ; then
    continue
  fi
  lista_scripts=`ls $FILTER_SCRIPTS 2>/dev/null`
  for job in $lista_scripts ; do
    let nchecks=${nchecks}+1
    if grep \#SBATCH $job > /dev/null ; then
      if work_exists $i $job ; then
        echo `date` Job $job from sample $i is in the queue system, with id: $ADD_DEPEND.
      else
        if work_done_successfully $i $job ; then
          if test $VERBOSE == "true" ; then
            echo `date` Job $job from sample $i has finished correctly
          fi
          if ! trabajo_con_fichero_salida $i $job ; then
                echo `date` job $job from sample $i never has been run, no output file exists.
                let unexec=${unexec}+1
          else
            echo rm ${i}/${OUTPUT_FILE} >> ../${DELETE_FILES}
            echo rm ${i}/${OUTPUT_FILE}|sed s/.out/.err/ >> ../${DELETE_FILES}
  	        grep CHECK $job|sed s/\#CHECK// | sed s\#ls\ -l\#\# |sed s\#\|\#\# >> ../${DELETE_FILES}
            echo `date` job $job from sample $i has finished with errors, outputfile: $OUTPUT_FILE
            let nerrors=${nerrors}+1
          fi
        fi
      fi
    fi
  done
  echo `date` checked sample $i with `echo $lista_scripts|wc -w` scripts
  popd > /dev/null
done

echo `date` $nchecks jobs have been checked with $nerrors errors found, and $unexec jobs that have never been run.

if test $nerrors -gt 0 ; then 
  echo
  echo To repeat the failed jobs you can do :
  echo . ${DELETE_FILES}
fi

exit 0

