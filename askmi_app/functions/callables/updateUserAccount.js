const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, FieldValue } = require("../lib/admin");
const { getCallerProfile, assertCanManageTarget } = require("../lib/permissions");
const { logActivity } = require("../lib/activity");
const { defaultPermissionsForRole } = require("../lib/role_permissions");
const {
  requireString,
  requireRole,
  requireStatus,
  requireBranch,
} = require("../lib/validation");

const updateUserAccount = onCall(async (request) => {
  const caller = await getCallerProfile(request.auth);
  const data = request.data || {};

  const uid = requireString(data.uid, "User");
  const targetRef = db.collection("users").doc(uid);
  const targetSnap = await targetRef.get();
  if (!targetSnap.exists) {
    throw new HttpsError("not-found", "The user account could not be found.");
  }
  const before = targetSnap.data();

  const firstName = requireString(data.firstName, "First name");
  const lastName = requireString(data.lastName, "Last name");
  const username = requireString(data.username, "Username", { minLength: 3 });
  const contactNumber = requireString(data.contactNumber, "Contact number");
  const role = requireRole(data.role);
  const branch = requireBranch(role, data.branch);
  const status = requireStatus(data.status || before.status || "active");
  const profileImageUrl = typeof data.profileImageUrl === "string" ? data.profileImageUrl.trim() : "";

  // Check against BOTH the account's current role/branch and the requested
  // new ones, so a Manager can't use this call to move a user out of, or
  // a user into, a branch/role they don't control.
  assertCanManageTarget(caller, { targetRole: before.role, targetBranch: before.branch });
  assertCanManageTarget(caller, { targetRole: role, targetBranch: branch });

  if (username !== before.username) {
    const usernameRef = db.collection("usernames").doc(username);
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(usernameRef);
      if (existing.exists) {
        throw new HttpsError("already-exists", "Username already exists.");
      }
      tx.set(usernameRef, { reservedAt: FieldValue.serverTimestamp() });
      if (before.username) {
        tx.delete(db.collection("usernames").doc(before.username));
      }
    });
  }

  const roleChanged = role !== before.role;
  const branchChanged = branch !== before.branch;

  await targetRef.update({
    first_name: firstName,
    last_name: lastName,
    name: `${firstName} ${lastName}`.trim(),
    username,
    contact_number: contactNumber,
    role,
    branch,
    status,
    active: status === "active",
    profile_image_url: profileImageUrl,
    // Re-derive permissions from the (possibly new) role rather than
    // trusting a client-supplied permissions map — this is what stops an
    // edit from silently smuggling in elevated permissions.
    permissions: defaultPermissionsForRole(role),
    updated_at: FieldValue.serverTimestamp(),
    updated_by: caller.uid,
  });

  const targetName = `${firstName} ${lastName}`.trim() || before.email;
  await logActivity({
    action: "User updated",
    targetUid: uid,
    targetName,
    administratorUid: caller.uid,
    administratorName: caller.name || caller.email,
    branch,
  });

  if (roleChanged) {
    await logActivity({
      action: "Role changed",
      targetUid: uid,
      targetName,
      administratorUid: caller.uid,
      administratorName: caller.name || caller.email,
      branch,
      notes: `${before.role} -> ${role}`,
    });
  }
  if (branchChanged) {
    await logActivity({
      action: "Branch changed",
      targetUid: uid,
      targetName,
      administratorUid: caller.uid,
      administratorName: caller.name || caller.email,
      branch,
      notes: `${before.branch} -> ${branch}`,
    });
  }

  return {};
});

module.exports = { updateUserAccount };