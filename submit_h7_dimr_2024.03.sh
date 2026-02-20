#! /bin/bash

# Usage:
#   - Modify this script where needed (e.g. number of nodes, number of tasks per node).
#   - Execute this script from the command line of H7 using:
#     sbatch submit_h7.sh
#
# This is an h7 specific script for single or multi-node simulations

#--- Specify Slurm SBATCH directives ------------------------------------------------------------------------
#SBATCH --nodes=1                                 # Number of nodes.
#SBATCH --ntasks-per-node=44                      # The number of tasks to be invoked on each node.
                                                  # For sequential runs, the number of tasks should be '1'.
                                                  # Note: SLURM_NTASKS is equal to "--nodes" multiplied by "--ntasks-per-node".
#SBATCH --job-name=WES_wq                            # Specify a name for the job allocation.
#SBATCH --time 10-00:00:00                        # Set a limit on the total run time of the job allocation.
#SBATCH --partition=44vcpu                        # Request a specific partition for the resource allocation.
                                                  # See: https://publicwiki.deltares.nl/display/Deltareken/Compute+nodes.
#SBATCH --mail-type=fail                          # Send an email when the job starts, stops, or fails.
#SBATCH --mail-user=Mario.FuentesMonjaraz@deltares.nl   # Specify the email address to which notifications are to be sent.


#--- Setup the model ----------------------------------------------------------------------------------------
# DIMR input-file
export dimrFile="dimr_config.xml"


#--- Setup the path to the DIMRSet --------------------------------------------------------------------------
dimrFolder=/p/d-hydro/dimrset/2024/2024.03/

# Set bash options. Exit on failures (and propagate errors in pipes).
set -eo pipefail

# Load the intelmpi module.
module load intelmpi/2021.10.0

# Set MPI options.
# Reference on intel MPI environment variables:
# https://www.intel.com/content/www/us/en/docs/mpi-library/developer-reference-linux/2021-8/environment-variable-reference.html
# https://www.intel.com/content/www/us/en/developer/articles/technical/mpi-library-2019-over-libfabric.html
export I_MPI_DEBUG=5
export I_MPI_FABRICS=ofi
export I_MPI_OFI_PROVIDER=tcp
export I_MPI_PMI_LIBRARY=/usr/lib64/libpmi2.so

D3D_HOME=${dimrFolder}/lnx64
BIN_DIR=${D3D_HOME}/bin
LIB_DIR=${D3D_HOME}/lib

# Configure environment variables and 'stacksize' limit.
ulimit -s unlimited
export PATH=$BIN_DIR:$PATH

# Set the library path to the `lib` folder in the dimrset
export LD_LIBRARY_PATH=$LIB_DIR:$LD_LIBRARY_PATH
export PROC_DEF_DIR=${D3D_HOME}/share/delft3d

export HDF5_USE_FILE_LOCKING=FALSE


# Replace number of processes in DIMR file
# You DO NOT need to modify the lines below.
PROCESSSTR="$(seq -s " " 0 $((SLURM_NTASKS-1)))"
sed -i "s/\(<process.*>\)[^<>]*\(<\/process.*\)/\1$PROCESSSTR\2/" $dimrFile

# Read MDU file from DIMR-file
export mduFile="$(sed -n 's/\r//; s/<inputFile>\(.*\).mdu<\/inputFile>/\1/p' $dimrFile)".mdu


# Partition by calling dflowfm executable
if [ $SLURM_NTASKS -gt 1 ]; then
    echo ""
    echo "Partitioning in folder ${PWD}"
    srun -n 1 -N 1 $BIN_DIR/dflowfm --nodisplay --autostartstop --partition:ndomains=$SLURM_NTASKS:icgsolver=6 $mduFile
else
    #--- No partitioning ---
    echo ""
    echo "No partitioning..."
fi

# Simulation by calling dimr executable
echo ""
echo "Computing "
srun $BIN_DIR/dimr $dimrFile
