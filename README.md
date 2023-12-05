# upv
Update Platform Version

```
.
├── data
│   ├── rosa-sts-hypershift-lp-interop-jobs.json
│   ├── rosa-sts-hypershift-lp-interop-jobs.txt
│   ├── self-managed-lp-interop-jobs.json
│   └── self-managed-lp-interop-jobs.txt
├── README.md
└── upv.sh

Contains the upv.sh script used to update platform version for the openshift-ci lp interop scenarios.  It also contains json and txt files that can be used as input to the script. Finally this README file.
The data directory contains sample input files.

## USE
1. Clone this repo to local machine.
2. If going to use one of the input files verify it contains all jobs desired.
   Verify the platform version of jobs in file matches the old/source platform version using.
   If not, contact appropriate person to obtain latest trigger file from vault or
   you may update the text file version manually.
   If json file input verify all the jobs desired to update are marked active.
3. Change directory (cd) to top level directory of the openshift-ci repo - 'release'.
4. Execute script with input file or a job/s

        upv.sh [options] -o ver -n ver [-i file | jobname]

        ex. json file input:

            <path>/upv.sh -o 4.15 -n 4.16 -i <path>/upv/data/self-managed-lp-interop-jobs.json

        ex. text file input:

            <path>/upv.sh -o 4.15 -n 4.16 -t -i <path>/upv/data/self-managed-lp-interop-jobs.txt

        ex. single jobname

            <path>/upv.sh -o 4.15 -n 4.16 periodic-ci-quay-quay-tests-master-ocp-415-quay39-quay-e2e-tests-quay39-ocp415-lp-interop

        ex. multiple jobnames

            <path>/upv.sh -o 4.15 -n 4.16 periodic-ci-redhat-developer-odo-main-odo-ocp4.15-lp-interop-odo-scenario-aws periodic-ci-syndesisio-syndesis-qe-1.15.x-fuse-online-ocp4.15-lp-interop-fuse-online-interop-aws periodic-ci-redhat-developer-service-binding-operator-release-v1.4.x-4.15-acceptance-lp-interop

   for more info on options and arguments run

        upv.sh --help

### upv.sh script
Script to update lp interop scenarios to run on new platform version.
1. Creates new config with proper name.
2. Updates config content to have correct platform version.
3. Updates cron in config to be 2 days prior current date.
4. Performs git add for new config file/s.
5. Runs make update
6. Update periodic jobs to contain correct slack notification for new job.
7. Performs git add to new/updated jobs files (periodic and presubmits) if exist.
8. Check output for ERRORs and WARNINGs.
9. Verify changes.
 
