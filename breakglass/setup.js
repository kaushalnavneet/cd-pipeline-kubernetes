const fs = require("fs");

const PIPELINE_CONFIG_MAP = {
	"apiVersion": "v1",
	"kind": "ConfigMap",
	"metadata": {
        "name": "",
        "namespace": ""
	},
	"data": {}
};

const PIPELINE_CONFIG_MAP_KEYREF = {
        "name": "",
        "valueFrom": {
          "configMapKeyRef": {
            "name": "configmapname",
            "key": ""
          }
        }
};

const PIPELINE_SERVICE_ACCOUNT = {
    "apiVersion": "v1",
    "kind": "ServiceAccount",
    "metadata": {
      "name": "agent-localpipeline",
      "namespace": ""
    }
  };

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

function processAdditionalPipeline(element) {
    return new Promise(async (resolve, reject) => {
        let payload = await readFromFile(__dirname + "/" + element.file);
        if (payload) {
            let pipe = {};
            pipe.payload = payload;
            pipe.config_name = element.config_name;
            resolve(pipe);
        } else {
            reject();
        }
    });
}

function addToStep(step, resources) {
    for (let index = 1; index < resources.length; index++) {
        const element = resources[index];
        let newStep = clone(PIPELINE_CONFIG_MAP_KEYREF);
        newStep.name = element.config_name;
        newStep.valueFrom.configMapKeyRef.name = element.config_name;
        newStep.valueFrom.configMapKeyRef.key = "pipeline";
        if (!step.env) {
            step.env = [];
        }
        step.env.push(newStep);
    }
    return step;
}

function injectConfigMaps(element, resources) {
    let temp = JSON.parse(element);
    if (temp.spec.steps) {
        let steps_final = temp.spec.steps.map(step => addToStep(step, resources));
        temp.spec.steps = steps_final;
    }
    //rewrite the steps to inject the config map
    return JSON.stringify(temp);
}

function printUsage() {
    console.log("Usage: node setup.js [pipeline.json]\n")
    console.log("pipeline.json format:")
    let input = {
        "main": "[MAIN EXPORTED PIPELINE JSON]",
        "additional": [
            {
                "config_name": "[ADDITIONAL PIPELINE CONFIG_MAP NAME]",
                "file": "[EXPORTED PIPELEINE JSON]"
            },
            {
                "config_name": "[ADDITIONAL PIPELINE CONFIG_MAP NAME 2]",
                "file": "[EXPORTED PIPELEINE JSON 2]"
            }
          ]
      };
    console.log(JSON.stringify(input));
}

let inputFile = process.argv.slice(2);

let res;
console.log("Reading input file " + inputFile);
if (inputFile.length == 0) {
    printUsage();
    process.exit(1);
}

(async() => {

res = await readFromFile(__dirname + "/" + inputFile);
let promises = [];

if (res.main) {
    promises.push(readFromFile(__dirname + "/" + res.main));
} else {
    console.log("Missing main pipeline in definition\n");
    printUsage();
    process.exit(1);
}


if (res.additional) {
     res.additional.forEach(async element => {
        promises.push(processAdditionalPipeline(element));
     });
 }

Promise.all(promises).then(result => {
    let mainFile = result[0];
   
    //get ns
    let ns_main = (mainFile.spec.payload.resources || []).filter(element => {
        let temp = JSON.parse(element);
        if (temp.kind && temp.kind === "Namespace") {
            return true;
        }
    });
  
    let original_namespace = "";
    let local_namespace = "";
    if (ns_main) {
        original_namespace = JSON.parse(ns_main).metadata.name;
        let timestamp =  new Date(Date.now());
        let date = timestamp.getFullYear().toString() +  (timestamp.getMonth() + 1).toString() + timestamp.getDate().toString() + timestamp.getUTCHours().toString() + timestamp.getUTCMinutes().toString() + timestamp.getUTCSeconds().toString();
        local_namespace = original_namespace + "-" + date;
    }
    
    console.log("Generating unique namespace...");
    //change all resource namespaces to use new local namespace
    for (let index = 0; index < mainFile.spec.payload.resources.length; index++) {
        const element = mainFile.spec.payload.resources[index];
        mainFile.spec.payload.resources[index] = element.replace(original_namespace, local_namespace);
    }
    
    console.log("Processing pipelines...");
    let tasks_cm = (mainFile.spec.payload.resources || []).filter(element => {
        let temp = JSON.parse(element);
        if (temp.kind && temp.kind === "Task") {
            return true;
        }
    });

    if (tasks_cm) {
        let task_final = tasks_cm.map(element => injectConfigMaps(element, result));
        
        //grant super powers
        let permissions = [];

        let localServiceAccount = clone(PIPELINE_SERVICE_ACCOUNT);
        localServiceAccount.metadata.namespace = local_namespace;
        permissions.push(JSON.stringify(localServiceAccount));
  
        let finalResources = (mainFile.spec.payload.resources).map(resource => {
            let temp = JSON.parse(resource);
            let newTask;
            if (temp.kind === "Task") {
                //replace original Tasks with configMapInjected Tasks
                newTask = (task_final).filter(element => {
                    let elmnt = JSON.parse(element);
                    if (elmnt.metadata.name === temp.metadata.name) {
                        return true;
                    }
                });
                return newTask[0];
            } else if (temp.kind === "PipelineRun") {
                //add Service Account
                temp.spec.serviceAccountName = "agent-localpipeline"
                return JSON.stringify(temp);
            }
            return resource;
        });

        mainFile.spec.payload.resources = finalResources.concat(permissions);
    }

    //write out additional pipelines as config maps
    for (let index = 1; index < result.length; index++) {
        const element = result[index];
        let newCM = clone(PIPELINE_CONFIG_MAP);
        newCM.metadata.namespace = local_namespace;
        newCM.metadata.name = element.config_name;
        newCM.data.pipeline = JSON.stringify(element.payload);
        mainFile.spec.payload.resources.push(JSON.stringify(newCM));
    }

    let outFile = mainFile.metadata.name + "-merged.json"
 
    fs.writeFile(__dirname + "/" + outFile, JSON.stringify(mainFile), (err) => {
        // throws an error, you could also catch it here
        if (err) throw err;
    
        // success case, the file was saved
        console.log(outFile + " saved");
    });
        
    //write out launch file
    console.log("Creating launch file...");
    let out = fs.createWriteStream("run-" + mainFile.metadata.name + ".sh");
    out.write("#!/bin/bash\n");
    let clusterRoleBindingName = "agent-localpipeline-role-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    out.write("kubectl apply -f " + outFile + "\n");
    out.write("kubectl create clusterrolebinding " + clusterRoleBindingName + " --clusterrole=cluster-admin --serviceaccount=" + local_namespace + ":agent-localpipeline\n"); 
    out.end();

    //write out clean up file
    console.log("Creating cleanup file...");
    let out2 = fs.createWriteStream("cleanup-" + mainFile.metadata.name + ".sh");
    out2.write("#!/bin/bash\n");
    out2.write("kubectl delete clusterrolebinding " + clusterRoleBindingName + "\n");
    out2.write("kubectl delete localpipeline " + mainFile.metadata.name + "\n");
    out2.end();

});
})();

