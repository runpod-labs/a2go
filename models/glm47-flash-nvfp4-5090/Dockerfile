# Dockerfile for GLM-4.7-Flash NVFP4 on RTX 5090 (Blackwell SM120)
#
# Model: GadflyII/GLM-4.7-Flash-NVFP4
# Context: 200,000 tokens
# Cost: ~$0.89/hr (RTX 5090)

FROM runpod/pytorch:1.0.3-cu1290-torch291-ubuntu2404

# Install vLLM nightly (required for glm47/glm45 parsers)
# Install Transformers from git main (required for GLM-4.7 support)
RUN pip install --no-cache-dir vllm --pre --extra-index-url https://wheels.vllm.ai/nightly && \
    pip install --no-cache-dir git+https://github.com/huggingface/transformers.git && \
    pip install --no-cache-dir "huggingface_hub[cli]"

# Install Node.js 22.x and GitHub CLI
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends nodejs gh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Clawdbot and Claude Code
RUN npm install -g --prefer-offline @anthropic-ai/claude-code clawdbot && \
    npm cache clean --force

# Environment defaults
ENV MODEL_NAME="GadflyII/GLM-4.7-Flash-NVFP4"
ENV MODEL_PATH="/workspace/models/GLM-4.7-Flash-NVFP4"
ENV SERVED_MODEL_NAME="glm-4.7-flash"
ENV MAX_MODEL_LEN="200000"
ENV VLLM_API_KEY="changeme"

# Clawdbot workspace
ENV CLAWDBOT_HOME="/workspace/.clawdbot"
ENV CLAWDBOT_WORKSPACE="/workspace/clawd"

COPY entrypoint.sh benchmark.sh /
RUN chmod +x /entrypoint.sh /benchmark.sh

EXPOSE 8000 18789 22
ENTRYPOINT ["/entrypoint.sh"]
