### 安装golang  
```
wget https://dl.google.com/go/go1.10.linux-amd64.tar.gz
tar xf go1.10.linux-amd64.tar.gz -C /usr/local
vim /etc/profile
  export GOROOT=/usr/local/go
  export PATH=$PATH:$GOROOT/bin
  export GOPATH=/root/dev/go #自建golang工作目录
```
### 设置工作目录  
`工作目录`就是用来存放开发代码的路径，对应Go里的`GOPATH`这个环境变量，可根据自己的喜好进行创建，并将其添加至配置文件中，Linux为`/etc/profile`。  
该目录下有3个子目录，
```
.
├── bin
├── pkg
└── src
```

* bin目录存放go install生成的可执行文件，以把$GOPATH/bin路径加入到PATH环境变量里，就和上面配置的$GOROOT/bin一样，这样就可以直接在终端里使用go开发生成的程序了；
* pkg文件夹是存在go编译生成的文件；
* src存放的是我们的go源代码，不同工程项目的代码以包名区分；

### go工程结构
配置好工作目录后，就可以编码开发了，在这之前，看下go的通用项目结构,这里的结构主要是源代码相应地资源文件存放目录结构。

源代码都是存放在GOPATH的src目录下，那么多个多个项目的时候，怎么区分呢？答案是通过包，使用包来组织项目目录结构。有过java开发的都知道，使用包进行组织代码，包以网站域名开头就不会有重复，比如我的个人网站是flysnow.org,我就可以以·flysnow.org·的名字创建一个文件夹，我自己的go项目都放在这个文件夹里，这样就不会和其他人的项目冲突，包名也是唯一的。  
如果没有个人域名，现在流行的做法是使用你个人的github.com，因为每个人的是唯一的，所以也不会有重复。
```
    src
    ├── flysnow.org
    ├── github.com
    ├── golang.org
    ├── gopkg.in
    ├── qiniupkg.com
    └── sourcegraph.com
```
如上，src目录下跟着一个个域名命名的文件夹。再以github.com文件夹为例，它里面又是以github用户名命名的文件夹，用于存储属于这个github用户编写的go源代码。
```
        src/github.com/spf13
        ├── afero
        ├── cast
        ├── cobra
        ├── fsync
        ├── hugo
        ├── jwalterweatherman
        ├── nitro
        ├── pflag
        └── viper
```
那么我们如何引用一个包呢，也就是go里面的import。其实非常简单，通过包路径，包路径就是从src目录开始，逐级文件夹的名字用/连起来就是我们需要的包名，比如：
```
        import (
        	"github.com/spf13/hugo/commands"
        )
```
### 安装程序
安装的意思，就是生成可执行的程序，以供我们使用，为此go为我们提供了很方便的install命令，可以快速的把我们的程序安装到$GOAPTH/bin目录下。

    go install flysnow.org/hello
打开终端，运行上面的命令即可，install后跟全路径的包名。 然后我们在终端里运行hello就看到打印的Hello World了。

    ~ hello
    Hell Worl
    
### 跨平台编译
以前运行和安装，都是默认根据我们当前的机器生成的可执行文件，比如你的是Linux 64位，就会生成Linux 64位下的可执行文件，比如我的Mac，可以使用go env查看编译环境,以下截取重要的部分。


    ~ go env
    GOARCH="amd64"
    GOEXE=""
    GOHOSTARCH="amd64"
    GOHOSTOS="darwin"
    GOOS="darwin"
    GOROOT="/usr/local/go"
    GOTOOLDIR="/usr/local/go/pkg/tool/darwin_amd64"
注意里面两个重要的环境变量GOOS和GOARCH,其中GOOS指的是目标操作系统，它的可用值为：

    darwin
    freebsd
    linux
    windows
    android
    dragonfly
    netbsd
    openbsd
    plan9
    solaris
一共支持10中操作系统。GOARCH指的是目标处理器的架构，目前支持的有：

    arm
    arm64
    386
    amd64
    ppc64
    ppc64le
    mips64
    mips64le
    s390x
一共支持9中处理器的架构，GOOS和GOARCH组合起来，支持生成的可执行程序种类很多，具体组合参考https://golang.org/doc/install/source#environment。如果我们要生成不同平台架构的可执行程序，只要改变这两个环境变量就可以了，比如要生成linux 64位的程序，命令如下：

    GOOS=linux GOARCH=amd64 go build flysnow.org/hello
前面两个赋值，是更改环境变量，这样的好处是只针对本次运行有效，不会更改我们默认的配置。

### 获取远程包
go提供了一个获取远程包的工具go get,他需要一个完整的包名作为参数，只要这个完成的包名是可访问的，就可以被获取到，比如我们获取一个CLI的开源库：

    go get -v github.com/spf13/cobra/cobra
就可以下载这个库到我们$GOPATH/src目录下了，这样我们就可以像导入其他包一样import了。  
特别提醒，go get的本质是使用源代码控制工具下载这些库的源代码，比如git，hg等，所以在使用之前必须确保安装了这些源代码版本控制工具。  
如果我们使用的远程包有更新，我们可以使用如下命令进行更新,多了一个-u标识。

    go get -u -v github.com/spf13/cobra/cobra

### 获取gitlab私有库包
如果是私有的git库怎么获取呢？比如在公司使用gitlab搭建的git仓库，设置的都是private权限的。这种情况下我们可以配置下git，就可以了，在此之前你公司使用的gitlab必须要在7.8之上。然后要把我们http协议获取的方式换成ssh，假设你要获取http://git.flysnow.org，对应的ssh地址为git@git.flysnow.org，那么要在终端执行如下命令。

    git config --global url."git@git.flysnow.org:".insteadOf "http://git.flysnow.org/"
这段配置的意思就是，当我们使用http://git.flysnow.org/获取git库代码的时候，实际上使用的是git@git.flysnow.org这个url地址获取的，也就是http到ssh协议的转换，是自动的，他其实就是在我们的~/.gitconfig配置文件中，增加了如下配置:

    [url "git@git.flysnow.org:"]
    insteadOf = http://git.flysnow.org/
现在我们就可以使用go get直接获取了，比如：

    go get -v -insecure git.flysnow.org/hello
仔细看，多了一个-insecure标识，因为我们使用的是http协议， 是不安全的。当然如果你自己搭建的gitlab支持https协议，就不用加-insecure了，同时把上面的url insteadOf换成https的就可以了。
### vim for golang
    vim-go requires Vim 7.4.1689 or Neovim, but you're using an older version.
    Please update your Vim for the best vim-go experience.
    If you really want to continue you can set this to make the error go away:
        let g:go_version_warning = 0
    Note that some features may error out or behave incorrectly.
    解决：
    vim ~/.vimrc
      let g:go_version_warning = 0

[Go语言环境搭建详解](http://www.flysnow.org/2017/01/05/install-golang.html)

[vim插件管理工具Vundle](https://github.com/VundleVim/Vundle.vim)