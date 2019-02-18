`journalctl -u kubelet -f`查看日志时发现一直在输出`“Orphaned pod`的信息：

```shell
Feb 11 03:20:21 k8s-prod-0-211 kubelet: E0211 03:20:21.964740    1597 kubelet_volumes.go:140] Orphaned pod "626ab649-26c0-11e9-a791-001517ac3898" found, but volume paths are still present on disk : There were a total of 1 errors similar to this. Turn up verbosity to see them.
Feb 11 03:20:23 k8s-prod-0-211 kubelet: E0211 03:20:23.973961    1597 kubelet_volumes.go:140] Orphaned pod "626ab649-26c0-11e9-a791-001517ac3898" found, but volume paths are still present on disk : There were a total of 1 errors similar to this. Turn up verbosity to see them.
```

说明`pod id`为`626ab649-26c0-11e9-a791-001517ac3898`的pod为`Orphaned pod`，并且试图删除pod残留数据时失败，为kubelet处理数据卷时出现的问题，`https://github.com/kubernetes/kubernetes/issues/60987`，可运行以下脚本来暂时修复：

```shell
echo "Start to scanning Orphaned Pod. Orphaned directory will be umounted if it is mounted, and will be removed if it is empty."

IFS=$'\r\n'
for ((i=1; i<=100; i++));
do
    orphanExist="false"
    for item in `tail /var/log/messages`;
    do
        if [[ $item == *"Orphaned pod"* ]] && [[ $item == *"but volume paths are still present on disk"* ]]; then
            secondPart=`echo $item | awk -F"Orphaned pod" '{print $2}'`
            podid=`echo $secondPart | awk -F"\"" '{print $2}'`

            # not process if the volume directory is not exist.
            if [ ! -d /data/kubelet/pods/$podid/volumes/ ]; then
                continue
            fi

            # umount subpath if exist
            if [ -d /data/kubelet/pods/$podid/volume-subpaths/ ]; then
                mountpath=`mount | grep /data/kubelet/pods/$podid/volume-subpaths/ | awk '{print $3}'`
                for mntPath in $mountpath;
                do
                    echo "umount subpath $mntPath"
                    umount $mntPath
                done
            fi

            orphanExist="true"
            volumeTypes=`ls /data/kubelet/pods/$podid/volumes/`
            for volumeType in $volumeTypes;
            do
                subVolumes=`ls -A /data/kubelet/pods/$podid/volumes/$volumeType`
                if [ "$subVolumes" != "" ]; then
                    echo "/data/kubelet/pods/$podid/volumes/$volumeType contents volume: $subVolumes"
                    for subVolume in $subVolumes;
                    do
                        # check subvolume path is mounted or not
                        findmnt /data/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                        if [ "$?" != "0" ]; then
                            echo "/data/kubelet/pods/$podid/volumes/$volumeType/$subVolume is not mounted, just need to remove"
                            content=`ls -A /data/kubelet/pods/$podid/volumes/$volumeType/$subVolume`
                            # if path is empty, just remove the directory.
                            if [ "$content" = "" ]; then
                                rmdir /data/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                            # if path is not empty, do nothing.
                            else
                                echo "/data/kubelet/pods/$podid/volumes/$volumeType/$subVolume is not mounted, but not empty"
                                orphanExist="false"
                            fi
                        # is mounted, umounted it first.
                        else
                            echo "/data/kubelet/pods/$podid/volumes/$volumeType/$subVolume is mounted, umount it"
                            umount /data/kubelet/pods/$podid/volumes/$volumeType/$subVolume
                        fi
                    done
                fi
            done
        fi
    done
    if [ "$orphanExist" = "false" ]; then
        break
    fi
    sleep 2
done
```



[挂载失败-日志中显示僵尸pod的问题](https://yq.aliyun.com/articles/688719)