import type { MiceAxis, Op } from '../../schemas';
import type { ContentBundle } from '../content';
import { THREE_CLUES } from '../content/rules';
import type { CampaignState, Risk } from './state';

/** Описание текущего акта из campaign.json. */
export function currentActDef(s: CampaignState, content: ContentBundle) {
  return content.campaign.acts.find((a) => a.act === s.act);
}

export function nextActDef(s: CampaignState, content: ContentBundle) {
  return [...content.campaign.acts].sort((a, b) => a.act - b.act).find((a) => a.act > s.act);
}

/** Операции, которые можно запланировать прямо сейчас. */
export function availableOps(s: CampaignState, content: ContentBundle): Op[] {
  return content.ops.filter((op) => {
    const result = s.op_results[op.op_id];
    const done = result === 'clean' || result === 'tail_missed';
    return (
      op.act <= s.act &&
      op.week <= s.week &&
      !done &&
      !s.planned_ops.includes(op.op_id) &&
      op.requires_targets_unlocked.every((t) => s.targets[t]?.unlocked)
    );
  });
}

/**
 * Есть ли хвост на маршруте этой операции. «Заметив повтор двух примет и вовремя свернув
 * на бытовую легенду, игрок теряет день, но спасает операцию» (GDD, Блок 3): после
 * своевременного отказа повторный выход проходит чисто.
 */
export function tailPresent(s: CampaignState, op: Op): boolean {
  return op.sdr_route.surveillance_present && s.op_results[op.op_id] !== 'aborted';
}

/**
 * Что игрок знает об оси MICE цели. «Гипотеза» — есть хотя бы одна улика,
 * «подтверждено» — три и больше (подсветка на доске MICE, «Правило трёх улик»).
 */
export type AxisKnowledge = 'unknown' | 'hypothesis' | 'confirmed';

export function axisKnowledge(s: CampaignState, content: ContentBundle, targetId: string, axis: MiceAxis): AxisKnowledge {
  const n = content.clues.filter(
    (c) => s.clues.includes(c.clue_id) && c.reveals.some((r) => r.target_id === targetId && r.axis === axis),
  ).length;
  return n === 0 ? 'unknown' : n >= THREE_CLUES ? 'confirmed' : 'hypothesis';
}

export type RiskLevel = 'calm' | 'warning' | 'danger';

export function riskLevel(value: number, content: ContentBundle): RiskLevel {
  const { warning, danger } = content.balance.thresholds;
  return value >= danger ? 'danger' : value >= warning ? 'warning' : 'calm';
}

export function riskLevels(s: CampaignState, content: ContentBundle): Record<Risk, RiskLevel> {
  return {
    sog_heat: riskLevel(s.risks.sog_heat, content),
    mole_hunt: riskLevel(s.risks.mole_hunt, content),
    treasury: riskLevel(s.risks.treasury, content),
    moscow_pressure: riskLevel(s.risks.moscow_pressure, content),
  };
}

export function unreadCables(s: CampaignState): string[] {
  return s.delivered_cables.filter((id) => !s.read_cables.includes(id));
}
