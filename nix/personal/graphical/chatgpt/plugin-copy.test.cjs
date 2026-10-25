const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { execFile } = require("node:child_process");
const { promisify } = require("node:util");
const { test } = require("node:test");

async function cleanup(directory) {
	const stat = await fs.lstat(directory);
	if (stat.isSymbolicLink()) return;
	await fs.chmod(directory, stat.mode | 0o200);
	if (stat.isDirectory()) {
		for (const entry of await fs.readdir(directory)) {
			await cleanup(path.join(directory, entry));
		}
	}
}

test("bundled plugin copies are writable without changing sources or symlink targets", async () => {
	const source = await fs.readFile(process.env.CHATGPT_MAIN, "utf8");
	const match = source.match(
		/async function Nie\(e,t\)\{.*?\}(?=async function Ys\()/s,
	);
	assert.ok(match, "upstream bundled-plugin copy helper must still match");
	const copy = new Function("A", "I", "sie", `return (${match[0]});`)(
		{ default: fs },
		{ default: { platform: "linux" } },
		promisify(execFile),
	);
	const root = await fs.mkdtemp(path.join(os.tmpdir(), "chatgpt-plugin-copy-"));
	const original = path.join(root, "source");
	const destination = path.join(root, "destination");
	const external = path.join(root, "external");
	try {
		await fs.mkdir(path.join(original, ".codex-plugin"), { recursive: true });
		await fs.mkdir(path.join(original, "empty"));
		await fs.mkdir(external);
		await fs.writeFile(
			path.join(original, ".codex-plugin", "plugin.json"),
			"{}",
			{ mode: 0o444 },
		);
		await fs.writeFile(path.join(original, "run.sh"), "#!/bin/sh\nexit 0\n", {
			mode: 0o555,
		});
		await fs.writeFile(path.join(external, "untouched"), "outside", {
			mode: 0o444,
		});
		await fs.symlink(external, path.join(original, "linked-directory"));
		await fs.symlink(
			path.join(external, "untouched"),
			path.join(original, "linked-file"),
		);
		await fs.symlink("missing", path.join(original, "dangling"));
		for (const directory of [
			original,
			path.join(original, ".codex-plugin"),
			path.join(original, "empty"),
			external,
		]) {
			await fs.chmod(directory, 0o555);
		}

		await copy(original, destination);
		const mode = async (file) => (await fs.stat(file)).mode & 0o777;
		assert.equal(await mode(destination), 0o755);
		assert.equal(
			await mode(path.join(destination, ".codex-plugin", "plugin.json")),
			0o644,
		);
		assert.equal(await mode(path.join(destination, "run.sh")), 0o755);
		assert.equal(
			await fs.readlink(path.join(destination, "linked-directory")),
			external,
		);
		assert.equal(
			await fs.readlink(path.join(destination, "linked-file")),
			path.join(external, "untouched"),
		);
		assert.equal(
			await fs.readlink(path.join(destination, "dangling")),
			"missing",
		);
		assert.equal(await mode(original), 0o555);
		assert.equal(
			await mode(path.join(original, ".codex-plugin", "plugin.json")),
			0o444,
		);
		assert.equal(await mode(external), 0o555);
		assert.equal(await mode(path.join(external, "untouched")), 0o444);
		await fs.writeFile(
			path.join(destination, ".codex-plugin", "plugin.json"),
			'{"bundledContentVariant":"live-disabled"}',
		);
		await fs.rm(path.join(destination, "empty"), { recursive: true });
	} finally {
		await cleanup(root);
		await fs.rm(root, { recursive: true });
	}
});

test("local executor can rewrite copied read-only MCP configuration", async () => {
	const source = await fs.readFile(process.env.CHATGPT_MAIN, "utf8");
	const match = source.match(
		/async function loe\(\{executorPluginRoot:e,resourcesPath:t\}\)\{.*?\}(?=async function uoe\()/s,
	);
	assert.ok(match, "upstream executor-plugin copy helper must still match");
	const root = await fs.mkdtemp(
		path.join(os.tmpdir(), "chatgpt-executor-copy-"),
	);
	const original = path.join(root, "source");
	const destination = path.join(root, "destination");
	const copy = new Function(
		"A",
		"C",
		"i",
		"Uc",
		"sie",
		"process",
		`return (${match[0]});`,
	)(
		{ default: fs },
		{ default: path },
		{ wi: "local" },
		async () => ({ cwd: original, command: path.join(original, "launch") }),
		promisify(execFile),
		{ platform: "linux" },
	);
	try {
		await fs.mkdir(original);
		await fs.writeFile(path.join(original, ".mcp.json"), "{}", { mode: 0o444 });
		await fs.writeFile(path.join(original, "launch"), "#!/bin/sh\nexit 0\n", {
			mode: 0o555,
		});
		await fs.chmod(original, 0o555);
		for (let run = 0; run < 2; run++) {
			assert.equal(
				await copy({ executorPluginRoot: destination }),
				destination,
			);
			const config = JSON.parse(
				await fs.readFile(path.join(destination, ".mcp.json"), "utf8"),
			);
			assert.equal(config.mcpServers.codex_app.cwd, destination);
			assert.equal(
				config.mcpServers.codex_app.command,
				path.join(destination, "launch"),
			);
			assert.equal(config.mcpServers.codex_app.enabled, true);
		}
		assert.equal(
			await fs.readFile(path.join(original, ".mcp.json"), "utf8"),
			"{}",
		);
		assert.equal(
			(await fs.stat(path.join(original, ".mcp.json"))).mode & 0o777,
			0o444,
		);
		assert.equal(
			(await fs.stat(path.join(destination, "launch"))).mode & 0o777,
			0o755,
		);
	} finally {
		await cleanup(root);
		await fs.rm(root, { recursive: true });
	}
});
