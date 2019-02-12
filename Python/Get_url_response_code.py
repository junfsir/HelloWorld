#!/bin/env python
# *_* coding:utf-8 *_*
import urllib
import requests

url = 'http://www.jb51.net'

status = urllib.urlopen(url).code
code = requests.get(url).status_code
