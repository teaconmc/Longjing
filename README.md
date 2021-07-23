# TeaCon Longjing

Make a Cup of Longjing Tea.

We leverage GitHub Actions to provide continuous integration and delivery of all TeaCon 2021 participant mods.

## 工作流程 Workflow

  1. 使用 GitHub Action 的 Cron Trigger，每隔 1 小时触发一次轮询。
     轮询的 Workflow 由 `.github/workflows/query.yaml` 描述。
  2. 轮询的过程为访问[碧螺春](https://github.com/teaconmc/Biluochun)的 API，获取当前有效报名的列表。
     通过 API 拿到报名信息中的队伍名、模组名和 Git Repo 地址，生成对应的信息。
     对于新报名的队伍，将会在 `.github/workflows/` 目录下创建新的 Workflow，并在 `mods` 下创建对应的目录。
     对于已有信息的队伍，将会更新其在 `mods` 目录下的信息（Git Repo 地址、HEAD shasum 等）
  3. 将新建或更新的构建信息推送回本仓库，触发构建和发布。
     构建时，`setup.gradle` 会作为参赛项目的 [Init Script][ref-2] 注入到构建流程中。
  4. 构建成功后，执行 `create_notice.sh` 将必要的信息注入到对应的 Workflow Run 的 Annotations 中。
  5. 同时，另有一个每天运行一次的 Workflow `.github/workflows/pack.yaml` 负责将所有需要的 Mod 整理成符合
     [RemoteSync](https://github.com/teaconmc/RemoteSync) 格式的 Mod 列表，并上传至云端。

[ref-2]: https://docs.gradle.org/current/userguide/init_scripts.html

## 项目结构 Structure

### `query.py`

轮询脚本的主体。

Main/entry script of the scheduled query.

### `workflow_template.yaml`

轮询时自动创建的新 GitHub Action Workflow 的模板，基于 Python 的 [`string.Template`][ref-3]。

Template used for automatically creating new GitHub Action Workflows duringa query. 
Based on Python's [`string.Template`][ref-3].

[ref-3]: https://docs.python.org/3/library/string.html#string.Template

### `auth.sh`

用于 GitHub App 的 Authentication。
在 GitHub Action 中，为防止意外触发无限递归的 Workflow Run，GitHub 默认提供的 `${{ github.TOKEN }}` 不能用于创建新的 Workflow
（即没有 `workflow:write` 权限）。
为此我们需要使用其他身份来推送自动创建的 Workflow，这里我们使用的是我们自己的 GitHub App。

Used for GitHub App Authentication.
In GitHub Action, the default, GitHub-provided `${{ github.TOKEN }}` cannot be used for creating new workflows 
(i.e. does not have `workflow:write` permission), for sake of avoiding accidential recursive workflow runs. 
To automatically create new workflows, we need to autheticate as other identities; here, we authenticate as 
our GitHub App.

### `commit_info.sh`

设定创建并推送新提交时所用的作者信息。

Set author info used for creating and pushing new commits.

### `mods/[team-id]/remote`

指定队伍的 Git 仓库的地址。

Address (URI) pointed to the git repo of the designated team.

### `mods/[team-id]/HEAD`

指定队伍的 Git 仓库的最新提交的校验和。

Checksum of the git repo of the designated team.

### `mods/[team-id]/ref`

（可选）轮询指定队伍的 Git repo 时使用的目标分支的 ref 名。当指定队伍因技术原因不能更改默认分支时可以使用此文件指定其他分支，甚至是标签。

(Optional) The ref name of the branch to query when querying the designated team for updates. 
Useful when the designated team cannot switch the default branch for technical reasons. 
Can also specify a tag ref here.

### `setup.gradle`

构建参赛项目时使用的 [Gradle Init Script][ref-2]，用于自动排查潜在问题、配置（Maven）发布信息等。

[Gradle Init Script][ref-2] used for building participating projects, capable of detecting potential issues 
and configuring (maven) publication information.

### `create_notice.sh`

参赛项目构建成功后使用的脚本，用于将下载链接展示在 Workflow Run 中的 Annotation 中方便有兴趣的玩家下载试玩。

Script used after successfully building participating projects, capable of displaying download link as an 
annotation in the corresponding workflow run, for those who are interested.

### `assemble/list.py`

组装 Mod 列表使用的脚本。

Script used for assembling the final mod list.

### `assemble/blacklist.json`

已知会导致严重问题的构建列表，结构为一个 JSON Object，键为目标项目对应的 Workflow 文件位置，值为所有有问题的构建编号的数组。

List of builds that are known to cause critical failures (e.g. crashes). 
It is a JSON Object: key is the path to the corresponding workflow file, value is an array of build numbers that are known to cause issues.

### `assemble/extra.json`

额外需要追加的 Mod 列表，主要用于提供参赛作品的依赖项目和其他基础 Mod。
结构为一个 JSON Array，每一个元素均如下列格式：

List of extra mods to append, used for providing dependencies and other essential mods. 
It is a JSON Array whose elements are in the following format:

```json
{
  "name": "文件名 / Filename",
  "file": "下载地址（直链） / Download URL (direct)",
  "sha256": "SHA-256 校验和 / SHA-256 checksum"
}
```

对于来自 CurseForge 上的 Mod，请使用基于 `https://media.forgecdn.net/` 的下载地址。

For mods from CurseForge, make sure to use URLs starts with `https://media.forgecdn.net/`.

## 问题反馈 Reporting issue

构建失败不一定意味着被构建的项目有问题，还有可能是龙井系统本身的问题。这样的情况已经出现过不止一次了。
如果你确定龙井本身有问题，欢迎在我们的问题追踪器内反馈。或是直接向我们发起 PR。

A build failure does not implies that the project being built has issue(s); it could very well be an issue inside Longjing. 
There have been cases where issues from Longjing itself cause build failures. 
If you believe that Longjing itself is causing issues, feel free to report in our issue tracker. 
Pull requests are more than welcome.

## 授权许可 License

[BSD-3-Clause](./LICENSE)
