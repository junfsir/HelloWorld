# [Go语言之读取yaml配置文件，转换成struct结构，json形式输出](https://blog.51cto.com/xingej/2115258)

## 1、例子1

### 1.1、yaml文件内容如下:

```yaml
host: localhost:3306
user: root
pwd: 123456
dbname: test  
```

### 1.2、代码如下：

```go
//将yaml文件，转换成对象，再转换成json格式输出
package main

import (
    "encoding/json"
    "fmt"
    "gopkg.in/yaml.v2"
    "io/ioutil"
)

//定义conf类型
//类型里的属性，全是配置文件里的属性
type conf struct {
    Host   string `yaml: "host"`
    User   string `yaml:"user"`
    Pwd    string `yaml:"pwd"`
    Dbname string `yaml:"dbname"`
}

func main() {
    var c conf
    //读取yaml配置文件
    conf := c.getConf()
    fmt.Println(conf)

    //将对象，转换成json格式
    data, err := json.Marshal(conf)

    if err != nil {
        fmt.Println("err:\t", err.Error())
        return
    }

    //最终以json格式，输出
    fmt.Println("data:\t", string(data))
}

//读取Yaml配置文件,
//并转换成conf对象
func (c *conf) getConf() *conf {
    //应该是 绝对地址
    yamlFile, err := ioutil.ReadFile("E:\\Program\\go2\\goPath\\src\\xingej-go\\xingej-go\\xingej-go666\\lib\\yaml\\conf.yaml")
    if err != nil {
        fmt.Println(err.Error())
    }

    err = yaml.Unmarshal(yamlFile, c)

    if err != nil {
        fmt.Println(err.Error())
    }

    return c
}
```

如果某一个包，本地没有的话，可以在cmd中使用下面的命令，进行下载，如:
go get gopkg.in/yaml.v2

==基本格式:== go get 包的路径

## 2、例子2，该配置文件中，存在map,slice类型，稍微复杂些

### 2.1、 配置文件内容：

```go
apiVersion: v1
kind: KafkaCluster2
metadata:
  name: kafka-operator
  labels:
    config1:
      address: kafka-operator-labels-01
      id: kafka-operator-labels-02
      name: mysql-example-cluster-master
      nodeName: 172.16.91.21
      role: master
    config2:
       address: kafka-operator-labels-01
       id: kafka-operator-labels-02
       name: mysql-example-cluster-slave
       nodeName: 172.16.91.110
       role: slave
spec:
  replicas: 1
  name: kafka-controller
  image: 172.16.26.4:5000/nginx
  ports: 8088
  conditions:
    - containerPort: 8080
      requests:
        cpu: "0.25"
        memory: "512Mi"
      limits:
        cpu: "0.25"
        memory: "1Gi"
    - containerPort: 9090
      requests:
        cpu: "0.33"
        memory: "333Mi"
      limits:
        cpu: "0.55"
        memory: "5Gi"
```

### 2.2、 代码如下：

