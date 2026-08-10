# MoonBit PCB 制造数据解析与检查工具

**项目标识**：`moonbit-gerberkit`  
**项目类型**：原创 MoonBit 开发工具  
**GitHub**：[Mgk789a/moonbit-gerberkit](https://github.com/Mgk789a/moonbit-gerberkit)  
**Gitlink**：[Mgk789a/moonbit-gerberkit](https://gitlink.org.cn/Mgk789a/moonbit-gerberkit)

## 项目简介

本项目面向 PCB 制造、开源硬件协作和持续集成场景，将 Gerber RS-274X 与 Excellon 钻孔文件解析为统一的 PCB 几何中间表示，帮助开发者在提交生产前发现常见制造风险。工具输出 JSON、SVG 和简化 ASCII 预览，既适合 CI 消费，也方便人工快速查看。

## 目标与价值

现有 PCB 设计软件通常关注编辑和布线，制造文件在进入工厂前仍缺少轻量、可脚本化、可复用的静态检查入口。本项目以 MoonBit 为主要实现语言，提供可嵌入库 API 和命令行工具，降低开源硬件项目进行制造数据预检的门槛，并为 MoonBit 工具生态补充一个实际工程方向。

## 核心功能

1. 解析 Gerber 常用单位、坐标、光圈、D01 绘线和 D03 闪点。
2. 解析 Excellon 单位、刀具直径和钻孔坐标。
3. 统一表示线路、焊盘、区域、钻孔、层、单位与包围盒。
4. 支持单位换算、层统计、几何范围计算和 JSON/SVG/ASCII 输出。
5. 提供空层、极小线宽和异常小孔等基础 DFM 规则检查。

## 实施范围与路线

首期完成解析器、几何中间表示、规则检查器、渲染器、测试夹具、可运行示例和 CI。后续增加完整 Gerber 状态机、Aperture Macro、区域轮廓、板框闭合、铜皮间距、阻焊桥、孔环、SARIF 输出和目录批处理。项目不实现完整 PCB 布线器，也不复制其他项目的实现代码。

## 交付与维护

仓库提供 Apache-2.0 许可证、中文 README、公开 API 接口快照、GitHub Actions 检查流程和持续可追踪的 Git 提交。解析、几何、规则和输出模块相互解耦，便于长期增加格式能力与规则集；测试覆盖 Gerber、Excellon、统计、包围盒及输出契约。
