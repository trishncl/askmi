const { HttpsError } = require("firebase-functions/v2/https");

const EMAIL_RE = /^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$/;
const VALID_ROLES = ["Owner", "Manager", "Cashier"];
const LEGACY_ROLE_ALIASES = { Staff: "Cashier" };
const VALID_STATUSES = ["active", "inactive", "pending"];

function requireString(value, fieldName, { minLength = 1 } = {}) {
  const v = typeof value === "string" ? value.trim() : "";
  if (v.length < minLength) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }
  return v;
}

function requireEmail(value) {
  const v = requireString(value, "Email").toLowerCase();
  if (!EMAIL_RE.test(v)) {
    throw new HttpsError("invalid-argument", "Enter a valid email address.");
  }
  return v;
}

function requireRole(value) {
  const normalized = LEGACY_ROLE_ALIASES[value] || value;
  if (!VALID_ROLES.includes(normalized)) {
    throw new HttpsError("invalid-argument", "Role must be Owner, Manager, or Cashier.");
  }
  return normalized;
}

function requireStatus(value) {
  if (!VALID_STATUSES.includes(value)) {
    throw new HttpsError("invalid-argument", "Invalid status.");
  }
  return value;
}

function requireBranch(role, branch) {
  const needsBranch = role === "Manager" || role === "Cashier";
  const b = typeof branch === "string" ? branch.trim() : "";
  if (needsBranch && (!b || b === "All Branches")) {
    throw new HttpsError(
      "invalid-argument",
      "A branch assignment is required for Manager and Cashier roles."
    );
  }
  return needsBranch ? b : "All Branches";
}

function requirePassword(value) {
  const v = typeof value === "string" ? value : "";
  if (v.length < 8 || !/[A-Za-z]/.test(v) || !/[0-9]/.test(v)) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 8 characters and include a letter and a number."
    );
  }
  return v;
}

module.exports = {
  requireString,
  requireEmail,
  requireRole,
  requireStatus,
  requireBranch,
  requirePassword,
};