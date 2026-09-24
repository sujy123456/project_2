# PantryFlow examples

本目录的所有数据均为虚构示例，仅用于演示计划、风险告警和损耗模拟。

## CSV 约定

未来 CLI 的导入命令使用 UTF-8 CSV；数量单位为克，日期使用距计划日的整数天数。

### `lots.csv`

`id,category,storage,received_day,expires_day,grams,state,reference,notes`

### `sites.csv`

`id,name,priority,ambient_grams,chilled_grams,frozen_grams,accepts_prepared_meals`

### `demands.csv`

`id,site_id,category,requested_grams,minimum_grams,delivery_day,priority`

导入器会拒绝空标识符、负数数量、重复标识符、无效站点及到期日早于接收日的批次。
