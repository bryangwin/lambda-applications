#!/bin/bash

# Description: This script should be run when a customer breaks
# their jupyter Cloud IDE by installing a package that breaks or overwrites
# their working packages. This script will remove all pip pacakges in /home/ubuntu
# and reinstall the default packages and dependencies to run lambda-jupyter then
# restart the lambda-jupyter service.

# Copyright 2024 Lambda, Inc.
# Website:		https://lambdalabs.com
# Author(s):		Bryan Gwin, Jordan Uggla
# Script License:	BSD 3-clause


JUPYTER_REQUIREMENTS="aiosqlite==0.20.0
anyio==4.3.0
argon2-cffi==23.1.0
argon2-cffi-bindings==21.2.0
asttokens==2.4.1
async-lru==2.0.4
attrs==23.2.0
Babel==2.14.0
backcall==0.2.0
beautifulsoup4==4.12.3
bleach==6.1.0
certifi==2024.2.2
cffi==1.16.0
charset-normalizer==3.3.2
comm==0.2.2
debugpy==1.8.1
decorator==5.1.1
defusedxml==0.7.1
exceptiongroup==1.2.0
executing==2.0.1
fastjsonschema==2.19.1
h11==0.14.0
httpcore==1.0.5
httpx==0.27.0
idna==3.6
importlib-metadata==7.1.0
importlib-resources==6.4.0
ipykernel==6.29.4
ipython==8.12.3
jedi==0.19.1
Jinja2==3.1.3
json5==0.9.24
jsonschema==4.21.1
jsonschema-specifications==2023.12.1
jupyter-client==8.6.1
jupyter-collaboration==2.0.11
jupyter-core==5.7.2
jupyter-events==0.10.0
jupyter-lsp==2.2.5
jupyter-server==2.13.0
jupyter-server-fileid==0.9.1
jupyter-server-terminals==0.5.3
jupyter-ydoc==2.0.1
jupyterlab==4.1.6
jupyterlab-pygments==0.3.0
jupyterlab-server==2.26.0
MarkupSafe==2.1.5
matplotlib-inline==0.1.6
mistune==3.0.2
nbclient==0.10.0
nbconvert==7.16.3
nbformat==5.10.4
nest-asyncio==1.6.0
notebook-shim==0.2.4
overrides==7.7.0
packaging==24.0
pandocfilters==1.5.1
parso==0.8.4
pexpect==4.9.0
pickleshare==0.7.5
pkgutil-resolve-name==1.3.10
platformdirs==4.2.0
prometheus-client==0.20.0
prompt-toolkit==3.0.43
psutil==5.9.8
ptyprocess==0.7.0
pure-eval==0.2.2
pycparser==2.22
pycrdt==0.8.18
pycrdt-websocket==0.12.7
pygments==2.17.2
python-dateutil==2.9.0.post0
python-json-logger==2.0.7
pytz==2024.1
PyYAML==6.0.1
pyzmq==25.1.2
referencing==0.34.0
requests==2.31.0
rfc3339-validator==0.1.4
rfc3986-validator==0.1.1
rpds-py==0.18.0
Send2Trash==1.8.3
six==1.16.0
sniffio==1.3.1
soupsieve==2.5
stack-data==0.6.3
terminado==0.18.1
tinycss2==1.2.1
tomli==2.0.1
tornado==6.4
traitlets==5.14.2
typing-extensions==4.11.0
urllib3==2.2.1
wcwidth==0.2.13
webencodings==0.5.1
websocket-client==1.7.0
zipp==3.18.1"

hash -r pip; pip list -v | grep '/home/ubuntu/' | awk '{print $1}' | xargs pip uninstall -y; hash -r pip

pip install -r <(echo "$JUPYTER_REQUIREMENTS")

sudo systemctl restart lambda-jupyter.service