const fs = require("fs");
const k8s = require('@kubernetes/client-node');
const { V1PersistentVolume, V1Pod } = require("@kubernetes/client-node");

const LOCAL_NAMESPACE = {
  "apiVersion": "v1",
    "kind": "Namespace",
    "metadata": {
        "name": "bog"
    }
}
const LOCAL_TETKTON_PV =  {
    "apiVersion": "v1",
    "kind": "PersistentVolume",
    "metadata": {
      "labels": {
        "app": "workeragent",
        "workeragent": ""
      },
      "name": "FILL-bog1-pv"
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "capacity": {
        "storage": "10Gi"
      },
      "hostPath": {
        "path": "FILL-/tmp/bog1/pw-55ad9045-660a-448d-998d-c677e2a3bd75-local-20201112203122",
        "type": "DirectoryOrCreate"
      },
      "nodeAffinity": {
        "required": {
          "nodeSelectorTerms": [
            {
              "matchExpressions": [
                {
                  "key": "kubernetes.io/hostname",
                  "operator": "In",
                  "values": [
                    "FILL-10.144.180.154"
                  ]
                }
              ]
            }
          ]
        }
      },
      "persistentVolumeReclaimPolicy": "Delete",
      "storageClassName": "tekton-local-storage",
      "volumeMode": "Filesystem"
    }
}

const LOCAL_TEKTON_PVC = {
    "kind": "PersistentVolumeClaim",
    "apiVersion": "v1",
    "metadata": {
      "name": "FILL-bog1-persistent-volume-claim"
    },
    "spec": {
      "storageClassName": "tekton-local-storage",
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": "1Gi"
        }
      }
    }
  }

const LOCAL_TEMP_DEPLOYMENT = {
        "kind": "Deployment",
        "apiVersion": "apps/v1",
        "metadata": {
          "name": "FILL-test-alpine-pvc"
        },
        "spec": {
          "replicas": 1,
          "selector": {
            "matchLabels": {
              "k8s-app": "store"
            }
          },
          "template": {
            "metadata": {
              "labels": {
                "k8s-app": "store"
              }
            },
            "spec": {
              "volumes": [
                {
                  "name": "store-volume",
                  "persistentVolumeClaim": {
                    "claimName": "FILL-bog1-persistent-volume-claim"
                  }
                }
              ],
              "containers": [
                {
                  "name": "ubuntu",
                  "image": "ubuntu:latest",
                  "command": [
                    "/bin/bash",
                    "-c",
                    "--"
                  ],
                  "args": [
                    "while true; do sleep 30; done;"
                  ],
                  "volumeMounts": [
                    {
                      "name": "store-volume",
                      "mountPath": "/data"
                    }
                  ]
                }
              ]
            }
          }
        }
}


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

//setup k8s client

const kc = new k8s.KubeConfig();
kc.loadFromDefault();

const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const k8sApps = kc.makeApiClient(k8s.AppsV1Api);

async function listNamespacedPod() {
  // return new Promise((resolve, reject) => {
  //     k8sApi.listNamespacedPod('default').then((res) => {
  //         resolve(res);
  //     });
  // });
  return k8sApi.listNamespacedPod('default');
}

async function listNode() {
  return k8sApi.listNode();
}


async function createPersistentVolume(localPV) {
  return k8sApi.createPersistentVolume(localPV);
}

async function createPersistentVolumeClaim(ns, localPVC) {
  return k8sApi.createNamespacedPersistentVolumeClaim(ns, localPVC);
}

async function createDeployment(ns, deployment) {
  return k8sApps.createNamespacedDeployment(ns, deployment);
}

async function createNamespace(namespace) {
  return k8sApi.createNamespace(namespace);
}


///

let inputFile = process.argv.slice(2);

let uniqueName = "parsednamefirstchars-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);

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

