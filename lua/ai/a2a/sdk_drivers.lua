-- /qompassai/Diver/lua/ai/a2a/sdk_drivers.lua
-- Qompass AI A2A SDK Drivers (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- One driver per official A2A SDK language. Each driver is a small
-- program written in the target language that uses the SDK's own
-- documented client API; the op to run (card, send, stream, get,
-- cancel) arrives as the first argument, the agent base URL second,
-- and the message text or task id third. Script-kind drivers run
-- straight under the language runtime; project-kind drivers
-- (compiled languages) get a cached scaffold under stdpath('cache')
-- that is initialized once and reused.
--
-- API sources (verified 2026-09-25 against the official repos):
--   python:     a2aproject/a2a-python, a2a-sdk 1.1.5 (src/a2a/client/client.py)
--   typescript: a2aproject/a2a-js, @a2a-js/sdk 1.2.1 (src/client/, src/samples/cli.ts)
--   go:         a2aproject/a2a-go, module github.com/a2aproject/a2a-go/v2 (a2aclient/)
--   java:       a2aproject/a2a-java, 1.3.2.Final (client/base, client/transport/jsonrpc)
--   dotnet:     a2aproject/a2a-dotnet (src/A2A/Client/IA2AClient.cs)
-- Where the docs were ambiguous the assumption is marked inline.

local M = {}

---@class A2aSdkDriver
---@field kind 'script'|'project'
---@field argv string[] script: runtime prefix; project: command run in the project dir.
---@field ext string script: temp file extension.
---@field args_via 'argv'|'env' How op args reach the driver.
---@field build fun(): string|table<string,string> script: program source;
---  project: relative-path -> file content for the whole scaffold.
---@field init_argv? string[] project: one-time setup command, run in the project dir.
---@field managed? string[] project: relative paths owned by the package
---  manager after init (e.g. go.mod/go.sum); never rewrite them once
---  they exist, or the dependency state init created is wiped.

-- Python -----------------------------------------------------------------
local function python_source()
    return [[
import asyncio
import sys

OP = sys.argv[1]


async def _card(base_url):
    import httpx
    from a2a.client import A2ACardResolver

    async with httpx.AsyncClient() as http:
        resolver = A2ACardResolver(httpx_client=http, base_url=base_url)
        card = await resolver.get_agent_card()
    try:
        from google.protobuf.json_format import MessageToJson

        print(MessageToJson(card))
    except Exception:
        print(str(card))


async def _client(base_url, streaming):
    import httpx
    from a2a.client import A2ACardResolver, ClientConfig, create_client

    async with httpx.AsyncClient() as http:
        resolver = A2ACardResolver(httpx_client=http, base_url=base_url)
        card = await resolver.get_agent_card()
    return await create_client(agent=card, client_config=ClientConfig(streaming=streaming))


async def _send(base_url, text, streaming):
    from a2a.helpers import new_text_message
    from a2a.types import Role, SendMessageRequest

    client = await _client(base_url, streaming)
    try:
        request = SendMessageRequest(message=new_text_message(text, role=Role.ROLE_USER))
        async for chunk in client.send_message(request):
            print(chunk)
    finally:
        await client.close()


async def _get(base_url, task_id):
    from a2a.types.a2a_pb2 import GetTaskRequest

    client = await _client(base_url, False)
    try:
        print(await client.get_task(GetTaskRequest(id=task_id)))
    finally:
        await client.close()


async def _cancel(base_url, task_id):
    # NOTE: CancelTaskRequest's field name is not shown in the SDK docs;
    # mirrors GetTaskRequest(id=...) per the a2aproject issue thread.
    from a2a.types.a2a_pb2 import CancelTaskRequest

    client = await _client(base_url, False)
    try:
        print(await client.cancel_task(CancelTaskRequest(id=task_id)))
    finally:
        await client.close()


async def _main():
    if OP == "card":
        await _card(sys.argv[2])
    elif OP == "send":
        await _send(sys.argv[2], sys.argv[3], False)
    elif OP == "stream":
        await _send(sys.argv[2], sys.argv[3], True)
    elif OP == "get":
        await _get(sys.argv[2], sys.argv[3])
    elif OP == "cancel":
        await _cancel(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit("unknown op: " + OP)


asyncio.run(_main())
]]
end

M.python = {
    kind = 'script',
    argv = { 'python3' },
    ext = '.py',
    args_via = 'argv',
    build = python_source,
}

-- TypeScript --------------------------------------------------------------
-- Runs under plain node from Neovim's cwd so a project-local
-- `npm install @a2a-js/sdk` resolves.
local function typescript_source()
    return [[
// op: card | send | stream | get | cancel
import { ClientFactory, ClientFactoryOptions } from '@a2a-js/sdk/client';
import { Role } from '@a2a-js/sdk';

const [op, baseUrl, extra] = process.argv.slice(2);
const factory = new ClientFactory(ClientFactoryOptions.default);

function messageParams(text) {
  return {
    tenant: '',
    message: {
      messageId: crypto.randomUUID(),
      role: Role.ROLE_USER,
      parts: [{ content: { $case: 'text', value: text }, mediaType: 'text/plain' }],
    },
    configuration: { acceptedOutputModes: ['text/plain'] },
    metadata: {},
  };
}

if (op === 'card') {
  // Mirrors what createFromUrl fetches before picking a transport.
  const res = await fetch(baseUrl.replace(/\/+$/, '') + '/.well-known/agent-card.json');
  console.log(await res.text());
} else if (op === 'send') {
  const client = await factory.createFromUrl(baseUrl);
  console.dir(await client.sendMessage(messageParams(extra)), { depth: 8 });
} else if (op === 'stream') {
  const client = await factory.createFromUrl(baseUrl);
  for await (const event of client.sendMessageStream(messageParams(extra))) {
    console.log(event.payload.$case, event.payload.value);
  }
} else if (op === 'get') {
  const client = await factory.createFromUrl(baseUrl);
  console.dir(await client.getTask({ id: extra, tenant: '' }), { depth: 8 });
} else if (op === 'cancel') {
  const client = await factory.createFromUrl(baseUrl);
  console.dir(await client.cancelTask({ id: extra, tenant: '' }), { depth: 8 });
} else {
  throw new Error('unknown op: ' + op);
}
]]
end

M.typescript = {
    kind = 'script',
    argv = { 'node' },
    ext = '.mjs',
    args_via = 'argv',
    build = typescript_source,
    cwd = 'nvim',
}

-- Go ----------------------------------------------------------------------
local function go_files()
    return {
        ['go.mod'] = 'module a2adriver\n\ngo 1.26.0\n',
        ['main.go'] = [[
package main

import (
	"context"
	"fmt"
	"os"

	"github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2aclient/agentcard"
)

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: driver <op> <base-url> [text|task-id]")
		os.Exit(2)
	}
	op, base, extra := os.Args[1], os.Args[2], ""
	if len(os.Args) > 3 {
		extra = os.Args[3]
	}
	ctx := context.Background()
	if op == "card" {
		card, err := agentcard.DefaultResolver.Resolve(ctx, base)
		if err != nil {
			fatal(err)
		}
		fmt.Printf("%+v\n", card)
		return
	}
	card, err := agentcard.DefaultResolver.Resolve(ctx, base)
	if err != nil {
		fatal(err)
	}
	client, err := a2aclient.NewFromCard(ctx, card,
		a2aclient.WithConfig(a2aclient.Config{
			PreferredTransports: []a2a.TransportProtocol{
				a2a.TransportProtocolJSONRPC,
			},
		}))
	if err != nil {
		fatal(err)
	}
	msg := a2a.NewMessage(a2a.MessageRoleUser, a2a.NewTextPart(extra))
	req := &a2a.SendMessageRequest{Message: msg}
	switch op {
	case "send":
		result, err := client.SendMessage(ctx, req)
		if err != nil {
			fatal(err)
		}
		fmt.Printf("%+v\n", result)
	case "stream":
		for event, err := range client.SendStreamingMessage(ctx, req) {
			if err != nil {
				fatal(err)
			}
			fmt.Printf("%T %+v\n", event, event)
		}
	case "get":
		task, err := client.GetTask(ctx, &a2a.GetTaskRequest{ID: a2a.TaskID(extra)})
		if err != nil {
			fatal(err)
		}
		fmt.Printf("%+v\n", task)
	case "cancel":
		task, err := client.CancelTask(ctx, &a2a.CancelTaskRequest{ID: a2a.TaskID(extra)})
		if err != nil {
			fatal(err)
		}
		fmt.Printf("%+v\n", task)
	default:
		fmt.Fprintln(os.Stderr, "unknown op: "+op)
		os.Exit(2)
	}
}
]],
    }
