#!/bin/bash

echo Creating an example experiment...

mkdir ../example_experiment
cd ../example_experiment
cp -R ../aps/worksteps .

echo TEST1 TEST2 >> samples_to_process.lis
echo 1 2 >> samples_to_process.lis
echo 3 4 >> samples_to_process.lis

echo export EXPERIMENT=example >> init_experiment.sh
echo export INPUTDIR=$PWD >> init_experiment.sh
echo export INPUTFILE=${INPUTDIR}/samples_to_process.lis >> init_experiment.sh
echo export JOB_SOURCE=${INPUTDIR}/worksteps >> init_experiment.sh

chmod +x init_experiment.sh

echo Example experiment has been created!
exit 0
