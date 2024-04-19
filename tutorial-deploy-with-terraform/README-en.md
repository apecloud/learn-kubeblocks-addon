## Deploy KubeBlocks Clusters with Terraform

### Goal
This tutorial introduces how to use Terraform to deploy an Oracle-Mysql cluster.
```txt
|── cluster-provision  # deploy cluster
│   ├── main.tf
└── definition-provision # deploy cluster definition and cluster version
    ├── main.tf
```
### 部署Oralce-Mysql集群模版
In this tutorial, we deploy the Oracle-Mysql Helm Chart created in Tutorial 1. The configuration file is as follows:
```hcl
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "oracle-mysql" {
  name       = "oracle-mysql"  # release naem
  repository = "https://jihulab.com/api/v4/projects/150246/packages/helm/stable"  # helm repo
  chart      = "oracle-mysql"       # chart name
  version    = "0.1.0"              # chart version
  namespace        = "kb-system"    # namespace
  create_namespace = true           # create namespace
}
```
Deploy by executing the following command:
```bash
cd ./definition-provision
terraform init
terraform apply
```
And check the deployment status by executing:
```bash
kubectl get cd,cv -n kb-system
```
Or
```bash
helm list -n kb-system
```
To verify the deployment status.

### Create a Database Cluster
In this tutorial, we deploy the Oracle-Mysql-Cluster Helm Chart created in Tutorial 1. The configuration file is as follows:
```hcl
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "mycluster" {
  name       = "mycluster"                   # release name
  repository = "https://jihulab.com/api/v4/projects/150246/packages/helm/stable"  # helm repo address
  chart      = "oracle-mysql-cluster" # helm chart name
  version    = "0.1.0" # chart version
  namespace  = "default" # namespace

  set {                   # set .Values.memory=4
    name = "memory"
    value = "4"
  }
  set {                  # set .Values.cpu=4
    name = "cpu"
    value = "4"
  }
}
```

Deploy by executing the following command:
```bash
cd ./cluster-provision
terraform init
terraform apply
```
And verify the deployment status by executing:
```bash
kubectl get cluster -n default
```
To perform a change, modify the configuration file, for example, change `cpu=2`, `memory=2`, and then execute the following command:
```bash
terraform apply
```
Expected output is as follows:
```txt
helm_release.mycluster: Refreshing state... [id=mycluster]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # helm_release.mycluster will be updated in-place
  ~ resource "helm_release" "mycluster" {
        id                         = "mycluster"
      ~ metadata                   = [
          - {
              - app_version = "8.0.32"
              - chart       = "oracle-mysql-cluster"
              - name        = "mycluster"
              - namespace   = "default"
              - revision    = 1
              - values      = jsonencode(
                    {
                      - cpu    = 4
                      - memory = 4
                    }
                )
              - version     = "0.1.0"
            },
        ] -> (known after apply)
        name                       = "mycluster"
        # (26 unchanged attributes hidden)

      - set {
          - name  = "cpu" -> null
          - value = "4" -> null
        }
      - set {
          - name  = "memory" -> null
          - value = "4" -> null
        }
      + set {
          + name  = "cpu"
          + value = "2"
        }
      + set {
          + name  = "memory"
          + value = "2"
        }
    }
```
If such change is made, the cluster will be updated accordingly and POD will be restarted.

## References
- [Terraform](https://www.terraform.io/)
- [Oracle MySQL](https://www.mysql.com/)
- [Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Managing Kubernetes resources in Terraform](https://www.arthurkoziel.com/managing-kubernetes-resources-in-terraform-helm-provider/)