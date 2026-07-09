# Containerization

Pi 默认以全部权限运行，但在某些情况下，你可能希望对 Pi 可以写入的目录和拥有的访问权限有更多控制。

有两个常规选项。你可以选择：
1. 在整个隔离环境中运行 `pi` 进程，或者
2. 在主机上运行 `pi`，并将工具执行路由到隔离环境中。

## 选择模式

| 模式 | 隔离什么 | 最适合 | 备注 |
| --- | --- | --- | --- |
| Gondolin 扩展 | 内置工具和 `!` 命令 | 本地 micro-VM 隔离，同时保持认证在主机上 | 参见 [`examples/extensions/gondolin/`](../examples/extensions/gondolin/) |
| 纯 Docker | 在本地容器中运行整个 `pi` 进程 | 简单的本地隔离 | 提供商 API 密钥会进入容器 |
| OpenShell | 在策略控制的沙箱中运行整个 `pi` 进程 | 本地或远程托管的沙箱 | 需要 OpenShell 网关 |

扩展在运行 `pi` 进程的地方运行。如果你在主机上运行带有工具路由扩展的 pi，其他自定义扩展工具仍然在主机上运行，除非它们也委托自己的操作。

## Gondolin

[Gondolin](https://github.com/earendil-works/gondolin) 是一个本地 Linux micro-VM。
当你希望 pi 在主机上运行，但将所有内置工具路由到 VM 中时，使用[示例扩展](../examples/extensions/gondolin)。

配置：

```bash
cp -R packages/coding-agent/examples/extensions/gondolin ~/.pi/agent/extensions/gondolin
cd ~/.pi/agent/extensions/gondolin
npm install --ignore-scripts
```

从要挂载的项目目录运行：

```bash
cd /path/to/project
pi -e ~/.pi/agent/extensions/gondolin
```

扩展将主机 cwd 挂载到 VM 中的 `/workspace`，并重写 `read`、`write`、`edit`、`bash`、`grep`、`find` 和 `ls`。
用户 `!` 命令也被路由到 VM 中。
`/workspace` 下的文件更改会写回到主机。

需求：Node.js >= 23.6.0 用于 `@earendil-works/gondolin`，加上 QEMU（需要通过包管理器安装）。

## 纯 Docker

当你想要最简单的本地容器边界时，可以在 Docker 中运行整个 `pi` 进程。

`Dockerfile.pi`：

```dockerfile
FROM node:24-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git ripgrep \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

WORKDIR /workspace
ENTRYPOINT ["pi"]
```

构建并运行：

```bash
docker build -t pi-sandbox -f Dockerfile.pi .

docker run --rm -it \
  -e ANTHROPIC_API_KEY \
  -v "$PWD:/workspace" \
  -v pi-agent-home:/root/.pi/agent \
  pi-sandbox
```

`-v "$PWD:/workspace"` 将当前目录挂载到容器的 /workspace 中，使得 Docker 内对 `/workspace` 的读写直接影响主机文件，就像 Gondolin 示例中一样。

如果你想要容器本地的设置和会话，请为 `/root/.pi/agent` 使用命名卷。挂载主机的 `~/.pi/agent` 会将主机认证和会话文件暴露给容器。

## OpenShell

当你需要一个带有文件系统、进程、网络、凭证和推理控制的策略控制沙箱时，使用 [NVIDIA OpenShell](https://docs.nvidia.com/openshell/about/overview)。
OpenShell 可以通过由 Docker、Podman 或 VM 运行时支持的本地网关运行沙箱，也可以通过远程 Kubernetes 网关运行。

每个沙箱都需要一个活动的网关。
在创建沙箱之前注册并选择一个：

```bash
openshell gateway add <gateway-url> --name <name>
openshell gateway select <name>
```

在 OpenShell 沙箱内启动 `pi`：

```bash
openshell sandbox create --name pi-sandbox --from pi -- pi
```

在这个模式中，整个 `pi` 进程在沙箱内运行。
内置工具、`!` 命令和扩展工具在 OpenShell 边界内执行。

如果网关是远程的，项目文件不会从主机绑定挂载，这意味着沙箱中的写入不会反映到你的机器上。
在沙箱内克隆仓库或使用 OpenShell 文件传输命令：

```bash
openshell sandbox upload pi-sandbox ./repo /workspace
openshell sandbox download pi-sandbox /workspace/repo ./repo-out
```

OpenShell 提供商可以将原始模型 API 密钥保留在沙箱外部。
当配置了推理路由时，沙箱内的代码可以调用 `https://inference.local`，网关会在上游注入配置的提供商凭证。
如果你想让模型流量使用此路由，请将 Pi 配置为使用相应的 OpenAI 兼容或 Anthropic 兼容端点。
