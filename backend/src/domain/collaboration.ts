import { Prisma, type PrismaClient } from "@prisma/client";

type Tx = Prisma.TransactionClient | PrismaClient;

export type AccessRole = "owner" | "editor" | "viewer" | null;

export type UserSummary = {
  id: bigint;
  email: string;
  name: string;
};

export type UserDirectory = Map<string, UserSummary>;

type CollaboratedRecord = {
  createdBy?: bigint | null;
  createdAt?: Date | null;
  updatedAt?: Date | null;
  isSensitive?: boolean | null;
};

export const userSummarySelect = {
  id: true,
  email: true,
  name: true,
} satisfies Prisma.UserSelect;

export function buildUserDirectory(users: UserSummary[]) {
  const directory: UserDirectory = new Map();
  for (const user of users) {
    directory.set(user.id.toString(), user);
  }
  return directory;
}

export function userFromDirectory(
  directory: UserDirectory | undefined,
  userId: bigint | null | undefined,
) {
  if (!userId) return null;
  return directory?.get(userId.toString()) ?? null;
}

export function normalizeSensitiveFlag(body: Record<string, unknown>) {
  return (
    body.isSensitive === true ||
    body.sensitive === true ||
    body.visibility === "private"
  );
}

export function canViewSensitiveRecord(args: {
  accessRole: AccessRole;
  viewerId: bigint;
  createdBy?: bigint | null;
  isSensitive?: boolean | null;
}) {
  if (!args.isSensitive) return true;
  if (args.accessRole === "owner" || args.accessRole === "editor") return true;
  return args.createdBy === args.viewerId;
}

export function sensitiveRecordWhere(accessRole: AccessRole, viewerId: bigint) {
  if (accessRole === "owner" || accessRole === "editor") return {};
  return {
    OR: [{ isSensitive: false }, { createdBy: viewerId }],
  };
}

export function collaborationMeta(args: {
  record: CollaboratedRecord;
  viewerId: bigint;
  accessRole: AccessRole;
  users?: UserDirectory;
}) {
  const createdBy = args.record.createdBy ?? null;
  const author = userFromDirectory(args.users, createdBy);
  const isMine = createdBy === args.viewerId;
  const isSensitive = args.record.isSensitive === true;
  const createdAt = args.record.createdAt ?? null;
  const updatedAt = args.record.updatedAt ?? null;
  const changed =
    createdAt !== null &&
    updatedAt !== null &&
    Math.abs(updatedAt.getTime() - createdAt.getTime()) > 1000;

  return {
    author: author
      ? { id: author.id, email: author.email, name: author.name }
      : null,
    authorLabel: createdBy
      ? isMine
        ? "나"
        : author?.name ?? "가족 구성원"
      : "작성자 미상",
    isMine,
    isSensitive,
    visibility: isSensitive ? "private" : "family",
    changeState: changed ? "updated" : "created",
    historyLabel: changed ? "수정됨" : "작성됨",
    createdAt,
    updatedAt,
    accessRole: args.accessRole,
  };
}

export function assignmentMeta(args: {
  assignedTo?: bigint | null;
  fallbackUserId?: bigint | null;
  viewerId: bigint;
  users?: UserDirectory;
}) {
  const responsibleUserId = args.assignedTo ?? args.fallbackUserId ?? null;
  const responsible = userFromDirectory(args.users, responsibleUserId);
  return {
    responsibleUserId,
    responsibleUser: responsible
      ? { id: responsible.id, email: responsible.email, name: responsible.name }
      : null,
    responsibleLabel: responsibleUserId
      ? responsibleUserId === args.viewerId
        ? "나"
        : responsible?.name ?? "가족 구성원"
      : "담당자 미지정",
    responsibilitySource: args.assignedTo
      ? "assignee"
      : args.fallbackUserId
        ? "creator"
        : "none",
  };
}

export async function writeAuditEvent(
  tx: Tx,
  args: {
    dogId: bigint;
    actorId: bigint;
    entityType: string;
    entityId?: bigint | null;
    action: string;
    summary?: string | null;
    metadata?: Prisma.InputJsonValue;
  },
) {
  await tx.recordAuditEvent.create({
    data: {
      dogId: args.dogId,
      actorId: args.actorId,
      entityType: args.entityType,
      entityId: args.entityId ?? null,
      action: args.action,
      summary: args.summary ?? null,
      metadata:
        args.metadata === undefined ? Prisma.JsonNull : args.metadata,
    },
  });
}
