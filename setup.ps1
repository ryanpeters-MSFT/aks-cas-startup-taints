$group = "rg-aks-startup-taints"
$cluster = "aksstartuptaint"
$location = "eastus2"
$userPool = "userpool"

$startupTaint = "startup-taint.cluster-autoscaler.kubernetes.io/testpodschedule=unavailable:NoSchedule"

# create the resource group
az group create `
  --name $group `
  --location $location

# create the AKS cluster
az aks create `
  --resource-group $group `
  --name $cluster `
  --node-count 1

# add a user node pool with CAS enabled (0 nodes to start) and node initialization taint
az aks nodepool add `
  --resource-group $group `
  --cluster-name $cluster `
  --name $userPool `
  --mode User `
  --enable-cluster-autoscaler `
  --min-count 0 `
  --max-count 2 `
  --node-count 0 `
  --node-taints $startupTaint

# get credentials
az aks get-credentials `
  --resource-group $group `
  --name $cluster `
  --overwrite-existing