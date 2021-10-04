#!/bin/bash 

# The goal of this script is check the current status of the job and counting how many of them have finished
# succesfully, have ended with errors, are running, are waiting and so on.
# In adition to that, the script creates a text file with the folders that should be deleted because they have 
# some failure.

. helper.sh

# The script starts populating variable l1 with the names of the colums within the input text file. 
# The name of the previous colums will be formatted and allocated in l2 like column1-column2-column3.
# And in l3 variable the list of template scripts will be saved.

export l1=`cat $INPUTFILE|tail -n +2`

process_lines=`cd ${JOB_SOURCE};ls [1-9]*.sh|grep $PROCESS_LINE`
if test -n "$process_lines" ; then 
  l2=`cat $INPUTFILE|tail -n +2 |sed 's/[ \t]*$//' |awk -F'\n' '{print $0"_'$PROCESS_LINE'"}'|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"`
else
  unset l2
fi

export l3=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|grep $SYNC_JOB|sort -n| sed s#.sh##`

# The next function is used to show a menu of the different options to the user in case it is needed

function show_help
{
	echo "-d dir 		only check directory dir."
	echo "-s script 	only check script."
	echo "-i suffix  	writes information about the jobs, one file per script, using scriptname with suffix as the filename."
        echo "			It uses the *.get_info scripts to extract the info."
	echo "-a 		check all scripts in case of error, doesn't stops at the first error of a sample."
}

# Initializing some variables like boolean values, filter criteria and error file.

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh"
export INFOFILE=information.out
export INFO=false
export VERBOSE=false
export CHECK_AFTER_ERR=false
export CLEAN_ERRS="commands_to_clean_errors.txt"

let nerrors=0
let unexec=0
let nchecks=0

# This loop will read the input parameters in the screen and it will perform the right acction depending on the parameters

while getopts "h?vd:s:i:a" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    a)  CHECK_AFTER_ERR=true
        ;;
    v)  VERBOSE=true
        ;;
    d)  l1=$OPTARG
        unset l2
	;;
    s)  FILTER_SCRIPTS=$OPTARG
	;;
    i)  INFOFILE=$OPTARG
	INFO=true
	for i in *${INFOFILE} ; do 
		mv --backup=t $i ${i}.bck
	done
        ;;
    esac
done

# The next command it´s used to move to the next input parameter of the script

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

echo \# `date` Begin check > $CLEAN_ERRS

rm $CACHE_SQUEUE_FILE 2> /dev/null

for i in $l1 $l2 $l3 ; do
 pushd . > /dev/null
 if ! cd $i 2> /dev/null ; then
  # If there is no directory
  continue
 fi
 scripts_list=`ls $FILTER_SCRIPTS 2>/dev/null`
 for job in $scripts_list ; do
  let nchecks=${nchecks}+1  
  if grep \#SBATCH $job > /dev/null ; then
  # The queue system is checked to verify if the job has been added in the queue.  
   if work_exists $i $job ; then
    echo `date` Job $job from sample $i is in the queue system, with id: $ADD_DEPEND.
    # If the job is not in the queue then the script checks if the job has successfully finished.
   else
    if work_done_successfully $i $job ; then
     if test $VERBOSE == "true" ; then
      echo `date` Job $job from sample $i has finished correctly
	   fi
	  if test $INFO == "true" ; then
     if test -f ${REAL_JOB_SOURCE}/${job}.get_info ; then 
      ${REAL_JOB_SOURCE}/$job.get_info $i >> ../${job}.${INFOFILE}
	   fi
    fi
  else  
   if ! output_file $i $job ; then
    echo `date` Job $job from sample $i never has been run, no output file exists.
    let unexec=${unexec}+1
   elif [ -s $OUTPUT_FILE ]
   then
    echo rm ${i}/${OUTPUT_FILE} >> ../${CLEAN_ERRS}
    echo rm ${i}/${OUTPUT_FILE}|sed s/.out/.err/ >> ../${CLEAN_ERRS}
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

# In case there are erros the next message is displayed.

if test $nerrors -gt 0 ; then 
  echo
  echo To repeat the failed jobs you can do :
  echo . ${CLEAN_ERRS}
fi

exit 0
