#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;33m'
NC='\033[0m' # No Color

function Usage() {
    echo "Usage: $0 job_name nr_proc nr_threads"
    echo ""
    echo "where:"
    echo "     job_name  : Name of the job"
    echo "     nr_proc   : Nr of processors to run with"
    echo ""
}
if [ $# -lt 2 ] ; then
    echo -e "${RED}Not all arguments were provided to the script!\n${NC}"
    Usage
    exit 
fi
JOB_NAME=$1
CORES=$2

sbatch <<EOT
#!/bin/bash
#SBATCH --job-name="$JOB_NAME"
#SBATCH --partition=compute
#SBATCH --account=Education-EEMCS-honours
#SBATCH --time=03:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task="$CORES"
#SBATCH --cpu-freq=high
#SBATCH --mem=20GB
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=<your_email>
#SBATCH --output=%x_%j.out

module load 2023r1

function Separator(){
    echo "============================================="
}

echo -e "${RED}shell.sh is: ${NC}"
echo -e "${CYAN}"
cat shell.sh
echo -e "${NC}"

Separator

echo -e "${GREEN}"
echo "Git data:"
git config color.ui auto
git log -1 --pretty
echo -e "${NC}"
Separator

echo -e "${CYAN}"
echo 'JOB DATA:'
echo "job name    : \$SLURM_JOB_NAME"
echo "job id      : \$SLURM_JOBID"
echo "job account : \$SLURM_JOB_ACCOUNT"
echo "job threads : $CORES"
echo "nr proc     : \$SLURM_CPUS_PER_TASK"

echo ""
echo "job start   : $(date)"
echo -e "${NC}"

Separator
echo 'Job started'
srun julia --project=. --threads $CORES src/iterators/meta_search/main.jl 
Separator

echo -e "${RED}End     : $(date)${NC}"

echo "Job done!"
Separator

echo "Stats about the cpu usage"
echo -e "${GREEN}"
seff \$SLURM_JOBID

echo -e "${NC}"
exit 0

EOT
echo "Submitted job with name: $JOB_NAME and cores : $CORES"

jobs
