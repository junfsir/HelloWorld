`lsns` from the [util-linux](https://en.wikipedia.org/wiki/Util-linux) package can list all of the different types of namespaces, in various useful formats.

```
# lsns --help

Usage:
 lsns [options] [<namespace>]

List system namespaces.

Options:
 -J, --json             use JSON output format
 -l, --list             use list format output
 -n, --noheadings       don't print headings
 -o, --output <list>    define which output columns to use
 -p, --task <pid>       print process namespaces
 -r, --raw              use the raw output format
 -u, --notruncate       don't truncate text in columns
 -t, --type <name>      namespace type (mnt, net, ipc, user, pid, uts, cgroup)

 -h, --help     display this help and exit
 -V, --version  output version information and exit

Available columns (for --output):
          NS  namespace identifier (inode number)
        TYPE  kind of namespace
        PATH  path to the namespace
      NPROCS  number of processes in the namespace
         PID  lowest PID in the namespace
        PPID  PPID of the PID
     COMMAND  command line of the PID
         UID  UID of the PID
        USER  username of the PID

For more details see lsns(8).
```

`lsns` only lists the lowest PID for each process - but you can use that PID with `pgrep` if you want to list all processes belonging to a namespace.

e.g. if I'm running gitlab in docker and want to find all the processes running in that namespace, I can:

```
# lsns  -t pid -o ns,pid,command  | grep gitlab
  4026532661   459 /opt/gitlab/embedded/bin/redis-server 127.0.0.1:0
```

and, then use that pid (459) with `pgrep`:

```
# pgrep --ns 459 -a
459 /opt/gitlab/embedded/bin/redis-server 127.0.0.1:0
623 postgres: gitlab gitlabhq_production [local] idle
[...around 50 lines deleted...]
30172 nginx: worker process
```

I could also use the namespace id (4026532661) with `ps`, e.g.:

```
ps -o pidns,pid,cmd | awk '$1==4026532661'
[...output deleted...]
```



[How to list namespaces in Linux?](https://unix.stackexchange.com/questions/105403/how-to-list-namespaces-in-linux)

