CREATE TABLE IF NOT EXISTS PairingRequests (
  PairingRequestId INT AUTO_INCREMENT PRIMARY KEY,
  SenderUserId INT NOT NULL,
  RecipientUserId INT NOT NULL,
  Status ENUM('pending', 'accepted', 'rejected', 'cancelled', 'expired') NOT NULL DEFAULT 'pending',
  ExpiresAt DATETIME NOT NULL,
  RespondedAt DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_pairing_sender_status (SenderUserId, Status, ExpiresAt),
  INDEX idx_pairing_recipient_status (RecipientUserId, Status, ExpiresAt),
  FOREIGN KEY (SenderUserId) REFERENCES Users(UserId),
  FOREIGN KEY (RecipientUserId) REFERENCES Users(UserId)
);
