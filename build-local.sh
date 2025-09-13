#!/bin/bash

# 本地构建脚本 - 在Docker构建前运行

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

# 检查Node.js
check_node() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js 未安装，请先安装 Node.js"
        exit 1
    fi
    
    node_version=$(node --version)
    print_info "Node.js 版本: $node_version"
}

# 检查npm
check_npm() {
    if ! command -v npm &> /dev/null; then
        print_error "npm 未安装，请先安装 npm"
        exit 1
    fi
    
    npm_version=$(npm --version)
    print_info "npm 版本: $npm_version"
}

# 清理旧构建
cleanup_old_build() {
    print_info "清理旧构建文件..."
    
    if [ -d "dist" ]; then
        rm -rf dist
        print_success "已清理旧的 dist 目录"
    fi
    
    if [ -d "node_modules" ]; then
        rm -rf node_modules
        print_success "已清理旧的 node_modules 目录"
    fi
}

# 安装依赖
install_dependencies() {
    print_info "安装前端依赖..."
    npm install
    print_success "依赖安装完成"
}

# 构建前端
build_frontend() {
    print_info "构建前端..."
    npm run build
    
    if [ $? -eq 0 ]; then
        print_success "前端构建完成"
    else
        print_error "前端构建失败"
        exit 1
    fi
}

# 验证构建结果
verify_build() {
    print_info "验证构建结果..."
    
    if [ -d "dist" ] && [ "$(ls -A dist)" ]; then
        print_success "dist 目录创建成功，包含以下文件:"
        ls -la dist/
        
        # 检查关键文件
        if [ -f "dist/index.html" ]; then
            print_success "index.html 文件存在"
        else
            print_warning "index.html 文件不存在"
        fi
        
        if [ -f "dist/js/app.js" ] || [ -f "dist/js/chunk-vendors.js" ]; then
            print_success "JavaScript 文件存在"
        else
            print_warning "JavaScript 文件可能不存在"
        fi
    else
        print_error "dist 目录为空或不存在"
        exit 1
    fi
}

# 显示Docker构建提示
show_docker_info() {
    echo ""
    print_info "Docker 构建提示:"
    echo "  本地构建已完成，现在可以运行 Docker 构建:"
    echo "  - 使用简化脚本: ./docker-simple.sh build"
    echo "  - 手动构建: docker-compose -f docker-compose.simple.yml build"
    echo "  - 启动服务: ./docker-simple.sh start"
    echo ""
    print_warning "注意: 请确保 dist 目录存在并包含构建文件"
}

# 主函数
main() {
    case "${1:-build}" in
        "check")
            check_node
            check_npm
            ;;
        "clean")
            cleanup_old_build
            ;;
        "deps")
            check_node
            check_npm
            install_dependencies
            ;;
        "build")
            print_info "开始本地构建..."
            check_node
            check_npm
            cleanup_old_build
            install_dependencies
            build_frontend
            verify_build
            show_docker_info
            print_success "本地构建完成！"
            ;;
        "help"|"-h"|"--help")
            echo "本地构建脚本 - 在Docker构建前运行"
            echo ""
            echo "使用方法:"
            echo "  $0 check      # 检查Node.js和npm环境"
            echo "  $0 clean      # 清理旧构建文件"
            echo "  $0 deps       # 仅安装依赖"
            echo "  $0 build      # 完整构建流程 (默认)"
            echo "  $0 help       # 显示帮助"
            echo ""
            echo "构建完成后，使用以下命令启动Docker容器:"
            echo "  ./docker-simple.sh start"
            ;;
        *)
            print_error "未知命令: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"