const fs = require("fs");
const k8s = require('@kubernetes/client-node');
const { KubernetesObjectApi } = require("@kubernetes/client-node");
const { strict } = require("assert");


const PIPELINE_SERVICE_ACCOUNT = {
    "apiVersion": "v1",
    "kind": "ServiceAccount",
    "metadata": {
      "name": "agent-localpipeline",
      "namespace": ""
    }
  };

const CLUSTER_ROLE_BINDING = {
    "kind": "ClusterRoleBinding",
    "apiVersion": "rbac.authorization.k8s.io/v1",
    "metadata": {
      "name": ""
    },
    "subjects": [
      {
        "kind": "ServiceAccount",
        "name": "agent-localpipeline",
        "namespace": ""
      }
    ],
    "roleRef": {
      "apiGroup": "rbac.authorization.k8s.io",
      "kind": "ClusterRole",
      "name": "cluster-admin",
    }
  }

let pipelineMappings = [];

function clone(obj) {
	return JSON.parse(JSON.stringify(obj));
}

async function readFromFile(file) {
    return new Promise((resolve, reject) => {
        fs.readFile(file, function (err, data) {
            if (err) {
                console.log(err);
                reject(err);
            }
            else {
                resolve(JSON.parse(data));
            }
        });
    });
}


function printUsage() {
    console.log("Usage: node simple.js [pipeline.json]\n")
    console.log("pipeline.json format:")
    let input = {
        "main": "{pipeline: [EXPORTED PIPELINE JSON], params: [{}, {}]}",
        "mappings": [
            {
                "file_alias": "[EXPORTED PIPELINE JSON]",
            }
          ]
      };
    console.log(JSON.stringify(input));
}

function addToStep(step, name, value) {
        let newStep = {name: name, value: value};
        if (!step.env) {
            step.env = [];
        }
        step.env.push(newStep);
    
    return step;
}

function injectEnvVar(element, name, value) {
    if (element.spec.steps) {
        let steps_final = element.spec.steps.map(step => addToStep(step, name, value));
        element.spec.steps = steps_final;
    }
    return element;
}

function subInSteps(steps, element) {
    if (steps.env) {
        for (let index = 0; index < steps.env.length; index++) {
            let currentStep = steps.env[index];
            let currentVal = currentStep.value.replace("$(params.", "");
            currentVal = currentVal.slice(0, -1);
            if (currentVal === element.name) {
                currentStep.value = element.value;
            }
        }
    }
    return steps;
}

function subInParams(params, element) {
    if (params.name === element.name && params.default) {
        params.default = element.value;
    }
    return params;
}

function subInResource(resource, params) {
    let temp = JSON.parse(resource);
    if (temp.kind === "Task") {
        if (params) {
            for (let index = 0; index < params.length; index++) {
                const element = params[index];
                if (temp.metadata.name === element.task) {
                    //first go through params and look for defaults
                    let steps_params = temp.spec.params.map(param => subInParams(param, element));
                    temp.spec.params = steps_params;
                    //next go through each step and override the env var
                    let steps_final = temp.spec.steps.map(step => subInSteps(step, element));
                    temp.spec.steps = steps_final;
                }
            }
        }
        return JSON.stringify(temp);
    }
    return resource;
}

function lookupMapping(resource, pipeline) {
    return (resource.pipeline && resource.pipeline === pipeline)
}
async function subParams(blob) {
    let pipeline = blob.pipeline;
    let params = blob.params;
        //check for any mapping
    let pipelineFile = pipeline;
    if (pipelineMappings.length > 0) {
        let map = pipelineMappings.filter(element => lookupMapping(element, pipeline));
        if (map.length > 0) {
            pipelineFile = map[0].file;
        }
    }
    //mapfile
    mainFile = await readFromFile(__dirname + "/" + pipelineFile);
    let finalResources = (mainFile.spec.payload.resources).map(resource => subInResource(resource, params));
    mainFile.spec.payload.resources = finalResources;
    return mainFile;
}

const kc = new k8s.KubeConfig();
kc.loadFromDefault();
const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const k8sApps = kc.makeApiClient(k8s.AppsV1Api);
const k8sRbac = kc.makeApiClient(k8s.RbacAuthorizationV1Api);

const asr = k8s.KubernetesObjectApi.makeApiClient(kc);
async function create(kobj) {
    let res =  await asr.create(kobj);
    return res;
}

async function deleteKube(kobj) {
    let res =  await asr.delete(kobj);
    return res;
}

