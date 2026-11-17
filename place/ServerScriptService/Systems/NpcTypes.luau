--!strict
-- Shared types of the NPC run pipeline (audit 2.2, session 8): CourseValidationService analysis -> ObstacleTraversalService route ->
-- NPCBrainService steering -> NPCRunService attempt. Tables that carry adapter-specific extras keep a [string]: any indexer.
local Types = {}

export type Step = { kind: string, p: Vector3?, tol: number?, from: Vector3?, need: number?, up: number?, dir: Vector3?, name: string?, [string]: any }
export type Route = { steps: { Step }, goal: Vector3? }
export type Stage = { uid: number, id: string, order: number, weight: number, sameTypeIndex: number, exit: Vector3, entry: Vector3, npc: boolean }
export type Analysis = { version: number, playerPlayable: boolean, npcPlayable: boolean, stages: { Stage }, path: { number },
	lowQuality: boolean, incompatible: { string }, [string]: any }
export type PadEntry = { npcId: string, model: Model, status: string, stage: number?, total: number?, [string]: any }
export type Run = {
	id: string, player: Player, plot: any, pad: number, def: any, model: Model, hum: Humanoid, hrp: BasePart,
	analysis: Analysis, version: number, route: Route, nextStage: number, earned: number, prior: number, startedAt: number,
	ended: boolean, seed: number, forward: Vector3, brain: any, fail: (string, string?) -> (), [string]: any,
}

return Types
