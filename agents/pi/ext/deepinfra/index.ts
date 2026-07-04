import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerProvider("deepinfra", {
		baseUrl: "https://api.deepinfra.com/v1/openai",
		apiKey: "$DEEPINFRA_API_KEY",
		api: "openai-completions",
		models: [
			{
				id: "deepseek-ai/DeepSeek-V3.1",
				name: "DeepSeek V3.1",
				reasoning: false,
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 163840,
				maxTokens: 8192,
			},
		],
	});
}
