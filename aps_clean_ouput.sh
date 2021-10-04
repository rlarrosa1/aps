#ª/bin/bash 

# The goal of this script is clean the output files. Depending of the experiment we can find hundreds of files
# and probable some of them are empty or they´re meanless.

. helper.sh


export l1=`cat $INPUTFILE|tail -n +2`

while read i2 ; do
      export tmp=`echo $i2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
      export i=`echo ${tmp}_${PROCESS_LINE}`
      export l2=`echo $l2 $i`
done < <(cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"|grep - )



function show_help
{
	echo "-d dir 		only clean directory dir."
	echo "-s script 	only clean script."
	echo "-e 		delete output files (.out & .err)"
}


function clean_job
{
  clean=`grep ^#CLEAN $2|sed "s/#CLEAN //"`
  if echo $clean | grep "\"" > /dev/null ; then 
    cmd=`echo $clean |awk  '{split($0,a,"\"");print a[1]}'`
    var=`echo $clean|awk  '{split($0,a,"\"");print a[2]}'`
    outfiles=`echo $clean|awk  '{split($0,a,"\"");print a[3]}'`
    if $cmd "${var}" $outfiles > /dev/null 2>&1 ; then
      return 0
    else 
      return 1
    fi
  elif echo $clean |grep find > /dev/null ; then
    cmd=`echo $clean |awk  '{split($0,a," ");print a[1]}'`
    outfiles=`echo $clean|awk  '{split($0,a," ");print a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10]}'`
    if test `$cmd $outfiles | wc -l` != 0  > /dev/null 2>&1 ; then
      return 0
    else    
      return 1
    fi
  else
    cmd=`echo $clean |awk  '{split($0,a," ");print a[1]}'`
    outfiles=`echo $clean|awk  '{split($0,a," ");print a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9],a[10]}'`
    if eval $cmd $outfiles > /dev/null 2>&1 ; then
      return 0
    else
      return 1
    fi
  fi
}



OPTIND=1  
unset CHECK
export FILTER_SCRIPTS="bbaaaaaaaash"
export INFOFILE=information.out
export INFO=false
export VERBOSE=false

let nerrors=0
let unexec=0
let nchecks=0

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
    e)  DEL_OUTPUTFILES=true
        ;;
    i)  INFOFILE=$OPTARG
	INFO=true
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift


for i in $l1 $l2 ; do
  pushd . > /dev/null
  if ! cd $i 2> /dev/null ; then    
    continue
  fi
  list_scripts=`ls $FILTER_SCRIPTS 2>/dev/null`
  for job in $list_scripts ; do
    let nchecks=${nchecks}+1
    if grep SBATCH $job > /dev/null ; then
     if work_exists $i $job > /dev/null 2>&1 ; then
      echo `date` job $job from sample $i is in the queue system.
     else
     if clean_job $i $job ; then
      if test $VERBOSE == "true" ; then
       echo `date` job $job from sample $i has finished correctly
	    fi
	    if test $INFO == "true" ; then
       ./$job.get_info >> $INFOFILE	  
      fi
     else
      if ! output_file $i $job ; then
       echo `date` job $job from sample $i never has been run, no output file exists.
    	 let unexec=${unexec}+1
      else
       echo `date` job $job from sample $i has finished with errors, outputfile: $OUTPUT_FILE
	     if ! test -z "$DEL_OUTPUTFILES" ; then
	      echo borrando ficheros de salida de $i
	      rm ${i}/${OUTPUT_FILE}
	      error=`echo ${i}/${OUTPUT_FILE}|sed s/.out/.err/`
	      rm $error
	     fi
       let nerrors=${nerrors}+1
       break
      fi
     fi
    fi
   fi
  done
  echo `date` checked sample $i with `echo $list_scripts|wc -w` scripts, with $nerrors errors in total
  popd > /dev/null
done

echo `date` $nchecks jobs have been checked with $nerrors errors found, and $unexec jobs that have never been run.
exit 0
