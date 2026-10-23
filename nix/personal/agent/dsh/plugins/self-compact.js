// Model-facing compaction. dsh only compacts an idle agent, so the tool queues
// the request and the agent compacts once its turn ends, then gets `resume` back.
import { defineTool } from '@deepseek-ai/dsh-tools'
import { createUserMessage } from '@deepseek-ai/dsh-llm'

export const name = 'self-compact'
export const inject = ['tools', 'agents', 'agentPresets']

const RESUME_FALLBACK = 'Context compacted. Continue the task you were working on.'

export function apply(ctx) {
	// session id → resume text; survives agent-loop reloads, unlike the agent object
	const pending = new Map()
	const abort = new AbortController()

	const live = agent => ctx.agents.get(agent.session.id) === agent

	async function compact(agent, resume) {
		const compaction = ctx.agentPresets.serviceFor(agent, 'compaction')
		let note = ''
		if (compaction === undefined) {
			note = ' (compaction is unavailable in this preset)'
		} else {
			try {
				const result = await compaction.compactNow(agent, abort.signal)
				if (result === null) note = ' (nothing was compactable yet)'
			} catch (error) {
				if (abort.signal.aborted || error?.code === 'cancelled') return
				if (error?.code === 'busy' && agent.status !== 'idle') {
					// new input won the race; the turn it started ends in another idle
					pending.set(agent.session.id, resume)
					return
				}
				ctx.logger.warn(`self-compact: compaction failed: ${error}`)
				note = ` (compaction failed: ${error instanceof Error ? error.message : String(error)})`
			}
		}
		if (!live(agent)) return
		agent.followup(createUserMessage({
			content: [{ type: 'text', text: (resume ?? RESUME_FALLBACK) + note }],
			source: { kind: 'self-compact' },
		}))
	}

	ctx.on('agent/status', ({ agent, status }) => {
		const id = agent.session.id
		if (status !== 'idle' || !pending.has(id)) return
		const resume = pending.get(id)
		pending.delete(id)
		void compact(agent, resume)
	})
	// an aborted or failed turn drops its request instead of compacting and resuming
	ctx.on('agent/error', ({ agent }) => { pending.delete(agent.session.id) })
	ctx.on('agent/disposed', ({ agent }) => {
		if (!live(agent)) pending.delete(agent.session.id)
	})

	ctx.effect(function* () {
		yield () => { abort.abort() }
	}, 'self-compact lifecycle')

	ctx.tools.register(defineTool({
		name: 'compact_context',
		description:
			'Condense older conversation history into a summary to free context window, e.g. before a long '
			+ 'new phase of work or when earlier exploration is no longer needed. Compaction runs after the '
			+ 'current turn ends, so end the turn right after calling this. `resume` comes back to you as the '
			+ 'next message once compaction is done: put there what to continue with.',
		parameters: {
			resume: {
				type: 'string',
				description: 'Instruction to continue with after compaction; defaults to continuing the current task.',
			},
		},
		output: {
			schema: {
				type: 'object',
				additionalProperties: false,
				properties: { scheduled: { type: 'boolean', required: true } },
			},
			render: () => [{ type: 'text', text: 'Compaction scheduled; end this turn now.' }],
		},
		execute(args, exec) {
			if (!exec.agent) throw new Error('compact_context requires an owning agent session')
			const resume = args.resume?.trim()
			pending.set(exec.agent.session.id, resume === undefined || resume === '' ? undefined : resume)
			return { scheduled: true }
		},
	}))
}
