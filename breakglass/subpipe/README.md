# Subpipelines

This folder contains a small node helper app and some examples of local pipelines calling pipelines.

## Folder contents:

* sample:
  * folder that contains .tekton folder with 3 different pipelines
  * pipelines-final.json - input file for the sample that maps constants used in the scripts to local files
* pipeline-entry.json - an example of an input file that overrides some params in the default pipeline
* subpipe.js - the node helper app that serves as an orchestrator for pipelines calling pipelines

## Pipelines Calling Pipelines

It can be convenient to organize an entire workflow amongst multiple pipelines and have a main pipeline invoke the other sub-pipelines as needed.

Unfortunately, Tekton does not offer this functionality nativel at the moment. However with some helper apps and some careful writing of the tasks, it is possible to synthesize this workflow right now.

For the purpose of this example, we will examine the pipelines contained in the sample/.tekon folder.

There are 3 folders inside .tekton, each containing a different pipeline:
* deploy
* main
* tests

Each pipeline is made up of 3 files, a listener file that contains a single listener, a pipeline file that defines the pipeline and tasks, and a task file that contains all the tasks required by the pipeline.

For this example, the main pipeline does some work and then kicks off the test pipeline. The main pipeline then waits around for the test pipeline to finish before starting off a deploy pipeline. The main pipeline once again waits for the deploy pipeline to finish before it finishes it's own last tasks.

### Synchronization Mechanics

In order to kick off and interact with other pipelines, there needs to some overall orchestrating component. This comes in the form of the helper nodejs application found in the subpipe folder called subpipe.js.

subpipe takes as input a json file that contains the start parameters - the name of the first pipeline to kick off as well as any parameters that need to be overwritten. Consider this sample pipeline entry file (called pipeline-entry.json):

```
{
    "pipeline": "main",
    "params": [
        {
            "task":"build-task",
            "name":"revision",
            "value":"bog/local"
        },{
            "task":"build-task",
            "name":"registryRegion",
            "value":"eu-gb"
        },{
            "task":"build-task",
            "name":"imageName",
            "value":"alpine"
            
        },{
            "task":"validate-task",
            "name":"repository",
            "value":"https://github.com/bogg/hello-tekton/tree/bog/local"
        }
      ],
      "mappings": [
          {
              "pipeline": "bog-pipeline",
              "file": "hello2-local.json"
          },
          {
            "pipeline": "main",
            "file": "mainpipe.json"
          }
      ]
  }
```

Some things to note:
* the mappings array contains a mapping of pipeline names -> local file names. The intent is to avoid having to touch your  Task code anytime you download a new exported version of a pipeline run. You can use the pipeline name in the script, put the current file name in the file: field of the mappings and the helper app will do the look up.
* the first pipeline entry is the pipeline name of the main pipeline to run
* the params array represent parameters in the tasks of the main pipeline that are to be replaced with the provided values

To see how a pipeline is supposed to call another pipeline, let's take a closer look at main_task.yaml in subpipe/sample/.tekton/main/. This file contains the main tasks for the main pipeline.

If you look carefully at the build-task job you'll notice this in the results section:
```
  results:
      - name: localpipeline-run-tests
        description: test pipeline to run - name mapped to real file in pipelines-final.json
      - name: localpipeline-run-tests-param-1
        description: sample param to pass to launched pipeline
```

This is the signaling mechansim from within a running pipeline. When the helper app detects one of these results, it will take the appropriate action and spin up the next pipeline.

Here is the actual code that writes out the values to the results. Something to notice:

