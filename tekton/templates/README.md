This is a templated Tekton pipeline designed to be copied and pasted wholesale when needing a new pipeline to do

1. Open CR
2. Do some work
3. Close PR

Some customizations that will be needed after copying

1. Rename the files, removing reference to "template" and match something for the functionality you needed
2. Rename the Task names and the referece to them in the pipeline
3. Rename the Pipeline and the reference to it in the trigger-template.yaml
4. Rename the TriggerTemplate, TriggerBinding and EventListener in trigger-template.yaml
5. Edit the Change Request Defaults in sn-bindings.yaml
6. If Further, dynamic changes are needed for these, include that functionality in the open-cr task

Expected Params to this templated pipeline

1. TEST_SN_TOKEN
2. PROD_SN_TOKEN

There's 2 default event listeners, these will need to be expanded, replaced as needed, only there to serve as an example

1. Dev
2. Prod
