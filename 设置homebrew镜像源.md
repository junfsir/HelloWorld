
## 设置中科大镜像源
**替换brew.git:**
```
cd "$(brew --repo)"
git remote set-url origin https://mirrors.ustc.edu.cn/brew.git
```
**替换homebrew-core.git:**
```
cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
git remote set-url origin https://mirrors.ustc.edu.cn/homebrew-core.git
```
**替换Homebrew Bottles源: **  
[替换参考](https://lug.ustc.edu.cn/wiki/mirrors/help/homebrew-bottles)
## 设置清华镜像源
[设置参考](https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/)
## 切换回官方源：
**重置brew.git:**
```
cd "$(brew --repo)"
git remote set-url origin https://github.com/Homebrew/brew.git
```
**重置homebrew-core.git:**
```
cd "$(brew --repo)/Library/Taps/homebrew/homebrew-core"
git remote set-url origin https://github.com/Homebrew/homebrew-core.git
```

*注释掉bash配置文件里的有关Homebrew Bottles即可恢复官方源。*  
*重启bash或让bash重读配置文件。*  

[参考](https://lug.ustc.edu.cn/wiki/mirrors/help/brew.git)