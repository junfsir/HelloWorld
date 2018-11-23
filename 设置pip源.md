**国内的网络环境有时不太稳定，在使用pip的官方源时极慢，可以通过设置国内的镜像源来提速。**  
*命令行安装时指定镜像源，此方式每次安装时都要指定，较麻烦；*  
`pip install -i http://pypi.tuna.tsinghua.edu.cn/simple matplotlib --trusted-host pypi.tuna.tsinghua.edu.cn`  
*修改配置文件；* 
``` 
    vim ~/.pip/pip.conf
    [global]
    index-url = http://pypi.tuna.tsinghua.edu.cn/simple
    trusted-host = pypi.tuna.tsinghua.edu.cn
```
