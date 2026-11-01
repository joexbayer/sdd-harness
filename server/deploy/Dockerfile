# sdd-server: the published package in node:26-trixie-slim (/bin/sh is dash, awk is mawk; git and
# ssh from apt). It installs what `npx sdd-server` runs, pinned by the package's npm-shrinkwrap.json.
FROM node:26-trixie-slim
RUN apt-get update && apt-get install -y --no-install-recommends git openssh-client ca-certificates \
 && rm -rf /var/lib/apt/lists/* && mkdir /data && chown node:node /data
ARG SDD_SERVER_VERSION=0.1.0
RUN npm install -g --ignore-scripts sdd-server@${SDD_SERVER_VERSION} && npm cache clean --force
USER node
VOLUME /data
EXPOSE 8080
HEALTHCHECK --interval=30s CMD ["sdd-server", "health"]
ENTRYPOINT ["sdd-server"]
CMD ["serve", "--config", "/etc/sdd-server/config"]
