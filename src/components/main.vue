
<template>
  <div class="layout" v-if="data">
    <Layout>
      <Sider
        breakpoint="md"
        collapsible
        :collapsed-width="78"
        v-model="isCollapsed"
        :style="{ position: 'fixed', height: '100vh', left: 0 }"
      >
        <!-- <div class="logo-con">
          <a href="./"><img src="logo.png" key="max-logo" /></a>
        </div> -->
        <Menu
          active-name="1-2"
          theme="dark"
          width="auto"
          :class="menuitemClasses"
          @on-select="jumpAnchor"
        >
          <!-- <MenuItem name="我的收藏">
                        <Icon type="ios-heart" />
                        <span>我的收藏</span>
                    </MenuItem> -->
          <!-- <MenuItem name="常用网址">
                        <Icon type="ios-navigate"></Icon>
                        <span>常用网址</span>
                    </MenuItem> -->
          <template v-for="(item, index) in data">
            <MenuItem
              :name="item.title"
              v-if="!item.children && childrenList.indexOf(index) < 0"
              :key="index"
            >
              <Icon :type="item.icon ? item.icon : 'ios-search'"></Icon>
              <span>{{ item.title }}</span>
            </MenuItem>
            <Submenu :name="item.title" v-if="item.children" :key="index">
              <template slot="title"
                ><Icon :type="item.icon ? item.icon : 'ios-search'"></Icon>
                <span>{{ item.title }}</span></template
              >
              <MenuItem
                :name="data[key] ? data[key].title : key"
                v-for="key in item.children"
                :key="key"
              >
                <span>{{ data[key] ? data[key].title : key }}</span>
              </MenuItem>
            </Submenu>
          </template>
        </Menu>
        <div slot="trigger"></div>
      </Sider>
      <Layout class="layout-right">
        <Header
          class="layout-header-bar"
          :style="{ position: 'fixed', width: '100%', zIndex: 99 }"
          >欢迎使用
          <Input
            v-model="search"
            placeholder="请输入内容搜索"
            class="search"
            @on-enter="searchData"
          />
          <span class="search-text"
            ><Button type="primary" icon="search" @click="searchData"
              >搜索</Button
            ></span
          >
          <Button
            type="success"
            icon="plus-round"
            @click="resetSearch"
            v-show="searchStatus"
            >重置</Button
          >
          <Button
            type="primary"
            icon="ios-add"
            @click="showAddModal"
            style="margin-left: 10px"
            >新建</Button
          >
          <!-- <Button type="success" icon="plus-round" @click="resetSearch" >重置</Button> -->
        </Header>
        <Content
          :style="{
            margin: '88px 20px 0',
            background: '#fff',
            minHeight: '500px',
          }"
        >
          <NavSub :data="data" :spinShow="spinShow"></NavSub>
        </Content>
        <!-- <Footer class="layout-footer-center">lenav ©2021 Created by Lework <a href="https://github.com/lework/lenav" target="_blank">GitHub</a></Footer> -->
      </Layout>
    </Layout>
    <BackTop></BackTop>

    <!-- 新建弹框 -->
    <Modal
      v-model="addModalVisible"
      title="新建项目"
      :mask-closable="false"
      :closable="true"
      width="600"
      @on-ok="handleAddSubmit"
      @on-cancel="handleAddCancel"
    >
      <Form
        ref="addForm"
        :model="addFormData"
        :rules="addFormRules"
        :label-width="80"
      >
        <FormItem label="项目名称" prop="name">
          <Input v-model="addFormData.name" placeholder="请输入项目名称" />
        </FormItem>
        <FormItem label="项目地址" prop="link">
          <Input v-model="addFormData.link" placeholder="请输入项目地址" />
        </FormItem>
        <FormItem label="项目描述" prop="desc">
          <Input v-model="addFormData.desc" placeholder="请输入项目描述" />
        </FormItem>
        <FormItem label="Logo地址" prop="icon">
          <Input v-model="addFormData.icon" placeholder="请输入Logo地址" />
        </FormItem>
        <FormItem label="所属分类" prop="category">
          <Select v-model="addFormData.category" placeholder="请选择所属分类">
            <Option value="company">公司环境地址</Option>
            <Option value="group">组内环境</Option>
            <Option value="dev">开发环境地址</Option>
            <Option value="cloud">研发上云环境</Option>
            <Option value="k8s">k8s环境相关地址</Option>
            <Option value="k8s-test">k8s测试环境地址</Option>
            <Option value="k8s-demo">k8s演示环境地址</Option>
            <Option value="pre-prod">内部预生产环境</Option>
            <Option value="prod">内部生产地址</Option>
          </Select>
        </FormItem>
      </Form>
    </Modal>
  </div>
