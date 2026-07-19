const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { db, auth, FieldValue } = require("../lib/admin");
const { getCallerProfile, assertCanManageTarget } = require("../lib/permissions");
const { logActivity } = require("../lib/activity");
const { defaultPermissionsForRole } = require("../lib/role_permissions");
const {
  requireString,
  requireEmail,
  requireRole,
  requireStatus,
  requireBranch,
  requirePassword,
} = require("../lib/validation");

/**
 * Creates a real Firebase Auth account (never done client-side, per the
 * security brief) and its matching `users/{uid}` Firestore profile.
 *
 * Username uniqueness is enforced with a Firestore transaction against a
 * dedicated `usernames/{username}` reservation doc — this is the piece a
 * plain "query users where username == X" check (as the Flutter form also
 * does, for a fast pre-check) can't fully guarantee, since two callers
 * could race past a query-based check at the same instant. The
 * transaction is the actual source of truth.
 */
const createUserAccount = onCall(async (request) => {
  const caller = await getCallerProfile(request.auth);
  const data = request.data || {};

  const firstName = requireString(data.firstName, "First name");
  const lastName = requireString(data.lastName, "Last name");
  const username = requireString(data.username, "Username", { minLength: 3 });
  const email = requireEmail(data.email);
  const contactNumber = requireString(data.contactNumber, "Contact number");
  const role = requireRole(data.role);
  const branch = requireBranch(role, data.branch);
  const status = requireStatus(data.status || "active");
  const password = requirePassword(data.password);
  const profileImageUrl = typeof data.profileImageUrl === "string" ? data.profileImageUrl.trim() : "";

  assertCanManageTarget(caller, { targetRole: role, targetBranch: branch });

  const usernameRef = db.collection("usernames").doc(username);

  // Reserve the username first. If Auth creation fails below, the
  // reservation is released in the catch block so the name isn't
  // permanently burned by a failed attempt.
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(usernameRef);
    if (existing.exists) {
      throw new HttpsError("already-exists", "Username already exists.");
    }
    tx.set(usernameRef, { reservedAt: FieldValue.serverTimestamp() });
  });

  let uid;
  try {
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: `${firstName} ${lastName}`.trim(),
      disabled: status !== "active",
    });
    uid = userRecord.uid;
  } catch (error) {
    await usernameRef.delete().catch(() => {});
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Email address is already registered.");
    }
    throw new HttpsError("internal", "Could not create the account. Please try again.");
  }

  const now = FieldValue.serverTimestamp();
  await db
    .collection("users")
    .doc(uid)
    .set({
      user_id: uid,
      first_name: firstName,
      last_name: lastName,
      name: `${firstName} ${lastName}`.trim(),
      username,
      email,
      contact_number: contactNumber,
      role,
      branch,
      status,
      active: status === "active",
      profile_image_url: profileImageUrl,
      permissions: defaultPermissionsForRole(role),
      created_at: now,
      updated_at: now,
      created_by: caller.uid,
      updated_by: caller.uid,
      sales_transactions_created: 0,
      inventory_logs_submitted: 0,
    });

  await logActivity({
    action: "User created",
    targetUid: uid,
    targetName: `${firstName} ${lastName}`.trim() || email,
    administratorUid: caller.uid,
    administratorName: caller.name || caller.email,
    branch,
    notes: `Role: ${role}`,
  });

  return { uid };
});

module.exports = { createUserAccount };