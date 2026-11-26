import type { ClueSource } from '../../schemas';
import type { ContentBundle } from './types';

export interface SimulationOptions {
  /** Учитывать только контент актов не позже этого. */
  maxAct?: number;
  /** Ветки, которые «провалились»: эти цели нельзя завербовать. */
  failedTargets?: ReadonlySet<string>;
  /** Операции, которые сорваны или отменены. */
  failedOps?: ReadonlySet<string>;
}

export interface SimulationResult {
  clues: Set<string>;
  unlockedTargets: Set<string>;
  recruitedTargets: Set<string>;
  availableOps: Set<string>;
}

/**
 * «Идеальный игрок»: находит всё, что вообще можно найти, повторяя шаги до тех пор,
 * пока что-то меняется. Улики дают доступ к целям, завербованные цели дают новые улики.
 * Если цель акта недостижима даже для идеального игрока, это софтлок.
 */
export function simulate(content: ContentBundle, opts: SimulationOptions = {}): SimulationResult {
  const maxAct = opts.maxAct ?? 4;
  const failedTargets = opts.failedTargets ?? new Set<string>();
  const failedOps = opts.failedOps ?? new Set<string>();

  const cables = new Set(content.cables.filter((c) => c.act <= maxAct).map((c) => c.cable_id));
  const targets = content.targets.filter((t) => t.act <= maxAct);
  const ops = content.ops.filter((o) => o.act <= maxAct && !failedOps.has(o.op_id));

  const state: SimulationResult = {
    clues: new Set(),
    unlockedTargets: new Set(),
    recruitedTargets: new Set(),
    availableOps: new Set(),
  };

  const sourceAvailable = (s: ClueSource): boolean => {
    switch (s.channel) {
      case 'document':
        return cables.has(s.from);
      case 'field':
        return state.availableOps.has(s.from);
      case 'agent':
        return state.recruitedTargets.has(s.from);
    }
  };

  let changed = true;
  while (changed) {
    changed = false;
    const add = (set: Set<string>, id: string) => {
      if (!set.has(id)) {
        set.add(id);
        changed = true;
      }
    };

    for (const op of ops) {
      if (op.requires_targets_unlocked.every((t) => state.unlockedTargets.has(t))) add(state.availableOps, op.op_id);
    }
    for (const clue of content.clues) {
      if (sourceAvailable(clue.source)) add(state.clues, clue.clue_id);
    }
    for (const t of targets) {
      const found = t.unlock.clue_ids.filter((id) => state.clues.has(id)).length;
      if (found >= t.unlock.clues_required) add(state.unlockedTargets, t.target_id);
    }
    for (const t of targets) {
      if (!state.unlockedTargets.has(t.target_id) || failedTargets.has(t.target_id)) continue;
      const axesKnown = t.approach.key_axes.every((axis) =>
        content.clues.some(
          (c) => state.clues.has(c.clue_id) && c.reveals.some((r) => r.target_id === t.target_id && r.axis === axis),
        ),
      );
      if (axesKnown) add(state.recruitedTargets, t.target_id);
    }
  }
  return state;
}
