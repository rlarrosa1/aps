#!/usr/bin/env bash

# Esta carpeta tiene que contener los indices del genoma de referencia para las

export DIRS=`echo "${BASH_SOURCE%/*}/"`

#module purge

export LOG=$PWD/crea_trabajos.log
export LOGERR=$PWD/envia_trabajos.err

echo `date` to create files in `pwd` >> $LOG

function show_help
{
#        echo "-d dir            only check directory dir."
        echo "-s script         only copy given script, it can contain wildchars."
        echo "-d directory      only create files in given directory."
        echo "-i outfile        writes in outfile info from the output of the scripts, using job.info to extract it."
}

OPTIND=1
unset CHECK
export FILTER_SCRIPTS="[1-9]*.sh*"
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
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift


. ${DIRS}/helper.sh

if ! grep -w "${EXPERIMENTO}" ini*.sh |grep " EXPERIMENTO=" ; then
	echo ERROR : current dir does not contain an init file for experiment ${EXPERIMENTO}
	exit 2
fi

if ! aps_flow_check.sh ; then 
  echo Please, correct the errors before creating the flow files.
  exit 1
fi

let npac=1

# aplicaciones que se usen (botwie, samtools, bwa, ...)
#export GENOMA_REFERENCIA=/mnt/home/soft/human/data/hg38/hgdownload.cse.ucsc.edu/goldenPath/hg38/bigZips
#export ORIGEN_DATOS=/mnt/scratch/users/pab_001_uma/macarroyo/EGA/datos_originales/descomprimidos/
#export ORIGEN_DATOS=/mnt/scratch/users/pab_001_uma/macarroyo/EGA/rna/
pushd .

cabeceras=`head -1 $INPUTFILE|tr -s "\t" " "|sed 's/[ \t]*$//'|tr -s " " "_"`
let index=1
for i in `head -1 $INPUTFILE` ; do 
  arr[${index}]=$i
  let index=${index}+1
done

# echo ${arr[1]} ${arr[2]}
# num de elementos del array
# echo ${#arr[@]}
# todos los elementos
# echo ${arr[@]}



lista_scripts=`cd ${JOB_SOURCE};ls $FILTER_SCRIPTS|sort -n`

PROCESS_LINE_JOBS=`echo $lista_scripts|grep $PROCESS_LINE`

for job in $lista_scripts ; do
  # checks if this script process all the line at the same time
  if echo $job| grep $PROCESS_LINE > /dev/null ; then
 #   for i in `cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr -s " " "·"`; do
cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | while read i2 ; do 
      let index=1
#echo leido $i2 del file input
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
      cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#GENOMA_REFERENCIA#$GENOMA_REFERENCIA#g |sed s#ORIGEN_DATOS#${ORIGEN_DATOS}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
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
    cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#GENOMA_REFERENCIA#$GENOMA_REFERENCIA#g |sed s#ORIGEN_DATOS#${ORIGEN_DATOS}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
# TODO : fill  job so it processes all previous samples
    echo `date` sync job file for $job in $i created >> $LOG
    echo `date` sync job file for $job in $i created 
    chmod +x ${job}
    let npac=${npac}+1
    popd > /dev/null
#    if ! test -z "$PROCESS_LINE_JOBS" ; then 
#        comparative_dirs=`cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//'|tr " " "-"`
#    fi
# cat $INPUTFILE|tail -n +2|tr -s "\t" " "|sed 's/[ \t]*$//' | tr -s " " "-"|grep -| while read i2 ; do
if echo $lista_scripts | grep PROCESS_LINE; then
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
      cat ${REAL_JOB_SOURCE}/$job | sed s#SAMPLE#${i}#g |sed s#GENOMA_REFERENCIA#$GENOMA_REFERENCIA#g |sed s#ORIGEN_DATOS#${ORIGEN_DATOS}#g|sed s#TEMPORAL_DIR#${TEMPORAL_DIR}#g > ${job}
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

#export DEPENDS=`cat espera_todo.lis| awk '{print substr($0,1,length($0)-1)}'`
#export job_une=`${JOB_SOURCE}/envia.sh ${JOB_SOURCE}/5_unir_VCF.sh`
#chequea $job_une 5_unir_VCF.sh



