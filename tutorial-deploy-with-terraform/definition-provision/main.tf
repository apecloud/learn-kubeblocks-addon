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