async function createClusterRolebinding(kobj) {
    let res = await k8sRbac.createClusterRoleBinding(kobj);
    return res;
}

async function deleteClusterRolebinding(kobj) {
    let res = await k8sRbac.deleteClusterRoleBinding(kobj.metadata.name);
    return res;
}


let inputFile = process.argv.slice(2);

let res;
console.log("===============================");
console.log("Reading input file " + inputFile);
if (inputFile.length == 0) {
    printUsage();
    process.exit(1);
}

(async() => {

res = await readFromFile(__dirname + "/" + inputFile);
//extract mappings
if (res.mappings) {
    pipelineMappings = res.mappings;
}
//do substitutions
let mainFile =  await subParams(res);

//get ns
let main_pipeline_id =  Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
let timestamp =  new Date(Date.now());
let date = timestamp.getFullYear().toString() +  (timestamp.getMonth() + 1).toString() + timestamp.getDate().toString() + timestamp.getUTCHours().toString() + timestamp.getUTCMinutes().toString() + timestamp.getUTCSeconds().toString();
let generated_namespace =  "pw-" + main_pipeline_id + "-local-" + date;

//grant super powers
let permissions = [];

let localServiceAccount = clone(PIPELINE_SERVICE_ACCOUNT);
localServiceAccount.metadata.namespace = generated_namespace;
permissions.push(JSON.stringify(localServiceAccount));

let finalResources = (mainFile.spec.payload.resources).map(resource => {
    let temp = JSON.parse(resource);
    if (temp.kind === "Namespace") {
        temp.metadata.name = generated_namespace;
        return JSON.stringify(temp);
    }
    if (temp.kind === "PipelineRun") {
        temp.metadata.namespace = generated_namespace;
        //add Service Account
        temp.spec.serviceAccountName = "agent-localpipeline";
        temp.metadata.labels = {localmainpipelineid: main_pipeline_id};
        return JSON.stringify(temp);
    } else if (temp.kind === "Task") {
        temp.metadata.namespace = generated_namespace;
        //add ENV VAR with sub id
        injectEnvVar(temp, "PIPELINE_SUB_ID", main_pipeline_id);
        injectEnvVar(temp, "BREAK_GLASS", "true");
        return JSON.stringify(temp);
    }
    temp.metadata.namespace = generated_namespace;
    return JSON.stringify(temp);
});

mainFile.spec.payload.resources = finalResources.concat(permissions);

//keep track of namespaces generated
let pipelinerun_ns  = {};
//array for cleaning up
let appliedPipelines = []
let appliedClusterRoleBinding = {};

pipelinerun_ns[generated_namespace] = {"done": false, counter: 0};
//generate script files
console.log("Creating cluster role binding...");
appliedClusterRoleBinding = clone(CLUSTER_ROLE_BINDING);
let clusterRoleBindingName = "agent-localpipeline-role-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
appliedClusterRoleBinding.metadata.name = clusterRoleBindingName;
appliedClusterRoleBinding.subjects[0].namespace = generated_namespace;
let b_res = await createClusterRolebinding(appliedClusterRoleBinding);
console.log("Starting main pipeline....");
appliedPipelines.push(mainFile);
let a_res = await create(mainFile);

let calledPipelines = {};

async function launchPipeline(pipelineMap) {  
    Object.entries(pipelineMap).forEach(async ([key, value]) => {
        if (!calledPipelines[key]) {
            calledPipelines[key] = "true";
            let nextFile = await subParams(value);
            //let pr_namespace = extractNamespace(nextFile);
            let generated_namespace =  "pw-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15) + "-local";
            pipelinerun_ns[generated_namespace] = {"done": false, counter: 0};
            //
            let finalResources = (nextFile.spec.payload.resources).map(resource => {
                let temp = JSON.parse(resource);
                if (temp.kind === "Namespace") {
                    temp.metadata.name = generated_namespace;
                    return JSON.stringify(temp);
                }
                if (temp.kind === "PipelineRun") {
                    temp.metadata.namespace = generated_namespace;
                    temp.metadata.labels = {localsubpipelineid: main_pipeline_id};
                    return JSON.stringify(temp);
                } 
                temp.metadata.namespace = generated_namespace;
                return JSON.stringify(temp);
            });
            
            nextFile.spec.payload.resources = finalResources;
            //
            console.log("Starting pipeline from pipeline...")
            appliedPipelines.push(nextFile);
            let a_res = await create(nextFile);
        }
      });
    
}

//pipline runs
const listFn2 = () => k8sApi.listNamespacedPod(generated_namespace);
const pipelinerun_path = "/apis/tekton.dev/v1beta1/pipelineruns";
const pipelinerun_watch = new k8s.Watch(kc);
const pipelinerun_cache = new k8s.ListWatch(pipelinerun_path, pipelinerun_watch, listFn2);
const looper2 = async () => {
    const prlist = pipelinerun_cache.list();
    //console.log(pipelinerun_ns.length);
    if (prlist) {
        for (let i = 0; i < prlist.length; i++) {
            Object.entries(pipelinerun_ns).forEach(([key, value]) => {
                if (value.done && value.counter > 6) {
                    //already checked for done, waited enough iterations, remove from list
                    delete pipelinerun_ns[key]
                } else if  (value.done) {
                    //already checked for done, increment counter
                    let count = value.counter + 1;
                    pipelinerun_ns[key] = {"done": true, counter: count};
                } else {
                    //full check
                    if (prlist[i].metadata.namespace.startsWith(key)) {
                        if (prlist[i].status && prlist[i].status.completionTime) {
                            console.log("Pipeline Run done " + prlist[i].metadata.namespace);
                            let count = value.counter + 1;
                            pipelinerun_ns[key] = {"done": true, counter: count};
                        }
                    }
                }
            }); 
            if (Object.keys(pipelinerun_ns).length === 0) {
                console.log("All Pipeline Runs complete");
                //clean up cluster role binding + localpipelines here
                console.log("Cleaning up ...")
                for (let i = 0; i < appliedPipelines.length; i++) {
                    await deleteKube(appliedPipelines[i]);
                }
                await deleteClusterRolebinding(appliedClusterRoleBinding);
                console.log("Done")
                console.log("===============================")
                process.exit();
            }
        }
    }
    setTimeout(looper2, 2000);
}
looper2();

const path = "/apis/tekton.dev/v1beta1/taskruns";
const watch = new k8s.Watch(kc);

const listFn = () => k8sApi.listNamespacedPod(generated_namespace);
const cache = new k8s.ListWatch(path, watch, listFn);

const looper = async () => {
    const list = cache.list();
    if (list) {
        let names = [];
        for (let i = 0; i < list.length; i++) {
            names.push(list[i].metadata.name);
            if (list[i].status && list[i].status.taskResults) {
                var pipelineName = /localpipeline-run-[a-zA-z0-9]+$/;
                //var pipelineNameParam = /localpipeline-run-[a-zA-z0-9]+-param-[a-zA-Z0-9_]+-[a-zA-Z0-9_]+$/;
                var pipelineNameParam = /localpipeline-run-[a-zA-z0-9]+-param-\d+$/;
                let pipelineMap = {};
                for (let index = 0; index < list[i].status.taskResults.length; index++) {
                    let taskResultName = list[i].status.taskResults[index].name;
                    let taskResultValue = list[i].status.taskResults[index].value;
                    if (taskResultName.match(pipelineName)){
                        let alreadyCalled = calledPipelines[taskResultName];
                        if (!alreadyCalled) {
                            //check to see if entry already exists, might have encountered param first
                            let entry = pipelineMap[taskResultName];
                            if (!entry) {
                                pipelineMap[taskResultName] = {pipeline: taskResultValue};
                            }
                            console.log("Detected a new pipeline to call: " + taskResultValue);
                        }
                    } else if (taskResultName.match(pipelineNameParam)) {
                        let sub = taskResultName.lastIndexOf("-param-");
                        let pipelineName = taskResultName.substring(0, sub);
                        let alreadyCalled = calledPipelines[pipelineName];
                        if (!alreadyCalled) {
                            let entry = pipelineMap[pipelineName];
                            if (!entry) {
                                pipelineMap[pipelineName] = {params: [{name: taskResultName.substring(sub + 7), value: taskResultValue}]};
                            }
                            if (!entry.params) {
                                entry.params = [];
                            }
                            entry["params"].push(JSON.parse(taskResultValue));
                            pipelineMap[pipelineName] = entry;
                            console.log("Detected a new pipeline param: " +  list[i].status.taskResults[index].value);
                        }
                    }
                }
                //run new pipeline
                await launchPipeline(pipelineMap);
            }
          

        }
        //console.log(names.join(','));
    }
    setTimeout(looper, 2000);
}

looper();

})();


