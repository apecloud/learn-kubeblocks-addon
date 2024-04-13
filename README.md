# learn-kubeblocks-addon

This is a companion repository for KubeBlocks Addon Tutorial, while KubeBlocks is a cloud-native data infrastructure based on Kubernetes (K8s) used for managing various types of database engines.

The document aims to introduce the basic knowledge of integrated database engines, helping you to quickly get started and become a member of the KubeBlocks community.

KubeBlocks has a rich integrated ecosystem and has connected to many mainstream databases, including:

- Relational databases: ApeCloud-MySQL (MySQL cluster version), PostgreSQL (PostgreSQL master-slave version);
- NoSQL databases: MongoDB, Redis;
- Graph databases: Nebula (contributed by the community);
- Time-series databases: TDengine, Greptime (contributed by the community);
- Vector databases: Milvus, Qdrant, Weaviate, etc;
- Stream databases: Kafka, Pulsar.

More database engines will be integrated, refer to [KubeBlocks Addon](https://github.com/apecloud/kubeblocks-addons) repository to get the latest information.

Before you start, you need to have the following knowledge:

Able to write some YAML (for example, know how many spaces are needed for YAML indentation).
- Understand Helm (for example, know what Helm and Helm chart are).
- Understand the basic concepts of K8s (for example, know what a Pod is, have used Helm to install Operator on K8s).
- Understand the basic concepts of KubeBlocks, such as ClusterDefinition, ClusterVersion, and Cluster.
