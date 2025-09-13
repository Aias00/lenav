#!/bin/bash

# Lenav 统一启动脚本
# 支持同时启动前端和后端服务

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
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

# 检查依赖
check_dependencies() {
    print_info "检查环境依赖..."
    
    # 检查Python3
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 未安装，请先安装 Python3"
        exit 1
    fi
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js 未安装，请先安装 Node.js"
        exit 1
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        print_error "npm 未安装，请先安装 npm"
        exit 1
    fi
    
    print_success "环境依赖检查完成"
}

# 设置环境变量
setup_environment() {
    print_info "设置环境变量..."
    
    # 设置默认值
    export NACOS_URL=${NACOS_URL:-"http://127.0.0.1:8848"}
    export DATA_ID=${DATA_ID:-"nav-config"}
    export GROUP=${GROUP:-"DEFAULT_GROUP"}
    export TENANT=${TENANT:-"nav-config"}
    export NACOS_USERNAME=${NACOS_USERNAME:-""}
    export NACOS_PASSWORD=${NACOS_PASSWORD:-""}
    
    # 显示环境变量
    echo "----------------------------------------"
    echo "环境变量配置:"
    echo "NACOS_URL: $NACOS_URL"
    echo "DATA_ID: $DATA_ID"
    echo "GROUP: $GROUP"
    echo "TENANT: $TENANT"
    if [ -n "$NACOS_USERNAME" ]; then
        echo "NACOS_USERNAME: $NACOS_USERNAME"
        echo "NACOS_PASSWORD: [HIDDEN]"
    else
        echo "NACOS Authentication: Disabled"
    fi
    echo "----------------------------------------"
}

# 清理进程
cleanup() {
    print_info "正在清理进程..."
    
    # 查找并终止相关进程
    pids=$(pgrep -f "python3 backend.py" || true)
    if [ -n "$pids" ]; then
        print_info "终止Python后端进程: $pids"
        echo $pids | xargs kill -TERM 2>/dev/null || true
        sleep 1
        # 如果还有残留进程，强制终止
        pids=$(pgrep -f "python3 backend.py" || true)
        if [ -n "$pids" ]; then
            print_warning "强制终止残留Python进程: $pids"
            echo $pids | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    pids=$(pgrep -f "npm run serve" || true)
    if [ -n "$pids" ]; then
        print_info "终止前端服务进程: $pids"
        echo $pids | xargs kill -TERM 2>/dev/null || true
        sleep 1
        # 如果还有残留进程，强制终止
        pids=$(pgrep -f "npm run serve" || true)
        if [ -n "$pids" ]; then
            print_warning "强制终止残留npm进程: $pids"
            echo $pids | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    pids=$(pgrep -f "vue-cli-service serve" || true)
    if [ -n "$pids" ]; then
        print_info "终止Vue CLI进程: $pids"
        echo $pids | xargs kill -TERM 2>/dev/null || true
        sleep 1
        # 如果还有残留进程，强制终止
        pids=$(pgrep -f "vue-cli-service serve" || true)
        if [ -n "$pids" ]; then
            print_warning "强制终止残留Vue CLI进程: $pids"
            echo $pids | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # 清理端口占用
    print_info "清理端口占用..."
    
    # 清理后端端口 5555
    backend_pids=$(lsof -ti:5555 2>/dev/null || true)
    if [ -n "$backend_pids" ]; then
        print_info "清理后端端口5555占用: $backend_pids"
        echo $backend_pids | xargs kill -TERM 2>/dev/null || true
        sleep 1
        # 如果还有占用，强制清理
        backend_pids=$(lsof -ti:5555 2>/dev/null || true)
        if [ -n "$backend_pids" ]; then
            print_warning "强制清理端口5555占用: $backend_pids"
            echo $backend_pids | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # 清理前端端口 5556
    frontend_pids=$(lsof -ti:5556 2>/dev/null || true)
    if [ -n "$frontend_pids" ]; then
        print_info "清理前端端口5556占用: $frontend_pids"
        echo $frontend_pids | xargs kill -TERM 2>/dev/null || true
        sleep 1
        # 如果还有占用，强制清理
        frontend_pids=$(lsof -ti:5556 2>/dev/null || true)
        if [ -n "$frontend_pids" ]; then
            print_warning "强制清理端口5556占用: $frontend_pids"
            echo $frontend_pids | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # 等待进程完全退出
    sleep 2
    
    # 验证端口是否已释放
    if lsof -ti:5555 >/dev/null 2>&1; then
        print_warning "后端端口5555仍有占用"
    else
        print_success "后端端口5555已释放"
    fi
    
    if lsof -ti:5556 >/dev/null 2>&1; then
        print_warning "前端端口5556仍有占用"
    else
        print_success "前端端口5556已释放"
    fi
}

# 信号处理 - 只在监控模式下启用
# trap cleanup EXIT INT TERM

# 启动后端服务
start_backend() {
    print_info "启动Python后端服务..."
    
    # 检查是否存在虚拟环境
    if [ ! -d "venv" ]; then
        print_info "创建Python虚拟环境..."
        python3 -m venv venv
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 安装依赖
    print_info "安装Python依赖..."
    pip install -r requirements.txt
    
    # 启动后端服务（后台运行）
    print_info "启动后端服务在端口 5555..."
    nohup python3 backend.py > backend.log 2>&1 &
    BACKEND_PID=$!
    
    # 等待后端服务启动
    print_info "等待后端服务启动..."
    sleep 5
    
    # 检查后端服务是否正常
    if curl -s http://localhost:5555/api/health > /dev/null; then
        print_success "后端服务启动成功 (PID: $BACKEND_PID)"
        echo "后端日志: backend.log"
    else
        print_error "后端服务启动失败"
        print_info "查看日志: tail -f backend.log"
        exit 1
    fi
}

