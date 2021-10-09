#!/bin/bash

echo Creating an example experiment...

mkdir -p ~/example_experiment
cp -R ~/aps/worksteps ~/example_experiment

echo TEST1 TEST2 >> ~/example_experiment/samples_to_process.lis
echo 1 2 >> ~/example_experiment/samples_to_process.lis
echo 3 4 >> ~/example_experiment/samples_to_process.lis

echo export EXPERIMENT=example >> ~/example_experiment/init_experiment.sh
echo export INPUTDIR=~/example_experiment >> ~/example_experiment/init_experiment.sh
echo export INPUTFILE=~/samples_to_process.lis >> ~/example_experiment/init_experiment.sh
echo export JOB_SOURCE=~/example_experiment/worksteps >> ~/example_experiment/init_experiment.sh

chmod +x ~/example_experiment/init_experiment.sh

echo Example experiment has been created!
exit 0
