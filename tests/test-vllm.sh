#!/bin/bash
# test-vllm.sh - Verify vLLM server is working correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Configuration
VLLM_HOST="${VLLM_HOST:-localhost}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_API_KEY="${VLLM_API_KEY:-changeme}"
BASE_URL="http://${VLLM_HOST}:${VLLM_PORT}"

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local result="$2"

    if [ "$result" = "true" ]; then
        log_success "$name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_fail "$name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo ""
echo "==========================================="
echo "  vLLM Server Tests"
echo "==========================================="
echo "  Target: $BASE_URL"
echo "==========================================="
echo ""

# Test 1: Health endpoint
log_info "Test 1: Health endpoint..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health" 2>&1 || echo "000")
run_test "Health endpoint returns 200" "$([ "$HEALTH_RESPONSE" = "200" ] && echo true || echo false)"

# Test 2: Models endpoint
log_info "Test 2: Models endpoint..."
MODELS_RESPONSE=$(curl -s "${BASE_URL}/v1/models" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" 2>&1)
HAS_MODELS=$(echo "$MODELS_RESPONSE" | grep -q '"data"' && echo true || echo false)
run_test "Models endpoint returns model list" "$HAS_MODELS"

if [ "$HAS_MODELS" = "true" ]; then
    MODEL_ID=$(echo "$MODELS_RESPONSE" | jq -r '.data[0].id' 2>/dev/null || echo "unknown")
    echo "  -> Model ID: $MODEL_ID"
else
    MODEL_ID="unknown"
fi

# Test 3: Simple chat completion
log_info "Test 3: Chat completion..."
CHAT_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d "{
        \"model\": \"${MODEL_ID}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"What is 2+2? Answer with just the number.\"}],
        \"max_tokens\": 10,
        \"temperature\": 0
    }" 2>&1)

HAS_CHOICES=$(echo "$CHAT_RESPONSE" | grep -q '"choices"' && echo true || echo false)
run_test "Chat completion returns response" "$HAS_CHOICES"

if [ "$HAS_CHOICES" = "true" ]; then
    ANSWER=$(echo "$CHAT_RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | head -c 50)
    echo "  -> Response: $ANSWER"
fi

# Test 4: Coding prompt
log_info "Test 4: Coding prompt..."
CODE_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d "{
        \"model\": \"${MODEL_ID}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Write a Python function that adds two numbers. Just the code, no explanation.\"}],
        \"max_tokens\": 100,
        \"temperature\": 0
    }" 2>&1)

HAS_CODE=$(echo "$CODE_RESPONSE" | grep -q '"choices"' && echo true || echo false)
run_test "Coding prompt returns response" "$HAS_CODE"

if [ "$HAS_CODE" = "true" ]; then
    CODE=$(echo "$CODE_RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | head -c 100)
    echo "  -> Response preview: ${CODE}..."
fi

# Test 5: Token usage tracking
log_info "Test 5: Token usage..."
HAS_USAGE=$(echo "$CHAT_RESPONSE" | grep -q '"usage"' && echo true || echo false)
run_test "Response includes token usage" "$HAS_USAGE"

if [ "$HAS_USAGE" = "true" ]; then
    PROMPT_TOKENS=$(echo "$CHAT_RESPONSE" | jq -r '.usage.prompt_tokens' 2>/dev/null)
    COMPLETION_TOKENS=$(echo "$CHAT_RESPONSE" | jq -r '.usage.completion_tokens' 2>/dev/null)
    echo "  -> Prompt tokens: $PROMPT_TOKENS, Completion tokens: $COMPLETION_TOKENS"
fi

# Test 6: Streaming support
log_info "Test 6: Streaming support..."
STREAM_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d "{
        \"model\": \"${MODEL_ID}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Hi\"}],
        \"max_tokens\": 5,
        \"stream\": true
    }" 2>&1 | head -c 500)

HAS_STREAM=$(echo "$STREAM_RESPONSE" | grep -q "data:" && echo true || echo false)
run_test "Streaming returns SSE format" "$HAS_STREAM"

# Summary
echo ""
echo "==========================================="
echo "  Test Summary"
echo "==========================================="
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo "==========================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
