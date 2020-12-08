# Break Glass 

Break Glass support (aka Pipeline Run Export) allows users to export an existing Tekton pipeline that already runs in the CD Pipeline offering and run it manually on another cluster. 

There are 2 main parts to this support:
* Running an exported pipeline by itself
* Running an exported pipeline that calls a number of other exported pipelines (ie. *pipelines calling pipelines* or *subpipelines*)

Contents of this folder:
* decrypt.sh -  shell script for decrypting a downloaded pipeline payload (see Single Pipeline section for instructions)
* subpipe - folder that contains helper app and examples for running a local pipeline that calls another pipeline

## Single Pipeline

## Subpipelines

It can be convenient to organize an entire workflow amongst multiple pipelines and have a main pipeline invoke the other sub-pipelines as needed.

Unfortunately, Tekton does not offer this functionality nativel at the moment. However with some helper apps and some careful writing of the tasks, it is possible to synthesize this workflow right now. For an in-depth explanation take a look at the [README.MD in the subpipes folder](https://github.ibm.com/org-ids/cd-pipeline-kubernetes/blob/master/breakglass/subpipe/README.md)
