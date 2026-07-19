const { db, FieldValue } = require("./admin");

/**
 * Writes one entry to `user_activity`. This is the ONLY writer of that
 * collection — Firestore rules deny client writes to it entirely (see
 * firestore.rules), so every entry here is guaranteed to have actually
 * come from a Cloud Function, not something the app faked locally.
 */
async function logActivity({
  action,
  targetUid,
  targetName,
  administratorUid,
  administratorName,
  branch,
  notes = "",
}) {
  await db.collection("user_activity").add({
    action,
    target_uid: targetUid,
    target_name: targetName,
    administrator_uid: administratorUid,
    administrator_name: administratorName,
    branch: branch || "All Branches",
    notes,
    created_at: FieldValue.serverTimestamp(),
  });
}

module.exports = { logActivity };