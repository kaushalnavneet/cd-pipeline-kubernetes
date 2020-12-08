# Break Glass 

Break Glass support (aka Pipeline Run Export) allows users to export an existing Tekton pipeline that already runs in the CD Pipeline offering and run it manually on another cluster. 

There are 2 main parts to this support:
* Running an exported pipeline by itself
* Running an exported pipeline that calls a number of other exported pipelines (ie. *pipelines calling pipelines* or *subpipelines*)


## Single Pipeline

## Subpipelines

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
