#!/bin/bash
# test-tool-calling.sh - Verify tool calling functionality

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
echo "  Tool Calling Tests"
echo "==========================================="
echo "  Target: $BASE_URL"
echo "==========================================="
echo ""

# Get model ID
MODELS_RESPONSE=$(curl -s "${BASE_URL}/v1/models" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" 2>&1)
MODEL_ID=$(echo "$MODELS_RESPONSE" | jq -r '.data[0].id' 2>/dev/null || echo "unknown")
log_info "Using model: $MODEL_ID"
echo ""

# Test 1: Single tool calling - Weather
log_info "Test 1: Single tool call (weather function)..."
TOOL_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d '{
        "model": "'"${MODEL_ID}"'",
        "messages": [
            {"role": "user", "content": "What is the weather in San Francisco?"}
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Get the current weather in a given location",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "location": {
                                "type": "string",
                                "description": "The city and state, e.g. San Francisco, CA"
                            },
                            "unit": {
                                "type": "string",
                                "enum": ["celsius", "fahrenheit"],
                                "description": "Temperature unit"
                            }
                        },
                        "required": ["location"]
                    }
                }
            }
        ],
        "tool_choice": "auto",
        "max_tokens": 256
    }' 2>&1)

HAS_TOOL_CALL=$(echo "$TOOL_RESPONSE" | grep -q '"tool_calls"' && echo true || echo false)
run_test "Model returns tool_calls in response" "$HAS_TOOL_CALL"

if [ "$HAS_TOOL_CALL" = "true" ]; then
    TOOL_NAME=$(echo "$TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls[0].function.name' 2>/dev/null)
    TOOL_ARGS=$(echo "$TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls[0].function.arguments' 2>/dev/null)
    echo "  -> Tool called: $TOOL_NAME"
    echo "  -> Arguments: $TOOL_ARGS"

    CORRECT_TOOL=$([ "$TOOL_NAME" = "get_weather" ] && echo true || echo false)
    run_test "Correct tool selected (get_weather)" "$CORRECT_TOOL"

    HAS_LOCATION=$(echo "$TOOL_ARGS" | grep -qi "san francisco" && echo true || echo false)
    run_test "Arguments include location" "$HAS_LOCATION"
fi

# Test 2: Multiple tools available
log_info "Test 2: Multiple tools (calculator + search)..."
MULTI_TOOL_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d '{
        "model": "'"${MODEL_ID}"'",
        "messages": [
            {"role": "user", "content": "Calculate 15 * 7 + 23"}
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "calculator",
                    "description": "Perform mathematical calculations",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "expression": {
                                "type": "string",
                                "description": "The mathematical expression to evaluate"
                            }
                        },
                        "required": ["expression"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "web_search",
                    "description": "Search the web for information",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "The search query"
                            }
                        },
                        "required": ["query"]
                    }
                }
            }
        ],
        "tool_choice": "auto",
        "max_tokens": 256
    }' 2>&1)

