#!/usr/bin/env python3
"""
Lenav Python Backend Service
提供数据接口的Python后端服务，从Nacos获取配置数据
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from nacos_py_client import NacosClient
import json
import os
import time
from typing import Dict, Any

app = Flask(__name__)
CORS(app)

# 配置
NACOS_URL = os.getenv('NACOS_URL', 'http://127.0.0.1:8848')
DATA_ID = os.getenv('DATA_ID', 'nav-config')
GROUP = os.getenv('GROUP', 'DEFAULT_GROUP')
TENANT = os.getenv('TENANT', 'nav-config')
NACOS_USERNAME = os.getenv('NACOS_USERNAME', '')
NACOS_PASSWORD = os.getenv('NACOS_PASSWORD', '')

# 内存缓存数据
cached_data = None
nacos_client = None


def init_nacos_client():
    """初始化Nacos客户端"""
    global nacos_client
    try:
        # 构建客户端配置 - 保持完整的URL格式
        client_config = {
            'server_addr': NACOS_URL,
            'namespace_id': TENANT
        }

        # 如果有认证信息，添加到配置中
        if NACOS_USERNAME and NACOS_PASSWORD:
            client_config['username'] = NACOS_USERNAME
            client_config['password'] = NACOS_PASSWORD

        print(f"Initializing Nacos client with config: {client_config}")
        nacos_client = NacosClient(**client_config)

        # 测试连接
        nacos_client.config.get(DATA_ID, GROUP, TENANT)
        print("Nacos client initialized successfully")
        return True

    except Exception as e:
        print(f"Failed to initialize Nacos client: {e}")
        return False


def get_nacos_config() -> Dict[str, Any]:
    """从Nacos获取配置数据，如果Nacos不可用则从本地文件加载"""
    global nacos_client

    try:
        # 如果客户端未初始化，先初始化
        if nacos_client is None:
            if not init_nacos_client():
                print("Failed to initialize Nacos client, loading from local file")
                return load_from_local_file()

        print(
            f"Getting config from Nacos - DataID: {DATA_ID}, Group: {GROUP}, Namespace: {TENANT}")

        # 从Nacos获取配置
        config_content = nacos_client.config.get(DATA_ID, GROUP, TENANT)

        if config_content:
            print(
                f"Config retrieved successfully, length: {len(config_content)}")
            return json.loads(config_content)
        else:
            print("No config content returned from Nacos, loading from local file")
            return load_from_local_file()

    except Exception as e:
        print(f"Error getting config from Nacos: {e}")
        # 更详细的错误信息
        error_str = str(e)
        if "404" in error_str:
            print("Config not found in Nacos, loading from local file")
        elif "403" in error_str:
            print("Permission denied - check user permissions, loading from local file")
        elif "401" in error_str:
            print(
                "Authentication failed - check username and password, loading from local file")
        elif "Connection" in error_str:
            print(
                "Connection error - check Nacos server address, loading from local file")
        return load_from_local_file()


def get_default_data() -> Dict[str, Any]:
    """获取默认数据（当Nacos不可用时使用）"""
    return {
        "company": {
            "title": "公司环境地址",
            "name": "company",
            "nav": [
                {
                    "icon": "./static/images/confluence.png",
                    "name": "Confluence",
                    "desc": "Confluence, 技术文档",
                    "link": "http://10.191.21.235:8090/#all-updates",
                    "doc": "https://www.atlassian.com/software/confluence"
                },
                {
                    "icon": "./static/images/nexus.png",
                    "name": "nexus",
                    "desc": "nexus私服",
                    "link": "http://10.126.138.142:8081/nexus/#welcome"
                }
            ]
        },
        "group": {
            "title": "组内环境",
            "name": "group",
            "nav": [
                {
                    "icon": "http://172.16.21.45:10001/favicon.ico",
                    "name": "原型管理",
                    "desc": "原型管理",
                    "link": "http://172.16.21.45:10001/"
                }
            ]
        }
    }


def save_nacos_config(config_data: Dict[str, Any]) -> bool:
    """保存配置到Nacos，如果Nacos不可用则保存到本地文件"""
    global nacos_client

    try:
        # 如果客户端未初始化，先初始化
        if nacos_client is None:
            if not init_nacos_client():
                print("Failed to initialize Nacos client, saving to local file")
                return save_to_local_file(config_data)

        # 将配置数据转换为JSON字符串
        config_content = json.dumps(config_data, ensure_ascii=False, indent=2)

        print(
            f"Saving config to Nacos - DataID: {DATA_ID}, Group: {GROUP}, Namespace: {TENANT}")

        # 发布配置到Nacos
        result = nacos_client.config.publish(
            DATA_ID, GROUP, config_content, TENANT)

        if result:
            print("Config saved successfully to Nacos")
            return True
        else:
            print("Failed to save config to Nacos, saving to local file")
            return save_to_local_file(config_data)

    except Exception as e:
        print(f"Error saving config to Nacos: {e}, saving to local file")
        return save_to_local_file(config_data)


def save_to_local_file(config_data: Dict[str, Any]) -> bool:
    """保存配置到本地文件"""
    try:
        config_file = "nav_config_backup.json"
        config_content = json.dumps(config_data, ensure_ascii=False, indent=2)

        with open(config_file, 'w', encoding='utf-8') as f:
            f.write(config_content)

        print(f"Config saved to local file: {config_file}")
        return True

    except Exception as e:
        print(f"Error saving config to local file: {e}")
        return False


def load_from_local_file() -> Dict[str, Any]:
    """从本地文件加载配置"""
    try:
        config_file = "nav_config_backup.json"
        if os.path.exists(config_file):
            with open(config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        else:
            return get_default_data()
    except Exception as e:
        print(f"Error loading config from local file: {e}")
        return get_default_data()


@app.route('/nacos/v1/cs/configs', methods=['GET'])
def get_configs():
    """获取Nacos配置接口"""
    global cached_data

    # 检查请求参数
    data_id = request.args.get('dataId', DATA_ID)
    group = request.args.get('group', GROUP)
    tenant = request.args.get('tenant', TENANT)

    # 只处理指定的配置
    if data_id == DATA_ID and group == GROUP and tenant == TENANT:
        try:
            # 从Nacos获取最新数据
            fresh_data = get_nacos_config()
            cached_data = fresh_data
            return jsonify(fresh_data)
        except Exception as e:
            print(f"Error getting fresh data: {e}")
            # 如果获取失败，返回缓存数据
            if cached_data:
                return jsonify(cached_data)
            else:
                return jsonify(get_default_data())
    else:
        return jsonify({"error": "Invalid config parameters"}), 400


@app.route('/api/nav/config', methods=['GET'])
def get_nav_config():
    """获取导航配置接口"""
    try:
        data = get_nacos_config()
        return jsonify({
            "success": True,
            "data": data,
            "timestamp": int(time.time())
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({
        "status": "healthy",
        "service": "lenav-backend",
        "version": "1.0.0"
    })


@app.route('/api/reload', methods=['POST'])
def reload_config():
    """重新加载配置"""
    global cached_data
    try:
        fresh_data = get_nacos_config()
        cached_data = fresh_data
        return jsonify({
            "success": True,
            "message": "配置重新加载成功"
        })
    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/api/nav/add', methods=['POST'])
def add_nav_item():
    """添加新的导航项目"""
    try:
        # 获取请求数据
        data = request.get_json()
        if not data:
            return jsonify({
                "success": False,
                "message": "请求数据不能为空"
            }), 400

        # 验证必填字段
        required_fields = ['name', 'link', 'category']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({
                    "success": False,
                    "message": f"字段 {field} 不能为空"
                }), 400

        # 获取当前配置
        current_config = get_nacos_config()

        # 确保分类存在
        category = data['category']
        if category not in current_config:
            # 如果分类不存在，创建新的分类
            category_titles = {
                'company': '公司环境地址',
                'group': '组内环境',
                'dev': '开发环境地址',
                'cloud': '研发上云环境',
                'k8s': 'k8s环境相关地址',
                'k8s-test': 'k8s测试环境地址',
                'k8s-demo': 'k8s演示环境地址',
                'pre-prod': '内部预生产环境',
                'prod': '内部生产地址'
            }
            current_config[category] = {
                "title": category_titles.get(category, category),
                "name": category,
                "nav": []
            }

        # 创建新的导航项目
        new_item = {
            "icon": data.get('icon', ''),
            "name": data['name'],
            "desc": data.get('desc', ''),
            "link": data['link']
        }

        # 添加可选的文档链接
        if 'doc' in data and data['doc']:
            new_item['doc'] = data['doc']

        # 添加到对应分类
        current_config[category]['nav'].append(new_item)

        # 保存到Nacos
        if save_nacos_config(current_config):
            # 更新缓存
            global cached_data
            cached_data = current_config
            return jsonify({
                "success": True,
                "message": "项目添加成功",
                "data": new_item
            })
        else:
            return jsonify({
                "success": False,
                "message": "保存到Nacos失败"
            }), 500

    except Exception as e:
        print(f"Error adding nav item: {e}")
        return jsonify({
            "success": False,
            "message": f"添加失败: {str(e)}"
        }), 500


if __name__ == '__main__':
    # 启动时预加载配置
    print("Starting Lenav Backend Service...")
    print(f"Nacos URL: {NACOS_URL}")
    print(f"Data ID: {DATA_ID}")
    print(f"Group: {GROUP}")
    print(f"Tenant: {TENANT}")
    if NACOS_USERNAME:
        print(f"Nacos Username: {NACOS_USERNAME}")
        print("Nacos Password: [HIDDEN]")
    else:
        print("Nacos Authentication: Disabled (no username provided)")

    # 预加载配置
    cached_data = get_nacos_config()
    print("Configuration loaded successfully!")

    # 启动Flask服务
    app.run(
        host='0.0.0.0',
        port=5555,
        debug=True,
        threaded=True
    )