end

M.go = {
    kind = 'project',
    argv = { 'go', 'run', '.' },
    ext = '.go',
    args_via = 'argv',
    build = go_files,
    -- go mod tidy resolves the imports in main.go and writes a
    -- complete go.sum; a bare `go get <module>` leaves go.sum
    -- short of the transitive build deps.
    init_argv = { 'go', 'mod', 'tidy' },
    -- go.mod/go.sum are package-manager-owned after init.
    managed = { 'go.mod', 'go.sum' },
}

-- Java ----------------------------------------------------------------------
local function java_files()
    return {
        ['pom.xml'] = [[
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>ai.qompass</groupId>
  <artifactId>a2a-driver</artifactId>
  <version>1.0.0</version>
  <properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.a2aproject.sdk</groupId>
      <artifactId>a2a-java-sdk-client</artifactId>
      <version>1.3.2.Final</version>
    </dependency>
    <dependency>
      <groupId>org.a2aproject.sdk</groupId>
      <artifactId>a2a-java-sdk-client-transport-jsonrpc</artifactId>
      <version>1.3.2.Final</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>exec-maven-plugin</artifactId>
        <version>3.5.0</version>
      </plugin>
    </plugins>
  </build>
</project>
]],
        ['src/main/java/A2aDriver.java'] = [[
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.function.BiConsumer;
import org.a2aproject.sdk.A2A;
import org.a2aproject.sdk.client.Client;
import org.a2aproject.sdk.client.ClientEvent;
import org.a2aproject.sdk.client.MessageEvent;
import org.a2aproject.sdk.client.transport.jsonrpc.JSONRPCTransport;
import org.a2aproject.sdk.client.transport.jsonrpc.JSONRPCTransportConfigBuilder;
import org.a2aproject.sdk.spec.AgentCard;
import org.a2aproject.sdk.spec.CancelTaskParams;
import org.a2aproject.sdk.spec.Task;
import org.a2aproject.sdk.spec.TaskQueryParams;

public class A2aDriver {
    public static void main(String[] args) throws Exception {
        // Args arrive via A2A_OP / A2A_BASE / A2A_EXTRA: Maven's
        // -Dexec.args would re-split them on spaces.
        List<String> lines = Files.readAllLines(Path.of("args.txt"));
        String op = lines.get(0);
        String base = lines.get(1);
        String extra = lines.size() > 2 ? lines.get(2) : "";
        if (op.equals("card")) {
            System.out.println(A2A.getAgentCard(base));
            return;
        }
        AgentCard card = A2A.getAgentCard(base);
        try (Client client = Client.builder(card)
                .withTransport(JSONRPCTransport.class, new JSONRPCTransportConfigBuilder())
                .build()) {
            switch (op) {
                case "send", "stream" -> {
                    // sendMessage is void: events arrive on the consumers.
                    // Streaming delivery is config-driven on both ends.
                    List<BiConsumer<ClientEvent, AgentCard>> consumers = List.of((event, c) -> {
                        if (event instanceof MessageEvent me) {
                            System.out.println(me.getMessage());
                        } else {
                            System.out.println(event);
                        }
                    });
                    client.sendMessage(A2A.toUserMessage(extra), consumers, null, null);
                }
                case "get" -> {
                    Task task = client.getTask(new TaskQueryParams(extra), null);
                    System.out.println(task);
                }
                case "cancel" -> {
                    // cancelTask takes CancelTaskParams per Client.java;
                    // an older Javadoc example showed TaskIdParams.
                    Task task = client.cancelTask(new CancelTaskParams(extra), null);
                    System.out.println(task);
                }
                default -> throw new IllegalArgumentException("unknown op: " + op);
            }
        }
    }
}
]],
    }
