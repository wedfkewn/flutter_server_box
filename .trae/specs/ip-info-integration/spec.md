# 集成 IP 国家查询功能 Spec

## 为什么
用户需要在服务器详情页面能够便捷地查询 IP 地址的地理位置信息（特别是国家信息），以方便了解网络连接情况或进行简单的网络诊断。

## 变更内容
- 新增 IP 查询服务 (`IpInfoService`)，对接 ipinfo.io API。
- 新增数据模型 (`IpInfo`) 用于存储 API 响应。
- 新增 UI 组件 (`IpLocationQueryWidget`)，包含输入框、查询按钮和结果显示。
- 修改 `ServerCardModern` 组件，在指定位置（Tags 区域下方）集成 IP 查询功能。

## 影响
- **代码**:
    - `lib/data/model/app/ip_info.dart`: 新增模型。
    - `lib/data/provider/ip_info.dart`: 新增 Provider。
    - `lib/view/widget/ip_location_query.dart`: 新增 Widget。
    - `lib/view/page/server/tab/card_modern.dart`: 修改 UI。

## 新增需求
### 需求：IP 信息查询
系统应提供查询 IP 地理位置的功能。

#### 场景：成功查询
- **WHEN** 用户输入有效 IP 并点击查询
- **THEN** 调用 API，显示国家名称和代码

#### 场景：缓存
- **WHEN** 用户在 5 分钟内查询相同 IP
- **THEN** 返回缓存结果，不发起网络请求

#### 场景：限流
- **WHEN** 用户频繁点击查询（超过 1次/秒）
- **THEN** 忽略多余请求或排队处理（建议防抖/节流）

#### 场景：错误处理
- **WHEN** API 请求失败或 IP 无效
- **THEN** 显示友好的错误提示

## 技术要求
- API Token: `6f434b09039258`
- HTTPS 协议
- 缓存 TTL: 5 分钟
- 限流: 1 RPS
