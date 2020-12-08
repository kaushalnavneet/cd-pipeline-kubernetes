# Subpipelines

This folder contains a small node helper app and some examples of local pipelines calling pipelines.

Folder contents:

* sample:
  * folder that contains .tekton folder with 3 different pipelines
  * pipelines-final.json - input file for the sample that maps constants used in the scripts to local files
* pipeline-entry.json - an example of an input file that overrides some params in the default pipeline
* subpipe.js - the node helper app that serves as an orchestrator for pipelines calling pipelines