Promise.all(promises).then(async (result) => {
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
    

//grant super powers
let permissions = [];

let localServiceAccount = clone(PIPELINE_SERVICE_ACCOUNT);
localServiceAccount.metadata.namespace = local_namespace;
permissions.push(JSON.stringify(localServiceAccount));

let finalResources = (mainFile.spec.payload.resources).map(resource => {
    let temp = JSON.parse(resource);
    let newTask;
    if (temp.kind === "PipelineRun") {
        //add Service Account
        temp.spec.serviceAccountName = "agent-localpipeline"
        // //pass down secondary workspace
        // if (!temp.spec.workspaces) {
        //   temp.spec.workspaces = [];
        // }
        // temp.spec.workspaces.push({name: "local-pipelines", persistentVolumeClaim:{claimName: uniqueName + "-pvc"}});
        return JSON.stringify(temp);
    } else if (temp.kind === "Pipeline") {
      // //pass down secondary workspace
      // if (!temp.spec.workspaces) {
      //   temp.spec.workspaces = [];
      // }
      // temp.spec.workspaces.push({name: "local-pipelines"});
      // //pass down secondary workspace to tasks
      // if (temp.spec.tasks) {
      //   for (let index = 0; index < temp.spec.tasks.length; index++) {
      //     let task = temp.spec.tasks[index];
      //     if (!task.workspaces) {
      //       task.workspaces = [];
      //     }
      //     task.workspaces.push({name: 'local-pipelines', workspace: 'local-pipelines'});
      //   }
      // }
      // return JSON.stringify(temp);
    } else if (temp.kind === "Task") {
      // //pass down secondary workspace
      // if (!temp.spec.workspaces) {
      //   temp.spec.workspaces = [];
      // }
      // temp.spec.workspaces.push({name:"local-pipelines", mountPath: "/localpipelines"});


      // if (!temp.spec.volumes) {
      //   temp.spec.volumes = []
      // }
      // temp.spec.volumes.push({name: "local-pipelines", persistentVolumeClaim:{claimName: uniqueName + "-pvc"}});
      // if (temp.spec.steps) {
      //   for (let index = 0; index < temp.spec.steps.length; index++) {
      //     let step = temp.spec.steps[index];
      //     if (!step.volumeMounts) {
      //       step.volumeMounts = [];
      //     }
      //     step.volumeMounts.push({mountPath: '/data', name: 'local-pipelines'});
      //   }
      // }



     // return JSON.stringify(temp);
    }
    return resource;
});

mainFile.spec.payload.resources = finalResources.concat(permissions);


//create pvc + deployment 
let nodes = await listNode()

let nodeList = nodes.body
let nodeAddresses = [];
if (nodeList.items) {
    for (let index = 0; index < nodeList.items.length; index++) {
        let node = nodeList.items[index];
        let nspec = node.spec;
        if (nspec.taints) {
            //can't use
            console.log("taint detected - skip");
        } else {
            //ok
            console.log("no taints");
            let status = node.status;
            if (status.addresses) {
                let hostAddress = status.addresses.filter(element => {
                    if (element.type && element.type === "Hostname") {
                        return true;
                    }
                });
                if (hostAddress.length > 0) {
                    nodeAddresses.push(hostAddress[0]);
                }
            }
        }
        
    }
    if (nodeAddresses.length > 0) {
        //Create PV
        let localPV = clone(LOCAL_TETKTON_PV);
        localPV.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0] = nodeAddresses[0].address;
        let pvName = uniqueName + "-pv";
        localPV.metadata.name = pvName;
        localPV.spec.hostPath.path = "/tmp/localtekpv-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
        try {
            let answer = await createPersistentVolume(localPV);
            console.log(localPV); 
        } catch (error ) {
            console.error(error);
            process.exit(1);
        }

        //Create ns
        let localNS = clone(LOCAL_NAMESPACE);
        let deploymentNS = "localcp-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
        localNS.metadata.name = deploymentNS;
        await createNamespace(localNS);

        //Create PVC
        let localPVC = clone(LOCAL_TEKTON_PVC);
        let pvcName = uniqueName + "-pvc";
        localPVC.metadata.name = pvcName; 
        localPVC.metadata.namespace = deploymentNS;
         try {
            let answer = await createPersistentVolumeClaim(deploymentNS, localPVC);
            console.log(localPV); 
        } catch (error ) {
            console.error(error);
            process.exit(1);
        }

        //Create Deployment
        let copyDeployment = clone(LOCAL_TEMP_DEPLOYMENT);
        copyDeployment.spec.template.spec.volumes[0].persistentVolumeClaim.claimName = pvcName;
        let deploymentName = "ubuntu-k8scopy";
        copyDeployment.metadata.name = deploymentName;
        copyDeployment.metadata.namespace = deploymentNS;
        try {
            let answer = await createDeployment(deploymentNS, copyDeployment);
            console.log(localPV); 
        } catch (error ) {
            console.error(error);
            process.exit(1);
        }


        //generate script files

        
        let dirName = "localpipeline-" +  Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
        console.log("Created dir " + dirName + " for scripts...")

        fs.mkdirSync(dirName);

        let outFile = mainFile.metadata.name + "-merged.json"
 
        fs.writeFile(dirName + "/" + outFile, JSON.stringify(mainFile), (err) => {
            // throws an error, you could also catch it here
            if (err) throw err;
        
            // success case, the file was saved
            console.log(outFile + " saved");
        });
        
        //write out launch file
        console.log("Creating launch file...");
        let out = fs.createWriteStream(dirName + "/run-" + mainFile.metadata.name + ".sh");
        out.write("#!/bin/bash\n");
        let clusterRoleBindingName = "agent-localpipeline-role-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
        out.write("kubectl create -f " + outFile + "\n");
        out.write("kubectl create clusterrolebinding " + clusterRoleBindingName + " --clusterrole=cluster-admin --serviceaccount=" + local_namespace + ":agent-localpipeline\n"); 
        out.end();

        //write out copy file
        console.log("Creating copy file...");
        let out3 = fs.createWriteStream(dirName + "/copy" + mainFile.metadata.name + ".sh");
        out3.write("#!/bin/bash\n");
        out3.write("POD=$(kubectl get pod -n " + deploymentNS  + " -o jsonpath=\"{.items[0].metadata.name}\")\n");
        out3.write("kubectl cp hello2-local.json " + deploymentNS + "/$POD:/data\n");
        out3.end();

        //write out clean up file
        console.log("Creating cleanup file...");
        let out2 = fs.createWriteStream(dirName + "/cleanup-" + mainFile.metadata.name + ".sh");
        out2.write("#!/bin/bash\n");
        out2.write("kubectl delete clusterrolebinding " + clusterRoleBindingName + "\n");
        out2.write("kubectl delete localpipeline " + mainFile.metadata.name + "\n");
        out2.write("kubectl delete deployment " + deploymentName + " -n " + deploymentNS + "\n");
        out2.write("kubectl delete pvc " + pvcName + " -n " + deploymentNS + "\n");
        out2.write("kubectl delete pv " + pvName + " -n " + deploymentNS + "\n");
        out2.write("kubectl delete ns " + deploymentNS + "\n");
        out2.end();

        // //write out clean up file
        // console.log("Creating cleanup file...");
        // let out2 = fs.createWriteStream("cleanup-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15) + ".sh");
        // out2.write("#!/bin/bash\n");
        // out2.write("kubectl delete deployment " + deploymentName + "\n");
        // out2.write("kubectl delete pvc " + pvcName + "\n");
        // out2.write("kubectl delete pv " + pvName + "\n");
        // out2.end();


        //copy stuff
       // k8sApi.listNamespacedPod()

    } else {
        console.log("No worker nodes detected. Try again with or maybe pass in a node to use")
        process.exit(1);
    }
}
});

})();
///