# 启动前端服务
start_frontend() {
    print_info "启动前端服务..."
    # 检查是否存在node_modules
    if [ ! -d "node_modules" ]; then
        print_info "安装前端依赖..."
        npm install
    fi
    
    # 启动前端服务（后台运行）
    print_info "启动前端服务在端口 5556..."
    export NODE_OPTIONS="--openssl-legacy-provider"
    nohup npm run serve > frontend.log 2>&1 &
    FRONTEND_PID=$!
    
    # 等待前端服务启动
    print_info "等待前端服务启动..."
    sleep 15
    
    # 检查前端服务是否正常
    if curl -s http://localhost:5556 > /dev/null; then
        print_success "前端服务启动成功 (PID: $FRONTEND_PID)"
        echo "前端日志: frontend.log"
    else
        print_error "前端服务启动失败"
        print_info "查看日志: tail -f frontend.log"
        exit 1
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "========================================"
    echo "🎉 Lenav 服务启动成功！"
    echo "========================================"
    echo "📱 前端访问地址: ${GREEN}http://localhost:5556${NC}"
    echo "🔧 后端API地址: ${GREEN}http://localhost:5555${NC}"
    echo ""
    echo "📋 API 接口:"
    echo "   - 健康检查: http://localhost:5556/api/health"
    echo "   - 获取配置: http://localhost:5556/api/nav/config"
    echo "   - Nacos接口: http://localhost:5556/nacos/v1/cs/configs?dataId=nav-config&group=DEFAULT_GROUP&tenant=nav-config"
    echo ""
    echo "📄 日志文件:"
    echo "   - 后端日志: tail -f backend.log"
    echo "   - 前端日志: tail -f frontend.log"
    echo ""
    echo "⚠️  按 Ctrl+C 停止所有服务"
    echo "========================================"
}

# 监控服务状态
monitor_services() {
    print_info "正在监控服务状态..."
    
    while true; do
        sleep 30
        
        # 检查后端服务
        if ! curl -s http://localhost:5555/api/health > /dev/null; then
            print_warning "后端服务异常，尝试重启..."
            start_backend
        fi
        
        # 检查前端服务
        if ! curl -s http://localhost:5556 > /dev/null; then
            print_warning "前端服务异常，尝试重启..."
            pkill -f "npm run serve" || true
            pkill -f "vue-cli-service serve" || true
            start_frontend
        fi
    done
}

# 主函数
main() {
    echo "========================================"
    echo "🚀 Lenav 统一启动脚本"
    echo "========================================"
    
    # 检查命令行参数
    if [ "$1" = "stop" ]; then
        print_info "停止所有服务..."
        cleanup
        print_success "所有服务已停止"
        exit 0
    fi
    
    if [ "$1" = "restart" ]; then
        print_info "重启所有服务..."
        cleanup
        setup_environment
        start_backend
        start_frontend
        show_access_info
        print_info "服务已在后台运行，使用 './start_all.sh status' 检查状态"
        exit 0
    fi
    
    if [ "$1" = "status" ]; then
        print_info "检查服务状态..."
        if curl -s http://localhost:5555/api/health > /dev/null; then
            print_success "后端服务运行正常"
        else
            print_error "后端服务未运行"
        fi
        
        if curl -s http://localhost:5556 > /dev/null; then
            print_success "前端服务运行正常"
        else
            print_error "前端服务未运行"
        fi
        exit 0
    fi
    
    if [ "$1" = "monitor" ]; then
        print_info "启动服务并进入监控模式..."
        # 在监控模式下启用信号处理
        trap cleanup EXIT INT TERM
        check_dependencies
        setup_environment
        start_backend
        start_frontend
        show_access_info
        monitor_services
        exit 0
    fi
    
    if [ "$1" = "logs" ]; then
        print_info "查看服务日志..."
        echo "后端日志 (按 Ctrl+C 退出):"
        tail -f backend.log
        exit 0
    fi
    
    if [ "$1" = "logs-frontend" ]; then
        print_info "查看前端日志..."
        echo "前端日志 (按 Ctrl+C 退出):"
        tail -f frontend.log
        exit 0
    fi
    
    if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  (无参数)    启动服务并在后台运行"
        echo "  monitor     启动服务并进入监控模式"
        echo "  stop        停止所有服务"
        echo "  restart     重启所有服务"
        echo "  status      检查服务状态"
        echo "  logs        查看后端日志"
        echo "  logs-frontend 查看前端日志"
        echo "  help        显示此帮助信息"
        echo ""
        echo "示例:"
        echo "  $0                    # 启动服务并在后台运行"
        echo "  $0 monitor           # 启动服务并监控状态"
        echo "  $0 stop              # 停止所有服务"
        echo "  $0 status            # 检查服务状态"
        echo "  $0 logs              # 查看后端日志"
        echo "  $0 logs-frontend     # 查看前端日志"
        exit 0
    fi
    
    # 默认启动所有服务并在后台运行
    check_dependencies
    setup_environment
    start_backend
    start_frontend
    show_access_info
    print_info "服务已在后台运行，使用 './start_all.sh status' 检查状态"
    print_info "使用 './start_all.sh logs' 查看日志"
    print_info "使用 './start_all.sh stop' 停止服务"
}

# 运行主函数
main "$@"
