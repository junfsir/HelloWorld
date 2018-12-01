**在Sublime Text 3安装GoSublime搭建GoLang开发环境**

- [ ] 快捷键 shift + command + p，弹出框中输入install package；

- [ ] 输入gosublime，回车确认；

- [ ] 安装完成后，Preferences -> package settings -> GoSublime -> Settings - Uesrs需要配置下GOPATH，GOROOT：

``` json
		{

		    "env": {

		        "GOPATH": "/User/jeason/Go",

		        "GOROOT": "/usr/local/go" 

		    }

		}


```



``` go
/*
GOPATH：自定义工作dir；
GOROOT：GoLang安装包dir；
*/
```