</template>
<script>
import NavSub from '@/components/card/sub';
// import Data from '@/data/data'
export default {
  data () {
    return {
      isCollapsed: false,
      search: '',
      searchStatus: false,
      data: null,
      childrenList: [],
      sourceData: '',
      serarchNum: 0,
      spinShow: false,
      // 新建弹框相关
      addModalVisible: false,
      addFormData: {
        name: '',
        link: '',
        desc: '',
        icon: '',
        category: 'company'
      },
      addFormRules: {
        name: [
          { required: true, message: '请输入项目名称', trigger: 'blur' }
        ],
        link: [
          { required: true, message: '请输入项目地址', trigger: 'blur' },
          { type: 'url', message: '请输入正确的URL格式', trigger: 'blur' }
        ],
        desc: [
          { required: false, message: '请输入项目描述', trigger: 'blur' }
        ],
        icon: [
          { required: false, message: '请输入Logo地址', trigger: 'blur' },
          {
            validator: (rule, value, callback) => {
              if (value && value.trim() !== '') {
                const urlPattern = /^https?:\/\/.+/;
                if (!urlPattern.test(value)) {
                  callback(new Error('请输入正确的URL格式'));
                } else {
                  callback();
                }
              } else {
                callback();
              }
            },
            trigger: 'blur'
          }
        ],
        category: [
          { required: true, message: '请选择所属分类', trigger: 'change' }
        ]
      }
    };
  },
  computed: {
    menuitemClasses: function () {
      return [
        'menu-item',
        this.isCollapsed ? 'collapsed-menu' : ''
      ];
    }
  },
  created: function () {
    // window.console.group('------Create创建前状态------');
    this._getData();
  },
  methods: {
    _getData () {
      this.spinShow = true;
      this.$axios
        .get("/api/nav/config") // 获取nav数据
        .then(rep => {
          // 新的API返回结构是 {success: true, data: {...}}
          this.data = rep.data.data || rep.data; // 兼容新旧两种格式
          for (let key in this.data) {
            if (this.data[key].hasOwnProperty("children")) {
              this.childrenList = this.childrenList.concat(this.data[key].children);
            }
          }
          this.spinShow = false;
        })
        .catch(e => {
          this.$Message.error({
            content: "获取数据失败!",
            duration: 120,
            closable: true
          });
          window.console.log("错误信息：", e);
        });
    },
    jumpAnchor (name) {
      if (document.documentElement.clientWidth <= 768) {
        this.isCollapsed = true;
      }

      let offset = 66;
      let el = document.querySelector('#' + name);
      window.scroll({ top: (el.offsetTop - offset), left: 0, behavior: 'smooth' });
    },
    searchData () {
      if (typeof this.search === 'undefined' || this.search === null || this.search === '') {
        this.$Message.error('请输入要搜索的内容');
        return true;
      }
      if (!this.searchStatus) {
        this.sourceData = JSON.parse(JSON.stringify(this.data));
      } else {
        this.data = JSON.parse(JSON.stringify(this.sourceData));
      }
      this.searchStatus = true;
      this.serarchNum = 0;
      for (let d in this.data) {
        if (!this.data[d].hasOwnProperty("nav")) {
          continue;
        }
        for (let i = 0; i < this.data[d]['nav'].length; i++) {
          if (this.data[d]['nav'][i]['name'].toLowerCase().indexOf(this.search.toLowerCase()) === -1) {
            if (this.data[d]['nav'][i]['link'].toLowerCase().indexOf(this.search.toLowerCase()) === -1) {
              this.data[d]['nav'].splice(i--, 1);
            } else {
              this.serarchNum++;
            }
          } else {
            this.serarchNum++;
          }
        }
      }
      if (this.serarchNum === 0) {
        this.$Message.error('没找到哦，请重试!');
      } else {
        this.$Message.success('查找到了' + this.serarchNum + '个相近的.');
      }
    },
    resetSearch () {
      this.spinShow = true;
      this.searchStatus = false;
      this.search = '';
      this.serarchNum = 0;
      this.data = JSON.parse(JSON.stringify(this.sourceData));
      setTimeout(() => {
        this.spinShow = false;
      }, 1000);
    },
    // 新建相关方法
    showAddModal () {
      this.addModalVisible = true;
      this.resetAddForm();
    },
    resetAddForm () {
      this.addFormData = {
        name: '',
        link: '',
        desc: '',
        icon: '',
        category: 'company'
      };
      this.$nextTick(() => {
        this.$refs.addForm.resetFields();
      });
    },
    handleAddCancel () {
      this.addModalVisible = false;
      this.resetAddForm();
    },
    handleAddSubmit () {
      this.$refs.addForm.validate((valid) => {
        if (valid) {
          this.submitAddForm();
        } else {
          this.$Message.error('请检查表单信息');
        }
      });
    },
    submitAddForm () {
      this.spinShow = true;
      this.$axios.post('/api/nav/add', this.addFormData)
        .then(response => {
          if (response.data.success) {
            this.$Message.success('添加成功！');
            this.addModalVisible = false;
            this.resetAddForm();
            // 重新加载数据
            this._getData();
          } else {
            this.$Message.error(response.data.message || '添加失败');
          }
        })
        .catch(error => {
          console.error('添加失败:', error);
          this.$Message.error('添加失败，请重试');
        })
        .finally(() => {
          this.spinShow = false;
        });
    }
  },
  components: {
    NavSub
  }
}
</script>

