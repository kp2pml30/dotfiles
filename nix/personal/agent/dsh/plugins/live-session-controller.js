// The slice of the web app's sessionController that dsh-schedule delivers through.
// Only sessions live in this process resolve; a reminder for a closed one is not
// acknowledged, and dsh-schedule retries it on its next drive (e.g. restart).
import { Service } from '@deepseek-ai/cordis'

export default class LiveSessionController extends Service {
	static inject = ['agents']

	constructor(ctx) {
		super(ctx, 'sessionController')
	}

	async resolveAgent(sessionId) {
		const agent = this.ctx.agents.get(sessionId)
		return agent === undefined
			? { error: new Error(`session ${sessionId} is not open in this dsh process`) }
			: { agent }
	}
}
