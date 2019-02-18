 > $ kubectl [command] [TYPE] [NAME] [flags]  
 > * command：子命令，用于操作Kubernetes集群资源对象的命令，例如create、delete、describe、get、apply等；  
 ![子命令1](https://github.com/junfsir/memo/raw/master/images/subcomm1.png)  
 ![子命令1](https://github.com/junfsir/memo/raw/master/images/subcomm2.png)  
 > * TYPE：资源对象的类型，区分大小写，能以单数形式、复数形式或者简写形式表示；  
 ![资源对象](https://github.com/junfsir/memo/raw/master/images/type.png)  
 > * NAME：资源对象的名称，区分大小写。如果不指定名称，则系统将返回属于TYPE的全部对象的列表，例如$kubectl get pods将返回所有Pod的列表；  
 > * flags：kubectl子命令的可选参数，例如使用“-s”指定apiserver的URL地址而不用默认值；  
 ![参数](https://github.com/junfsir/memo/raw/master/images/flags.png)  
 ![输出格式](https://github.com/junfsir/memo/raw/master/images/输出格式.png)  



