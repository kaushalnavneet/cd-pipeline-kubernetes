FROM ibmcom/ibmnode:8
RUN apt-get update
RUN apt-get install -y libssl-dev
ENV NODE_PATH=/usr/local/lib/node_modules
RUN npm -g config set user root
RUN npm install -g js-yaml tar nodegit
