provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "oracle-mysql" {
  name       = "oracle-mysql"
  repository = "https://jihulab.com/api/v4/projects/150246/packages/helm/stable"
  chart      = "oracle-mysql"
  version    = "0.1.0"
  namespace        = "kb-system"
  create_namespace = true
}

resource "helm_release" "mycluster" {
  name       = "mycluster"
  repository = "https://jihulab.com/api/v4/projects/150246/packages/helm/stable"
  chart      = "oracle-mysql-cluster"
  version    = "0.1.0"
  namespace  = "default"
  set {
    name = "memory"
    value = "2"
  }
  set {
    name = "cpu"
    value = "2"
  }

  depends_on = [helm_release.oracle-mysql]
}


