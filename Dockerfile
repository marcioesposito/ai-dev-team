FROM node:22-alpine
# Install system dependencies
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk add --no-cache bash curl git github-cli py3-pip python3
# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code
# Create a non-root user for safety
RUN adduser -D -s /bin/bash agent
USER agent
WORKDIR /home/agent
# Copy agent scripts
COPY --chown=agent:agent agent/ ./
RUN chmod +x run_agent.sh
ENTRYPOINT ["./run_agent.sh"]