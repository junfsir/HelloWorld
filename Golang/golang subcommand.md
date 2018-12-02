[Go语言几大命令简单介绍](https://blog.csdn.net/wuya814070935/article/details/50219915)  

#### go build  
`go build` 命令主要是用于测试编译；在包的编译过程中，若有必要，会同时编译与之相关联的包。

- [ ] 如果是普通包，当你执行`go build`命令后，不会产生任何文件;
- [ ] 如果是main包，当只执行`go build`命令后，会在当前目录下生成一个可执行文件；如果需要在`$GOPATH/bin`下生成相应的可执行文件，需要执行`go install` 或者使用 `go build -o` 指定路径；
- [ ] 如果某个文件夹下有多个文件，而你只想编译其中某一个文件，可以在 `go build` 之后加上文件名，例如 `go build test.go`；`go build` 命令默认会编译当前目录下的所有go文件；
- [ ] 你也可以指定编译输出的文件名；比如，我们可以指定`go build -o myapp`，默认是package名(非main包)，或者是第一个源文件的文件名(main包)；
- [ ] `go build `会忽略目录下以”_”或者”.”开头的go文件；
- [ ] 如果你的源代码针对不同的操作系统需要不同的处理，那么你可以根据不同的操作系统后缀来命名文件；例如有一个读取数组的程序，它对于不同的操作系统可能有如下几个源文件：

``` shell
array_linux.go 
array_darwin.go 
array_windows.go 
array_freebsd.go
```

`go build`时会选择性地编译以系统名结尾的文件（Linux、Darwin、Windows、Freebsd）；例如Linux系统下编译只会选择`array_linux.go`文件，其它系统命名后缀文件全部忽略。

### go clean  
`go clean` 命令是用来移除当前源码包里面编译生成的文件，这些文件包括：

- [ ] _obj/ 旧的object目录，由Makefiles遗留
- [ ] test/ 旧的test目录，由Makefiles遗留
- [ ] _testmain.go 旧的gotest文件，由Makefiles遗留
- [ ] test.out 旧的test记录，由Makefiles遗留
- [ ] build.out 旧的test记录，由Makefiles遗留
- [ ] *.[568ao] object文件，由Makefiles遗留
- [ ] DIR(.exe) 由 go build 产生
- [ ] DIR.test(.exe) 由 go test -c 产生
- [ ] MAINFILE(.exe) 由 go build MAINFILE.go产生

### go get

`go get` 命令主要是用来动态获取远程代码包的，目前支持的有`BitBucket`、`GitHub`、`Google Code`和`Launchpad`;这个命令在内部实际上分成了两步操作：第一步是下载源码包，第二步是执行`go install`；下载源码包的go工具会自动根据不同的域名调用不同的源码工具，对应关系如下：

```shell
BitBucket (Mercurial Git)
GitHub (Git)
Google Code Project Hosting (Git, Mercurial, Subversion)
Launchpad (Bazaar)
```

`go get` 命令本质上可以理解为：首先通过源码工具clone代码到src目录，然后执行`go install`；

### go install  
`go install` 命令在内部实际上分成了两步操作：第一步是生成结果文件(可执行文件或者.a包)，第二步会把编译好的结果移到 `$GOPATH/pkg` 或者 `$GOPATH/bin`；

- [ ] .exe文件： 一般是 `go install` 带main函数的go文件产生的，有函数入口，所有可以直接运行；
- [ ] .a应用包： 一般是 `go install` 不包含main函数的go文件产生的，没有函数入口，只能被调用；

### go test

`go test` 命令，会自动读取源码目录下面名为`*_test.go`的文件，生成并运行测试用的可执行文件。输出的信息类似

```shell
ok   archive/tar   0.011s
FAIL archive/zip   0.022s
ok   compress/gzip 0.033s
...
```

默认的情况下，不需要任何的参数，它会自动把你源码包下面所有test文件测试完毕，当然你也可以带上参数，详情请参考go help testflag；

### go doc
`go doc` 命令其实就是一个很强大的文档工具；

如何查看相应package的文档呢？ 例如builtin包，那么执行`go doc builtin`；如果是http包，那么执行`go doc net/http`；查看某一个包里面的函数，那么执行`godoc fmt Printf`；也可以查看相应的代码，执行`godoc -src fmt Printf`；

通过命令在命令行执行 `godoc -http=:port`， 比如`godoc -http=:8080`；然后在浏览器中打开127.0.0.1:8080，你将会看到一个golang.org的本地copy版本，通过它你可以查询pkg文档等其它内容。如果你设置了GOPATH，在pkg分类下，不但会列出标准包的文档，还会列出你本地GOPATH中所有项目的相关文档，这对于经常被限制访问的用户来说是一个不错的选择；

### 其他命令

```shell
go fix 用来修复以前老版本的代码到新版本，例如go1之前老版本的代码转化到go1

go version 查看go当前的版本

go env 查看当前go的环境变量

go list 列出当前全部安装的package

go run 编译并运行Go程序
```



