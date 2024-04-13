## Lifecycle Management
This series of tutorials uses Oracle MySQL Standalone Cluster as an example, introducing how to integrate MySQL as an Addon into KubeBlocks, and manage the lifecycle of MySQL database through KubeBlocks.

## Goals
Introduce how to create a MySQL database instance on KubeBlocks.

## CRDs
- [ClusterDefinition](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterDefinition)
- [ClusterVersion](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterVersion)


## Integration Process
### Understand the Cluster Architecture
First, you should clarify the architecture of the cluster, including
- What components does the cluster contain
- What is the form of each component: stateful/stateless

### ClusterDefinition and ClusterVersion

#### Describe the Cluster Topology using ClusterDefinition

Create a ClusterDefinition object to describe the cluster topology, and save it as oracle-mysql-cd.yaml file

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
