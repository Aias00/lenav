/*
 * Copyright 1999-2018 Alibaba Group Holding Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import axios from 'axios'
import qs from 'qs'
import { isPlainObject } from './nacosutil'
import storage from './storage'

const API_GENERAL_ERROR_MESSAGE = 'Request error, please try again later!'

function goLogin () {
  const url = window.location.href
  localStorage.removeItem('token')
  const baseUrl = url.split('#')[0]
  window.location.href = `${baseUrl}#/login`
}

const request = () => {
  const instance = axios.create({
    baseURL: process.env.NAOCS_URL
  })

  instance.interceptors.request.use(
    config => {
      const { url, params, data, method, headers } = config
      if (!params) {
        config.params = {}
      }
      if (!url.includes('auth/users/login')) {
        let token = {}
        try {
          token = storage.get(storage.keys.LOGIN_TOKEN)
        } catch (e) {
          console.log(e)
          goLogin()
        }
        // const { accessToken = '', username = '' } = token
        config.params.accessToken = token
        // support #3548 and fix #5835
        if (!url.includes('auth')) {
          config.params.username = 'nacos'
        }
        config.headers = Object.assign({}, headers, { token })
      }
      if (data && isPlainObject(data) && ['post', 'put'].includes(method)) {
        config.data = qs.stringify(data)
        if (!headers) {
          config.headers = {}
        }
        config.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      }
      return config
    },
    error => Promise.reject(error)
  )

  instance.interceptors.response.use(
    response => {
      console.log(response)
      const { success, resultCode, resultMessage = API_GENERAL_ERROR_MESSAGE } = response.data
      // if (!success && resultCode !== SUCCESS_RESULT_CODE) {
      //   Message.error(resultMessage);
      //   return Promise.reject(new Error(resultMessage));
      // }
      return response
    },
    error => {
      if (error.response) {
        const { data = {}, status } = error.response
        let message = `HTTP ERROR: ${status}`
        if (typeof data === 'string') {
          message = data
        } else if (typeof data === 'object') {
          message = data.message
        }
        // Message.error(message)
        this.$message.error(message)

        if (
          [401, 403].includes(status) &&
          ['unknown user!', 'token invalid!', 'token expired!', 'session expired!'].includes(
            message
          )
        ) {
          goLogin()
        }
        return Promise.reject(error.response)
      }
      // Message.error(API_GENERAL_ERROR_MESSAGE)
      this.$message.error(API_GENERAL_ERROR_MESSAGE)
      return Promise.reject(error)
    }
  )

  return instance
}

export default request()
