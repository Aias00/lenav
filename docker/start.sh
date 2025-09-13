#!/bin/bash

# Docker容器启动脚本

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

# 信号处理函数
cleanup() {
    print_info "收到终止信号，正在优雅关闭..."
    
    # 停止后端服务
    if [ -n "$BACKEND_PID" ]; then
        print_info "停止后端服务..."
        kill -TERM $BACKEND_PID 2>/dev/null || true
        wait $BACKEND_PID 2>/dev/null || true
    fi
    
    # 停止nginx
    if [ -n "$NGINX_PID" ]; then
        print_info "停止nginx服务..."
        nginx -s quit 2>/dev/null || true
        wait $NGINX_PID 2>/dev/null || true
    fi
    
    print_success "所有服务已停止"
    exit 0
}

# 注册信号处理
trap cleanup TERM INT

# 等待服务就绪
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_info "等待 $service_name 服务就绪..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            print_success "$service_name 服务已就绪"
            return 0
        fi
        
        print_info "等待 $service_name 服务... (尝试 $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name 服务启动超时"
    return 1
}

# 检查依赖
check_dependencies() {
    print_info "检查服务依赖..."
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 未找到"
        exit 1
    fi
    
    # 检查nginx
    if ! command -v nginx &> /dev/null; then
        print_error "nginx 未找到"
        exit 1
    fi
    
    print_success "依赖检查完成"
}

# 启动后端服务
start_backend() {
    print_info "启动Python后端服务..."
    
    # 设置环境变量
    export NACOS_URL=${NACOS_URL:-"http://nacos:8848"}
    export DATA_ID=${DATA_ID:-"nav-config"}
    export GROUP=${GROUP:-"DEFAULT_GROUP"}
    export TENANT=${TENANT:-"nav-config"}
    export NACOS_USERNAME=${NACOS_USERNAME:-""}
    export NACOS_PASSWORD=${NACOS_PASSWORD:-""}
    
    print_info "后端配置:"
    print_info "  NACOS_URL: $NACOS_URL"
    print_info "  DATA_ID: $DATA_ID"
    print_info "  GROUP: $GROUP"
    print_info "  TENANT: $TENANT"
    if [ -n "$NACOS_USERNAME" ]; then
        print_info "  NACOS_USERNAME: $NACOS_USERNAME"
    fi
    
    # 启动后端服务
    cd /app
    nohup python3 backend.py > /app/logs/backend.log 2>&1 &
    BACKEND_PID=$!
    
    print_info "后端服务已启动 (PID: $BACKEND_PID)"
}

# 启动nginx服务
start_nginx() {
    print_info "启动nginx服务..."
    
    # 创建必要的目录
    mkdir -p /app/logs
    
    # 测试nginx配置
    if ! nginx -t; then
        print_error "nginx配置测试失败"
        return 1
    fi
    
    # 启动nginx
    nginx &
    NGINX_PID=$!
    
    print_info "nginx服务已启动 (PID: $NGINX_PID)"
}

# 健康检查
health_check() {
    print_info "执行健康检查..."
    
    # 检查后端服务
    if ! wait_for_service "http://localhost:5555/api/health" "后端"; then
        print_error "后端服务健康检查失败"
        return 1
    fi
    
    # 检查nginx服务
    if ! wait_for_service "http://localhost/health" "nginx"; then
        print_error "nginx服务健康检查失败"
        return 1
    fi
    
    print_success "所有服务健康检查通过"
}

# 显示启动信息
show_startup_info() {
    echo ""
    echo "========================================"
    echo "🎉 Lenav Docker 容器启动成功！"
    echo "========================================"
    echo "🌐 服务访问地址:"
    echo "   - 主应用: ${GREEN}http://localhost${NC}"
    echo "   - API健康检查: ${GREEN}http://localhost/api/health${NC}"
    echo "   - 获取配置: ${GREEN}http://localhost/api/nav/config${NC}"
    echo ""
    echo "📊 容器信息:"
    echo "   - 后端服务: http://localhost:5555"
    echo "   - nginx服务: http://localhost:80"
    echo ""
    echo "📋 环境变量:"
    echo "   - NACOS_URL: $NACOS_URL"
    echo "   - DATA_ID: $DATA_ID"
    echo "   - GROUP: $GROUP"
    echo "   - TENANT: $TENANT"
    echo ""
    echo "📄 日志文件:"
    echo "   - 后端日志: /app/logs/backend.log"
    echo "   - nginx访问日志: /app/logs/nginx.access.log"
    echo "   - nginx错误日志: /app/logs/nginx.error.log"
    echo ""
    echo "⚠️  使用 'docker logs <container_id>' 查看日志"
    echo "========================================"
}

# 主函数
main() {
    print_info "启动 Lenav 应用..."
    
    # 检查依赖
    check_dependencies
    
    # 启动后端服务
    start_backend
    
    # 等待后端服务就绪
    if ! wait_for_service "http://localhost:5555/api/health" "后端"; then
        print_error "后端服务启动失败"
        exit 1
    fi
    
    # 启动nginx服务
    start_nginx
    
    # 等待nginx服务就绪
    if ! wait_for_service "http://localhost/health" "nginx"; then
        print_error "nginx服务启动失败"
        exit 1
    fi
    
    # 健康检查
    health_check
    
    # 显示启动信息
    show_startup_info
    
    # 等待后台进程
    wait
}

# 运行主函数
main "$@"