#!/bin/bash

# Docker启动脚本

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
    print_info "创建必要的目录..."
    
    mkdir -p logs
    mkdir -p docker/mysql
    mkdir -p docker/prometheus
    mkdir -p docker/grafana/{dashboards,provisioning/{dashboards,datasources}}
    
    print_success "目录创建完成"
}

# 清理旧容器和镜像
cleanup() {
    print_info "清理旧的容器和镜像..."
    
    # 停止并删除容器
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # 删除旧镜像
    docker rmi lenav_lenav 2>/dev/null || true
    
    print_success "清理完成"
}

# 构建和启动服务
start_services() {
    print_info "构建和启动服务..."
    
    # 构建镜像
    docker-compose build --no-cache
    
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
    echo "  - Nacos控制台: http://localhost:8848/nacos"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Grafana: http://localhost:3000 (admin/admin123)"
    echo ""
    print_info "查看日志:"
    echo "  - 所有服务: docker-compose logs -f"
    echo "  - 应用服务: docker-compose logs -f lenav"
    echo "  - Nacos服务: docker-compose logs -f nacos"
}

# 停止服务
stop_services() {
    print_info "停止所有服务..."
    docker-compose down
    print_success "服务已停止"
}

# 重启服务
restart_services() {
    print_info "重启服务..."
    docker-compose restart
    print_success "服务已重启"
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
            docker-compose build --no-cache
            ;;
        "start")
            check_docker
            setup_directories
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
            docker-compose logs -f "${2:-lenav}"
            ;;
        "shell")
            docker-compose exec lenav /bin/bash
            ;;
        "nacos-shell")
            docker-compose exec nacos /bin/bash
            ;;
        "mysql-shell")
            docker-compose exec mysql mysql -unacos -pnacos nacos
            ;;
        *)
            echo "Lenav Docker 管理脚本"
            echo ""
            echo "使用方法:"
            echo "  $0 check      # 检查Docker环境"
            echo "  $0 setup      # 设置目录"
            echo "  $0 clean      # 清理旧容器和镜像"
            echo "  $0 build      # 构建镜像"
            echo "  $0 start      # 启动所有服务"
            echo "  $0 stop       # 停止所有服务"
            echo "  $0 restart    # 重启所有服务"
            echo "  $0 status     # 显示服务状态"
            echo "  $0 logs       # 查看日志"
            echo "  $0 shell      # 进入应用容器"
            echo "  $0 nacos-shell # 进入Nacos容器"
            echo "  $0 mysql-shell # 进入MySQL数据库"
            echo ""
            echo "环境变量:"
            echo "  NACOS_URL     # Nacos服务器地址"
            echo "  NACOS_USERNAME # Nacos用户名"
            echo "  NACOS_PASSWORD # Nacos密码"
            echo "  DATA_ID       # 配置ID"
            echo "  GROUP         # 配置组"
            echo "  TENANT        # 命名空间"
            ;;
    esac
}

main "$@"