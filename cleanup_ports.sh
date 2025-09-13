#!/bin/bash

# 端口清理脚本 - 用于清理被占用的端口

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 清理指定端口
cleanup_port() {
    local port=$1
    local service_name=$2
    
    if [ -z "$port" ]; then
        print_error "请指定端口号"
        return 1
    fi
    
    print_info "检查端口 $port ($service_name)..."
    
    # 检查端口占用情况
    if lsof -ti:$port >/dev/null 2>&1; then
        print_warning "端口 $port 被占用"
        
        # 显示占用端口的进程信息
        print_info "占用端口 $port 的进程:"
        lsof -i:$port
        
        # 获取占用端口的进程ID
        pids=$(lsof -ti:$port 2>/dev/null || true)
        
        if [ -n "$pids" ]; then
            print_info "尝试优雅终止进程..."
            echo $pids | xargs kill -TERM 2>/dev/null || true
            sleep 2
            
            # 检查是否还有进程占用端口
            remaining_pids=$(lsof -ti:$port 2>/dev/null || true)
            if [ -n "$remaining_pids" ]; then
                print_warning "优雅终止失败，强制终止进程..."
                echo $remaining_pids | xargs kill -9 2>/dev/null || true
                sleep 1
            fi
        fi
        
        # 最终检查
        if lsof -ti:$port >/dev/null 2>&1; then
            print_error "端口 $port 清理失败"
            return 1
        else
            print_success "端口 $port 清理成功"
        fi
    else
        print_info "端口 $port 未被占用"
    fi
}

# 清理所有相关端口
cleanup_all_ports() {
    print_info "开始清理所有相关端口..."
    
    # 定义要清理的端口
    declare -A ports=(
        [5555]="Python后端服务"
        [5556]="前端开发服务"
        [8080]="默认前端服务（如果有）"
        [5000]="默认后端服务（如果有）"
        [3000]="常用开发端口（如果有）"
    )
    
    for port in "${!ports[@]}"; do
        service_name="${ports[$port]}"
        cleanup_port $port "$service_name"
        echo ""
    done
    
    print_success "所有端口清理完成"
}

# 显示端口状态
show_port_status() {
    print_info "端口状态检查:"
    
    declare -A ports=(
        [5555]="Python后端服务"
        [5556]="前端开发服务"
        [8080]="默认前端服务"
        [5000]="默认后端服务"
    )
    
    for port in "${!ports[@]}"; do
        service_name="${ports[$port]}"
        if lsof -ti:$port >/dev/null 2>&1; then
            print_warning "端口 $port ($service_name): ${RED}占用${NC}"
            lsof -i:$port | head -2
        else
            print_success "端口 $port ($service_name): ${GREEN}空闲${NC}"
        fi
    done
}

# 主函数
main() {
    echo "========================================"
    echo "🧹 端口清理工具"
    echo "========================================"
    
    case "${1:-}" in
        "5555")
            cleanup_port 5555 "Python后端服务"
            ;;
        "5556")
            cleanup_port 5556 "前端开发服务"
            ;;
        "8080")
            cleanup_port 8080 "默认前端服务"
            ;;
        "5000")
            cleanup_port 5000 "默认后端服务"
            ;;
        "all")
            cleanup_all_ports
            ;;
        "status")
            show_port_status
            ;;
        *)
            echo "使用方法:"
            echo "  $0 5555     # 清理Python后端端口"
            echo "  $0 5556     # 清理前端端口"
            echo "  $0 8080     # 清理默认前端端口"
            echo "  $0 5000     # 清理默认后端端口"
            echo "  $0 all      # 清理所有相关端口"
            echo "  $0 status   # 显示端口状态"
            echo ""
            show_port_status
            ;;
    esac
}

main "$@"