-- CreateTable
CREATE TABLE "dog_memberships" (
    "id" BIGSERIAL NOT NULL,
    "dog_id" BIGINT NOT NULL,
    "user_id" BIGINT NOT NULL,
    "role" VARCHAR(20) NOT NULL DEFAULT 'viewer',
    "status" VARCHAR(20) NOT NULL DEFAULT 'active',
    "invited_by" BIGINT,
    "joined_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "dog_memberships_pkey" PRIMARY KEY ("id")
);

-- Backfill existing primary owners as active owner memberships.
INSERT INTO "dog_memberships" (
    "dog_id",
    "user_id",
    "role",
    "status",
    "joined_at",
    "created_at",
    "updated_at"
)
SELECT
    "id",
    "primary_owner_id",
    'owner',
    'active',
    "created_at",
    "created_at",
    "updated_at"
FROM "dogs"
;

-- CreateIndex
CREATE UNIQUE INDEX "dog_memberships_dog_id_user_id_key" ON "dog_memberships"("dog_id", "user_id");
CREATE INDEX "idx_dog_memberships_user_status" ON "dog_memberships"("user_id", "status");
CREATE INDEX "idx_dog_memberships_dog_role" ON "dog_memberships"("dog_id", "role");

-- AddForeignKey
ALTER TABLE "dog_memberships" ADD CONSTRAINT "dog_memberships_dog_id_fkey" FOREIGN KEY ("dog_id") REFERENCES "dogs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "dog_memberships" ADD CONSTRAINT "dog_memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
