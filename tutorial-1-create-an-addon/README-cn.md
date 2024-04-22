## 生命周期管理

本系列教程以Oracle MySQL单节点为例, 介绍如何在KubeBlocks对接MySQL数据库, 并通过KubeBlocks管理MySQL数据库的生命周期。

## 教程目标
介绍如何在KubeBlocks上创建一个MySQL数据库实例。

教程中使用的`YAML` 示例可以在 `./examples`目录下找到, 此外还在`./chart`目录下提供了`Helm`示例.
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

## 相关CRD
- [ClusterDefinition](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterDefinition)
- [ClusterVersion](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/cluster#apps.kubeblocks.io/v1alpha1.ClusterVersion)
- [Addon](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/add-on#extensions.kubeblocks.io/v1alpha1.Addon)


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
        - mountPath: /var/lib/mysql   #  mountPath 为容器中的挂载路径, 需要根据实际情况修改
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
或者使用 `kbcli` 工具创建集群实例
```bash
kbcli cluster create mycluster --cluster-definition oracle-mysql --cluster-version oracle-mysql-8.0.32
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

## 用Helm部署集群
前文介绍了如何通过`YAML`文件创建集群模版, 不论是`ClusterDefinition`还是`ClusterVersion`都是通过`YAML`文件来定义的, 但是在实际生产环境中, 通过`YAML`文件来管理会比较麻烦, 推荐使用`Helm`来管理[Helm Tutorial](https://helm.sh/docs/intro/quickstart/)

在`./chart`目录下提供了`Helm`示例, 可以通过`Helm`部署模板
```bash
kubectl create ns demo
helm -n demo install oracle-mysql ./chart/oracle-mysql
```

通过`Helm`创建集群, 例如
```bash
kubectl create ns cluster-demo
helm -n cluster-demo install mycluster ./chart/oracle-mysql-cluster
```

## 用Addon CR管理模版
到目前为止, 我们掌握了在本地开发环境部署集群的方法, 但是如何让KubeBlocks的用户都能用上呢? 为了解决这个问题, 我们可以使用Addon CR来管理你的模版.
KubeBlocks用`Addon`来管理两类插件:
- 数据库引擎插件, 例如 ApeCloud-MySQL, Nebula-Graph, StarRocks. 更多引擎插件可以在 [kubeblocks-addons](https://github.com/apecloud/kubeblocks-addons/)找到
- 应用插件, 例如 snapshot-controller, Kube-Bench, fault-chaos-mesh等.

### 打包helm chart
首先我们要把`Helm`模板打包成`tgz`文件, 例如
```bash
helm package ./chart/oracle-mysql
```
并推送到`Helm`仓库, 例如
```bash
helm push oracle-mysql-0.1.0.tgz <your-helm-repo>
```

### 创建Addon CR
```yaml
apiVersion: extensions.kubeblocks.io/v1alpha1
kind: Addon
metadata:
  annotations:
    addon.kubeblocks.io/kubeblocks-version: '>=0.8.0'  # 插件支持的KubeBlocks版本, 用于兼容不同版本的KubeBlocks
  labels:
    addon.kubeblocks.io/model: RDBMS                   # 插件包装的引擎类型, 常用的有RDBMS, NoSQL, Graph等
    addon.kubeblocks.io/provider: ApeCloud             # 插件提供者
    addon.kubeblocks.io/version: 0.1.0                 # 插件版本, 用于区分不同版本的插件
  name: oracle-mysql                                   # Addon名称, 通常用引擎名表示
spec:
  description: MySQL is a widely used, open-source relational database management system (RDBMS).
  helm:
    chartLocationURL: https://jihulab.com/api/v4/projects/152630/packages/helm/stable/charts/oracle-mysql-0.1.0.tgz # helm chart的地址
    installValues:   # helm install时的参数, 对应`values.yaml`文件
      setValues:
        - "image.registry=docker.io"
  install:
    enabled: false
  defaultInstallValues:
  - enabled: false
  type: Helm
```
1. 清理环境, 删除已有的ClusterDefinition和ClusterVersion
```bash
kubectl get cd,cv,cluster
```
若存上述的资源, 需要先删除

2. 部署Addon CR
```bash
kubectl apply -f oracle-mysql-addon.yaml
```
3. 查看Addon状态
```bash
kubectl get addon oracle-mysql
```
可以看到输出如下信息
```text
NAME           TYPE   STATUS     AGE
oracle-mysql   Helm   Disabled   15s
```

可以通过kbcli查看
```bash
kbcli addon list oracle-mysql
```
可以看到输出如下信息
```text
NAME           VERSION   PROVIDER   STATUS     AUTO-INSTALL
oracle-mysql   0.1.0     ApeCloud   Disabled   false
```
这里的`STATUS`显示为"Disabled"表示Addon创建成功, 但是没有自动安装

4. 可以通过`kbcli addon install oracle-mysql`命令来安装Addon
```bash
kbcli addon install oracle-mysql
```
在kb-system名空间下会生成一个名为`install-oracle-mysql-addon`类型的`Job`对象, 用于安装Addon. 它会通过`Helm`安装`addon.spec.helm.chartLocationURL`中指定的chart.

此时, 查看到的Addon状态从 Disabled 变为 Enabling, 最终变为 Endabled, 表示Addon安装成功.

通过分发Addon CR, 所有KubeBlocks用户都可以通过`kbcli addon install oracle-mysql`命令来安装Addon, 从而创建集群实例.

> 所有提交到`kubeblocks-addons`仓库的插件都会有一个对应的Aaddon CR, 用户可以通过`kbcli addon search`命令查看所有的插件.
> 为了方便用户使用, 可以通过`kbcli addon install <addon-name>`命令来安装插件.


## YAML, Helm, Addon 到底选哪一个
如果你对Helm Chart不熟悉, 在本地开发环境测试集成流程时, 推荐使用`YAML`快速开发, 通过`kubectl apply -f`命令来部署集群模版, 创建集群实例.
测试通过后可以利用Helm的模版功能来优化上述文件构并建成Helm Chart, 可以参考[Heml 开发指南](https://helm.sh/zh/docs/chart_template_guide/getting_started/)

如果你对Helm Chart熟悉, 推荐使用`Helm`来部署集群模版, 创建集群实例.
推荐为你的集群模版(ClusterDefinition和ClusterVersion)和集群(Cluster)分别创建一个Helm Chart, 方便用户灵活部署.
例如, 在本教程中,
```txt
├── charts
│   ├── oracle-mysql          # chart for ClusterDefinition and ClusterVersion
│   └── oracle-mysql-cluster  # chart for Cluster
```
更多引擎插件的例子可以在 [kubeblocks-addons](https://github.com/apecloud/kubeblocks-addons/)找到


Addon 可以理解为KubeBlocks的插件管理方式. 你可以通过`kbcli addon search/upgrade/install/uninstall <addon-name>`命令来管理插件及其版本.
插件开发完成后, 如果你想让KubeBlocks的用户都能用上, 我们推荐使用`Addon`来管理, 它描述了插件的基本信息, 例如依赖的KubeBlocks版本, 插件的提供者, 插件的版本, 默认安装参数等.

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
s
### Question 4. 如何在创建集群时指定StorageClass?
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

### Question 7. 如何快速调试Helm Chart?
参考[Helm 调试模板](https://helm.sh/zh/docs/chart_template_guide/debugging//),
在本地开发环境中, 可以用一下命令来快速调试Helm Chart
- `helm lint` 是验证chart是否遵循最佳实践的首选工具, 可以快速检查chart的问题
- `helm template --debug` 在本地测试渲染chart模板
- `helm install --dry-run --debug`, 这是让服务器渲染模板的好方法，然后返回生成的清单文件
- `helm get manifest` 这是查看安装在服务器上的模板的好方法。
此外, 我们还可以在helm chart中添加一个`valeus.schema.json`文件, 用于描述`values.yaml`文件的schema; 或者添加一个`validation.yaml`文件, 用于描述`values.yaml`文件的校验规则.

### Question 8. 为什么重启后数据丢失了?
在Kubernetes中, 通过PersistentVolume来保证数据的持久性. 在创建集群后, KubeBlocks会自动创建一个PersistentVolumeClaim, 用于存储数据.
如果集群重启后数据丢失, 可能是因为数据存储在本地, 没有使用PersistentVolume.
1. 查看PersistentVolumeClaim状态是否为Bound, 记录该PVC的名字为"data-mycluster-mysql-comp-0"
```bash
k get pvc
NAME                                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-mycluster-mysql-comp-0   Bound    pvc-d6e66e51-859c-4597-abbd-beba09c0363d   20Gi       RWO            standard       165m
```
2. 查看POD使用的Volumes
```bash
kubectl get pod mycluster-mysql-comp-0 -ojson | jq '.spec.volumes'
```
会看到输出如下信息
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
查看第一步中对应PVC的"name", 在本例中为"data"

3. 查看Container中使用的VolumeMounts
```bash
kubectl get pod mycluster-mysql-comp-0 -ojson | jq '.spec.containers[0].volumeMounts'
```
会看到输出如下信息
```json
[
  {
    "mountPath": "/var/lib/mysql",
    "name": "data"
  }
  ...
]
```
查看`mountPath`字段, 在本例中为"/var/lib/mysql", 确认该目录是否和数据库引擎配置一致, 确保需要持久化的数据存储在该目录下.
如果不一致, 需要修改`ClusterDefinition`中的`spec.componentDefs[*].podSpec.containers[*].volumeMounts[*].mountPath`字段, 使其和数据库配置一致. 修改后, 重新创建集群实例.

### Question 9. Permission Denied? 目录没有权限写入, 如何解决
如果容器启动时, 看到如下的错误信息
```txt
cannot access data directory: xxx : Permission denied
```
说明容器没有权限写入该目录(文件夹只有owner(也就是root)才有写权限.)

不同StorageClass的默认行为不同, 为了解决该问题, 可以通过`initContainer`来修改目录的权限, 例如:
```yaml
  podSpec:
    initContainers:
      - name: volume-permissions
        image: busybox:1.28
        imagePullPolicy: IfNotPresent
        command:
          - /bin/sh
          - -ec
          - |
            chown -R groupid:userid /mounted/path
        securityContext:
          runAsUser: 0
        volumeMounts:
          - name: data
            mountPath: /mounted/path
    containers:
      - name: etcd
        imagePullPolicy: "IfNotPresent"
        securityContext:
          runAsNonRoot: false
          runAsUser: userid
        volumeMounts:
          - mountPath: /mounted/path
            name: data
        ports:
        ...
```

这个配置中，initContainer 主要用于在主容器启动之前确保挂载卷上的文件权限正确。在这个例子中，initContainer 会将 `/mounted/path` 目录的所有者更改为`userid:groupid`。这样，主容器就可以在 `/mounted/path` 目录中写入文件了。`groupid:userid` 和挂载的路径 `/mounted/path` 需要根据实际情况修改。
可以参考案例[Greptime](https://github.com/apecloud/kubeblocks-addons/blob/e22dc624905183b91ccb5d87512bdc491b454849/addons/greptimedb/templates/clusterdefinition.yaml#L349)



## Reference
- [KubeBlocks API Reference](https://kubeblocks.io/docs/release-0.8/developer_docs/api-reference/)
- [Helm Quickstart](https://helm.sh/docs/intro/quickstart/)
- [KubeBlocks Addons](https://github.com/apecloud/kubeblocks-addons/)
- [Helm JSON Schema](https://helm.sh/docs/topics/charts/#schema-files)
- [Validate Helm Chart Values with JSON Schema](https://www.arthurkoziel.com/validate-helm-chart-values-with-json-schemas/)