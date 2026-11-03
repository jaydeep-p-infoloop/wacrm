import type { DealStatus, StageOutcome } from "@/types";

interface StageWithOutcome {
  outcome?: StageOutcome | null;
}

/**
 * Status a deal should have after being dragged from `fromStage` to
 * `toStage` on the board. Returns `null` when the status should stay
 * as it is.
 *
 *   - into a won/lost stage            → that outcome
 *   - out of a won/lost stage into an
 *     ordinary stage                   → 'open' (the deal was reopened)
 *   - between ordinary stages          → unchanged (a deal marked
 *                                        won/lost via the form keeps it)
 */
export function statusForStageMove(
  currentStatus: DealStatus | undefined,
  fromStage: StageWithOutcome | undefined,
  toStage: StageWithOutcome | undefined,
): DealStatus | null {
  const target = toStage?.outcome ?? null;
  if (target) {
    return target === currentStatus ? null : target;
  }
  if (fromStage?.outcome && currentStatus && currentStatus !== "open") {
    return "open";
  }
  return null;
}
