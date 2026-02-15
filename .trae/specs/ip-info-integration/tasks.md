# Tasks
- [x] 任务 1: 创建 IP 信息数据模型 `IpInfo`
  - [x] 定义 `IpInfo` 类，包含 country, city, region, loc 等字段
  - [x] 使用 `freezed` 和 `json_serializable` 生成代码
  - [x] 运行 `build_runner`

- [x] 任务 2: 创建 IP 查询服务 Provider `ipInfoProvider`
  - [x] 实现 `fetchIpInfo` 方法，使用 Dio 调用 ipinfo.io API
  - [x] 实现简单的内存缓存机制 (Map<String, CachedResult>)，TTL 5 分钟
  - [x] 实现请求限流逻辑 (Debounce/Throttle)
  - [x] 处理网络错误和 API 异常

- [x] 任务 3: 创建 IP 查询 UI 组件 `IpLocationQueryWidget`
  - [x] 创建包含 TextField (输入 IP) 和 IconButton (查询) 的 Row
  - [x] 显示查询结果 (Chip 或 Text)
  - [x] 处理加载状态 (CircularProgressIndicator)
  - [x] 处理错误提示 (SnackBar 或 Text)

- [x] 任务 4: 集成到 `ServerCardModern`
  - [x] 修改 `lib/view/page/server/tab/card_modern.dart`
  - [x] 在 `_buildTags` 下方添加 `IpLocationQueryWidget`
  - [x] 调整布局以适应卡片样式

- [x] 任务 5: 验证与测试
  - [x] 测试不同国家的 IP
  - [x] 验证缓存是否生效
  - [x] 验证限流是否生效
  - [x] 验证错误处理

# Task Dependencies
- [任务 2] depends on [任务 1]
- [任务 3] depends on [任务 2]
- [任务 4] depends on [任务 3]
