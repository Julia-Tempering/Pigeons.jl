#/bin/bash

if [[ $# < 1  ]]; then
  echo "$0 [PBS allocation]"
  exit 0
fi

ALLOC=$1

wget http://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-7.0.1.tar.gz
gunzip osu-micro-benchmarks-7.0.1.tar.gz
tar xvf osu-micro-benchmarks-7.0.1.tar 
cd osu-micro-benchmarks-7.0.1/

module load intel-oneapi-compilers/2021.4.0

./configure CC=`which mpicc` CXX=`which mpicxx`
make

cd ..

cp osu-micro-benchmarks-7.0.1/c/mpi/pt2pt/osu_latency .

cat << EOF > pbs_script.sh
#!/bin/bash
#PBS -l walltime=00:10:00,select=2:ncpus=1:mpiprocs=1:mem=1gb
#PBS -l place=scatter
#PBS -A $ALLOC
#PBS -N latency
#PBS -o stdout.txt
#PBS -e stderr.txt
cd \$PBS_O_WORKDIR
module load openmpi
mpiexec ./osu_latency
EOF

qsub pbs_script.sh