// (async() => {


// if (res.additional) {
//      res.additional.forEach(async element => {
//         promises.push(processAdditionalPipeline(element));
//      });
//  }

// Promise.all(promises).then(result => {
  

//     console.log("Processing pipelines...");
//     let tasks_cm = (mainFile.spec.payload.resources || []).filter(element => {
//         let temp = JSON.parse(element);
//         if (temp.kind && temp.kind === "Task") {
//             return true;
//         }
//     });



//     //write out additional pipelines as config maps
//     for (let index = 1; index < result.length; index++) {
//         const element = result[index];
//         let newCM = clone(PIPELINE_CONFIG_MAP);
//         newCM.metadata.namespace = local_namespace;
//         newCM.metadata.name = element.config_name;
//         newCM.data.pipeline = JSON.stringify(element.payload);
//         mainFile.spec.payload.resources.push(JSON.stringify(newCM));
//     }

//     let outFile = mainFile.metadata.name + "-merged.json"
 
//     fs.writeFile(__dirname + "/" + outFile, JSON.stringify(mainFile), (err) => {
//         // throws an error, you could also catch it here
//         if (err) throw err;
    
//         // success case, the file was saved
//         console.log(outFile + " saved");
//     });
        
//     //write out launch file
//     console.log("Creating launch file...");
//     let out = fs.createWriteStream("run-" + mainFile.metadata.name + ".sh");
//     out.write("#!/bin/bash\n");
//     let clusterRoleBindingName = "agent-localpipeline-role-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
//     out.write("kubectl create -f " + outFile + "\n");
//     out.write("kubectl create clusterrolebinding " + clusterRoleBindingName + " --clusterrole=cluster-admin --serviceaccount=" + local_namespace + ":agent-localpipeline\n"); 
//     out.end();

//     //write out clean up file
//     console.log("Creating cleanup file...");
//     let out2 = fs.createWriteStream("cleanup-" + mainFile.metadata.name + ".sh");
//     out2.write("#!/bin/bash\n");
//     out2.write("kubectl delete clusterrolebinding " + clusterRoleBindingName + "\n");
//     out2.write("kubectl delete localpipeline " + mainFile.metadata.name + "\n");
//     out2.end();

// });
// })();

