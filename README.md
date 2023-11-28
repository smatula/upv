# upv
Update Platform Version

```.
├── data
│   ├── rosa-sts-hypershift-lp-interop-jobs.json
│   └── self-managed-lp-interop-jobs.json
├── README.md
└── upv.sh
```

Contains the upv.sh script used to update platform version for the openshift-ci lp interop scenarios.  It also contains json files that can be used as input to the script. Finally this README file.

## USE
1. Clone this repo to local machine.
2. If going to use one of the json files verify it contains all jobs desired.
   If not, contact appropriate person to obtain latest trigger file from vault.
   Verify all the jobs desired to update are marked active.
3. Change directory (cd) to top level directory of the openshift-ci repo - 'release'.
4. Execute script with file or a signle job

        upv.sh [options] -o ver -n ver [-f file | jobname]

   for more info execute
    
        upv.sh --help
   
### upv.sh scipt
Script to update lp interop scenarios to run on new platform version.  
1. Creates new config with proper name.
2. Updates config to have correct platform version.
3. Updates cron to be 2 days ago.
4. Performs git add to new config file.
5. Run make update
6. Update jobs to contain correct slack notification for new job.
7. Performs git add to new/updated jobs file.

 
