-- CreateTable
CREATE TABLE "medical_visit_attachments" (
    "id" BIGSERIAL NOT NULL,
    "medical_visit_id" BIGINT NOT NULL,
    "file_type" VARCHAR(30) NOT NULL,
    "file_url" TEXT NOT NULL,
    "original_filename" VARCHAR(255),
    "mime_type" VARCHAR(100),
    "file_size_bytes" INTEGER,
    "uploaded_by" BIGINT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "medical_visit_attachments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_medical_visit_attachments_visit_id" ON "medical_visit_attachments"("medical_visit_id");

-- CreateIndex
CREATE INDEX "idx_medical_visit_attachments_file_type" ON "medical_visit_attachments"("file_type");

-- AddForeignKey
ALTER TABLE "medical_visit_attachments" ADD CONSTRAINT "medical_visit_attachments_medical_visit_id_fkey" FOREIGN KEY ("medical_visit_id") REFERENCES "medical_visits"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "medical_visit_attachments" ADD CONSTRAINT "medical_visit_attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
