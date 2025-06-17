#!/bin/bash

# vLLM Resource Cleanup Script
# Description: Cleanup of resources after vllm serve process
# Usage: ./vllm_cleanup.sh [options]
# Options:
#   -f, --force     Force cleanup without confirmation
#   -p, --port      Specify custom port (default: 8000)
#   -g, --gpu-reset Reset GPU (requires sudo)
#   -a, --all       Perform all cleanup operations
#   -h, --help      Show help

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
FORCE=false
PORT=8000
GPU_RESET=false
ALL_CLEANUP=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
vLLM Resource Cleanup Script

Usage: $0 [options]

Options:
    -f, --force         Force cleanup without confirmation
    -p, --port PORT     Specify custom port (default: 8000)
    -g, --gpu-reset     Reset GPU (requires sudo)
    -a, --all           Perform all cleanup operations
    -h, --help          Show this help message

Examples:
    $0                  # Basic cleanup with confirmations
    $0 -f               # Force cleanup without confirmations
    $0 -p 8080 -f       # Cleanup with custom port
    $0 -a               # Perform all cleanup operations
    $0 -g               # Include GPU reset

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -g|--gpu-reset)
            GPU_RESET=true
            shift
            ;;
        -a|--all)
            ALL_CLEANUP=true
            GPU_RESET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to confirm action
confirm_action() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    local message="$1"
    read -p "$message (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
    return 0
}

# Function to kill vLLM processes
kill_vllm_processes() {
    print_info "Checking for vLLM processes..."
    
    # Find vLLM processes
    local vllm_pids=$(pgrep -f "vllm serve" 2>/dev/null || true)
    
    if [ -z "$vllm_pids" ]; then
        print_success "No vLLM processes found"
        return 0
    fi
    
    print_warning "Found vLLM processes: $vllm_pids"
    
    if confirm_action "Kill vLLM processes?"; then
        # Try graceful shutdown first
        print_info "Attempting graceful shutdown..."
        for pid in $vllm_pids; do
            kill -TERM "$pid" 2>/dev/null || true
        done
        
        sleep 3
        
        # Force kill if still running
        vllm_pids=$(pgrep -f "vllm serve" 2>/dev/null || true)
        if [ -n "$vllm_pids" ]; then
            print_warning "Processes still running, force killing..."
            for pid in $vllm_pids; do
                kill -9 "$pid" 2>/dev/null || true
            done
        fi
        
        print_success "vLLM processes terminated"
    fi
}

# Function to clean up GPU memory
cleanup_gpu_memory() {
    print_info "Checking GPU memory usage..."
    
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "nvidia-smi not found, skipping GPU cleanup"
        return 0
    fi
    
    # Show current GPU status
    echo -e "\nCurrent GPU status:"
    nvidia-smi
    
    # Find processes using GPU
    local gpu_processes=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null || true)
    
    if [ -z "$gpu_processes" ]; then
        print_success "No processes using GPU"
        return 0
    fi
    
    print_warning "Found processes using GPU: $gpu_processes"
    
    if confirm_action "Kill GPU processes?"; then
        for pid in $gpu_processes; do
            # Check if it's a Python process (likely ML related)
            if ps -p "$pid" -o comm= | grep -q "python"; then
                print_info "Killing GPU process: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
        print_success "GPU processes terminated"
    fi
    
    # GPU reset option
    if [ "$GPU_RESET" = true ]; then
        if check_root; then
            if confirm_action "Reset GPU?"; then
                print_info "Resetting GPU..."
                nvidia-smi --gpu-reset 2>/dev/null || print_warning "GPU reset failed (may require no active processes)"
            fi
        else
            print_warning "GPU reset requires root privileges. Run with sudo to enable GPU reset."
        fi
    fi
}

# Function to clean up ports
cleanup_ports() {
    print_info "Checking port $PORT..."
    
    # Check if port is in use
    local port_pid=$(lsof -ti:$PORT 2>/dev/null || true)
    
    if [ -z "$port_pid" ]; then
        print_success "Port $PORT is not in use"
        return 0
    fi
    
    print_warning "Port $PORT is in use by process: $port_pid"
    
    if confirm_action "Kill process using port $PORT?"; then
        kill -9 "$port_pid" 2>/dev/null || true
        print_success "Port $PORT freed"
    fi
}

# Function to clean up shared memory
cleanup_shared_memory() {
    print_info "Cleaning up shared memory..."
    
    # Remove shared memory segments used by vLLM
    local shm_segments=$(ipcs -m | grep -i "vllm serve" | awk '{print $2}')
    
    if [ -z "$shm_segments" ]; then
        print_info "No vLLM shared memory segments found."
    else
        for segment in $shm_segments; do
            ipcrm -m "$segment" 2>/dev/null || true
        done
        print_success "Cleaned up vLLM shared memory segments"
    fi
}

# Function to clean up caches and temporary files
cleanup_caches() {
    print_info "Cleaning up caches and temporary files..."
    
    # Clear CUDA cache
    print_info "Clearing CUDA cache..."
    python3 -c "import torch; torch.cuda.empty_cache()" 2>/dev/null || {
        print_warning "Failed to clear CUDA cache. Is PyTorch installed?"
    }
    
    # Ensure temporary directory exists and clean it
    print_info "Cleaning up temporary files in /tmp/vllm/..."
    mkdir -p /tmp/vllm 2>/dev/null || true
    rm -f /tmp/vllm/* 2>/dev/null || true

    # Clear system cache if running as root
    if [ "$(id -u)" -eq 0 ]; then
        print_info "Clearing system cache..."
        sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || {
            print_warning "Failed to clear system cache"
        }
    else
        print_info "Skipping system cache clear (requires root privileges)"
    fi

    print_success "Cache and temporary files cleanup completed"
}


# Function to show resource summary
show_resource_summary() {
    echo -e "\n${BLUE}=== Resource Summary ===${NC}"
    
    # Memory usage
    echo -e "\n${YELLOW}Memory Usage:${NC}"
    free -h
    
    # GPU status (if available)
    if command -v nvidia-smi &> /dev/null; then
        echo -e "\n${YELLOW}GPU Status:${NC}"
        nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv
    fi
    
    # Port status
    echo -e "\n${YELLOW}Port $PORT Status:${NC}"
    lsof -i:$PORT 2>/dev/null || echo "Port $PORT is free"
    
    echo -e "\n${BLUE}=======================${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}=== vLLM Resource Cleanup Script ===${NC}\n"
    
    # Show initial resource summary
    if [ "$FORCE" != true ]; then
        show_resource_summary
        echo
        if ! confirm_action "Proceed with cleanup?"; then
            print_info "Cleanup cancelled"
            exit 0
        fi
    fi
    
    # Perform cleanup operations
    kill_vllm_processes
    cleanup_gpu_memory
    cleanup_ports
    cleanup_shared_memory
    cleanup_caches


    
    # Show final resource summary
    echo
    print_success "Cleanup completed!"
    show_resource_summary
}

# Run main function
main