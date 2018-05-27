ARG theia_version=latest
FROM theiaide/theia:$theia_version

FROM centos/nodejs-8-centos7
WORKDIR /opt/app-root/src
ENV NODEJS_VERSION=8 \
    NPM_RUN=start \
    NAME=nodejs \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH
SHELL ["/bin/bash", "-c"]
USER root
RUN curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo && \
    curl --silent --location https://rpm.nodesource.com/setup_8.x | bash - && \
    rpm -Uvh --nodeps $(repoquery --location yarn)
RUN mkdir /home/theia
COPY --from=0 /home/theia/package.json /home/theia/package.json
COPY wrapper_process.sh $STI_SCRIPTS_PATH/run
COPY theia_process.sh /home/theia/theia_process.sh
RUN rm -rf /opt/app-root/src && \
    mkdir /opt/app-root/src && \
    chown -R 1001:0 /home/theia /opt/app-root $STI_SCRIPTS_PATH/run && \
    chmod -R ug+rwx /home/theia /opt/app-root && \
    chmod -R ug+x $STI_SCRIPTS_PATH/run && \
    echo 'if [ ! $DEV_MODE ]; then rm -rf /home/theia/* ; fi' >> $STI_SCRIPTS_PATH/assemble
USER 1001
ARG version=latest
RUN cd /home/theia && \
    yarn && \
    yarn theia build && \
    rm -rf ./node_modules/electron && \
    yarn cache clean
RUN chown -R 1001:0 /home/theia /opt/app-root && \
    chmod -R g=u /home/theia /opt/app-root
EXPOSE 3000
ENV SHELL /bin/bash
ENV USE_LOCAL_GIT true
CMD $STI_SCRIPTS_PATH/run
