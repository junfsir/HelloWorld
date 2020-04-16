```shell
#!/bin/bash
container_id=$(head -1 /proc/$1/cgroup | cut -d / -f 5)
docker_id=`echo ${container_id:0:12}`
docker ps  | grep $docker_id | awk '{print $NF}' | awk -F 'k8s_|_default' '{print $2}'
```