end

M.java = {
    kind = 'project',
    argv = { 'mvn', '-q', 'compile', 'exec:java', '-Dexec.mainClass=A2aDriver' },
    ext = '.java',
    args_via = 'file',
    build = java_files,
}

-- .NET ----------------------------------------------------------------------
local function dotnet_files()
    return {
        ['A2aDriver.csproj'] = [[
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="A2A" Version="*-*" />
  </ItemGroup>
</Project>
]],
        ['Program.cs'] = [[
using System;
using A2A;

// op: card | send | stream | get | cancel
var op = args[0];
var baseUrl = new Uri(args[1]);
var extra = args.Length > 2 ? args[2] : "";

var resolver = new A2ACardResolver(baseUrl);
AgentCard agentCard = await resolver.GetAgentCardAsync();

if (op == "card")
{
    Console.WriteLine(agentCard);
    return;
}

var client = new A2AClient(new Uri(agentCard.SupportedInterfaces[0].Url));

if (op is "send" or "stream")
{
    var request = new SendMessageRequest
    {
        Message = new Message
        {
            MessageId = Guid.NewGuid().ToString("N"),
            Role = Role.User,
            Parts = [Part.FromText(extra)]
        }
    };
    if (op == "send")
    {
        Console.WriteLine(await client.SendMessageAsync(request));
    }
    else
    {
        // NOTE: the samples README names this SendMessageStreamAsync;
        // IA2AClient and the sample code use SendStreamingMessageAsync.
        await foreach (StreamResponse evt in client.SendStreamingMessageAsync(request))
        {
            Console.WriteLine(evt);
        }
    }
}
else if (op == "get")
{
    Console.WriteLine(await client.GetTaskAsync(new GetTaskRequest { Id = extra }));
}
else if (op == "cancel")
{
    Console.WriteLine(await client.CancelTaskAsync(new CancelTaskRequest { Id = extra }));
}
else
{
    throw new ArgumentException("unknown op: " + op);
}
]],
    }
end

M.dotnet = {
    kind = 'project',
    argv = { 'dotnet', 'run', '--' },
    ext = '.cs',
    args_via = 'argv',
    build = dotnet_files,
}

return M
