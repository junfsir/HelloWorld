### install pyenv on MacOS  
```
$ brew update
$ brew install pyenv
$ echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bash_profile
$ echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bash_profile
$ echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bash_profile
$ exec "$SHELL"
```
### install pyenv-virtualenv on MacOS  
```
$ brew install pyenv-virtualenv
$ echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bash_profile
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```
### install python 3.6.5
$ pyenv install 3.6.5
### create virtual environment  
```
pyenv virtualenv 3.6.5 python3
pyenv activate python3
pip install --upgrade pip
pip install ipython
pip install jupter
pip install tensorflow
pip install keras
pip install sklearn
pip install tf-nightly
pip install matplotlib
pip install pandas
pyenv deactivate
```

### issue  
```
Cannot uninstall 'numpy'. It is a distutils installed project and thus we cannot accurately determine which files belong to it which would lead to only a partial uninstall.
    resolution：pip install --ignore-installed numpy

In [1]: import tensorflow
/Users/jeason/.pyenv/versions/3.6.5/lib/python3.6/importlib/_bootstrap.py:219: RuntimeWarning: compiletime version 3.5 of module 'tensorflow.python.framework.fast_tensor_util' does not match runtime version 3.6
  return f(*args, **kwds)

  resolution：pip3 install tf-nightly

Working with Matplotlib on OSX：
resolution：echo "backend: TkAgg" >> ~/.matplotlib/matplotlibrc

$ git clone https://github.com/GenTang/intro_ds.git
xcrun: error: invalid active developer path (/Library/Developer/CommandLineTools), missing xcrun at: /Library/Developer/CommandLineTools/usr/bin/xcrun
cause：升级OSX引起xcode command line tools版本不匹配，可到https://developer.apple.com/download下载对应的版本安装
```  
