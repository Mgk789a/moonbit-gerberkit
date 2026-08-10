# moonbit-gerberkit

MoonBit PCB 制造数据解析与检查工具。项目面向开源硬件协作和 CI，在 PCB 生产前把 Gerber RS-274X 与 Excellon 钻孔数据转换为统一的几何中间表示，并输出机器可读报告和轻量预览。

## 当前范围

- Gerber：单位识别、坐标、光圈宽度、D01 绘线和 D03 闪点。
- Excellon：单位、刀具直径、钻孔坐标。
- 中间表示：层、线路、焊盘、区域、钻孔、包围盒。
- DFM 基础规则：空层、极小线宽和异常小孔。
- 输出：JSON、SVG、ASCII；核心 API 可嵌入 MoonBit 工程。

首版明确不实现完整 PCB 布线器、布尔几何内核和生产商专有扩展。后续可扩展铜皮间距、阻焊桥、孔环、板框闭合性与更多 RS-274X aperture macro。

## 快速开始

需要 MoonBit 0.10.3 或更新版本：

```bash
moon check --deny-warn
moon test --deny-warn
moon run --target native cmd/gerberkit
```

库入口在 `src` 包：`parse_gerber`、`parse_excellon`、`parse_auto`、`report`、`to_json`、`to_svg` 和 `to_ascii`。当前命令行示例使用内置样例，后续会加入文件参数和目录批处理。

## 设计

解析器只负责把制造指令变成几何对象，检查器只消费中间表示，因此可以独立替换语法解析、规则集和渲染器。所有坐标在层进入中间表示时统一为毫米，`convert` 保留用于 API 使用方的显式单位换算。

## 项目来源与许可证

这是原创 MoonBit 工具项目，不是其他语言项目的直接移植；Gerber/Excellon 是公开制造文件格式，本仓库未复制第三方实现代码。项目采用 Apache-2.0，见 [LICENSE](LICENSE)。测试夹具为本仓库自编的短文本，不含商业 PCB 数据。

## 参赛材料说明

本仓库为 2026 MoonBit 8 月黑客松准备。开发过程保留可追踪的 Git 提交；CI 覆盖格式化、警告检查、接口信息生成、默认后端与 native 测试。正式提交前请将 `moon.mod` 中的仓库地址替换为实际 GitHub/Gitlink 地址，并确认远程默认分支。

## Roadmap

1. 完善 Gerber 状态机、区域轮廓和 aperture macro。
2. 增加板框闭合、孤立图形、孔环和层间距规则。
3. 增加真实文件 CLI、目录扫描、稳定 JSON schema 与 SARIF 输出。
4. 发布到 mooncakes.io，并补充跨平台 CI 与性能基准。
