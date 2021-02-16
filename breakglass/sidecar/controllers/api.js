/*******************************************************************************
 * Licensed Materials - Property of IBM
 * (c) Copyright IBM Corporation 2019, 2020. All Rights Reserved.
 *
 * Note to U.S. Government Users Restricted Rights:
 * Use, duplication or disclosure restricted by GSA ADP Schedule
 * Contract with IBM Corp.
 *******************************************************************************/
'use strict';

const express = require('express'),
	fs = require('fs'),
	k8s = require('@kubernetes/client-node'),
	request = require('request'),
	router = express.Router();

const { KubernetesObjectApi } = require("@kubernetes/client-node");
const e = require('express');
const { parse } = require('path');

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

function clone(obj) {
	return JSON.parse(JSON.stringify(obj));
}

async function findPipelineFile(dirname, pipelineId, eventListener) {
    return new Promise((resolve, reject) => {
		fs.readdir(dirname, function(err, filenames) {
			if (err) {
				console.log(err);
				reject(err);
			}
			filenames.forEach(async function(filename) {
				if (filename.endsWith(".json") && filename.includes(eventListener)) {
					await fs.readFile(dirname + filename, function (err, data) {
						if (err) {
							console.log(err);
							reject(err);
						}
						else {
							let  parsedData = JSON.parse(data);
							if (parsedData.spec && parsedData.spec.payload &&  parsedData.spec.payload.pipeline_id === pipelineId) {
								resolve(parsedData);
							}
						}
					});
				}
			});
		});
    });
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
			Object.entries(params).forEach(([key, value]) => {
				console.log(key + " " + value);
				const element = {};
				element.name = key;
				element.value = value;
					
					if (temp.spec) {
						//first go through params and look for defaults
						if (temp.spec.params) {
							let steps_params = temp.spec.params.map(param => subInParams(param, element));
							temp.spec.params = steps_params;
						}

						//next go through each step and override the env var
						if (temp.spec.steps) {
							let steps_final = temp.spec.steps.map(step => subInSteps(step, element));
							temp.spec.steps = steps_final;
						}
					}
			});
        }
        return JSON.stringify(temp);
    }
    return resource;
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


// async function deleteClusterRolebinding(kobj) {
//     let res = await k8sRbac.deleteClusterRoleBinding(kobj.metadata.name);
//     return res;
// }
const promisifiedRequest = function(uri, options) {
	return new Promise((resolve,reject) => {
	  request.get(uri, options, (error, response, body) => {
		if (response) {
		  return resolve(response);
		}
		if (error) {
		  return reject(error);
		}
	  });
	});
  };

router.get('/:pipelineId/runs/:id', async(req, res, next) => {
	try {
		let generated_namespace = req.url.slice(req.url.lastIndexOf("/") + 1, req.url.length);
		const opts = {};
		kc.applyToRequest(opts);
		let response = await promisifiedRequest(`${kc.getCurrentCluster().server}/apis/tekton.dev/v1beta1/namespaces/${generated_namespace}/pipelineruns`, opts);
		if (response) {
			if (response.error) {
				console.log(`error: ${error}`);
			}
			if (response.statusCode) {
				console.log(`statusCode: ${response.statusCode}`);
			}
			if (response.body) {
				let pipelineRunList = JSON.parse(response.body);
				if (pipelineRunList.items && pipelineRunList.items.length > 0) {
					let pipelineRun = pipelineRunList.items[0];
					let resp = 	{};
					if (pipelineRun.status && pipelineRun.status.completionTime) {
						console.log("hi");
						let promises = [];
						promises.push(promisifiedRequest(`${kc.getCurrentCluster().server}/apis/tekton.dev/v1beta1/namespaces/${generated_namespace}/taskruns`, opts));
						promises.push(promisifiedRequest(`${kc.getCurrentCluster().server}/apis/tekton.dev/v1beta1/namespaces/${generated_namespace}/tasks`, opts));
						promises.push(promisifiedRequest(`${kc.getCurrentCluster().server}/apis/tekton.dev/v1beta1/namespaces/${generated_namespace}/pipelineruns`, opts));
						promises.push(promisifiedRequest(`${kc.getCurrentCluster().server}/apis/tekton.dev/v1beta1/namespaces/${generated_namespace}/pipelines`, opts));
						//promises.push(promisifiedRequest(`${kc.getCurrentCluster().server}/api/v1/namespaces/${generated_namespace}/configmaps`, opts));
						Promise.all(promises).then(result => {
							if (result) {
								resp.resources = [];
								resp.status = {"state": "succeeded"};
								for (let index = 0; index < result.length; index++) {
									const element = result[index];
									if (element.body) {
										let parseElement = JSON.parse(element.body);
										if (parseElement.items && parseElement.items.length > 0) {
											for (let index = 0; index < parseElement.items.length; index++) {
												const item = parseElement.items[index];
												resp.resources.push(item);
											}
										}
									}
								}
							}
							return res.status(200).json(resp);
						});
					} else {
						resp.status = {"state": "running"};
						return res.status(200).json(resp);
					}
				}
			}
		}
	} catch (err) {
		next(err);
	}
	
});

