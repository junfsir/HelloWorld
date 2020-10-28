```shell
# man 5 resolv.conf
       search Search list for host-name lookup.
              The search list is normally determined from the local domain name; by default, it contains only the local domain name.   This may  be  changed  by  listing  the desired domain search path following the search keyword with spaces or tabs separating the names.  Resolver queries having fewer than ndots dots (default is 1) in them will be attempted using each  component  of  the search  path  in turn until a match is found.  For environments with multiple subdomains please read options ndots:n below to avoid man-in-the-middle attacks and unnecessary traffic for the root-dns-servers.  Note that this process  may  be  slow  and will generate a lot of network traffic if the servers for the listed domains are not local, and that queries will time out if no server is available for one of the domains.

              The search list is currently limited to six domains with a total of 256 characters.
             
       options
              ndots:n
                     sets a threshold for the number of dots which must appear in a name given to res_query(3) (see resolver(3)) before  an initial  absolute  query will be made.  The default for n is 1, meaning that if there are any dots in a name, the name will be tried first as an absolute name before any search list elements are appended to it.  The value for this option is silently capped to 15.
```

> 在所有查询中，如果 `.` 的个数小于 `ndots` 指定的数，则会根据 `search` 中配置的列表依次在对应域中查询，如果没有返回，则最后直接查询域名本身。
>
> 可以看出 `ndots` 其实是设置了 `.` 的阈值。

示例

```
# host -v kubernetes.default.svc
Trying "kubernetes.default.svc.default.svc.cluster.local"
Trying "kubernetes.default.svc.svc.cluster.local"
Trying "kubernetes.default.svc.cluster.local"
...
```

解析的 `kubernetes.default.svc` 中的 `.` 只有2，小于5，这时会依次拼接上 `search` 中的地址之后再进行查询，如果都查询不到，则再查询本身。

Refer

- https://tizeen.github.io/2019/02/27/DNS%E4%B8%AD%E7%9A%84ndots/
- https://www.ichenfu.com/2018/10/09/resolv-conf-desc/