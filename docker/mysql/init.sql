-- Nacos数据库初始化脚本
-- 创建nacos数据库
CREATE DATABASE IF NOT EXISTS nacos DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nacos;

-- 创建用户并授权
CREATE USER IF NOT EXISTS 'nacos'@'%' IDENTIFIED BY 'nacos';
GRANT ALL PRIVILEGES ON nacos.* TO 'nacos'@'%';
FLUSH PRIVILEGES;

-- Nacos表结构（简化版本）
CREATE TABLE IF NOT EXISTS config_info (
  id BIGINT NOT NULL AUTO_INCREMENT,
  data_id VARCHAR(255) NOT NULL,
  group_id VARCHAR(255) NOT NULL,
  tenant_id VARCHAR(128) DEFAULT '',
  app_name VARCHAR(128) DEFAULT '',
  content LONGTEXT NOT NULL,
  md5 VARCHAR(32) DEFAULT NULL,
  gmt_create DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  gmt_modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  src_user TEXT,
  src_ip VARCHAR(50) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_configinfo_datagrouptenant (data_id, group_id, tenant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 插入默认配置
INSERT INTO config_info (data_id, group_id, tenant_id, content, md5) 
VALUES ('nav-config', 'DEFAULT_GROUP', 'nav-config', '{
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
}', MD5('default-nav-config')) ON DUPLICATE KEY UPDATE content = VALUES(content), md5 = VALUES(md5);