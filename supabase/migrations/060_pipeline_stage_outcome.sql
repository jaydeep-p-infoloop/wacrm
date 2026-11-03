-- 060: pipeline_stages.outcome — mark a stage as the "won" / "lost"
-- terminal stage so the board can keep deals.status in sync when a
-- deal is dragged into (or out of) it.
--
-- Before this, moving a deal into the "Won" column only changed
-- stage_id; deals.status stayed 'open', so pipeline analytics and the
-- dashboard (which read status) disagreed with the board.
--
-- Additive and idempotent:
--   * new nullable column, NULL = ordinary stage;
--   * backfill tags only stages that still carry a default "Won" name
--     (en / es / ko / pt — the shipped catalogues), one per pipeline,
--     and never overwrites an outcome that is already set;
--   * no deal rows are modified — the fix applies to future moves.

ALTER TABLE public.pipeline_stages
  ADD COLUMN IF NOT EXISTS outcome TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pipeline_stages_outcome_check'
      AND conrelid = 'public.pipeline_stages'::regclass
  ) THEN
    ALTER TABLE public.pipeline_stages
      ADD CONSTRAINT pipeline_stages_outcome_check
      CHECK (outcome IS NULL OR outcome IN ('won', 'lost'));
  END IF;
END $$;

-- One "won" stage per pipeline (and one "lost").
CREATE UNIQUE INDEX IF NOT EXISTS pipeline_stages_one_outcome_per_pipeline
  ON public.pipeline_stages (pipeline_id, outcome)
  WHERE outcome IS NOT NULL;

-- Backfill: the highest-positioned stage named like a default "Won"
-- stage, in pipelines that don't have a won stage yet.
WITH candidates AS (
  SELECT DISTINCT ON (s.pipeline_id) s.id
  FROM public.pipeline_stages s
  WHERE lower(btrim(s.name)) IN ('won', 'ganado', 'ganho', '성사')
    AND NOT EXISTS (
      SELECT 1 FROM public.pipeline_stages w
      WHERE w.pipeline_id = s.pipeline_id AND w.outcome = 'won'
    )
  ORDER BY s.pipeline_id, s.position DESC
)
UPDATE public.pipeline_stages s
SET outcome = 'won'
FROM candidates c
WHERE s.id = c.id
  AND s.outcome IS NULL;
