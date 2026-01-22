# Dockerfile for GLM-4.7-Flash NVFP4 on RTX 5090 (Blackwell SM120)
#
# Pre-built vLLM images don't work on Blackwell because PyTorch lacks SM120 support.
# Solution: Use vLLM's CUDA base + PyTorch nightly + build from source.
#
# References:
# - https://discuss.vllm.ai/t/vllm-on-rtx5090-working-gpu-setup-with-torch-2-9-0-cu128/1492
# - https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile

# Use same CUDA version as vLLM official Dockerfile
FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

ARG PYTHON_VERSION=3.12
ARG VLLM_VERSION=main
ARG MAX_JOBS=8

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies (following vLLM's approach)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    git \
    curl \
    ccache \
    openssh-server \
    gcc-10 \
    g++-10 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 110 \
       --slave /usr/bin/g++ g++ /usr/bin/g++-10 \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       python${PYTHON_VERSION} \
       python${PYTHON_VERSION}-dev \
       python${PYTHON_VERSION}-venv \
    && rm -f /etc/ssh/ssh_host_* && mkdir -p /var/run/sshd \
    && rm -rf /var/lib/apt/lists/*

# Setup Python
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3

# SM120/Blackwell environment variables (set early for all subsequent steps)
ENV TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120" \
    VLLM_FLASH_ATTN_VERSION=2 \
    VLLM_TARGET_DEVICE=cuda \
    MAX_JOBS=${MAX_JOBS} \
    PATH="/usr/lib/ccache:${PATH}"

# Step 1: Install PyTorch nightly cu129 (required for SM120 support)
RUN pip install --no-cache-dir --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu129 && \
    python -c "import torch; print(f'PyTorch {torch.__version__}, CUDA {torch.version.cuda}')"

# Step 2: Clone vLLM with retry logic (GitHub sometimes returns 500)
WORKDIR /opt/vllm
RUN for i in 1 2 3 4 5; do \
        git clone --depth 1 --branch ${VLLM_VERSION} https://github.com/vllm-project/vllm.git . && break || \
        (echo "Clone retry $i..." && sleep 10); \
    done && \
    test -f setup.py || (echo "ERROR: vLLM clone failed!" && exit 1)

# Step 3: Prevent PyTorch from being overwritten by requirements
RUN python use_existing_torch.py && \
    echo "Verifying torch removed from requirements..." && \
    ! grep -qi "^torch==" requirements/build.txt || (echo "ERROR: torch still in build.txt!" && exit 1)

# Step 4: Install build dependencies
RUN pip install --no-cache-dir -r requirements/build.txt

# Step 5: Build and install vLLM with SM120 support
# Using regular install (not editable) for production use
RUN TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120" \
    pip install --no-build-isolation . && \
    rm -rf build .git

# Verify vLLM works
RUN python -c "import vllm; print(f'vLLM {vllm.__version__} ready')"

# Install Node.js and GitHub CLI
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends nodejs gh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install tools
RUN pip install --no-cache-dir "huggingface_hub[cli]" && \
    npm install -g --prefer-offline @anthropic-ai/claude-code clawdbot && \
    npm cache clean --force

WORKDIR /

ENV MODEL_NAME="GadflyII/GLM-4.7-Flash-NVFP4" \
    MODEL_PATH="/workspace/models/GLM-4.7-Flash-NVFP4" \
    SERVED_MODEL_NAME="glm-4.7-flash" \
    MAX_MODEL_LEN="200000" \
    VLLM_API_KEY="changeme" \
    CLAWDBOT_HOME="/workspace/.clawdbot" \
    CLAWDBOT_WORKSPACE="/workspace/clawd"

COPY entrypoint.sh benchmark.sh /
RUN chmod +x /entrypoint.sh /benchmark.sh

EXPOSE 8000 18789 22
ENTRYPOINT ["/entrypoint.sh"]