SELECTED_TOOL=$(echo "$MULTI_TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls[0].function.name' 2>/dev/null)
CORRECT_SELECTION=$([ "$SELECTED_TOOL" = "calculator" ] && echo true || echo false)
run_test "Model selects calculator for math problem" "$CORRECT_SELECTION"

if [ "$SELECTED_TOOL" = "calculator" ]; then
    CALC_ARGS=$(echo "$MULTI_TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls[0].function.arguments' 2>/dev/null)
    echo "  -> Calculator arguments: $CALC_ARGS"
fi

# Test 3: Tool result handling
log_info "Test 3: Tool result handling..."
TOOL_RESULT_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d '{
        "model": "'"${MODEL_ID}"'",
        "messages": [
            {"role": "user", "content": "What is the weather in New York?"},
            {"role": "assistant", "content": null, "tool_calls": [{"id": "call_123", "type": "function", "function": {"name": "get_weather", "arguments": "{\"location\": \"New York, NY\"}"}}]},
            {"role": "tool", "tool_call_id": "call_123", "content": "{\"temperature\": 72, \"condition\": \"sunny\", \"humidity\": 45}"}
        ],
        "max_tokens": 256
    }' 2>&1)

HAS_RESPONSE=$(echo "$TOOL_RESULT_RESPONSE" | grep -q '"choices"' && echo true || echo false)
run_test "Model processes tool result" "$HAS_RESPONSE"

if [ "$HAS_RESPONSE" = "true" ]; then
    FINAL_RESPONSE=$(echo "$TOOL_RESULT_RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | head -c 100)
    echo "  -> Model response: $FINAL_RESPONSE..."

    MENTIONS_TEMP=$(echo "$FINAL_RESPONSE" | grep -qi "72\|sunny\|temperature" && echo true || echo false)
    run_test "Response incorporates tool data" "$MENTIONS_TEMP"
fi

# Test 4: Code-related tool (file operations)
log_info "Test 4: Code-related tool (read_file)..."
CODE_TOOL_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d '{
        "model": "'"${MODEL_ID}"'",
        "messages": [
            {"role": "user", "content": "Read the contents of package.json and tell me what dependencies are listed"}
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "read_file",
                    "description": "Read the contents of a file",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "path": {
                                "type": "string",
                                "description": "The path to the file to read"
                            }
                        },
                        "required": ["path"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "write_file",
                    "description": "Write content to a file",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "path": {
                                "type": "string",
                                "description": "The path to write to"
                            },
                            "content": {
                                "type": "string",
                                "description": "The content to write"
                            }
                        },
                        "required": ["path", "content"]
                    }
                }
            }
        ],
        "tool_choice": "auto",
        "max_tokens": 256
    }' 2>&1)

FILE_TOOL=$(echo "$CODE_TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls[0].function.name' 2>/dev/null)
CORRECT_FILE_TOOL=$([ "$FILE_TOOL" = "read_file" ] && echo true || echo false)
run_test "Model selects read_file for reading task" "$CORRECT_FILE_TOOL"

if [ "$FILE_TOOL" = "read_file" ]; then
    FILE_PATH=$(echo "$CODE_TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls[0].function.arguments' 2>/dev/null)
    echo "  -> Arguments: $FILE_PATH"

    HAS_PACKAGE=$(echo "$FILE_PATH" | grep -q "package.json" && echo true || echo false)
    run_test "Correct file path in arguments" "$HAS_PACKAGE"
fi

# Test 5: No tool needed
log_info "Test 5: Model knows when NOT to use tools..."
NO_TOOL_RESPONSE=$(curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${VLLM_API_KEY}" \
    -d '{
        "model": "'"${MODEL_ID}"'",
        "messages": [
            {"role": "user", "content": "What is the capital of France?"}
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "get_weather",
                    "description": "Get the current weather in a given location",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "location": {"type": "string"}
                        },
                        "required": ["location"]
                    }
                }
            }
        ],
        "tool_choice": "auto",
        "max_tokens": 100
    }' 2>&1)

NO_TOOL_CALLS=$(echo "$NO_TOOL_RESPONSE" | jq -r '.choices[0].message.tool_calls' 2>/dev/null)
ANSWERED_DIRECTLY=$([ "$NO_TOOL_CALLS" = "null" ] || [ -z "$NO_TOOL_CALLS" ] && echo true || echo false)
run_test "Model answers without unnecessary tool calls" "$ANSWERED_DIRECTLY"

if [ "$ANSWERED_DIRECTLY" = "true" ]; then
    DIRECT_ANSWER=$(echo "$NO_TOOL_RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null | head -c 50)
    echo "  -> Direct answer: $DIRECT_ANSWER"
fi

# Summary
echo ""
echo "==========================================="
echo "  Tool Calling Test Summary"
echo "==========================================="
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo "==========================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    log_warn "Some tests failed. Tool calling may not work correctly."
    log_info "This could be due to:"
    echo "  - Model doesn't fully support function calling"
    echo "  - Wrong tool_call_parser for this model"
    echo "  - Model version incompatibility"
    exit 1
fi

log_success "All tool calling tests passed!"
exit 0
