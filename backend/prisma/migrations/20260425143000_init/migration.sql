-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "users" (
    "id" BIGSERIAL NOT NULL,
    "email" VARCHAR(255) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(20),
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "last_login_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dogs" (
    "id" BIGSERIAL NOT NULL,
    "primary_owner_id" BIGINT NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "breed" VARCHAR(100) NOT NULL,
    "birth_date" DATE,
    "sex" VARCHAR(10) NOT NULL,
    "neutered" BOOLEAN NOT NULL DEFAULT false,
    "current_weight_kg" DECIMAL(5,2),
    "target_weight_kg" DECIMAL(5,2),
    "activity_level" VARCHAR(20) NOT NULL DEFAULT 'medium',
    "insurance_status" VARCHAR(20) NOT NULL DEFAULT 'none',
    "photo_url" TEXT,
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "dogs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dog_conditions" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "condition_type" VARCHAR(30) NOT NULL,
    "condition_name" VARCHAR(100) NOT NULL,
    "severity" VARCHAR(20),
    "diagnosed_on" DATE,
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "dog_conditions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dog_medications" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "medication_name" VARCHAR(120) NOT NULL,
    "dosage" VARCHAR(50),
    "frequency_text" VARCHAR(100),
    "started_on" DATE,
    "ended_on" DATE,
    "prescribed_by" VARCHAR(100),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "dog_medications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "care_schedules" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "schedule_type" VARCHAR(30) NOT NULL,
    "title" VARCHAR(120) NOT NULL,
    "description" TEXT,
    "due_date" DATE NOT NULL,
    "repeat_cycle_days" INTEGER,
    "priority" VARCHAR(20) NOT NULL DEFAULT 'medium',
    "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
    "source_type" VARCHAR(20) NOT NULL DEFAULT 'system',
    "completed_at" TIMESTAMPTZ(6),
    "reminder_enabled" BOOLEAN NOT NULL DEFAULT true,
    "last_reminded_at" TIMESTAMPTZ(6),
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "care_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "health_logs" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "log_type" VARCHAR(30) NOT NULL,
    "title" VARCHAR(120),
    "recorded_at" TIMESTAMPTZ(6) NOT NULL,
    "value_numeric" DECIMAL(10,2),
    "value_unit" VARCHAR(20),
    "memo" TEXT,
    "metadata" JSONB,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "health_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "medical_visits" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "hospital_name" VARCHAR(150) NOT NULL,
    "veterinarian_name" VARCHAR(100),
    "visit_date" TIMESTAMPTZ(6) NOT NULL,
    "visit_reason" VARCHAR(150),
    "symptoms" TEXT,
    "diagnosis" TEXT,
    "treatment" TEXT,
    "prescribed_items" TEXT,
    "follow_up_date" DATE,
    "notes" TEXT,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "medical_visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "expenses" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "medical_visit_id" BIGINT,
    "expense_category" VARCHAR(30) NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "expense_date" DATE NOT NULL,
    "vendor_name" VARCHAR(150),
    "memo" TEXT,
    "receipt_url" TEXT,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cost_forecasts" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "scenario" VARCHAR(20) NOT NULL,
    "monthly_estimate" DECIMAL(12,2) NOT NULL,
    "range_min" DECIMAL(12,2) NOT NULL,
    "range_max" DECIMAL(12,2) NOT NULL,
    "yearly_estimate" DECIMAL(12,2) NOT NULL,
    "six_month_estimate" DECIMAL(12,2) NOT NULL,
    "lifetime_estimate" DECIMAL(14,2) NOT NULL,
    "confidence_level" VARCHAR(20) NOT NULL DEFAULT 'low',
    "breakdown" JSONB NOT NULL DEFAULT '{}',
    "assumptions" JSONB,
    "generated_by" VARCHAR(20) NOT NULL DEFAULT 'system',
    "generated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cost_forecasts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visit_reports" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "report_type" VARCHAR(30) NOT NULL DEFAULT 'vet_visit_summary',
    "title" VARCHAR(150) NOT NULL,
    "summary_json" JSONB NOT NULL,
    "rendered_text" TEXT,
    "pdf_url" TEXT,
    "generated_by" BIGINT,
    "generated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visit_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "idx_dogs_primary_owner_id" ON "dogs"("primary_owner_id");

-- CreateIndex
CREATE INDEX "idx_dogs_breed" ON "dogs"("breed");

-- CreateIndex
CREATE INDEX "idx_dog_conditions_dog_id" ON "dog_conditions"("dog_id");

-- CreateIndex
CREATE INDEX "idx_dog_conditions_type" ON "dog_conditions"("condition_type");

-- CreateIndex
CREATE INDEX "idx_dog_medications_dog_id" ON "dog_medications"("dog_id");

-- CreateIndex
CREATE INDEX "idx_dog_medications_active" ON "dog_medications"("is_active");

-- CreateIndex
CREATE INDEX "idx_care_schedules_dog_id" ON "care_schedules"("dog_id");

-- CreateIndex
CREATE INDEX "idx_care_schedules_due_date" ON "care_schedules"("due_date");

-- CreateIndex
CREATE INDEX "idx_care_schedules_status" ON "care_schedules"("status");

-- CreateIndex
CREATE INDEX "idx_care_schedules_type" ON "care_schedules"("schedule_type");

-- CreateIndex
CREATE INDEX "idx_health_logs_dog_id" ON "health_logs"("dog_id");

-- CreateIndex
CREATE INDEX "idx_health_logs_recorded_at" ON "health_logs"("recorded_at" DESC);

-- CreateIndex
CREATE INDEX "idx_health_logs_type" ON "health_logs"("log_type");

-- CreateIndex
CREATE INDEX "idx_medical_visits_dog_id" ON "medical_visits"("dog_id");

-- CreateIndex
CREATE INDEX "idx_medical_visits_visit_date" ON "medical_visits"("visit_date" DESC);

-- CreateIndex
CREATE INDEX "idx_medical_visits_hospital_name" ON "medical_visits"("hospital_name");

-- CreateIndex
CREATE INDEX "idx_expenses_dog_id" ON "expenses"("dog_id");

-- CreateIndex
CREATE INDEX "idx_expenses_expense_date" ON "expenses"("expense_date" DESC);

-- CreateIndex
CREATE INDEX "idx_expenses_category" ON "expenses"("expense_category");

-- CreateIndex
CREATE INDEX "idx_expenses_medical_visit_id" ON "expenses"("medical_visit_id");

-- CreateIndex
CREATE INDEX "idx_cost_forecasts_dog_id" ON "cost_forecasts"("dog_id");

-- CreateIndex
CREATE INDEX "idx_cost_forecasts_generated_at" ON "cost_forecasts"("generated_at" DESC);

-- CreateIndex
CREATE INDEX "idx_cost_forecasts_scenario" ON "cost_forecasts"("scenario");

-- CreateIndex
CREATE INDEX "idx_visit_reports_dog_id" ON "visit_reports"("dog_id");

-- CreateIndex
CREATE INDEX "idx_visit_reports_generated_at" ON "visit_reports"("generated_at" DESC);

-- AddForeignKey
ALTER TABLE "dogs" ADD CONSTRAINT "dogs_primary_owner_id_fkey" FOREIGN KEY ("primary_owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dog_conditions" ADD CONSTRAINT "dog_conditions_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dog_medications" ADD CONSTRAINT "dog_medications_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "care_schedules" ADD CONSTRAINT "care_schedules_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_logs" ADD CONSTRAINT "health_logs_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "health_logs" ADD CONSTRAINT "health_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medical_visits" ADD CONSTRAINT "medical_visits_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medical_visits" ADD CONSTRAINT "medical_visits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_medical_visit_id_fkey" FOREIGN KEY ("medical_visit_id") REFERENCES "medical_visits"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cost_forecasts" ADD CONSTRAINT "cost_forecasts_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_reports" ADD CONSTRAINT "visit_reports_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visit_reports" ADD CONSTRAINT "visit_reports_generated_by_fkey" FOREIGN KEY ("generated_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

