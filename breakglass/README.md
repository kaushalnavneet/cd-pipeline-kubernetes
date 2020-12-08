# Break Glass 

Break Glass support (aka Pipeline Run Export) allows users to export an existing Tekton pipeline that already runs in the CD Pipeline offering and run it manually on another cluster. 

There are 2 main parts to this support:
* Running an exported pipeline by itself
* Running an exported pipeline that calls a number of other exported pipelines (ie. *pipelines calling pipelines* or *subpipelines*)


## Single Pipeline

## Subpipelines

It can be convenient to organize an entire workflow amongst multiple pipelines and have a main pipeline invoke the other sub-pipelines as needed.

Unfortunately, Tekton does not offer this functionality at the moment.
