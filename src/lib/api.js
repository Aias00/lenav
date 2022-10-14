import request from './request'

const $api = {

  /**
   * 获取配置
   * @param {*} param
   * @returns
   */
  getConfig: param => {
    console.log("获取配置信息")
    return request.get(`/nacos/v1/cs/configs?show=all&dataId=${param.dataId}&group=${param.group}&tenant=${param.tenant}`)
  }
}

export default $api
