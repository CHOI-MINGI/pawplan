import assert from "node:assert/strict";
import {
  assignmentMeta,
  buildUserDirectory,
  canViewSensitiveRecord,
  collaborationMeta,
  normalizeSensitiveFlag,
  sensitiveRecordWhere,
} from "../src/domain/collaboration.js";

const ownerId = 1n;
const editorId = 2n;
const viewerId = 3n;

const users = buildUserDirectory([
  { id: ownerId, email: "owner@pawplan.local", name: "Owner" },
  { id: editorId, email: "editor@pawplan.local", name: "Editor" },
  { id: viewerId, email: "viewer@pawplan.local", name: "Viewer" },
]);

assert.equal(
  normalizeSensitiveFlag({ visibility: "private" }),
  true,
  "private visibility should be treated as sensitive",
);
assert.equal(
  canViewSensitiveRecord({
    accessRole: "viewer",
    viewerId,
    createdBy: ownerId,
    isSensitive: true,
  }),
  false,
  "viewer should not see another guardian's sensitive record",
);
assert.equal(
  canViewSensitiveRecord({
    accessRole: "viewer",
    viewerId,
    createdBy: viewerId,
    isSensitive: true,
  }),
  true,
  "record author should still see their own sensitive record",
);
assert.equal(
  canViewSensitiveRecord({
    accessRole: "editor",
    viewerId: editorId,
    createdBy: ownerId,
    isSensitive: true,
  }),
  true,
  "editor should see sensitive records for the shared dog",
);

const hiddenWhere = sensitiveRecordWhere("viewer", viewerId);
assert.deepEqual(hiddenWhere, {
  OR: [{ isSensitive: false }, { createdBy: viewerId }],
});

const updatedMeta = collaborationMeta({
  record: {
    createdBy: editorId,
    isSensitive: true,
    createdAt: new Date("2026-05-18T00:00:00Z"),
    updatedAt: new Date("2026-05-18T00:10:00Z"),
  },
  viewerId,
  accessRole: "viewer",
  users,
});
assert.equal(updatedMeta.authorLabel, "Editor");
assert.equal(updatedMeta.visibility, "private");
assert.equal(updatedMeta.historyLabel, "수정됨");

const assignee = assignmentMeta({
  assignedTo: editorId,
  fallbackUserId: ownerId,
  viewerId,
  users,
});
assert.equal(assignee.responsibleUser?.name, "Editor");
assert.equal(assignee.responsibilitySource, "assignee");

console.log("Collaboration checks passed");
