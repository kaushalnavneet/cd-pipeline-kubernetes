# Break Glass 

Break Glass support (aka Pipeline Run Export) allows users to export an existing Tekton pipeline that already runs in the CD Pipeline offering and run it manually on another cluster. 

There are 2 main parts to this support:
* Running an exported pipeline by itself
* Running an exported pipeline that calls a number of other exported pipelines (ie. *pipelines calling pipelines* or *subpipelines*)

Contents of this folder:
* decrypt.sh -  shell script for decrypting a downloaded pipeline payload (see Single Pipeline section for instructions)
* subpipe - folder that contains helper app and examples for running a local pipeline that calls another pipeline

## Single Pipeline


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
6. To decrypt each local pipeline:
  * `chmod +x decrypt.sh`
  * `decrypt.sh [localRun_file] [AES key]`
7. The decrypted file will be labeled with the name you gave the listener + a timestamp. For example:
```
tests-test-listener-local-2020-12-08-212904utc.json
```
8. Login to the cluster that is configured with an worker agent (any version > 0.8.3).
9. To run the pipeline use the kubectl cli: `kubectl create -f [FILENAME]`

### Tekton Dashboard


To observe the pipelines, it is suggested you install the local tekton dashboard:

1. `kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml`
2. Easiest way to view it is by using port-forward: `kubectl --namespace tekton-pipelines port-forward service/tekton-dashboard 9097:9097`
3. You can then watch the action by going to `http://localhost:9097/#/pipelineruns`


## Subpipelines

It can be convenient to organize an entire workflow amongst multiple pipelines and have a main pipeline invoke the other sub-pipelines as needed.

Unfortunately, this functionality is not built into Tekton at the moment. However with some helper apps and some careful writing of the tasks, it is possible to synthesize this workflow right now. For an in-depth explanation take a look at the [README.MD in the subpipes folder](https://github.ibm.com/org-ids/cd-pipeline-kubernetes/blob/master/breakglass/subpipe/README.md)
