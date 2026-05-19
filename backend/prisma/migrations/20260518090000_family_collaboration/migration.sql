ALTER TABLE "dog_conditions" ADD COLUMN "is_sensitive" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "dog_conditions" ADD COLUMN "created_by" BIGINT;

ALTER TABLE "dog_medications" ADD COLUMN "is_sensitive" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "dog_medications" ADD COLUMN "created_by" BIGINT;

ALTER TABLE "care_schedules" ADD COLUMN "assigned_to" BIGINT;

ALTER TABLE "health_logs" ADD COLUMN "is_sensitive" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "medical_visits" ADD COLUMN "is_sensitive" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "expenses" ADD COLUMN "is_sensitive" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "record_audit_events" (
  "id" BIGSERIAL NOT NULL,
  "dog_id" BIGINT NOT NULL,
  "actor_id" BIGINT,
  "entity_type" VARCHAR(40) NOT NULL,
  "entity_id" BIGINT,
  "action" VARCHAR(30) NOT NULL,
  "summary" VARCHAR(180),
  "metadata" JSONB,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "record_audit_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_record_audit_events_dog_created" ON "record_audit_events"("dog_id", "created_at" DESC);
CREATE INDEX "idx_record_audit_events_entity" ON "record_audit_events"("entity_type", "entity_id");
CREATE INDEX "idx_record_audit_events_actor" ON "record_audit_events"("actor_id");

ALTER TABLE "record_audit_events"
  ADD CONSTRAINT "record_audit_events_dog_id_fkey"
  FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "record_audit_events"
  ADD CONSTRAINT "record_audit_events_actor_id_fkey"
  FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
