# MoonBit PCB 制造数据解析与检查工具

## 项目目标

`moonbit-gerberkit` 面向开源硬件和 PCB CI，把 Gerber/Excellon 制造文件解析成统一几何中间表示，在送厂前发现空层、极小线宽、异常小孔等常见风险，并输出 JSON、SVG 与 ASCII 预览。

## 方向与范围

这是原创 MoonBit 开发工具，不是现有项目的代码移植。首期覆盖 RS-274X 常用绘图/闪点、Excellon 钻孔、单位归一化、层统计、包围盒和基础 DFM。明确不做完整布线器。

## 技术路线与交付物

按 types → parser → geometry → rules → render 分层实现；提供公开库 API、可运行示例、测试夹具、Apache-2.0 LICENSE、README 和 GitHub Actions CI。后续扩展板框、孔环、铜皮间距与 SARIF。

## 可维护性

解析、检查和输出互不依赖，规则可以独立增加；测试覆盖 Gerber 绘线/闪点、Excellon 钻孔、包围盒和输出格式。所有开发通过可追踪 Git 提交完成。
