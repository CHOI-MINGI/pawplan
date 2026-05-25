-- CreateTable
CREATE TABLE "cats" (
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

    CONSTRAINT "cats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_memberships" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
    "user_id" BIGINT NOT NULL,
    "role" VARCHAR(20) NOT NULL DEFAULT 'viewer',
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "invited_by" BIGINT,
    "joined_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_memberships_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_conditions" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
    "condition_type" VARCHAR(30) NOT NULL,
    "condition_name" VARCHAR(100) NOT NULL,
    "severity" VARCHAR(20),
    "diagnosed_on" DATE,
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "notes" TEXT,
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_conditions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_medications" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
    "medication_name" VARCHAR(120) NOT NULL,
    "dosage" VARCHAR(50),
    "frequency_text" VARCHAR(100),
    "started_on" DATE,
    "ended_on" DATE,
    "prescribed_by" VARCHAR(100),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "notes" TEXT,
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_medications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_care_schedules" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
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
    "assigned_to" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_care_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_health_logs" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
    "log_type" VARCHAR(30) NOT NULL,
    "title" VARCHAR(120),
    "recorded_at" TIMESTAMPTZ(6) NOT NULL,
    "value_numeric" DECIMAL(10,2),
    "value_unit" VARCHAR(20),
    "memo" TEXT,
    "metadata" JSONB,
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_health_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_medical_visits" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
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
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_medical_visits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_medical_visit_attachments" (
    "id" BIGSERIAL NOT NULL,
    "medical_visit_id" BIGINT NOT NULL,
    "file_type" VARCHAR(30) NOT NULL,
    "file_url" TEXT NOT NULL,
    "original_filename" VARCHAR(255),
    "mime_type" VARCHAR(100),
    "file_size_bytes" INTEGER,
    "uploaded_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cat_medical_visit_attachments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_expenses" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
    "medical_visit_id" BIGINT,
    "expense_category" VARCHAR(30) NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "expense_date" DATE NOT NULL,
    "vendor_name" VARCHAR(150),
    "memo" TEXT,
    "receipt_url" TEXT,
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "created_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cat_expenses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_cost_forecasts" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
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

    CONSTRAINT "cat_cost_forecasts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cat_visit_reports" (
    "id" BIGSERIAL NOT NULL,
    "cat_id" BIGINT NOT NULL,
    "report_type" VARCHAR(30) NOT NULL DEFAULT 'vet_visit_summary',
    "title" VARCHAR(150) NOT NULL,
    "summary_json" JSONB NOT NULL,
    "rendered_text" TEXT,
    "pdf_url" TEXT,
    "generated_by" BIGINT,
    "generated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cat_visit_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_cats_primary_owner_id" ON "cats"("primary_owner_id");

-- CreateIndex
CREATE INDEX "idx_cats_breed" ON "cats"("breed");

-- CreateIndex
CREATE UNIQUE INDEX "cat_memberships_cat_id_user_id_key" ON "cat_memberships"("cat_id", "user_id");

-- CreateIndex
CREATE INDEX "idx_cat_memberships_user_status" ON "cat_memberships"("user_id", "status");

-- CreateIndex
CREATE INDEX "idx_cat_memberships_cat_role" ON "cat_memberships"("cat_id", "role");

-- CreateIndex
CREATE INDEX "idx_cat_conditions_cat_id" ON "cat_conditions"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_conditions_type" ON "cat_conditions"("condition_type");

-- CreateIndex
CREATE INDEX "idx_cat_medications_cat_id" ON "cat_medications"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_medications_active" ON "cat_medications"("is_active");

-- CreateIndex
CREATE INDEX "idx_cat_care_schedules_cat_id" ON "cat_care_schedules"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_care_schedules_due_date" ON "cat_care_schedules"("due_date");

-- CreateIndex
CREATE INDEX "idx_cat_care_schedules_status" ON "cat_care_schedules"("status");

-- CreateIndex
CREATE INDEX "idx_cat_care_schedules_type" ON "cat_care_schedules"("schedule_type");

-- CreateIndex
CREATE INDEX "idx_cat_health_logs_cat_id" ON "cat_health_logs"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_health_logs_recorded_at" ON "cat_health_logs"("recorded_at" DESC);

-- CreateIndex
CREATE INDEX "idx_cat_health_logs_type" ON "cat_health_logs"("log_type");

-- CreateIndex
CREATE INDEX "idx_cat_medical_visits_cat_id" ON "cat_medical_visits"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_medical_visits_visit_date" ON "cat_medical_visits"("visit_date" DESC);

-- CreateIndex
CREATE INDEX "idx_cat_medical_visits_hospital_name" ON "cat_medical_visits"("hospital_name");

-- CreateIndex
CREATE INDEX "idx_cat_medical_visit_attachments_visit_id" ON "cat_medical_visit_attachments"("medical_visit_id");

-- CreateIndex
CREATE INDEX "idx_cat_medical_visit_attachments_file_type" ON "cat_medical_visit_attachments"("file_type");

-- CreateIndex
CREATE INDEX "idx_cat_expenses_cat_id" ON "cat_expenses"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_expenses_expense_date" ON "cat_expenses"("expense_date" DESC);

-- CreateIndex
CREATE INDEX "idx_cat_expenses_category" ON "cat_expenses"("expense_category");

-- CreateIndex
CREATE INDEX "idx_cat_expenses_medical_visit_id" ON "cat_expenses"("medical_visit_id");

-- CreateIndex
CREATE INDEX "idx_cat_cost_forecasts_cat_id" ON "cat_cost_forecasts"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_cost_forecasts_generated_at" ON "cat_cost_forecasts"("generated_at" DESC);

-- CreateIndex
CREATE INDEX "idx_cat_cost_forecasts_scenario" ON "cat_cost_forecasts"("scenario");

-- CreateIndex
CREATE INDEX "idx_cat_visit_reports_cat_id" ON "cat_visit_reports"("cat_id");

-- CreateIndex
CREATE INDEX "idx_cat_visit_reports_generated_at" ON "cat_visit_reports"("generated_at" DESC);

-- AddForeignKey
ALTER TABLE "cats" ADD CONSTRAINT "cats_primary_owner_id_fkey" FOREIGN KEY ("primary_owner_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_memberships" ADD CONSTRAINT "cat_memberships_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_memberships" ADD CONSTRAINT "cat_memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_conditions" ADD CONSTRAINT "cat_conditions_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_medications" ADD CONSTRAINT "cat_medications_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_care_schedules" ADD CONSTRAINT "cat_care_schedules_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_health_logs" ADD CONSTRAINT "cat_health_logs_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_health_logs" ADD CONSTRAINT "cat_health_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_medical_visits" ADD CONSTRAINT "cat_medical_visits_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_medical_visits" ADD CONSTRAINT "cat_medical_visits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_medical_visit_attachments" ADD CONSTRAINT "cat_medical_visit_attachments_medical_visit_id_fkey" FOREIGN KEY ("medical_visit_id") REFERENCES "cat_medical_visits"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_medical_visit_attachments" ADD CONSTRAINT "cat_medical_visit_attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_expenses" ADD CONSTRAINT "cat_expenses_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_expenses" ADD CONSTRAINT "cat_expenses_medical_visit_id_fkey" FOREIGN KEY ("medical_visit_id") REFERENCES "cat_medical_visits"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_expenses" ADD CONSTRAINT "cat_expenses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_cost_forecasts" ADD CONSTRAINT "cat_cost_forecasts_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_visit_reports" ADD CONSTRAINT "cat_visit_reports_cat_id_fkey" FOREIGN KEY ("cat_id") REFERENCES "cats"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cat_visit_reports" ADD CONSTRAINT "cat_visit_reports_generated_by_fkey" FOREIGN KEY ("generated_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
