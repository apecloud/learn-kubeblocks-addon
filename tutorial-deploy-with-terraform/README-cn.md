## 用Terraform部署集群

### 教程目标
介绍如何使用Terraform部署一个Oralce-Mysql集群。
```txt
|── cluster-provision  # 集群部署文件
│   ├── main.tf
└── definition-provision # 模版部署文件
    ├── main.tf
```
### 部署Oralce-Mysql集群模版
我们通过部署 Tutorial 1中的Oralce-Mysql集群模版来实现, 通过Terraform部署一个oracle-mysql helm chart, 配置文件如下:
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
通过执行以下命令部署:
```bash
terraform init
terraform apply
```
执行完成后, 通过
```bash
kubectl get cd,cv -n kb-system
```
或者
```bash
helm list -n kb-system
```
查看部署状态。

### 创建一个数据库集群
我们通过部署 Tutorial 1中的数据库集群来实现, 通过Terraform部署一个oracle-mysql-cluster helm chart, 配置文件如下:
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

通过执行以下命令部署:
```bash
terraform init
terraform apply
```
执行完成后, 通过
```bash
kubectl get cluster -n default
```
可以看到到集群的状态。

若要发起变更, 可以通过修改配置文件, 例如, 需改cpu=2, memory=2, 然后执行以下命令:
```bash
terraform apply
```
会看到一下信息:
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
执行完成后, 发现POD的cpu和memory已经变更并且发生了重启.

## References
- [Terraform](https://www.terraform.io/)
- [Oracle MySQL](https://www.mysql.com/)
- [Helm Provider](https://github.com/hashicorp/terraform-provider-helm)
- [Managing Kubernetes resources in Terraform](https://www.arthurkoziel.com/managing-kubernetes-resources-in-terraform-helm-provider/)