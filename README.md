# Introduction 
Infrastructure as Code (IaC) in Bicep format to show the deployment of a few useful Azure resources.

# Getting Started
1.  Download [Visual Studio Code](https://github.com/Microsoft/vscode)
2.	Install Bicep extension
3.	'Open folder' at repository root
4.  Create a resource group named `birdatlasiac` in your subscription.

# Test locally
You can test locally running following command in Visual Studio Code shell (or any CLI tool):

```
az deployment group what-if --name 'TestLocal' --resource-group birdatlasiac --template-file .\templates\main.bicep --parameters .\templates\parameters\DEV.parameters.json 
```

If you're not logged in yet, run `az login` first and use `az account set --subscription "SubName"` to set the default subscription to work on.

# Deploy
Deployment can be done through Azure DevOps or GitHub actions (or any other CI/CD tooling). To deploy from your machine, use following command:

```
az deployment group create --name 'TestLocal' --resource-group birdatlasiac --template-file .\templates\main.bicep --parameters .\templates\parameters\DEV.parameters.json 
```