import { describe, expect, it } from "vitest";
import { statusForStageMove } from "./stage-outcome";

const ordinary = { outcome: null };
const won = { outcome: "won" as const };
const lost = { outcome: "lost" as const };

describe("statusForStageMove", () => {
  it("marks a deal won when dropped into the won stage", () => {
    expect(statusForStageMove("open", ordinary, won)).toBe("won");
  });

  it("marks a deal lost when dropped into a lost stage", () => {
    expect(statusForStageMove("open", ordinary, lost)).toBe("lost");
  });

  it("switches won → lost when moved between outcome stages", () => {
    expect(statusForStageMove("won", won, lost)).toBe("lost");
  });

  it("is a no-op when the deal already has the target outcome", () => {
    expect(statusForStageMove("won", ordinary, won)).toBeNull();
  });

  it("reopens a deal dragged out of the won stage", () => {
    expect(statusForStageMove("won", won, ordinary)).toBe("open");
  });

  it("leaves status alone between ordinary stages", () => {
    expect(statusForStageMove("open", ordinary, ordinary)).toBeNull();
    // A deal marked lost from the form keeps that status while moving.
    expect(statusForStageMove("lost", ordinary, ordinary)).toBeNull();
  });

  it("handles stages without an outcome field (pre-060 rows)", () => {
    expect(statusForStageMove("open", {}, {})).toBeNull();
    expect(statusForStageMove("open", undefined, undefined)).toBeNull();
  });
});