<style lang=less scoped>
.layout {
  border: 1px solid #d7dde4;
  background: #f5f7f9;
  position: relative;
  border-radius: 4px;
  overflow: hidden;
}
.layout-header-bar {
  background: #fff;
  box-shadow: 0 1px 1px rgba(0, 0, 0, 0.1);
}
.menu-item span {
  display: inline-block;
  overflow: hidden;
  width: 120px;
  text-overflow: ellipsis;
  white-space: nowrap;
  vertical-align: bottom;
  transition: width 0.2s ease 0.2s;
}
.menu-item i {
  transform: translateX(0px);
  transition: font-size 0.2s ease, transform 0.2s ease;
  vertical-align: middle;
  font-size: 16px;
}
.collapsed-menu span {
  width: 0px;
  transition: width 0.2s ease;
}
.collapsed-menu i {
  transform: translateX(5px);
  transition: font-size 0.2s ease 0.2s, transform 0.2s ease 0.2s;
  vertical-align: middle;
  font-size: 22px;
}
.ivu-layout-sider {
  z-index: 100;
}
.logo-con img {
  width: 180px;
  margin: 10px;
}
.search {
  margin-left: 10px;
  width: 200px;
  @media screen {
    @media (max-width: 768px) {
      width: auto;
    }
  }
}
.search-text {
  margin: 0 10px;
  @media screen {
    @media (max-width: 768px) {
      margin: 0 3px;
    }
  }
}
.ivu-layout-header {
  @media screen {
    @media (max-width: 768px) {
      padding: 0 0 0 20px;
    }
  }
}
.layout-right {
  margin-left: 200px;
  @media screen {
    @media (max-width: 768px) {
      margin-left: 0px;
    }
  }
}
</style>