* localpipeline-run-tests is used to write out the next pipeline mapping (the e2e-tests.json value has a mapping table look up entry that points to the real downloaded local pipeline file to use
* localpipeline-run-tests-param-1 contains the parameter override in the run-cleanup-tests job. This is the mechanism for overriding parameters in the next pipeling.

The format in the name is useful to observe as well:

localpipeline-run-[name_var] for pipelines
localpipeline-run-[name_var]-parama-[number] for parameters

You can have as many parameters as you want but [number] needs to be unique and the payload needs to exist (ie. task must actually exist in the pipeline etc)

```
    - name: launch-test-suite
      image: ibmcom/pipeline-base-image
      command: ["/bin/bash", "-c"]
      args:
        - set -e -o pipefail;
          echo "Launching test pipeline";
          echo -n "e2e-tests.json" > $(results.localpipeline-run-tests.path);
          echo -n "{\"task\":\"run-cleanup-tests\", \"name\":\"repository\", \"value\":\"https://github.com/bogg/orion.server\" }" > $(results.localpipeline-run-tests-param-1.path); 
 ```
 
 ### Waiting Mechanics 
 
 The split side of launching is being able to detect when a pipeline that you have launched has completed running. As a result of running the main pipeline with the helper app, the main pipeline has the ability to interact with the cluster and make kubectl calls.
 
 This allows you to write script in a task that queries the cluster to determine if a launched pipeline is finished. Consider the following block from the *wait-for-tests* job in the sample main_task.yaml:

```
    - name: wait-until-done
      image: ibmcom/pipeline-base-image:2.7
      command: ["/bin/bash", "-c"]
      args:
        - |
          set -e
          if [[ -z "${BREAK_GLASS}" ]]; then
            echo "Running in reguar mode, will curl for pipeline to finish"
          else
            echo "Break glass mode detected"
            while [ "$(kubectl get pipelinerun --selector tekton.dev/pipeline=e2e-tests,localsubpipelineid=$PIPELINE_SUB_ID --all-namespaces -o=custom-columns=NAME:.status.completionTime --no-headers)" == "<none>" ]; do
              echo "Waiting for pipleinerun in $latestns to finish"
              sleep 5
            done
            echo "Done!"
          fi
```

We first check to see if the BREAK_GLASS env var is defined (this gets automatically injected as an env var by the helper app when running pipeline calling pipeline). If we are in the break glass mode we make use of the kubectl cli (provided by the ibmcom/pipeline-base-image:2.7) to inspect the pipeline runs on the cluster.

```
"$(kubectl get pipelinerun --selector tekton.dev/pipeline=e2e-tests,localsubpipelineid=$PIPELINE_SUB_ID --all-namespaces -o=custom-columns=NAME:.status.completionTime --no-headers)" == "<none>" 
```

The point of interest here is the values used for the selector. In this case we are looking for a pipeline called e2e-tests. To look for another pipeline just change the name. For example:

```
--selector tekton.dev/pipeline=[PIPELINE NAME HERE],localsubpipelineid=$PIPELINE_SUB_ID 
```

The $PIPELINE_SUB_ID part is a unique identifier that gets automatically injected into each pipeline run. It allows you to distinguish the current pipeline run from previous ones. 

## Running the sample

Here are the step by step instructions on how to run the pipeline.

### Create Pipelines

1. Create a new toolchain and populate it with a new GitHub repo and 3 tekton pipelines called main, tests and deploy.
2. Clone your new GitHub repo locally and copy over the .tekton folder from this repo and push the changes.
3. In your main pipeline:
      * set the definition to your git repo and the path .tekton/main
      * create a new manual trigger
      * select a worker (either add/create a private worker or select the IBM Managed Worker)
4. In your tests pipeline:
      * set the definition to your git repo and the path .tekton/tests
      * create a new manual trigger
      * select a worker (either add/create a private worker or select the IBM Managed Worker)
5. In your deploy pipeline:
      * set the definition to your git repo and the path .tekton/deploy
      * create a new manual trigger
      * select a worker (either add/create a private worker or select the IBM Managed Worker)
      
Checkpoint: At this stage you should be able to run any of these pipelines normally from the UI. Note they aren't set up to call each other in the remote case so they will just run to completion.

### Export Pipeline Runs

In order to be able to run the pipeline locally, you first need to obtain a local copy of the pipeline run. To do this:

1. Generate a 256-bit AES key (for example from here https://www.allkeysgenerator.com/Random/Security-Encryption-Key-Generator.aspx). Make sure it is in hex format (there is an option in the www.allkeysgenerator.com for hex)
2. Repeat these steps for each pipeline (main, tests and deploy):
  * Click on the pipeline and go to the Other Settings tab.
  * Check the Enable Pipeline Run Export box and hit Save
  * Go the Environment Properties tab. Add a new secure property called `localrun_aes_key` and paste the generated hex AES key as the value. Hit Save when done.
3. To download the pipelines, click on Run Pipeline, check the Export Pipeline Run box and click Run. Instead of kicking off a new pipeline run, you will get a new file download called localRun. 
4. Once the file is downloaded, create a new work directory and copy the localRun file over.
5. Copy over the following utils from this repo to your work dir:
  * [decrypt.sh](https://github.ibm.com/org-ids/cd-pipeline-kubernetes/blob/master/breakglass/decrypt.sh)
  * [subpipe.js](https://github.ibm.com/org-ids/cd-pipeline-kubernetes/blob/master/breakglass/subpipe/subpipe.js)
6. To decrypt each local pipeline:
  * `chmod +x decrypt.sh`
  * `decrypt.sh [localRun_file] [AES key]`
7. The decrypted file will be labeled with the name you gave the listener + a timestamp. For example:
```
tests-test-listener-local-2020-12-08-212904utc.json
main-main-listener-local-2020-12-08-220425utc.json
deploy-deploy-listener-local-2020-12-08-220618utc.json
```

Checkpoint: At this stage you have exported and decrypted the pipeline runs locally.


### Setup Pipelines Calling Pipelines

Before running the main pipeline via the subpipe.js script, we need to provide an input file that details the main pipeline to run, any parameters we want to change in the main pipeline task and any mappings we might need in other pipelines. 

For this example we are going create a file that uses `main` as the main pipeline. We add entries to the mapping array that map main to the actual filename we decryped for the main file, and add other mappings for `e2e-tests.json` and `deployer.json`. 

In our scripts we will launch pipelines called e2e-tests.json and deployer.json. The subpipe.js script will use this mapping table to look up the files to use. This is done to allow us to write the scripts once and not have to change it every time a file name changes.

```
{
    "pipeline": "main",
      "mappings": [
          {
              "pipeline": "e2e-tests.json",
              "file": "tests-test-listener-local-2020-12-08-212904utc.json"
          },
          {
            "pipeline": "main",
            "file": "main-main-listener-local-2020-12-08-220425utc.json"
          },
          {
            "pipeline": "deployer.json",
            "file": "deploy-deploy-listener-local-2020-12-08-220618utc.json"
          }
      ]
  }
```

### Run Pipelines Calling Pipelines

Finally to run the pipeline, all we need to do is `node subpipe [INPUT FILE]`.

To observe the pipelines, it is suggested you install the local tekton dashboard:

1. `kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml`
2. Easiest way to view it is by using port-forward: `kubectl --namespace tekton-pipelines port-forward service/tekton-dashboard 9097:9097`
3. You can then watch the action by going to `http://localhost:9097/#/pipelineruns`
