#!/bin/bash
#PBS -l walltime=00:10:00,select=300:ncpus=1:mpiprocs=1:mem=8gb
#PBS -A st-alexbou-1
#PBS -N CDSCo0xw
#PBS -o stdout.txt
#PBS -e stderr.txt
cd $PBS_O_WORKDIR

module load git
module load gcc
module load intel-mkl
module load openmpi


touch started
mpiexec echo OK
touch finish
