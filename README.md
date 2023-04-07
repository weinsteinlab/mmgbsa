# Table of contents:
- [Setup Environment](#setup-enviornment)
- [Calculation Setup](#calculation-setup)
  * [Editing ./scripts/setenv.sh](#editing-scriptssetenvsh)
  * [Editing ./RUN.sh](#editing-runsh)
  * [Editing ./top_files_mackerell](#editing-top_files_mackerell)
- [Running MM-GBSA](#running-mm-gbsa)
  * [Submitting the job](#submitting-the-job)
  * [Check job status](#check-job-status)
<!-- toc -->
---
# Setup Environment

This implementation of molecular mechanics-Generalized Born Surface Area (MM-GBSA) has several software dependencies:

*  VMD (v1.9.3)
*  CHARMM (Free Version 43b2)
*  Perl (v5.16.3)
*  Slurm (v17.02.7) # job scheduler

This code was built and tested against the software versions described above, but using other similar versions is *probably* fine (*caveat emptor*). Please consult each of the above's website for installation documentation.
<br>
<br>

---
# Calculation Setup

The first step in using these tools is to first clone a copy of this repository, in a directory that is appropriate for running this calculation:
```
cd wherever_you_wish_to_run
git clone git@github.com:weinsteinlab/mmgbsa.git
```

Optionally, you can rename the cloned repository to something meaningful for your calculations
```
mv mmgbsa my_mmgbsa_run
```
Once this is done, go into this directory:
```
cd my_mmgbsa_run # or whatever the directory is named at this point
```

**Note: directory is hereafter assumed to be your current working directory `./`**
<br><br>

## Editing ./scripts/setenv.sh
First, you will need to edit `./scripts/setenv.sh`, in which you must provide paths to the software dependencies described above. Specifically, you'll need to:
1. Edit: `export mmgbsa_path=/absolute/path/to/parent/mmgbsa` # this must be the absolute path to your MM-GBSA parent directory.<br><br>
Next, you'll see 2 `if` blocks. This gives you the ability to set different paths to software dependencies for different clusters/file systems.<br><br>
2. For each `if` block, you'll see several `[[  $HOSTNAME = cluster_node_name  ]]` Simply change `cluster_node_name` to whatever your cluster uses for compute node names. The first `if` block has 3 of these names, but you really only need to edit one of them (you can keep the extraneous `[[]]` or delete them-it doesn't make a difference).<br><br>
3. Within each `if` block, you'll need to change the absolute path to CHARMM, VMD, and Perl.
<br><br>
## Editing ./RUN.sh

1. Edit `mmgbsa_path`. This must be the absolute directory path to the parent MM-GBSA directory.<br><br>
2. You will also need to define the following variables that define the system, interacting partners, input files, etc. (each is described in `./RUN.sh`):
    * system_selection # should only include two protein/molecules of interest
    * partA_selection= # first interacting protein/molecule
    * partB_selection= # first interacting protein/molecule
    * cutoff_residues= # controls which residues are included in decomposition, unless manual definitions are provided (via the next to variables described)
    * partA_residues_selection= # Part A residues to include in per-residue energy decomposition
    * partB_residues_selection= # Part B residues to include in per-residue energy decomposition
    * traj= # absolute path to your trajectory file--.dcd or . xtc can be used.<br><br>
3. You will also need to edit the following variables that control job parallelization:
    * start_frame= # first frame in the dcd file to use (index-1)
    * frame_stride= # e.g., if set to 2, only use every other trajectory frame
    * frames_per_job= # number of frames per subjob. The smaller this number is, the more subjobs that will be run (where each subjob runs on its own CPU core)
    * n_jobs= # how many subjobs. Should equal ceiling(frames/frames_per_job)
    * max_jobs_running_simultaneously= # consider limiting the number of concurrently running subjobs if on a shared cluster.
    * queueing_system= # should be "SLURM" (most robustly tested), though "LSF" and "SGE" are implemented.
    * queue_name= # Slurm partition to use for subjobs<br><br>
4. More variables related to the model investigated:
    * proteins= # number of proteins in the system
    * For each protein, you'll need the following lines:
        capping[1]= # is the first protein/peptide's n-term capped? 0 for no, 1 for yes.
        capping[2]= # is the first protein/peptide's n-term capped? 0 for no, 1 for yes.
        <br><br>
        *the next protein would continue incrementing the capping number: capping[3], capping[4], ...*<br><br>

## Editing ./top_files_mackerell
* The directory `./top_files_mackerell` should include all of the `./.prm`, `./.rtf`, and `./.str` files used to run the simulation.

## Adding input files
1. Create the directory `input` with the following command in the parent directory `mkdir input`
2. Add the following files to `input:
    * your system's .psf file
    * a .pdb of the first frame of the trajectory

<br>

---
# Running MM-GBSA
After performing all of the above edits, you're ready to submit the job! I would recommend launching the job from an interactive job session (i.e., not the login/submission node), as the job submission has brief interludes of non-trivial computation.<br><br>
## Submitting the job
To submit the job, first run the following command, which does some pre-job setup (in the parent directory):
`./scripts/generate_loader_str.sh` # note, this command is **NOT** submitted with `sbatch`!

Once the prior command returns, run the following command in the parent directory: `./RUN.sh` # note, this command is **NOT** submitted with `sbatch`! Follow on-screen prompts and instructions. This script will setup and submit all of the needed subjobs.
<br><br>
Running this script will take anywhere from 2-10 minutes.
<br><br>
## Check job status
The status of the MD swarm can be checked with the following command:

```
squeue -u your_username
```