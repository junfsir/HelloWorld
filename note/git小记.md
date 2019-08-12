> * `git init` //把当前目录变成git可以管理的仓库
> * `git config --global user.name 'junfsir'` //git全局配置
> * `git config --global user.email 'xxx@gmail.com'` //git全局配置
> * `git clone https://github.com/junfsir/memo.git`
> * `git remote add memo https://github.com/junfsir/memo.git`
> * `git add gc分析.md` //添加本地文件到仓库
> * `git commit -m 'test'` //对本次提交的说明
> * `git push memo  master` //push到GitHub
> * `git status` //查看仓库当前状态
> * `git diff $file` //查看文件差异
> * `git log --pretty=oneline` //查看最近到最远的提交日志
> * `git clone -b release-1.6.0 https://github.com/goharbor/harbor.git` //指定分支
> * `git mv test.go Golang/` //mv code file to dest dir;first create the dest dir, and finally commit the changes;
> * `git rm -r --cached TARGET && git commit -m "delete TARGET"` //delete directory
