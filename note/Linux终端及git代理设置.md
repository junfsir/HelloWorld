### Linux终端设置代理

#### http代理

```shell
# vim ~/.bashrc
export http_proxy="http://${host}:${port}"
export https_proxy="http://${host}:${port}"
```

或者

```shell
# vim ~/.bashrc
export ALL_PROXY="http://${host}:${port}"
```

认证

```shell
# vim ~/.bashrc
export http_proxy=${user}:${pass}@${host}:${port}
export https_proxy=${user}:${pass}@${host}:${port}
```

取消代理

```shell
$ unset http_proxy
$ unset https_proxy
$ unset ALL_RPOXY
```



#### socks5代理

```shell
# vim ~/.bashrc
export ALL_PROXY=socks5://127.0.0.1:1086
```

### git设置代理

代理格式`[protocol://][user[:password]@]proxyhost[:port]`

#### http代理

```shell
git config --global http.proxy http://127.0.0.1:8118
git config --global https.proxy http://127.0.0.1:8118
```

#### socks5代理

```shell
git config --global http.proxy socks5://127.0.0.1:1080
git config --global https.proxy socks5://127.0.0.1:1080
```

取消代理

```shell
git config --global --unset http.proxy
git config --global --unset https.proxy
```