```go
package main

import (
    "encoding/json"
    "fmt"
    "gopkg.in/yaml.v2"
    "io/ioutil"
)

type KafkaCluster struct {
    ApiVersion string   `yaml:"apiVersion"`
    Kind       string   `yaml: "kind"`
    Metadata   Metadata `yaml: "metadata"`
    Spec       Spec     `yaml: "spec"`
}

type Metadata struct {
    Name string `yaml:"name"`
    //map类型
    Labels map[string]*NodeServer `yaml:"labels"`
}

type NodeServer struct {
    Address string `yaml: "address"`
    Id      string `yaml: "id"`
    Name    string `yaml: "name"`
    //注意，属性里，如果有大写的话，tag里不能存在空格
    //如yaml: "nodeName" 格式是错误的，中间多了一个空格，不能识别的
    NodeName string `yaml:"nodeName"`
    Role     string `yaml: "role"`
}

type Spec struct {
    Replicas int    `yaml: "replicas"`
    Name     string `yaml: "name"`
    Image    string `yaml: "iamge"`
    Ports    int    `yaml: "ports"`
    //slice类型
    Conditions []Conditions `yaml: "conditions"`
}

type Conditions struct {
    ContainerPort string   `yaml:"containerPort"`
    Requests      Requests `yaml: "requests"`
    Limits        Limits   `yaml: "limits"`
}

type Requests struct {
    CPU    string `yaml: "cpu"`
    MEMORY string `yaml: "memory"`
}

type Limits struct {
    CPU    string `yaml: "cpu"`
    MEMORY string `yaml: "memory"`
}

func main() {
    var c KafkaCluster
    //读取yaml配置文件, 将yaml配置文件，转换struct类型
    conf := c.getConf()

    //将对象，转换成json格式
    data, err := json.Marshal(conf)

    if err != nil {
        fmt.Println("err:\t", err.Error())
        return
    }

    //最终以json格式，输出
    fmt.Println("data:\t", string(data))
}

//读取Yaml配置文件,
//并转换成conf对象  struct结构
func (kafkaCluster *KafkaCluster) getConf() *KafkaCluster {
    //应该是 绝对地址
    yamlFile, err := ioutil.ReadFile("E:\\Program\\go2\\goPath\\src\\xingej-go\\xingej-go\\xingej-go666\\lib\\yaml\\sparkConfig.yaml")
    if err != nil {
        fmt.Println(err.Error())
    }

    //err = yaml.Unmarshal(yamlFile, kafkaCluster)
    err = yaml.UnmarshalStrict(yamlFile, kafkaCluster)

    if err != nil {
        fmt.Println(err.Error())
    }

    return kafkaCluster
}
```

### 2.3、运行结果：

```json
data:    {"ApiVersion":"v1","Kind":"KafkaCluster2","Metadata":{"Name":"kafka-operator","Labels":{"config1":{"Address":"kafka-operator-labels-01","Id":"kafka-operator-labels-02","Name":"mysql-example-cluster-master","NodeName":"172.16.91.21","Role":"master"},"config2":{"Address":"kafka-operator-labels-01","Id":"kafka-operator-labels-02","Name":"mysql-example-cluster-slave","NodeName":"172.16.91.110","Role":"slave"}}},"Spec":{"Replicas":1,"Name":"kafka-controller","Image":"172.16.26.4:5000/nginx","Ports":8088,"Conditions":[{"ContainerPort":"8080","Requests":{"CPU":"0.25","MEMORY":"512Mi"},"Limits":{"CPU":"0.25","MEMORY":"1Gi"}},{"ContainerPort":"9090","Requests":{"CPU":"0.33","MEMORY":"333Mi"},"Limits":{"CPU":"0.55","MEMORY":"5Gi"}}]}}
```

==注意：==

```
yaml配置文件里，如果属性里存在大写的话，定义对应的属性时，一定不能有空格，可以参考上面例子中NodeServer里的说明  
```

## 3 例子3，读取yaml配置文件中的某一个属性

### 3.1、 配置文件的内容：

```yaml
apiVersion: v1
Kind: KafkaCluster
```

### 3.2、代码如下：

```go
//测试读取yaml文件的
package main

import (
    "fmt"
    "github.com/kylelemons/go-gypsy/yaml"
)

func main() {
    file, err := yaml.ReadFile("E:\\Program\\go2\\goPath\\src\\xingej-go\\xingej-go\\xingej-go666\\lib\\yaml\\nginx")

    if err != nil {
        panic(err.Error())
    }

    apiVersion, error := file.Get("apiVersion")
    if error != nil {
        panic(error.Error())
    }

    fmt.Println("=apiVersion===:\t", apiVersion)

}
```

### 3.3、运行结果 ：

```
=apiVersion===:  v1 
```

## 4. 说明

```
例子3中用到的yaml解析包跟前面两个例子不是同一个。  

"gopkg.in/yaml.v2"
"github.com/kylelemons/go-gypsy/yaml"  

例子1，例子2 是整体读取Yaml配置文件，转换成其他格式  

例子3，是读取yaml配置里的某一个属性，  

因此，两者的使用场景是不一样的
```