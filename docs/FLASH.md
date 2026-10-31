# 刷机与首启检查清单（R4A 千兆版 V1）

> 本清单只覆盖本项目的固件。设备必须是 **4A 千兆版 + 5G 射频 MT7612**（`xiaomi,mi-router-4a-gigabit`，非 `-v2`）。
> 原理与完整背景见 `../../小米路由器4A千兆版刷OpenWrt完整教程.md`。

---

## 一、刷机前

- [ ] 已确认 5G 射频是 MT7612，设备标识是 `xiaomi,mi-router-4a-gigabit`（不是 `-v2`）
- [ ] 已装好 breed，能打开 `http://192.168.1.1`
- [ ] 已有整片 Flash 备份 `all_backup.bin`（**16 MB**）
- [ ] 已有原厂 `Factory.bin`（64 KB，含 2.4G/5G 校准）
- [ ] 电脑用**网线**连接 LAN 口，不用 Wi-Fi
- [ ] 固件 SHA-256 与 `sha256sums` 一致
- [ ] 刷机期间不会断电、不会碰网线

> `Factory.bin` 和整片备份至少各存两份（电脑 + 网盘/NAS）。这是变砖后唯一的退路。

---

## 二、刷入

1. 路由器断电 → 按住复位键 → 上电 → 等指示灯闪烁后松开，进入 breed；
2. 浏览器打开 `http://192.168.1.1`；
3. **固件更新** → 选择 `*-xiaomi_mi-router-4a-gigabit-squashfs-sysupgrade.bin`；
4. 首次刷入建议**不保留配置**；
5. 点击刷写，等待 2–5 分钟；
6. 指示灯稳定后访问 `http://192.168.1.1`。

---

## 三、首启检查

登录后（默认 `root`，密码为空）依次执行：

```sh
# 1. 设备标识
cat /tmp/sysinfo/board_name
# 期望：xiaomi,mi-router-4a-gigabit

# 2. 分区表
cat /proc/mtd
# 期望能看到 u-boot / factory / firmware 等分区

# 3. 无线校准
dmesg | grep -iE 'eeprom|mt76|mt7603|mt76x2'
# 不应出现 EEPROM data check failed / invalid EEPROM

# 4. 无线状态与功率
iwinfo
# 2.4G、5G 都应出现；5G 正常约 23 dBm，2.4G 约 20 dBm

# 5. 可写空间
df -h /overlay

# 6. 系统日志
logread | tail -50
```

### 结果判断

| 检查项 | 正常 | 异常处理 |
| --- | --- | --- |
| board_name | `xiaomi,mi-router-4a-gigabit` | 刷错固件，回 breed 重刷 |
| 5G 功率 | 约 23 dBm | 3 dBm + 随机 MAC → 回写 `Factory.bin` |
| 2.4G 功率 | 约 20 dBm | 检查 factory 0x0 校准 |
| overlay 空间 | 有剩余（几 MB） | 装包过多，精简或外挂 U 盘 |
| dmesg | 无 EEPROM 报错 | 按教程 11.3 节处理 |

---

## 四、刷完后建议立即做

- [ ] 设置强 root 密码
- [ ] 关闭 WAN 侧 Web/SSH 管理
- [ ] Wi-Fi 改 WPA2/WPA3 + 强密码，关闭 WPS
- [ ] 改默认 SSID，确认 2.4G/5G 信道不拥塞
- [ ] 需要远程访问再装 ZeroTier，并配置防火墙
- [ ] 导出配置备份：`sysupgrade -b /tmp/backup.tar.gz`
- [ ] 记录本次固件的 `sha256sums` 和 `config.buildinfo`

---

## 五、R4A 的两个特殊点

### 1. 固件在 `0x180000`

R4A 的 `firmware` 分区起始于 `0x180000`。如果 breed 的自动引导仍然去 `0x50000` 找系统，断电后就起不来。需要在 breed 里固化：

```sh
envconf 0x1e000 0x1000
reset
# 重新进 breed 后
env set autoboot.command "boot flash 0x180000"
env save
reset
```

### 2. factory 在 `0x50000`

64 KB，2.4G 校准在 `0x0`，5G 校准在 `0x8000`。写入错误数据会导致：

- 5G 只有 3 dBm；
- 5G MAC 变成随机地址；
- `dmesg` 报 `EEPROM data check failed`。

修复时必须用**与原厂逐字节一致**的 `Factory.bin` 整块回写，不要用其他机器的校准文件。

---

## 六、回滚

1. 进 breed；
2. **固件备份 → 编程器固件恢复**，选择 `all_backup.bin`；
3. 或者只恢复 `Factory.bin` 修复无线；
4. 恢复后核对 MAC、无线功率、原厂后台是否正常。

> 回滚前先确认备份文件大小和校验值。残缺的备份比没有备份更危险。
