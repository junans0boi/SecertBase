export const normalizeCoupleUserId = (value) => {
  const userId = Number(value);
  return Number.isInteger(userId) && userId > 0 ? userId : null;
};

export const isCoupleMember = (couple, userId) => {
  const normalizedUserId = normalizeCoupleUserId(userId);
  if (!couple || !normalizedUserId) return false;
  return (
    Number(couple.User1Id) === normalizedUserId ||
    Number(couple.User2Id) === normalizedUserId
  );
};

export const partnerIdForCouple = (couple, userId) => {
  if (!isCoupleMember(couple, userId)) return null;
  return Number(couple.User1Id) === Number(userId)
    ? Number(couple.User2Id)
    : Number(couple.User1Id);
};
