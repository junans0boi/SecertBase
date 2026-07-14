export const normalizeMapEditorUserId = (value) => {
  const userId = Number(value);
  return Number.isInteger(userId) && userId > 0 ? userId : null;
};

export const canEditMapPin = (pin, editorUserId, editorUserCode = null) => {
  if (!pin || !editorUserId) return false;

  const ownerUserId = normalizeMapEditorUserId(pin.user_id);
  if (ownerUserId) return ownerUserId === editorUserId;

  const ownerUserCode = `${pin.created_by ?? ''}`.trim();
  const currentUserCode = `${editorUserCode ?? ''}`.trim();
  return ownerUserCode.length > 0 && ownerUserCode === currentUserCode;
};
