## 生命周期管理

本系列教程以Oracle MySQL单节点为例, 介绍如何在KubeBlocks对接MySQL数据库, 并通过KubeBlocks管理MySQL数据库的生命周期。

## 教程目标
介绍如何在KubeBlocks上创建一个MySQL数据库实例。

## 相关CRD
- [ClusterDefinition](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterDefinition)
- [ClusterVersion](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterVersion)


## 集成流程
### 了解集群架构
首先需要明确集群的架构, 包括
- 集群包含哪些组件
- 每个组件是什么形态: 有状态/无状态
- 单机版/主备版/集群版

本文档要部署的集群只包含一个组件，该组件是有状态的，且只有一个节点

### 创建集群模版

#### 描述集群拓扑

创建一个`ClusterDefinition`对象来描集群述拓, 保存到为`oracle-mysql-cd.yaml`文件中.

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
可以看到一个ClusterDefinition对象主要描述了以下信息:
1. 该拓扑的名称: oracle-mysql
2. 集群的组件定义
   每个集群拓扑都包含一个或多个组件定义, 该示例中只包含一个组件定义: mysql-compdef, 定义了该组件的一些属性, 包括:
   - 容器: mysql-container
   - 服务名和端口
   - workload类型: Stateful
3. 集群的连接凭证: root用户, 随机密码

`podSpec`和`service`字段分别描述了组件的容器和服务的属性, 可以根据实际情况进行修改.
`connectionCredential`字段描述了集群的连接凭证. 在创建Cluster时, KubeBlocks会先创建一个 secret，其命名规则为 {clusterName}-conn-credential。它包含用户名、密码、endpoint、port 等常规信息，在其他服务访问该集群时使用（这个 secret 会先于其他资源创建，可以在其他地方引用该对象）。 在这个字段中，可以使用一些占位符来引用其他字段的值，如 $(SVC_FQDN)、$(SVC_PORT_mysql)、$(RANDOM_PASSWD) 等。

| 占位符 | 描述 |
| --- | --- |
|UUID	|生成一个随机的 UUID v4 字符串|
|UUID_B64	|生成一个随机的 UUID v4 BASE64 编码的字符串|
|UUID_STR_B64	|生成一个随机的 UUID v4 字符串，然后进行 BASE64 编码|
|UUID_HEX|	生成一个随机的 UUID v4 的 HEX 表示|
|HEADLESS_SVC_FQDN	|无头服务的 FQDN 占位符。值为 - $(CLUSTER_NAME)-$(1ST_COMP_NAME)-headless.$(NAMESPACE).svc，其中 1ST_COMP_NAME 是提供 ClusterDefinition.spec.componentDefs[].service 属性的第一个组件。|
|SVC_FQDN|	服务的 FQDN 占位符。值为 - $(CLUSTER_NAME)-$(1ST_COMP_NAME).$(NAMESPACE).svc，其中 1ST_COMP_NAME 是提供 ClusterDefinition.spec.componentDefs[].service 属性的第一个组件。|
|SVC_PORT_{PORT_NAME}	| 具有指定端口名称的 ServicePort 的端口值。例如，在一个 servicePort 的 JSON struct {"name": "mysql", "targetPort": "mysqlContainerPort", "port": 3306} 中，连接凭证值中的 "$(SVC_PORT_mysql)" 为 3306。|
|RANDOM_PASSWD	| 随机生成的 8 个字符的密码。|

#### 描述集群版本
创建一个`ClusterVersion`对象来描集群各个组件的版本, 保存到为`oracle-mysql-cv.yaml`文件中
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
ClusterVersion对象主要描述了以下信息:
1. 该ClusterVersion的名称: oracle-mysql-8.0.32
2. 该版本引用的拓扑模版: oracle-mysql
   若ClusterVersion引用的ClusterDefinition不存在, 则会导致ClusterVersion的状态为"Unavailable"
3. 该版本的组件版本
   每个集群版本都包含一个或多个组件版本, 该示例中只包含一个组件版本: mysql-compdef, 定义了该组件的容器镜像版本, 包括:
   - 容器: mysql-container
   - 镜像: docker.io/mysql:8.0.32
  若`componentDefRef`中引用组件定义不存在, 则会导致ClusterVersion的状态为"Unavailable"

### 部署集群模版
1. 通过kubectl命令部署集群模版
```bash
kubectl apply -f oracle-mysql-cd.yaml
kubectl apply -f oracle-mysql-cv.yaml
```

2. 查看集群拓扑模版状态
```bash
kubectl get clusterdefinition    # 查看集群拓扑模版状态
```
可以看到输出如下信息, `STATUS`显示为"Available"则表示集群拓扑模版创建成功
```bash
NAME             MAIN-COMPONENT-NAME   STATUS      AGE
oracle-mysql     mysql-compdef         Available   2s
```

3. 查看集群版本状态
```bash
kubectl get clusterversion       # 查看集群版本状态
```
可以看到输出如下信息, `STATUS`显示为"Available"则表示集群版本创建成功
```txt
NAME                                   CLUSTER-DEFINITION   STATUS      AGE
oracle-mysql-8.0.32                    oracle-mysql         Available   2s
```


### 创建集群
创建一个`Cluster`对象来描述集群实例, 保存到为`oracle-mysql-cluster.yaml`文件中.

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

Cluste对象主要描述:
1. 集群的名称: mycluster
2. 集群的命名空间: default
3. 集群的拓扑模版: oracle-mysql
4. 集群的版本: oracle-mysql-8.0.32
4. 集群的组件实例: mysql-compdef
5. 集群的资源配置: cpu/memory分别为1/1Gi
6. 集群的存储配置: 20Gi
7. 集群的终止策略: Delete
  更多有关终止策略的说明请参考[TerminationPolicyType](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.TerminationPolicyType), 本文档中使用的是`Delete`策略, 表示删除集群时会删除集群中的所有存储资源。


