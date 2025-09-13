#!/bin/bash

# 简化版Docker启动脚本

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

# 检查Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    print_success "Docker 环境检查通过"
}

# 创建日志目录
setup_directories() {
    print_info "创建日志目录..."
    mkdir -p logs
    print_success "目录创建完成"
}

# 清理旧容器和镜像
cleanup() {
    print_info "清理旧的容器和镜像..."
    
    # 停止并删除容器
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 删除旧镜像
    docker rmi lenav_lenav 2>/dev/null || true
    
    print_success "清理完成"
}

# 构建和启动服务
start_services() {
    print_info "构建和启动服务..."
    
    # 构建镜像
    docker-compose build
    
    # 启动服务
    docker-compose up -d
    
    print_success "服务启动完成"
}

# 显示服务状态
show_status() {
    print_info "服务状态:"
    docker-compose ps
    
    echo ""
    print_info "访问地址:"
    echo "  - 主应用: http://localhost"
    echo "  - API健康检查: http://localhost/api/health"
    echo "  - 获取配置: http://localhost/api/nav/config"
    echo ""
    print_info "查看日志:"
    echo "  - 应用日志: docker-compose logs -f"
    echo "  - 实时日志: docker-compose logs -f lenav"
}

# 停止服务
stop_services() {
    print_info "停止服务..."
    docker-compose down
    print_success "服务已停止"
}

# 重启服务
restart_services() {
    print_info "重启服务..."
    docker-compose restart
    print_success "服务已重启"
}

# 查看日志
show_logs() {
    if [ "$1" = "-f" ]; then
        docker-compose logs -f lenav
    else
        docker-compose logs lenav
    fi
}

# 进入容器
enter_container() {
    docker-compose exec lenav /bin/bash
}

# 主函数
main() {
    case "${1:-start}" in
        "check")
            check_docker
            ;;
        "setup")
            check_docker
            setup_directories
            ;;
        "clean")
            cleanup
            ;;
        "build")
            check_docker
            setup_directories
            # 检查本地构建文件
            if [ ! -d "dist" ] || [ -z "$(ls -A dist)" ]; then
                print_warning "dist 目录不存在或为空"
                print_info "请先运行 ./build-local.sh 进行本地构建"
                exit 1
            fi
            docker-compose build
            ;;
        "start")
            check_docker
            setup_directories
            # 检查本地构建文件
            if [ ! -d "dist" ] || [ -z "$(ls -A dist)" ]; then
                print_warning "dist 目录不存在或为空"
                print_info "请先运行 ./build-local.sh 进行本地构建"
                exit 1
            fi
            start_services
            show_status
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "shell")
            enter_container
            ;;
        "help"|"-h"|"--help")
            echo "Lenav Docker 管理脚本"
            echo ""
            echo "使用方法:"
            echo "  $0 check      # 检查Docker环境"
            echo "  $0 setup      # 设置目录"
            echo "  $0 clean      # 清理旧容器和镜像"
            echo "  $0 build      # 构建镜像"
            echo "  $0 start      # 启动服务"
            echo "  $0 stop       # 停止服务"
            echo "  $0 restart    # 重启服务"
            echo "  $0 status     # 显示服务状态"
            echo "  $0 logs       # 查看日志"
            echo "  $0 logs -f    # 实时查看日志"
            echo "  $0 shell      # 进入容器"
            echo "  $0 help       # 显示帮助"
            echo ""
            echo "重要提示:"
            echo "  在执行 build 或 start 之前，请先运行 ./build-local.sh 进行本地构建"
            echo "  本地构建会生成 dist 目录，Docker 镜像将使用这些文件"
            echo ""
            echo "环境变量（可选）:"
            echo "  NACOS_URL     # Nacos服务器地址（如不配置将使用默认数据）"
            echo "  NACOS_USERNAME # Nacos用户名"
            echo "  NACOS_PASSWORD # Nacos密码"
            echo "  DATA_ID       # 配置ID (默认: nav-config)"
            echo "  GROUP         # 配置组 (默认: DEFAULT_GROUP)"
            echo "  TENANT        # 命名空间 (默认: nav-config)"
            echo ""
            echo "示例:"
            echo "  # 首先进行本地构建"
            echo "  ./build-local.sh"
            echo ""
            echo "  # 使用默认配置启动"
            echo "  $0 start"
            echo ""
            echo "  # 连接外部Nacos启动"
            echo "  NACOS_URL=http://nacos-server:8848 NACOS_USERNAME=nacos NACOS_PASSWORD=password $0 start"
            ;;
        *)
            print_error "未知命令: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"