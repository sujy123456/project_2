# PantryFlow 架构与质量边界

## 目标与边界

PantryFlow 为社区食品物资点提供匿名库存调度建议。输入是食品批次、分发站点能力与按品类汇总的需求；输出是可解释的分配计划、审计结果、损耗模拟、库存覆盖预测和策略比较结果。

系统不保存受助者身份、地址、健康信息、支付信息或捐赠者个人资料；不执行食品安全鉴定、召回判断、营养建议或监管申报。运营人员必须依据当地法规和人工质检决定食品是否可分发。

## 数据流

```text
CSV fixtures / API adapter
        │
        ▼
CSV parser → typed importer → domain validation
        │                         │
        ▼                         ▼
FoodLot / DistributionSite / DemandLine ──→ diagnostics
        │
        ▼
FEFO allocation planner → AllocationPlan → independent audit
        │                       │                 │
        ▼                       ▼                 ▼
loss simulation       coverage forecast     actionable findings
        │
        ▼
scenario comparison → operator summary / Markdown report
```

## 核心模块

| 模块 | 职责 | 关键约束 |
|---|---|---|
| `domain` | 领域类型与数量、日期、策略模型 | 数量以克保存；需求按品类聚合 |
| `csv`、`importer` | 确定性 CSV 读取与类型转换 | 拒绝引号字段、缺列及非法数值；保留行号诊断 |
| `validate` | 输入完整性校验 | 空标识、重复标识、无效日期、容量与需求问题 |
| `planner`、`scoring` | FEFO 分配和排序 | 到期日、站点能力、容量、最低保障与品类匹配 |
| `audit` | 独立验证分配计划 | 防止超库存、超需求、超容量、过期交付和站点不匹配 |
| `simulator` | 按日库存/损耗模拟 | 仅模拟已知批次与聚合需求，不预测真实行为 |
| `forecast`、`scenario` | 覆盖风险与策略权衡 | 策略输出供人工比较，不自动替代运营决策 |
| `report`、`summary` | 可复核的文本报告 | 保留计划原因、指标与风险信息 |

## 正确性与失败处理

调度器不是唯一安全边界。导入器对每行解析失败生成诊断；领域校验阻止无效输入进入计划；独立审计再次验证计划结果。任何审计发现都应由调用方作为阻断或人工复核信号处理。

测试覆盖数量下界、FEFO 顺序、容量、预制食品接收限制、无效输入、CSV 错误、导入诊断、审计规则、损耗模拟、覆盖预测和策略比较。CI 固定执行 `moon check`、`moon test`、`moon fmt --check` 与可运行示例。

## 许可证与依赖

项目采用 Apache License 2.0。当前运行时只依赖 MoonBit 标准库；第三方代码、数据和素材状态记录于 `THIRD_PARTY_NOTICES.md`。新增第三方内容前必须记录来源、版本、许可证和兼容性。
