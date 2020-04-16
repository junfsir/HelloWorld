```shell
#! /bin/sh
 
host=$1
port=$2
end_date=`openssl s_client -host $host -port $port -showcerts </dev/null 2>/dev/null |
          sed -n '/BEGIN CERTIFICATE/,/END CERT/p' |
      openssl x509 -text 2>/dev/null |
      sed -n 's/ *Not After : *//p'`
# openssl 检验和验证SSL证书。
# </dev/null 定向标准输入，防止交互式程序Hang。从/dev/null 读时，直接读出0 。
# sed -n 和p 一起使用，仅显示匹配到的部分。 //,// 区间匹配。
# openssl x509 -text 解码证书信息，包含证书的有效期。
 
if [ -n "$end_date" ]
then
    end_date_seconds=`date '+%s' --date "$end_date"`
# date指令format字符串时间。
    now_seconds=`date '+%s'`
    echo "($end_date_seconds-$now_seconds)/24/3600" | bc
fi
```

```shell
#!/bin/sh
### SSL Certificate Expire Day Check Script ###
if [ "$1" = '' ];then
    echo "Need URL."
    exit 1
fi
TARGET_URL=$1
EXP_DAY=`openssl s_client -connect ${TARGET_URL}:6443 < /dev/null 2> /dev/null | openssl x509 -text 2> /dev/null | grep "Not After" | sed -e 's/^ *//g' | cut -d " " -f 4,5,6,7,8`
NOW_TIME=`date +%s`
EXP_TIME=`date +%s -d "${EXP_DAY}"`
if [ "${EXP_DAY}" != '' -a ${NOW_TIME} -lt ${EXP_TIME} ]; then
    echo $(((EXP_TIME-NOW_TIME)/(60*60*24)))
else
    echo "ERROR"
    exit 1;
fi
```

```shell
#!/bin/bash
crt_file=$1
end_date=$(openssl x509 -in ${crt_file} -noout -dates|grep notAfter|awk -F'=' '{print $2}')
now=$[$(date '+%s' --date "${end_date}")-$(date '+%s')]
days=$[${now}/24/3600]
if [ "${days}" -gt 30 ];then
    echo "the cert is long than 30 days."
    exit 0
else
    echo "the cert is less than 30 days."
    exit 2
fi
```

refer：

[监控SSL证书过期 Monitor SSL certificate expiry](http://noops.me/?p=945)