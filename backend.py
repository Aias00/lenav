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
    """从Nacos获取配置数据"""
    global nacos_client
    
    try:
        # 如果客户端未初始化，先初始化
        if nacos_client is None:
            if not init_nacos_client():
                print("Failed to initialize Nacos client, using default data")
                return get_default_data()
        
        print(f"Getting config from Nacos - DataID: {DATA_ID}, Group: {GROUP}, Namespace: {TENANT}")
        
        # 从Nacos获取配置
        config_content = nacos_client.config.get(DATA_ID, GROUP, TENANT)
        
        if config_content:
            print(f"Config retrieved successfully, length: {len(config_content)}")
            return json.loads(config_content)
        else:
            print("No config content returned from Nacos")
            return get_default_data()
            
    except Exception as e:
        print(f"Error getting config from Nacos: {e}")
        # 更详细的错误信息
        error_str = str(e)
        if "404" in error_str:
            print("Config not found in Nacos")
        elif "403" in error_str:
            print("Permission denied - check user permissions")
        elif "401" in error_str:
            print("Authentication failed - check username and password")
        elif "Connection" in error_str:
            print("Connection error - check Nacos server address")
        return get_default_data()

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