router.post('/:pipelineId/runs', async(req, res, next) => {
	try {

		let body = req.body;
		let resp = {};
		if (body) {
			console.log("POST OUT!!");
			let eventListener = body.eventListener;
			let eventParams = body.eventParams;
			if (eventListener) {
				//look up local pipeline
				let pipelineId = req.url.slice(1, req.url.length - 5);
				let filecontents = await findPipelineFile("/app/data/", pipelineId, eventListener)

				if (eventParams) {
					//sub?
					let finalResources = (filecontents.spec.payload.resources).map(resource => subInResource(resource, eventParams));
					filecontents.spec.payload.resources = finalResources;
				}

				let timestamp =  new Date(Date.now());
				let date = timestamp.getFullYear().toString() +  (timestamp.getMonth() + 1).toString() + timestamp.getDate().toString() + timestamp.getUTCHours().toString() + timestamp.getUTCMinutes().toString() + timestamp.getUTCSeconds().toString();
				let generated_namespace =  "pw-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15) + "-local-" + date;
				let finalResources = (filecontents.spec.payload.resources).map(resource => {
					let temp = JSON.parse(resource);
					if (temp.kind === "Namespace") {
						temp.metadata.name = generated_namespace;
						return JSON.stringify(temp);
					}
					temp.metadata.namespace = generated_namespace;
					return JSON.stringify(temp);
				});

				let permissions = [];
				let localServiceAccount = clone(PIPELINE_SERVICE_ACCOUNT);
				localServiceAccount.metadata.namespace = generated_namespace;
				permissions.push(JSON.stringify(localServiceAccount));
	
				filecontents.spec.payload.resources = finalResources.concat(permissions);

				//generate script files
				console.log("Creating cluster role binding...");
				let appliedClusterRoleBinding = clone(CLUSTER_ROLE_BINDING);
				let clusterRoleBindingName = "agent-localpipeline-role-" + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
				appliedClusterRoleBinding.metadata.name = clusterRoleBindingName;
				appliedClusterRoleBinding.subjects[0].namespace = generated_namespace;
				let b_res = await createClusterRolebinding(appliedClusterRoleBinding);

				let a_res = await create(filecontents);
				console.log("");
				resp.html_url = "LOCAL_RUN";
				resp.status = {"state": "running"};
				resp.url = "http://tekton-localpipeline-sidecar.default.svc:5555"+ req.originalUrl + "/" + generated_namespace;
			}

			return res.status(201).json(resp);
			
		}
			///
// {
//   "pipelineId": "1dee99f7-9c44-4ac1-87be-5e6658dbad42",
//   "buildNumber": {
//     "buildNumber": 6,
//     "type": "tekton"
//   },
//   "status": {
//     "state": "pending"
//   },
//   "eventParams": {},
//   "envProperties": [],
//   "listenerName": "main-listener",
//   "pipelineDefinitionId": "c81a7954-5edb-461d-bc08-f2b01daa9508",
//   "trigger": {},
//   "workerId": "08936d23-cd83-49ba-8b9c-92e7ec29302c",
//   "type": "pipeline_run",
//   "created": "2021-01-05T04:54:44.466Z",
//   "updated_at": "2021-01-05T04:54:44.466Z",
//   "updated_at_timestamp": 1609822484466,
//   "created_timestamp": 1609822484466,
//   "id": "2dcc048c-0a2b-4205-83bd-239fb1ec6107",
//   "url": "https://devops-api.us-south.devops.cloud.ibm.com/v1/tekton-pipelines/1dee99f7-9c44-4ac1-87be-5e6658dbad42/runs/2dcc048c-0a2b-4205-83bd-239fb1ec6107",
//   "html_url": "https://cloud.ibm.com/devops/pipelines/tekton/1dee99f7-9c44-4ac1-87be-5e6658dbad42/runs/2dcc048c-0a2b-4205-83bd-239fb1ec6107?env_id=ibm:yp:us-south",
//   "logs": {}
// }%              



// HTML_URL=$(jq -r '.html_url' job_start)
// API_URL=$(jq -r '.url' job_start)
// status=$(jq -r '.status.state' job_start)
// jobid=$(jq -r '.id' job_start)

// echo ""
// echo "Pipeline run successfully started"
// jq -c '.buildNumber, .status, .eventParams' job_start
// jq -c '{pipelineId: .id}' job_start
// echo "Browser URL: $HTML_URL"
// echo "API URL: $API_URL"
// echo ""
// jq -r .buildNumber.buildNumber job_start > $DOWNSTREAM_BUILD_NUMBER_PATH
// echo -n "waiting for pipeline run to complete: ."

// while [ ${status} == "pending" -o ${status} == "running" -o ${status} == "queued" -o  ${status} == "waiting" ]
// do
//    sleep 15
//    rm -f job_status
//    echo -n .
//    STATUS_CODE=$(curl --silent -w "%{http_code}" -o job_status -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN"  "$API_URL")
//    if [ "${STATUS_CODE}" == "200" ]; then
// 	  status=$(jq -r .status.state job_status)
//    elif [ "${STATUS_CODE}" == "403" ]; then

		
 		res.status(200).json(resp);
	} catch (err) {
		next(err);
	}
	
});

module.exports = router;