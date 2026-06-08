# 主页同步巡检 routine — 设计文档

日期：2026-06-08 · 仓库：`claude-skill-hub`（alpha137 内部工作台）

## 目标

让 `claude-skill-hub` 主页（服务 / 演示两栏）跟"真实部署的服务"保持一致：
当服务器上任何一个服务发生变化（新增部署、URL 变更、下线、改名、描述过时），
有一个机制能**自行判断主页是否需要更新**，并**通知**维护者。

## 决策（已与维护者确认）

| 维度 | 决定 |
|---|---|
| 形态 | `/schedule` 创建的 cron 定时远程 agent |
| 频率 | 每 6 小时一次 |
| 范围 | `services.json` + `demos.json`（服务 + 演示） |
| 动作 | **只通知，不自动改、不 push** |
| 真源 | **GitHub 仓库扫描**为主路径；Zeabur API 仅作可选交叉验证 |
| 降噪 | 无可执行差异时**完全静默**，只在发现该改时才通知 |

## 真源：为什么用 GitHub 仓库扫描

每个服务 / demo 仓库的 `CLAUDE.md`（或 `README.md`）里都记录了它的 Zeabur 公开地址
（如 `https://mirrorsea.zeabur.app`、`https://longku-vault.zeabur.app`）。因此"已部署的服务清单"
可以通过 `gh repo list l1mzh0317` + 逐仓库读 `CLAUDE.md` 抓 `*.zeabur.app` URL 得到，
**只依赖 `gh` 鉴权**（远程 routine 环境基本都有），规避远程环境里 Zeabur CLI 鉴权可能缺失的问题。
若运行环境恰好有 Zeabur 鉴权，可额外用 Zeabur API 拉各 project 的 service + domain 做交叉验证。

## 每次运行的流程

1. **取主页现状**：`git pull` 最新 `claude-skill-hub`，读 `services.json` + `demos.json`。
2. **取真实世界真源**：`gh repo list l1mzh0317 --json name,description,isPrivate,pushedAt`；
   对每个仓库读 `CLAUDE.md`/`README.md`，提取其中的 `*.zeabur.app` 公开地址与一句话简介。
3. **对比并自行判断**，找出需要主页响应的偏差：
   - **缺收录**：有已部署且可公开访问的服务 / 可展示 demo，但主页未登记；
   - **失效 / 漂移**：主页某条目的 URL 已变更或无法访问；
   - **下线 / 改名 / 过时**：服务被移除、改名，或标题/描述明显与现状不符。
   - 对每个差异，agent **判断它是否真的值得上主页**：临时测试 / 内部脚手架服务不登记，
     真正面向团队的服务或可展示 demo 才建议收录。判断标准见下。
4. **通知（只通知不改）**：
   - 若有≥1 个可执行差异 → 输出简报：每条差异说明 + 建议动作（加/改/删哪条）+ **可直接粘贴的 json 片段**。
   - 若无差异 → **静默**（不产生通知）。

### "值得上主页"的判断标准

- 收录：有稳定的 `*.zeabur.app` 公开 URL、面向团队使用或可对外展示、非一次性测试。
- 不收录：仓库名/描述含 `test`/`tmp`/`demo-scratch` 等明显临时标记；无公开 URL；fork 的上游项目。
- 服务 vs 演示：交互式在线工具/后端服务 → `services.json`；可截图展示的成品页面 → `demos.json`。

## 输出契约（json 字段，供建议片段对齐渲染器）

- service：`{ name, title, description, url, tags[] }`，可选 `status:"maintenance"` 或 `online:false`。
- demo：`{ name, title, description, url, repo, thumb, tags[] }`（`thumb` 指向 `demos/<name>.jpg`，
  巡检只能建议、无法自动截图，故新 demo 的缩略图仍需人工补）。

## 非目标（YAGNI）

- 不自动编辑 json、不自动 `git push`、不开 PR（本期明确只通知）。
- 不自动截图生成 demo 缩略图。
- 不长期保存巡检历史 / 状态文件；每次运行无状态地重新比对。

## 落地

巡检 prompt 即本设计的可执行形式，通过 `/schedule` 注册为 cron 每 6 小时的 routine，
通知经 routine 的运行输出回传给维护者。
