## Lifecycle Management
This series of tutorials uses Oracle MySQL Standalone Cluster as an example, introducing how to integrate MySQL as an Addon into KubeBlocks, and manage the lifecycle of MySQL database through KubeBlocks.

## Goals
Introduce how to create a MySQL database instance on KubeBlocks.
The YAML examples used in the tutorial can be found in the `./examples` directory, and Helm examples are also provided in the `./chart` directory.
```txt
├── README-cn.md  # readme 文件
├── README-en.md  # readme 文件
├── charts        # Helm 示例
│   ├── oracle-mysql  # clusterdefiniton和clusterversion的Helm示例
│   └── oracle-mysql-cluster # cluster的Helm示例
└── examples      # YAML 示例
    ├── mycluster.yaml
    ├── oracle-mysql-cd.yaml
    └── oracle-mysql-cv.yaml
```


## CRDs
- [ClusterDefinition](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterDefinition)
- [ClusterVersion](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterVersion)
- [Addon](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/add-on#extensions.kubeblocks.io/v1alpha1.Addon)

## Integration Process
### Understand the Cluster Architecture
First, you should clarify the architecture of the cluster, including
- What components does the cluster contain
- What is the form of each component: stateful/stateless

### ClusterDefinition and ClusterVersion

#### Describe the Cluster Topology using ClusterDefinition

Create a ClusterDefinition object to describe the cluster topology, and save it as `oracle-mysql-cd.yaml` file

```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: ClusterDefinition
metadata:
  name: oracle-mysql
spec:
  componentDefs:
  - characterType: mysql
    name: mysql-compdef
    podSpec:
      containers:
      - env:
        - name: MYSQL_ROOT_HOST
          value: '%'
        - name: MYSQL_ROOT_USER
          valueFrom:
            secretKeyRef:
              key: username
              name: $(CONN_CREDENTIAL_SECRET_NAME)
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: $(CONN_CREDENTIAL_SECRET_NAME)
        imagePullPolicy: IfNotPresent
        name: mysql-container
        ports:
        - containerPort: 3306
          name: mysql
          protocol: TCP
        resources: {}
        volumeMounts:
        - mountPath: /var/lib/mysql
          name: data
    service:
      ports:
      - name: mysql
        port: 3306
        protocol: TCP
        targetPort: mysql
    workloadType: Stateful
  connectionCredential:
    endpoint: $(SVC_FQDN):$(SVC_PORT_mysql)
    host: $(SVC_FQDN)
    password: $(RANDOM_PASSWD)
    port: $(SVC_PORT_mysql)
    username: root
```
ClusterDefinition object mainly describes the following information:
- name of this topology: oracle-mysql
- definition of the cluster components
  Each cluster topology contains one or more component definitions. This example only contains one component definition, namely, `mysql-compdef`, which defines key properties of this component, including:
  - Container: mysql-container
  - Service name and port: mysql, 3306
  - Workload type: Stateful
- connection credentials of the cluster (to be accsessed by internal/external services)

The `podSpec` and `service` fields describe the properties of the component's container and service, which can be modified according to the actual situation.
The `connectionCredential` field describes the connection credentials of the cluster. When creating a Cluster, KubeBlocks will first create a secret, named after `{clusterName}-conn-credential`. It contains regular information such as username, password, endpoint, port, etc., which is used when other services access this cluster (this secret will be created before other resources, and you can reference this object elsewhere). In this field, you can use some placeholders to reference the values of other fields, such as $(SVC_FQDN), $(SVC_PORT_mysql), $(RANDOM_PASSWD), etc.

Some common placeholders are as follows:

| PlaceHolder | Description |
| --- | --- |
| HEADLESS_SVC_FQDN	|FQDN placeholder for headless service. The value is - $(CLUSTER_NAME)-$(1ST_COMP_NAME)-headless.$(NAMESPACE).svc, where 1ST_COMP_NAME is the first component providing the `ClusterDefinition.spec.componentDefs[].service` attribute.|
| SVC_FQDN |	FQDN placeholder for the service. The value is - $(CLUSTER_NAME)-$(1ST_COMP_NAME).$(NAMESPACE).svc, where 1ST_COMP_NAME is the first component providing the `ClusterDefinition.spec.componentDefs[].service` attribute.。|
| SVC_PORT_{PORT_NAME}	| ServicePort's port value with specified port name, i.e, a servicePort JSON struct: `{"name": "mysql", "targetPort": "mysqlContainerPort", "port": 3306}`, and `$(SVC_PORT_mysql)` in the connection credential value is 3306 |
| RANDOM_PASSWD	| random 8 characters |
| STRONG_RANDOM_PASSWD | random 16 characters, with mixed cases, digits and symbols|

#### Describe the Cluster Version using ClusterVersion
Create a ClusterVersion object to describe the versions of each component of the cluster, and save it as `oracle-mysql-cv.yaml` file
```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: ClusterVersion
metadata:
  name: oracle-mysql-8.0.32
spec:
  clusterDefinitionRef: oracle-mysql
  componentVersions:
  - componentDefRef: mysql-compdef
    versionsContext:
      containers:
      - name: mysql-container
        image: docker.io/mysql:8.0.32
        imagePullPolicy: IfNotPresent
```
A ClusterVersion object mainly describes the following information:
- name of this ClusterVersion: oracle-mysql-8.0.32
- topology template referenced by this version: oracle-mysql
  If the ClusterDefinition referenced by the ClusterVersion does not exist, it will cause the status of the ClusterVersion to be "Unavailable"
- component version
  Each cluster version contains one or more component versions. This example only contains one component version: mysql-compdef, and it defines the container image version of this component
  If the component definition referenced in componentDefRef does not exist, it will cause the status of the ClusterVersion to be "Unavailable"

### Deploy Cluster Definition and Cluster Version
1. use `kubectl` to apply the ClusterDefinition and ClusterVersion
```bash
kubectl apply -f oracle-mysql-cd.yaml
kubectl apply -f oracle-mysql-cv.yaml
```

2. verify the status of ClusterDefinition
```bash
kubectl get clusterdefinition
```
You will see the following output information, if `STATUS` is displayed as "Available", it means that the cluster topology template was created successfully

```bash
NAME             MAIN-COMPONENT-NAME   STATUS      AGE
oracle-mysql     mysql-compdef         Available   2s
```

3. verify the status of ClusterVersion
```bash
kubectl get clusterversion
```
You will see the following output information, if `STATUS` is displayed as "Available", it means that the cluster version resource was created successfully
```txt
NAME                                   CLUSTER-DEFINITION   STATUS      AGE
oracle-mysql-8.0.32                    oracle-mysql         Available   2s
```


### Create a Cluster
Create a `Cluster` object to describe the cluster instance, and save it as `oracle-mysql-cluster.yaml` file.

```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: mycluster
  namespace: default
spec:
  clusterDefinitionRef: oracle-mysql
  clusterVersionRef: oracle-mysql-8.0.32
  componentSpecs:
  - componentDefRef: mysql-compdef
    name: mysql-comp
    replicas: 1
    resources:
      limits:
        cpu: "1"
        memory: 1Gi
      requests:
        cpu: "1"
        memory: 1Gi
    volumeClaimTemplates:
    - name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
  terminationPolicy: Delete
```

The Cluster object mainly describes the following information:

- name of the cluster: mycluster
- reference to cluster definition and cluster version: oracle-mysql and oracle-mysql-8.0.32
  which set constraints on the cluster instance
- list of components in the cluster: mysql-compdef, and set resources for this component, such as
  - cpu/memory: 1/1Gi
  - storage configuration of the cluster: 20Gi
- termination policy of the cluster: `Delete`
  for more information about the termination policy, please refer to [TerminationPolicyType](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.TerminationPolicyType). The `Delete` policy is used in this example, which means that all storage resources in the cluster will be deleted when the cluster is deleted.


1. create a mysql cluster
```bash
kubectl apply -f oracle-mysql-cluster.yaml
```
2. check cluster status
```bash
kubectl  get cluster mycluster
```

You can see the following output information
- `CLUSTER-DEFINITION` is displayed as "oracle-mysql", it means that the cluster referneces the `oracle-mysql` ClusterDefinition
- `VERSION` means that the cluster instance uses the version `oracle-mysql-8.0.32`
- `STATUS` is displayed as "Running", it means that the cluster has been created successfully.
- `AGE` is displayed as "1m", it means that the cluster was created 1 minute ago.
- `TERMINATION-POLICY` is displayed as "Delete", it means that the termination policy of the cluster is "Delete".

```text
NAME        CLUSTER-DEFINITION   VERSION               TERMINATION-POLICY   STATUS    AGE
mycluster   oracle-mysql         oracle-mysql-8.0.32   Delete               Running   1m
```

3. Modify cluster resources
If you need to modify cluster resources, there are multiple ways to do so
  - Use the `kubectl edit cluster mycluster` command to modify the cluster resources
  - Use `kbcli` to issue a modification request
```bash
kbcli cluster vscale mycluster --components mysql-comp --cpu 2 --memory 2Gi
```
This operation will generate a `OpsRequest` object of type `VerticalScaling`. You can view the progress of this operation by using the `kubectl get opsrequest` command.

## Deploying with Helm Charts
The previous sections introduced how to create a cluster template through YAML files. Both ClusterDefinition and ClusterVersion are defined through YAML files. However, managing through YAML files can be cumbersome in actual production environments. It is recommended to use Helm for management. Helm Tutorial](https://helm.sh/docs/intro/quickstart/)

Helm examples are provided in the ./chart directory, and you can deploy templates through Helm.
```bash
kubectl create ns demo
helm -n demo install oracle-mysql ./chart/oracle-mysql
```

You can create a cluster through Helm, for example:
```bash
kubectl create ns cluster-demo
helm -n cluster-demo install mycluster ./chart/oracle-mysql-cluster
```

## Using Addon CR to Manage
So far, we have shown how to deploy clusters in a local development environment, but how can we make it available to all KubeBlocks users? To solve this problem, we can use `Addon` CR to manage aforementioned templates. KubeBlocks uses Addon to manage two types of plugins:
- Database engine plugins, such as ApeCloud-MySQL, Nebula-Graph, StarRocks. More engine plugins can be found at [kubeblocks-addons](https://github.com/apecloud/kubeblocks-addons/)
- Application plugins, such as snapshot-controller, Kube-Bench, fault-chaos-mesh, etc.

### Packaging Helm chart
First, we need to package the Helm template into a tgz file, for example
```bash
helm package ./chart/oracle-mysql
```
and push it to your Helm repository, for example
```bash
helm push oracle-mysql-0.1.0.tgz <your-helm-repo>
```
### Create an Addon CR
```yaml
apiVersion: extensions.kubeblocks.io/v1alpha1
kind: Addon
metadata:
  annotations:
    addon.kubeblocks.io/kubeblocks-version: '>=0.8.0'  # KubeBlocks version requirement
  labels:
    addon.kubeblocks.io/model: RDBMS                   # Addon Mode, such as RDBMS, NoSQL, Graph
    addon.kubeblocks.io/provider: ApeCloud             # Addon Provider
    addon.kubeblocks.io/version: 0.1.0                 # Addon Version
  name: oracle-mysql                                   # Addon Name
spec:
  description: MySQL is a widely used, open-source relational database management system (RDBMS). # Addon Description
  helm:
    chartLocationURL: https://jihulab.com/api/v4/projects/152630/packages/helm/stable/charts/oracle-mysql-0.1.0.tgz # helm chart URL
    installValues:   # helm install values, you can modify the values according to your needs
      setValues:     # helm set values, here we set the image registry to docker.io for example
        - "image.registry=docker.io"
  install:           # whether to enable the Addon
    enabled: false
  defaultInstallValues: # default install values
  - enabled: false
  type: Helm
```
With the evolution of KubeBlocks API, we strongly recommend that you specify the `addon.kubeblocks.io/kubeblocks-version` field in the Addon CR to ensure compatibility with the KubeBlocks version. If the KubeBlocks version does not meet the requirements, the Addon will not be installed.

1. List and delete existing ClusterDefinition and ClusterVersion, if any
```bash
kubectl get cd,cv,cluster # List existing ClusterDefinition, ClusterVersion, and Cluster
```
If the above resources exist, they need to be deleted first

2. Deploy Addon CR
```bash
kubectl apply -f oracle-mysql-addon.yaml
```

3. Check the status of the Addon
```bash
kubectl get addon oracle-mysql
```
You will see the following output information
```text
NAME           TYPE   STATUS     AGE
oracle-mysql   Helm   Disabled   15s
```
Or you can use `kbcli` to check the detailed information of the Addon
```bash
kbcli addon list oracle-mysql
```
You can see the following output
```text
NAME           VERSION   PROVIDER   STATUS     AUTO-INSTALL
oracle-mysql   0.1.0     ApeCloud   Disabled   false
```
The `STATUS` is displayed as "Disabled", which means that the Addon is not enabled yet.

4. Enable the Addon
```bash
kbcli addon enable oracle-mysql
```
A `Job` object named `install-oracle-mysql-addon` will be generated in the `kb-system` namespace to install the Addon. It will install the chart specified in `addon.spec.helm.chartLocationURL` through Helm, and once the installation is complete, the status of the Addon will be updated to "Enabled".

## YAML, Helm, Addon, Which One to Use And When?
If you are not familiar with Helm Chart, when testing the integration process in a local development environment, it is recommended to use YAML for rapid development, and use the `kubectl apply -f` command to deploy the cluster template and create cluster instances. After the test passes, you can use Helm's template function to optimize the above file structure and build it into a Helm Chart. You can refer to the [Helm Development Guide]((https://helm.sh/zh/docs/chart_template_guide/getting_started/))

Otherwise,  it is recommended to create a Helm Chart for your cluster template (ClusterDefinition and ClusterVersion) and cluster (Cluster) respectively, to facilitate flexible deployments.

E.g., in this tutorial, we provide two helm charts
```txt
├── charts
│   ├── oracle-mysql          # chart for ClusterDefinition and ClusterVersion
│   └── oracle-mysql-cluster  # chart for Cluster
```
You may refer to [kubeblocks-addons](https://github.com/apecloud/kubeblocks-addons/) for more examples.

Addon CRs are used to manage those Addons for KubeBlocks.
You can use the `kbcli addon search/upgrade/install/uninstall <addon-name>` command to manage addons and their versions, and once the Addon is enabled/disabled, the corresponding Helm Chart (say, oracle-mysql) will be installed/uninstalled automatically.

With the evolution of the KubeBlocks ecosystem, more and more Addons will be provided, and you can use Addon CRs to manage them in a more flexible way.

As a developer, you can choose the appropriate method according to your actual needs.

## Q&A
### Question 1. What is the reason for the ClusterVersion status being "Unavailable"?
Usually, the ClusterVersion status is "Unavailable" because of the following reasons:
- The `spec.clusterDefinitionRef` field references a ClusterDefinition that does not exist, or
- The `spec.componentSpecs[*].componentDefs` field references a component definition that does not exist
  You can check the detailed information of ClusterVersion by using the `kubectl describe cv oracle-mysql-8.0.32` command.
  ```bash
  kubectl describe cv oracle-mysql-8.0.32
  ```
  And you can see the following error message in the ClusterVersion status

  ```txt
  Status:
  Cluster Def Generation:  1
  Message:                 spec.componentSpecs[*].componentDefRef [mysql-compdef2] not found in ClusterDefinition.spec.componentDefs[*].name
  ...
  ```
  Update the value of the `spec.componentVersions[*].componentDefRef` field in the ClusterVersion to match the value of the `spec.componentDefs[*].name` field in the ClusterDefinition will solve this problem.

### Question 2. What is the reason for the Cluster status being always "Creating"?
Since KubeBlocks Release 0.8, each Cluster consists of one or more Components, and each Component corresponds to a StatefulSet. If the Cluster is not created successfully, you can troubleshoot the problem by following the steps below:
- Check the Cluster status
  ```bash
  kubectl describe cluster mycluster  # Replace mycluster with the actual Cluster name
  ```
- Check the Component status
  ```bash
  kubectl descirbe component mycluster-mysql-comp  # Replace mycluster-mysql-comp with the actual Component name
  ```
- Check the StatefulSet status
  ```bash
  kubectl describe statefulset mycluster-mysql-comp  # Replace mycluster-mysql-comp with the actual StatefulSet name
  ```
  Usually, you can see the detailed error information in the Events, and troubleshoot the problem based on the error information.

### Question 3. How to support multiple versions of MySQL?
You can create a new ClusterVersion, for example, modify the `oracle-mysql-cv.yaml` file as follows:
```yaml
```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: ClusterVersion
metadata:
  name: oracle-mysql-8.0.32
spec:
  clusterDefinitionRef: oracle-mysql
  componentVersions:
  - componentDefRef: mysql-compdef
    versionsContext:
      containers:
      - name: mysql-container
        image: docker.io/mysql:8.0.32
        imagePullPolicy: IfNotPresent
---
kind: ClusterVersion
metadata:
  name: oracle-mysql-5.7
spec:
  clusterDefinitionRef: oracle-mysql
  componentVersions:
  - componentDefRef: mysql-compdef
    versionsContext:
      containers:
      - name: mysql-container
        image: docker.io/mysql:5.7
        imagePullPolicy: IfNotPresent
```
When creating a Cluster, you can specify the name of the ClusterVersion, for example
```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: mycluster
  namespace: default
spec:
  clusterDefinitionRef: oracle-mysql
  clusterVersionRef: oracle-mysql-5.7  ## update the version name from oracle-mysql-8.0.32 to oracle-mysql-5.7
  componentSpecs:
  - componentDefRef: mysql-compdef
    name: mysql-comp
    replicas: 1
    resources:
      limits:
        cpu: "1"
        memory: 1Gi
      requests:
        cpu: "1"
        memory: 1Gi
    volumeClaimTemplates:
    - name: data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
  terminationPolicy: Delete
```

### Question 4. How to modify the StorageClass when creating a Cluster?
You can specify the StorageClass in the `spec.componentSpecs[*].volumeClaimTemplates[*].spec.storageClassName` field when creating a Cluster, for example, set the StorageClass to `standard`.
```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: mycluster
  namespace: default
spec:
  clusterDefinitionRef: oracle-mysql
  clusterVersionRef: oracle-mysql-8.0.32
  componentSpecs:
  - componentDefRef: mysql-compdef
    name: mysql-comp
    replicas: 1
    resources:
      limits:
        cpu: "1"
        memory: 1Gi
      requests:
        cpu: "1"
        memory: 1Gi
    volumeClaimTemplates:
    - name: data
      spec:
        storageClassName: standard   # 指定StorageClass名称
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi
  terminationPolicy: Delete
```

### Question 5. StatefulSet Event shows "Pod "mycluster-mysql-comp-0" is invalid: spec.containers[0].image: Required value"
If you encounter this error, it is usually because the `spec.componentVersions[*].versionsContext[*].containers[*].name` field in the ClusterVersion does not match the `spec.componentDefs[*].name` field in the ClusterDefinition, which causes the corresponding container to fail to render.
You can check whether the container name in the ClusterVersion matches the container name in the ClusterDefinition by using the following command
```bash
kubectl get cv oracle-mysql-8.0.32 -ojson | jq '.spec.componentVersions[0].versionsContext.containers[0].name'
kubectl get cd oracle-mysql -ojson | jq '.spec.componentDefs[0].podSpec.containers[0].name'
```

### Question 6. Pod is always Pending and the Event shows "pod has unbound immediate PersistentVolumeClaims"
If you encounter this error, it is usually because the PersistentVolumeClaim (PVC) is not bound to the PersistentVolume (PV). You can check the status of the PVC and PV by using the following command
```bash
kubectl get storageclass
```
And set one of the StorageClass as the default StorageClass with the following command
```txt
```bash
kubectl patch storageclass <storageclass-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```


### Question 7. How to debug Helm Chart?
There are a few commands that can help you debug. Refer to the [Helm Debugging Guide](https://helm.sh/docs/chart_template_guide/debugging/)

- `helm lint` is your go-to tool for verifying that your chart follows best practices
- `helm template --debug` will test rendering chart templates locally.
- `helm install --dry-run --debug` will also render your chart locally without installing it, but will also check if conflicting resources are already running on the cluster. Setting --dry-run=server will additionally execute any lookup in your chart towards the server.
- `helm get manifest` This is a good way to see what templates are installed on the server.

Besides, you can create a `values.schema.json` file to impose a schema on your values.yaml file.

### Question 8. Why is data lost after a restart?
In Kubernetes, data persistence is ensured through `PersistentVolumes`. After creating a cluster, KubeBlocks automatically creates a PersistentVolumeClaim (PVC) for data storage.
If data is lost after a cluster restart, it may be because the data was stored locally and not on a PersistentVolume.

1. Check if the PersistentVolumeClaim status is Bound, and record the name of the PVC as "data-mycluster-mysql-comp-0"
```bash
k get pvc
NAME                                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-mycluster-mysql-comp-0   Bound    pvc-d6e66e51-859c-4597-abbd-beba09c0363d   20Gi       RWO            standard       165m
```
2. Check the Volumes used by the POD
```bash
kubectl get pod mycluster-mysql-comp-0 -ojson | jq '.spec.volumes'
```
The output will show the following information:
```json
[
  {
    "name": "data",
    "persistentVolumeClaim": {
      "claimName": "data-mycluster-mysql-comp-0"
    }
  }
  ...
]
```
Refer to the "name" of the corresponding PVC in the first step, which in this case is "data".

3. Check the VolumeMounts used in the Container
```bash
kubectl get pod mycluster-mysql-comp-0 -ojson | jq '.spec.containers[0].volumeMounts'
```
The output will show the following information:

```json
[
  {
    "mountPath": "/var/lib/mysql",
    "name": "data"
  }
  ...
]
```
Check the `mountPath` field, which in this case is "/var/lib/mysql", to ensure it matches the database engine configuration. Make sure that the data needing persistence is stored in this directory.
If there is a mismatch, you need to modify the `mountPath` field in `ClusterDefinition under spec.componentDefs[*].podSpec.containers[*].volumeMounts[*]` to align with the database configuration. After modification, recreate the cluster instance.

## Reference
- [KubeBlocks API Reference](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/)
- [Helm Quickstart](https://helm.sh/docs/intro/quickstart/)
- [KubeBlocks Addons](https://github.com/apecloud/kubeblocks-addons/)
- [Helm JSON Schema](https://helm.sh/docs/topics/charts/#schema-files)
- [Validate Helm Chart Values with JSON Schema](https://www.arthurkoziel.com/validate-helm-chart-values-with-json-schemas/)