1. 创建集群实例
```bash
kubectl apply -f oracle-mysql-cluster.yaml
```
2. 查看集群状态
然后就可以看到一个名为`mycluster`的集群实例被创建了。
```bash
kubectl  get cluster mycluster
```
可以看到输出如下信息
- `CLUSTER-DEFINITION`显示为"oracle-mysql"则表示集群实例使用的拓扑模版为`oracle-mysql`
- `VERSION`显示为"oracle-mysql-8.0.32"则表示集群实例使用的版本为`oracle-mysql-8.0.32`
- `STATUS`显示为"Running"则表示集群创建成功
- `AGE`显示为"1m"则表示集群创建时间为1分钟
- `TERMINATION-POLICY`显示为"Delete"则表示集群终止策略为"Delete"

```text
NAME        CLUSTER-DEFINITION   VERSION               TERMINATION-POLICY   STATUS    AGE
mycluster   oracle-mysql         oracle-mysql-8.0.32   Delete               Running   1m
```

3. 修改集群资源
如果需要修改集群的资源配置, 目前有多种方式可以修改
  - 通过`kubectl edit cluster mycluster`命令来修改集群的资源配置
  - 通过`kbcli`下发修改请求
```bash
kbcli cluster vscale mycluster --components mysql-comp --cpu 2 --memory 2Gi
```
该操作会生成一个`VerticalScaling`类型的`OpsRequest`对象, 用于修改集群的资源配置, 通过`kubectl get opsrequest`命令可以查看该操作的进度.


## Q&A
### Question 1. ClusterVersion状态为"Unavailable"是什么原因?
  查看ClusterVersion的状态, 如果状态为"Unavailable",可以通过`kubectl describe clusterversion oracle-mysql-8.0.32`查看详细信息.
  通常是因为ClusterVersion中
  - `spec.clusterDefinitionRef`字段引用的ClusterDefinition不存在, 或者
  - `spec.componentSpecs[*].componentDefs`字段引用的组件定义不存在

  可以通过以下命令查看ClusterVersion的详细信息
  ```bash
  kubectl describe cv oracle-mysql-8.0.32  # 把oracle-mysql-8.0.32替换为实际的ClusterVersion名称
  ```

  看到ClusterVersion的Status的Message会显示如下错误
  ```txt
  Status:
  Cluster Def Generation:  1
  Message:                 spec.componentSpecs[*].componentDefRef [mysql-compdef2] not found in ClusterDefinition.spec.componentDefs[*].name
  ...
  ```
  更新ClusterVersion对应字段的值即可.

### Question 2. Cluster没有创建成功, 该如何排查问题?
  在KubeBlocks Release 0.8版本中, 每个Cluster有一个或者多个Component组成, 每个Component对应一个StatefulSet
  若Cluster如果没有创建成功, 可以按照以下流程排查问题
  - 查看Cluster状态
  ```bash
  kubectl describe cluster mycluster  # 把mycluster替换为实际的Cluster名称
  ```
  - 查看Component状态
  在KubeBlocks Release 0.8版本中, 每个Cluster有一个或者多个Component组成. 每个Component的状态信息保存在`Cluster`对象的`status.components`字段中, 可以通过以下命令查看Component的详细信息
  ```bash
  kubectl descirbe component mycluster-mysql-comp  # 把mycluster-mysql-comp替换为实际的Component名称
  ```
  - 查看StatefulSet状态
  ```bash
  kubectl describe statefulset mycluster-mysql-comp  # 把mycluster-mysql-comp替换为实际的StatefulSet名称
  ```
  通常可以在Events中查看到具体的错误信息, 根据错误信息进行排查.

### Question 3. 如果要支持多个版本的MySQL, 该如何修改?
可以新增一个ClusterVersion, 例如, 修改`oracle-mysql-cv.yaml`文件如下:
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
在创建集群时, 可以指定ClusterVersion的名称, 例如
```yaml
apiVersion: apps.kubeblocks.io/v1alpha1
kind: Cluster
metadata:
  name: mycluster
  namespace: default
spec:
  clusterDefinitionRef: oracle-mysql
  clusterVersionRef: oracle-mysql-5.7
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

### Question 4. 如何在创建集群时指定StorageClss?
在Cluster对象的`spec.componentSpecs[*].volumeClaimTemplates[*].spec.storageClassName`字段中指定存储类型, 例如
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

### Question 5. StatefulSet的Event显示Pod "mycluster-mysql-comp-0" is invalid: spec.containers[0].image: Required value
若出现该错误, 通常是因为ClusterVersion中的`spec.componentVersions[*].versionsContext[*].containers[*].name`字段和ClusterDefinition中的`spec.componentDefs[*].name`字段不一致, 导致无法渲染出对应的容器.
可通过下面的命令查看ClusterVersion和ClusterDefinition中的容器名称是否匹配
```bash
kubectl get cv oracle-mysql-8.0.32 -ojson | jq '.spec.componentVersions[0].versionsContext.containers[0].name'
kubectl get cd oracle-mysql -ojson | jq '.spec.componentDefs[0].podSpec.containers[0].name'
```
### Question 6. Pod一直Pending且Event显示 "pod has unbound immediate PersistentVolumeClaims"
通常是因为Kubernetes集群中没有标记为"default"的StorageClass, 可以通过以下命令查看StorageClass
```bash
kubectl get storageclass
```
并将其中一个StorageClass标记为"default"
```bash
kubectl patch storageclass <storageclass-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
